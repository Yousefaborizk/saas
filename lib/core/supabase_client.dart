import 'package:supabase_flutter/supabase_flutter.dart';

/// العميل الرئيسي لـ Supabase — نستخدمه في كل حتة في التطبيق
final supabase = Supabase.instance.client;

/// الـ organization_id بتاع المستخدم الحالي (من الـ JWT)
/// بيرجع null لو المستخدم لسه ما أنشأش شركة
String? get currentOrgId =>
    supabase.auth.currentUser?.appMetadata['organization_id'] as String?;

/// دور المستخدم الحالي (owner / admin / agent)
String? get currentRole =>
    supabase.auth.currentUser?.appMetadata['role'] as String?;

/// هل المستخدم الحالي مرتبط بشركة؟
bool get hasOrganization => currentOrgId != null && currentOrgId!.isNotEmpty;
