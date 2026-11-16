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
    # التحقق من التوقيع
    body = await request.body()
    signature = request.headers.get("X-Hub-Signature-256")
    if signature:
        expected_signature = "sha256=" + hmac.new(
            META_APP_SECRET.encode(), body, hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(expected_signature, signature):
            raise HTTPException(status_code=403, detail="Invalid signature")

    payload = await request.json()
    
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
                print("⚠️ No phone_number_id found in metadata")
                continue

            account_res = supabase.table("connected_accounts")\
                .select("id, organization_id")\
                .eq("platform", "whatsapp")\
                .eq("platform_account_id", phone_number_id)\
                .limit(1).execute()

            if not account_res.data:
                print(f"⚠️ Account not found for phone_number_id: {phone_number_id}")
                continue

            org_id = account_res.data[0]["organization_id"]
            account_id = account_res.data[0]["id"]

            if "messages" in value:
                for msg in value["messages"]:
                    if msg.get("type") != "text":
                        continue
                    
                    sender = msg.get("from")
                    text = msg.get("text", {}).get("body", "")
                    
                    await process_incoming_message(
                        org_id, account_id, sender, "whatsapp", text
                    )

# ==========================================
# 4. معالجة رسائل وكومنتات فيسبوك (مبدئي)
# ==========================================
async def handle_facebook(payload: dict):
    for entry in payload.get("entry", []):
        page_id = entry.get("id")
        
        account_res = supabase.table("connected_accounts")\
            .select("id, organization_id")\
            .eq("platform", "facebook")\
            .eq("platform_account_id", page_id)\
            .limit(1).execute()

        if not account_res.data:
            print(f"⚠️ FB Account not found for page_id: {page_id}")
            continue

        org_id = account_res.data[0]["organization_id"]
        account_id = account_res.data[0]["id"]

        for messaging in entry.get("messaging", []):
            sender = messaging.get("sender", {}).get("id")
            message = messaging.get("message", {})
            text = message.get("text", "")
            
            if sender and text:
                await process_incoming_message(
                    org_id, account_id, sender, "facebook", text
                )

# ==========================================
# 5. دالة مساعدة: تخزين الرسائل في قاعدة البيانات
# ==========================================
async def process_incoming_message(org_id, account_id, participant_id, platform, text):
    try:
        # البحث عن محادثة موجودة
        conv_res = supabase.table("conversations")\
            .select("id")\
            .eq("organization_id", org_id)\
            .eq("connected_account_id", account_id)\
            .eq("platform_thread_id", participant_id)\
            .limit(1).execute()

        if conv_res.data:
            conv_id = conv_res.data[0]["id"]
        else:
            # إنشاء محادثة جديدة لو مش موجودة
            new_conv = supabase.table("conversations").insert({
                "organization_id": org_id,
                "connected_account_id": account_id,
                "platform_thread_id": participant_id,
                "participant_id": participant_id,
                "participant_name": "عميل جديد",
                "status": "open"
            }).execute()
            conv_id = new_conv.data[0]["id"]

        # إضافة الرسالة
        supabase.table("messages").insert({
            "organization_id": org_id,
            "conversation_id": conv_id,
            "sender_type": "customer",
            "content": text,
            "status": "received"
        }).execute()

        # تحديث آخر رسالة في المحادثة
        supabase.table("conversations").update({
            "last_message_preview": text[:50],
            "last_message_at": datetime.now(timezone.utc).isoformat()
        }).eq("id", conv_id).execute()
        
        print(f"✅ Message saved successfully from {participant_id}")

    except Exception as e:
        print(f"❌ Error processing message: {str(e)}")
        raise e

# ==========================================
# 6. دالة إرسال الرسائل (Cron Job)
# ==========================================
@app.get("/api/cron/send-messages")
async def send_pending_messages():
    # جلب الرسائل المعلقة من الطابور
    queue_res = supabase.table("message_queue")\
        .select("*")\
        .eq("status", "pending")\
        .lte("next_attempt_at", datetime.now(timezone.utc).isoformat())\
        .limit(10)\
        .execute()

    processed_count = 0

    for item in queue_res.data:
        try:
            # 1. جلب الرسالة
            msg_res = supabase.table("messages").select("*").eq("id", item["message_id"]).limit(1).execute()
            if not msg_res.data:
                continue
            msg = msg_res.data[0]

            # 2. جلب المحادثة
            conv_res = supabase.table("conversations").select("*").eq("id", msg["conversation_id"]).limit(1).execute()
            if not conv_res.data:
                continue
            conv = conv_res.data[0]

            # 3. جلب الحساب المتصل
            acc_res = supabase.table("connected_accounts").select("*").eq("id", conv["connected_account_id"]).limit(1).execute()
            if not acc_res.data:
                continue
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
                
                async with httpx.AsyncClient() as client:
                    res = await client.post(url, headers=headers, json=payload)
                    
                    if res.status_code == 200:
                        # النجاح
                        supabase.table("messages").update({"status": "sent"}).eq("id", item["message_id"]).execute()
                        supabase.table("message_queue").update({"status": "done"}).eq("id", item["id"]).execute()
                        processed_count += 1
                    else:
                        # فشل الإرسال (هنسجل الخطأ)
                        raise Exception(f"Meta API Error: {res.status_code} - {res.text}")

        except Exception as e:
            print(f"Error sending message: {e}")
            # تحديث المحاولة عشان ميفضلش يحاول للأبد
            supabase.table("message_queue").update({
                "attempts": item["attempts"] + 1,
                "status": "failed" if item["attempts"] >= item["max_attempts"] else "pending",
                "last_error": str(e)[:255] # نسجل أول 255 حرف من الخطأ
            }).eq("id", item["id"]).execute()

    return {"status": "done", "processed": processed_count}