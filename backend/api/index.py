import os
import hmac
import hashlib
import json
import httpx
from datetime import datetime, timezone
from fastapi import FastAPI, Request, Response, HTTPException, Query
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

# --- إعدادات Supabase ---
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# --- إعدادات Meta ---
META_APP_SECRET = os.getenv("META_APP_SECRET")
VERIFY_TOKEN = os.getenv("META_VERIFY_TOKEN")
WA_API_VERSION = os.getenv("WHATSAPP_API_VERSION", "v20.0")

# ==========================================
# 1. التحقق من Webhook (GET)
# ==========================================
@app.get("/api/webhook")
async def verify_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
    hub_verify_token: str = Query(None, alias="hub.verify_token")
):
    if hub_mode == "subscribe" and hub_verify_token == VERIFY_TOKEN:
        return Response(content=hub_challenge, media_type="text/plain")
    raise HTTPException(status_code=403, detail="Verification failed")

# ==========================================
# 2. استقبال الأحداث (POST)
# ==========================================
@app.post("/api/webhook")
async def receive_webhook(request: Request):
    body = await request.body()
    signature = request.headers.get("X-Hub-Signature-256")
    
    # التحقق من التوقيع (موصى به بشدة في الإنتاج)
    if signature and META_APP_SECRET:
        expected_signature = "sha256=" + hmac.new(
            META_APP_SECRET.encode(), body, hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(expected_signature, signature):
            raise HTTPException(status_code=403, detail="Invalid signature")

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    try:
        if payload.get("object") == "whatsapp_business_account":
            await handle_whatsapp(payload)
        elif payload.get("object") == "page":
            await handle_facebook(payload)
    except Exception as e:
        print(f"❌ CRITICAL ERROR: {str(e)}")
        return {"status": "error", "message": str(e)}

    return {"status": "ok"}

# ==========================================
# 3. معالجة رسائل واتساب
# ==========================================
async def handle_whatsapp(payload: dict):
    for entry in payload.get("entry", []):
        for change in entry.get("changes", []):
            value = change.get("value", {})
            metadata = value.get("metadata", {})
            phone_number_id = metadata.get("phone_number_id")
            
            if not phone_number_id:
                continue

            account_res = supabase.table("connected_accounts")\
                .select("id, organization_id, access_token_encrypted")\
                .eq("platform", "whatsapp")\
                .eq("platform_account_id", phone_number_id)\
                .limit(1).execute()

            if not account_res.data:
                print(f"⚠️ WA Account not found for ID: {phone_number_id}")
                continue

            org_id = account_res.data[0]["organization_id"]
            account_id = account_res.data[0]["id"]
            token = account_res.data[0].get("access_token_encrypted") # لو هتحتاجه للرد التلقائي

            contact_name = "عميل واتساب"
            if "contacts" in value and len(value["contacts"]) > 0:
                contact_name = value["contacts"][0].get("profile", {}).get("name", "عميل واتساب")

            # الرسائل الواردة من العميل
            if "messages" in value:
                for msg in value["messages"]:
                    if msg.get("type") != "text":
                        continue
                    
                    sender = msg.get("from")
                    text = msg.get("text", {}).get("body", "")
                    message_id = msg.get("id")
                    
                    await process_incoming_message(
                        org_id, account_id, sender, "whatsapp", text, contact_name, 
                        is_from_agent=False, external_message_id=message_id
                    )
            
            # رسائل الواتساب الصادرة (الـ Echo بتاع الواتساب لو موجود)
            if "statuses" in value:
                # في واتساب، مش بنستقبل echo كامل بنفس الطريقة، لكن لو احتجت تتابع الحالات ممكن تضيفها هنا
                pass

# ==========================================
# 4. معالجة رسائل فيسبوك
# ==========================================
async def handle_facebook(payload: dict):
    for entry in payload.get("entry", []):
        page_id = entry.get("id")
        
        account_res = supabase.table("connected_accounts")\
            .select("id, organization_id, access_token_encrypted")\
            .eq("platform", "facebook")\
            .eq("platform_account_id", page_id)\
            .limit(1).execute()

        if not account_res.data:
            print(f"⚠️ FB Account not found for Page ID: {page_id}")
            continue

        org_id = account_res.data[0]["organization_id"]
        account_id = account_res.data[0]["id"]
        token = account_res.data[0].get("access_token_encrypted")

        for messaging in entry.get("messaging", []):
            sender = messaging.get("sender", {}).get("id")
            recipient = messaging.get("recipient", {}).get("id")
            message = messaging.get("message", {})
            text = message.get("text", "")
            message_id = message.get("mid")
            
            is_echo = message.get("is_echo", False)
            
            if is_echo:
                # دي رسالة صادرة منك (من الموبايل أو من التطبيق)
                participant_id = recipient # العميل هو المستقبل في هذه الحالة
                
                # التأكد إن الرسالة مش متسجلة مسبقاً (لو الـ API بتاعنا هو اللي بعتها)
                if message_id:
                    existing_msg = supabase.table("messages")\
                        .select("id")\
                        .eq("metadata->>external_message_id", message_id)\
                        .limit(1).execute()
                        
                    if not existing_msg.data:
                        await process_incoming_message(
                            org_id, account_id, participant_id, "facebook", text, "عميل فيسبوك", token,
                            is_from_agent=True, external_message_id=message_id
                        )
            else:
                # دي رسالة واردة من العميل
                if sender and text:
                    await process_incoming_message(
                        org_id, account_id, sender, "facebook", text, "عميل فيسبوك", token,
                        is_from_agent=False, external_message_id=message_id
                    )

# ==========================================
# 5. دالة مساعدة: تخزين الرسائل في قاعدة البيانات
# ==========================================
async def process_incoming_message(org_id, account_id, participant_id, platform, text, default_name="عميل جديد", token=None, is_from_agent=False, external_message_id=None):
    try:
        # جلب اسم العميل (بس لو الرسالة جاية منه، مش منك)
        if platform == "facebook" and token and not is_from_agent:
            try:
                async with httpx.AsyncClient() as client:
                    api_url = f"https://graph.facebook.com/{WA_API_VERSION}/{participant_id}?fields=first_name,last_name&access_token={token}"
                    res = await client.get(api_url)
                    if res.status_code == 200:
                        data = res.json()
                        first = data.get("first_name", "")
                        last = data.get("last_name", "")
                        if first or last:
                            default_name = f"{first} {last}".strip()
            except Exception as e:
                print(f"❌ Could not fetch FB name: {e}")

        # البحث عن محادثة موجودة أو إنشاء واحدة
        conv_res = supabase.table("conversations")\
            .select("id")\
            .eq("organization_id", org_id)\
            .eq("connected_account_id", account_id)\
            .eq("platform_thread_id", participant_id)\
            .limit(1).execute()

        if conv_res.data:
            conv_id = conv_res.data[0]["id"]
        else:
            new_conv = supabase.table("conversations").insert({
                "organization_id": org_id,
                "connected_account_id": account_id,
                "platform_thread_id": participant_id,
                "participant_id": participant_id,
                "participant_name": default_name,
                "status": "open"
            }).execute()
            conv_id = new_conv.data[0]["id"]

        # تحديد نوع المرسل (أنت أم العميل)
        sender_type = "agent" if is_from_agent else "customer"

        # تحضير بيانات الرسالة
        msg_data = {
            "organization_id": org_id,
            "conversation_id": conv_id,
            "sender_type": sender_type,
            "content": text,
            "status": "sent" if is_from_agent else "received",
        }
        
        # إضافة الـ metadata لو فيه message_id
        if external_message_id:
            msg_data["metadata"] = {"external_message_id": external_message_id}

        # حفظ الرسالة
        supabase.table("messages").insert(msg_data).execute()

        # تحديث المحادثة بآخر رسالة
        supabase.table("conversations").update({
            "last_message_preview": text[:50],
            "last_message_at": datetime.now(timezone.utc).isoformat()
        }).eq("id", conv_id).execute()
        
        sender_label = "Agent (You)" if is_from_agent else default_name
        print(f"✅ Message saved successfully from {sender_label} ({platform})")

    except Exception as e:
        print(f"❌ Error processing message: {str(e)}")
        raise e

# ==========================================
# 6. دالة إرسال الرسائل (Cron Job)
# ==========================================
@app.get("/api/cron/send-messages")
async def send_pending_messages():
    queue_res = supabase.table("message_queue")\
        .select("*")\
        .eq("status", "pending")\
        .lte("next_attempt_at", datetime.now(timezone.utc).isoformat())\
        .limit(10)\
        .execute()

    processed_count = 0

    for item in queue_res.data:
        try:
            msg_res = supabase.table("messages").select("*").eq("id", item["message_id"]).limit(1).execute()
            if not msg_res.data: continue
            msg = msg_res.data[0]

            conv_res = supabase.table("conversations").select("*").eq("id", msg["conversation_id"]).limit(1).execute()
            if not conv_res.data: continue
            conv = conv_res.data[0]

            acc_res = supabase.table("connected_accounts").select("*").eq("id", conv["connected_account_id"]).limit(1).execute()
            if not acc_res.data: continue
            acc = acc_res.data[0]

            recipient = conv["participant_id"]
            token = acc["access_token_encrypted"]
            text = msg["content"]

            if acc["platform"] == "whatsapp":
                url = f"https://graph.facebook.com/{WA_API_VERSION}/{acc['platform_account_id']}/messages"
                headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
                payload = {
                    "messaging_product": "whatsapp",
                    "to": recipient,
                    "type": "text",
                    "text": {"body": text}
                }
            elif acc["platform"] == "facebook":
                url = f"https://graph.facebook.com/{WA_API_VERSION}/me/messages?access_token={token}"
                headers = {"Content-Type": "application/json"}
                payload = {
                    "recipient": {"id": recipient},
                    "messaging_type": "RESPONSE",
                    "message": {"text": text}
                }
            else:
                continue

            async with httpx.AsyncClient() as client:
                res = await client.post(url, headers=headers, json=payload)
                
                if res.status_code == 200:
                    response_data = res.json()
                    # بنجيب الـ message_id اللي رجع من ميتا عشان نحفظه في الـ metadata
                    # عشان لما الـ Echo ييجي، الكود يعرف إن الرسالة دي اتسجلت خلاص وميكررهاش
                    meta_message_id = response_data.get("message_id")
                    
                    update_data = {"status": "sent"}
                    if meta_message_id:
                        update_data["metadata"] = {"external_message_id": meta_message_id}
                        
                    supabase.table("messages").update(update_data).eq("id", item["message_id"]).execute()
                    supabase.table("message_queue").update({"status": "done"}).eq("id", item["id"]).execute()
                    processed_count += 1
                    print(f"✅ Message sent successfully to {recipient} via {acc['platform']}")
                else:
                    raise Exception(f"Meta API Error: {res.status_code} - {res.text}")

        except Exception as e:
            print(f"Error sending message: {e}")
            supabase.table("message_queue").update({
                "attempts": item["attempts"] + 1,
                "status": "failed" if item["attempts"] >= item["max_attempts"] else "pending",
                "last_error": str(e)[:255]
            }).eq("id", item["id"]).execute()

    return {"status": "done", "processed": processed_count}