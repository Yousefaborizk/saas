import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _orgName = '';
  String _userRole = '';
  String? _errorMessage;

  int _accountsCount = 0;
  int _openConversations = 0;
  int _teamMembers = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("المستخدم غير مسجل دخول");

      final userData = await _supabase
          .from('users')
          .select('role, organization_id, organizations(name)')
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null) {
        throw Exception("لم يتم العثور على بيانات المستخدم");
      }

      final orgId = userData['organization_id'];
      if (orgId == null) {
        throw Exception("لا ينتمي لأي شركة (Organization ID is null)");
      }

      final orgData = userData['organizations'] as Map<String, dynamic>?;

      final accountsRes = await _supabase
          .from('connected_accounts')
          .select('*')
          .eq('organization_id', orgId)
          .count(CountOption.exact);
      final convsRes = await _supabase
          .from('conversations')
          .select('*')
          .eq('organization_id', orgId)
          .eq('status', 'open')
          .count(CountOption.exact);
      final teamRes = await _supabase
          .from('users')
          .select('*')
          .eq('organization_id', orgId)
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _orgName = orgData?['name'] ?? 'شركتي';
          _userRole = userData['role'] ?? 'agent';
          _accountsCount = accountsRes.count;
          _openConversations = convsRes.count;
          _teamMembers = teamRes.count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(_orgName.isEmpty ? 'لوحة التحكم' : _orgName),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Center(
              child: Text(user?.email ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 14))),
          const SizedBox(width: 16),
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: _logout),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 16)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchDashboardData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        )
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلاً بك، ${_userRole == 'owner' ? 'المدير' : 'الموظف'} 👋',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('إليك نظرة سريعة على أداء شركتك اليوم.',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = constraints.maxWidth > 900
                              ? 3
                              : (constraints.maxWidth > 600 ? 2 : 1);
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.5,
                            children: [
                              _buildStatCard(
                                title: 'محادثات مفتوحة',
                                value: '$_openConversations',
                                icon: Icons.chat_bubble_outline,
                                color: Colors.blue,
                                onTap: () => context
                                    .push('/inbox'), // 👈 هنا التوجيه للـ Inbox
                              ),
                              _buildStatCard(
                                  title: 'الحسابات المتصلة',
                                  value: '$_accountsCount',
                                  icon: Icons.link,
                                  color: Colors.green),
                              _buildStatCard(
                                  title: 'أعضاء الفريق',
                                  value: '$_teamMembers',
                                  icon: Icons.people_outline,
                                  color: Colors.orange),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('المحادثات الأخيرة',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              if (_openConversations == 0)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Icon(Icons.inbox,
                                            size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text('لا توجد محادثات حتى الآن',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50)),
                                  onPressed: () => context.push('/inbox'),
                                  icon: const Icon(Icons.forum),
                                  label: const Text('دخول على صندوق الرسائل'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color color,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
