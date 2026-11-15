import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'full_name': _name.text.trim()},
      );
      if (res.session == null) {
        setState(() => _info = 'تم إنشاء الحساب. افحص إيميلك لو محتاج تفعيل.');
      }
      // لو فيه session، الـ router هيوديه على /onboarding
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.person_add_alt_1,
                          size: 56, color: Color(0xFF2563EB)),
                      const SizedBox(height: 12),
                      const Text(
                        'إنشاء حساب جديد',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().length < 2
                            ? 'اسم قصير'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@')
                            ? 'إيميل غير صحيح'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (v) => v == null || v.length < 8
                            ? '8 حروف على الأقل'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Text(_info!,
                            style: const TextStyle(color: Colors.green)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('إنشاء حساب'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/auth/login'),
                        child: const Text('عندك حساب؟ سجل دخول'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
