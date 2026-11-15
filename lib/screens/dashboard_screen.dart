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
  
  // إحصائيات
  int _accountsCount = 0;
  int _openConversations = 0;
  int _teamMembers = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. جلب بيانات المستخدم والشركة
      final userData = await _supabase
          .from('users')
          .select('role, organization_id, organizations(name)')
          .eq('id', user.id)
          .single();

      final orgId = userData['organization_id'];
      final orgData = userData['organizations'] as Map<String, dynamic>?;

      // 2. جلب الإحصائيات (باستخدام Count)
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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
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
            child: Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: 'تسجيل خروج',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ترحيب
                  Text(
                    'أهلاً بك، $(_userRole == 'owner' ? 'المدير' : 'الموظف') 👋',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إليك نظرة سريعة على أداء شركتك اليوم.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // بطاقات الإحصائيات
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // عرض متجاوب (Responsive) حسب حجم الشاشة
                      int crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                      
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
                          ),
                          _buildStatCard(
                            title: 'الحسابات المتصلة',
                            value: '$_accountsCount',
                            icon: Icons.link,
                            color: Colors.green,
                          ),
                          _buildStatCard(
                            title: 'أعضاء الفريق',
                            value: '$_teamMembers',
                            icon: Icons.people_outline,
                            color: Colors.orange,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // قسم المحادثات الأخيرة
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المحادثات الأخيرة',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (_openConversations == 0)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    const Icon(Icons.inbox, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text('لا توجد محادثات حتى الآن', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        // TODO: توجيه لصفحة ربط الحسابات
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هنضيف شاشة ربط المنصات هنا قريبًا')));
                                      },
                                      icon: const Icon(Icons.add_link),
                                      label: const Text('اربط حساب واتساب أو فيسبوك'),
                                    )
                                  ],
                                ),
                              ),
                            )
                          else
                            const Text('هنا سيتم عرض قائمة المحادثات قريبًا...'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      // زر عائم (FAB) لبدء محادثة جديدة
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: إضافة محادثة
        },
        icon: const Icon(Icons.add_comment),
        label: const Text('محادثة جديدة'),
      ),
    );
  }

  // ويدجت مخصص لبطاقة الإحصائيات
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}