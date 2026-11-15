import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _org;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    try {
      final orgId = currentOrgId;
      if (orgId != null) {
        final org = await supabase
            .from('organizations')
            .select()
            .eq('id', orgId)
            .single();
        if (mounted) setState(() => _org = org);
      }
    } catch (e) {
      debugPrint('Error loading org: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(_org?['name'] ?? 'مساحة العمل'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل خروج',
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user?.email ?? ''),
                    subtitle: Text('الدور: ${currentRole ?? "?"}'),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.business)),
                    title: Text(_org?['name'] ?? ''),
                    subtitle: Text('Org ID: ${currentOrgId ?? "?"}'),
                  ),
                ),
                const SizedBox(height: 16),
                const Card(
                  color: Color(0xFFEFF6FF),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ الاتصال بـ Supabase شغال',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('الخطوة الجاية: ربط فيسبوك وواتساب.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
