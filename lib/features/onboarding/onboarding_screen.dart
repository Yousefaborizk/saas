import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _orgName = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_orgName.text.trim().length < 2) {
      setState(() => _error = 'اسم الشركة قصير');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.rpc('complete_registration',
          params: {'org_name': _orgName.text.trim()});

      // ⚠️ مهم جدًا: refreshSession عشان الـ JWT الجديد ياخد organization_id
      await supabase.auth.refreshSession();

      // الـ router هيتكفل بالتحويل لـ /home
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _orgName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.business,
                        size: 56, color: Color(0xFF2563EB)),
                    const SizedBox(height: 12),
                    const Text(
                      'خطوة أخيرة',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مرحبًا $email\nضيف اسم شركتك عشان ننشئ لك مساحة عمل',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _orgName,
                      decoration: const InputDecoration(
                        labelText: 'اسم الشركة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.apartment),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
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
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('إنشاء الشركة والبدء'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => supabase.auth.signOut(),
                      child: const Text('تسجيل خروج'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
