import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// ⚙️ 1) إعدادات Supabase
// ═══════════════════════════════════════════════════════════
const String supabaseUrl = 'https://edjkgzkssgdgrpthheoz.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkamtnemtzc2dkZ3JwdGhoZW96Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ1MDIwMTEsImV4cCI6MjExMDA3ODAxMX0.FRz0uCU3jV2w2PuJb4ZIj54KmM_fG-_CeAmG_dOiRbQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: true,
  );
  runApp(const ProviderScope(child: MyApp()));
}

// ═══════════════════════════════════════════════════════════
// 🧭 2) الراوتر (GoRouter)
// ═══════════════════════════════════════════════════════════
final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/accounts', builder: (_, __) => const ConnectedAccountsScreen()),
    GoRoute(path: '/inbox', builder: (_, __) => const InboxScreen()),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ChatScreen(
          conversationId: extra['id'],
          participantName: extra['name'] ?? 'عميل',
        );
      },
    ),
    GoRoute(path: '/team', builder: (_, __) => const TeamScreen()),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Social SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          filled: true,
          fillColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ⏳ 3) شاشة البداية (Splash)
// ═══════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('organization_id')
          .eq('id', session.user.id)
          .maybeSingle();

      if (res != null && res['organization_id'] != null) {
        if (mounted) context.go('/home');
      } else {
        if (mounted) context.go('/onboarding');
      }
    } catch (e) {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub, size: 80, color: Colors.deepPurple),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🟣 4) شاشة تسجيل الدخول
// ═══════════════════════════════════════════════════════════
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) context.go('/splash');
    } on AuthException catch (e) {
      _showSnack('❌ ${e.message}');
    } catch (e) {
      _showSnack('❌ خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_person, size: 80, color: Colors.deepPurple),
                    const SizedBox(height: 24),
                    const Text('تسجيل الدخول', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || !v.contains('@')) ? 'بريد غير صالح' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور 6 أحرف على الأقل' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text('دخول'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/signup'),
                      child: const Text('ماعندكش حساب؟ سجّل جديد', style: TextStyle(color: Colors.deepPurple)),
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

// ═══════════════════════════════════════════════════════════
// 🟢 5) شاشة إنشاء حساب
// ═══════════════════════════════════════════════════════════
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (res.session != null) {
        if (mounted) context.go('/splash');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إنشاء الحساب — افتح بريدك لتفعيل الإيميل')));
          context.go('/login');
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ غير متوقع: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('حساب جديد'), backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add, size: 80, color: Colors.deepPurple),
                    const SizedBox(height: 24),
                    const Text('إنشاء حساب جديد', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || !v.contains('@')) ? 'بريد غير صالح' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _signUp(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور 6 أحرف على الأقل' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _signUp,
                      child: _loading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text('إنشاء الحساب'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/login'),
                      child: const Text('عندك حساب بالفعل؟ سجّل دخول', style: TextStyle(color: Colors.deepPurple)),
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

// ═══════════════════════════════════════════════════════════
// 🏢 6) شاشة إنشاء الشركة (Onboarding)
// ═══════════════════════════════════════════════════════════
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  Future<void> _createOrg() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'من فضلك أدخل اسم الشركة');
      return;
    }
    
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final org = await Supabase.instance.client
          .from('organizations')
          .insert({'name': _nameCtrl.text.trim()})
          .select()
          .single();

      await Supabase.instance.client
          .from('users')
          .update({'organization_id': org['id']})
          .eq('id', user.id);

      if (mounted) context.go('/home');
      
    } on PostgrestException catch (e) {
      if (e.code == 'P0001' || e.message.contains('already has an organization')) {
        if (mounted) context.go('/home');
      } else {
        setState(() => _errorMsg = 'خطأ: ${e.message}');
      }
    } catch (e) {
      setState(() => _errorMsg = 'خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.domain, size: 72, color: Colors.blue),
                      const SizedBox(height: 16),
                      const Text('خطوة أخيرة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('مرحبًا $email', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 4),
                      const Text('ضيف اسم شركتك عشان ننشئ لك مساحة عمل', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الشركة',
                          prefixIcon: Icon(Icons.business),
                        ),
                        enabled: !_loading,
                      ),
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 16),
                        Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4B5C87),
                        ),
                        onPressed: _loading ? null : _createOrg,
                        child: _loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('إنشاء الشركة والبدء'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : () async {
                          await Supabase.instance.client.auth.signOut();
                          if (mounted) context.go('/login');
                        },
                        child: const Text('تسجيل خروج', style: TextStyle(color: Color(0xFF4B5C87))),
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

// ═══════════════════════════════════════════════════════════
// 🏠 7) لوحة التحكم (Dashboard)
// ═══════════════════════════════════════════════════════════
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
  
  int _accountsCount = 0;
  int _openConversations = 0;
  int _teamMembers = 0;
  
  RealtimeChannel? _dashboardChannel;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _setupRealtime();
  }
  
  void _setupRealtime() {
    _dashboardChannel = _supabase.channel('dashboard_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            _fetchDashboardData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'connected_accounts',
          callback: (payload) {
            _fetchDashboardData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _dashboardChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final userData = await _supabase
          .from('users')
          .select('role, organization_id, organizations(name)')
          .eq('id', user.id)
          .single();

      final orgId = userData['organization_id'];
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
        setState(() => _isLoading = false);
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
    final roleName = _userRole == 'owner' ? 'المدير' : (_userRole == 'admin' ? 'المشرف' : 'الموظف');

    return Scaffold(
      appBar: AppBar(
        title: Text(_orgName.isEmpty ? 'لوحة التحكم' : _orgName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.group, color: Colors.deepPurple),
            tooltip: 'إدارة الفريق',
            onPressed: () => context.push('/team'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: Colors.deepPurple),
            tooltip: 'الحسابات المتصلة',
            onPressed: () => context.push('/accounts'),
          ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'أهلاً بك، $roleName 👋',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            const Text('مباشر (Live)', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إليك نظرة سريعة على أداء شركتك اليوم.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  LayoutBuilder(
                    builder: (context, constraints) {
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
                            onTap: () => context.push('/inbox'),
                          ),
                          _buildStatCard(
                            title: 'الحسابات المتصلة',
                            value: '$_accountsCount',
                            icon: Icons.link,
                            color: Colors.green,
                            onTap: () => context.push('/accounts'),
                          ),
                          _buildStatCard(
                            title: 'أعضاء الفريق',
                            value: '$_teamMembers',
                            icon: Icons.people_outline,
                            color: Colors.orange,
                            onTap: () => context.push('/team'),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'المحادثات المباشرة',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                onPressed: () => context.push('/inbox'),
                                child: const Text('عرض الكل'),
                              ),
                            ],
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
                                      onPressed: () => context.push('/inbox'),
                                      icon: const Icon(Icons.chat),
                                      label: const Text('افتح صندوق الرسائل'),
                                    )
                                  ],
                                ),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inbox'),
        icon: const Icon(Icons.message),
        label: const Text('الرسائل'),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔗 8) شاشة الحسابات المتصلة
// ═══════════════════════════════════════════════════════════
class ConnectedAccountsScreen extends StatefulWidget {
  const ConnectedAccountsScreen({super.key});

  @override
  State<ConnectedAccountsScreen> createState() => _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState extends State<ConnectedAccountsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final userData = await _supabase.from('users').select('organization_id').eq('id', user.id).single();
      final res = await _supabase.from('connected_accounts').select().eq('organization_id', userData['organization_id']).order('created_at', ascending: false);
      if (mounted) setState(() { _accounts = List<Map<String, dynamic>>.from(res); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAccount(String platform, String name, String accountId) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final userData = await _supabase.from('users').select('organization_id').eq('id', user.id).single();
      await _supabase.from('connected_accounts').insert({
        'organization_id': userData['organization_id'],
        'platform': platform,
        'display_name': name,
        'platform_account_id': accountId,
        'access_token_encrypted': 'dummy_token',
        'is_active': true,
      });
      await _fetchAccounts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم الربط')));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    String selectedPlatform = 'whatsapp';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ربط حساب جديد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedPlatform,
                    decoration: const InputDecoration(labelText: 'المنصة'),
                    items: const [
                      DropdownMenuItem(value: 'whatsapp', child: Text('واتساب')),
                      DropdownMenuItem(value: 'facebook', child: Text('فيسبوك')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedPlatform = val!),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الحساب')),
                  const SizedBox(height: 16),
                  TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف أو ID')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty && idCtrl.text.isNotEmpty) {
                      Navigator.pop(context);
                      _addAccount(selectedPlatform, nameCtrl.text.trim(), idCtrl.text.trim());
                    }
                  },
                  child: const Text('ربط'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات المتصلة'), backgroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.link_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('لا توجد حسابات', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  FilledButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('ربط حساب')),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final acc = _accounts[index];
                    final isWhatsApp = acc['platform'] == 'whatsapp';
                    return Card(
                      child: ListTile(
                        leading: Icon(isWhatsApp ? Icons.chat : Icons.facebook, color: isWhatsApp ? Colors.green : Colors.blue),
                        title: Text(acc['display_name'] ?? 'حساب'),
                        subtitle: Text('${isWhatsApp ? "واتساب" : "فيسبوك"} • ${acc['platform_account_id']}'),
                        trailing: const Text('متصل', style: TextStyle(color: Colors.green)),
                      ),
                    );
                  },
                ),
      floatingActionButton: _accounts.isNotEmpty ? FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)) : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📥 9) صندوق الرسائل (Inbox) - مع Realtime
// ═══════════════════════════════════════════════════════════
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  RealtimeChannel? _inboxChannel;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _setupRealtime();
  }

  void _setupRealtime() {
    _inboxChannel = _supabase.channel('inbox_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            _fetchConversations();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _inboxChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final userData = await _supabase.from('users').select('organization_id').eq('id', user.id).single();
      final res = await _supabase.from('conversations').select().eq('organization_id', userData['organization_id']).order('last_message_at', ascending: false);
      if (mounted) setState(() { _conversations = List<Map<String, dynamic>>.from(res); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _simulateNewMessage() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final userData = await _supabase.from('users').select('organization_id').eq('id', user.id).single();
      final orgId = userData['organization_id'];

      final accounts = await _supabase.from('connected_accounts').select('id').eq('organization_id', orgId).limit(1);
      if (accounts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ لازم تربط حساب الأول!')));
          setState(() => _isLoading = false);
        }
        return;
      }

      final accountId = accounts[0]['id'];
      final conv = await _supabase.from('conversations').insert({
        'organization_id': orgId,
        'connected_account_id': accountId,
        'platform_thread_id': 'thread_${DateTime.now().millisecondsSinceEpoch}',
        'participant_id': 'user_${DateTime.now().millisecondsSinceEpoch}',
        'participant_name': 'عميل تجريبي',
        'last_message_preview': 'مرحباً، عايز أستفسر عن الأسعار',
        'last_message_at': DateTime.now().toIso8601String(),
        'status': 'open',
      }).select().single();

      await _supabase.from('messages').insert({
        'organization_id': orgId,
        'conversation_id': conv['id'],
        'sender_type': 'customer',
        'content': 'مرحباً، عايز أستفسر عن الأسعار',
      });

      // ملاحظة: مش محتاجين نستدعي _fetchConversations هنا، الـ Realtime هيعملها لوحده
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ وصلت رسالة جديدة!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق الرسائل'),
        backgroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.circle, color: Colors.green, size: 10),
              SizedBox(width: 4),
              Text('مباشر', style: TextStyle(color: Colors.green, fontSize: 12)),
            ]),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.mark_email_unread, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('لا توجد رسائل', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(onPressed: _simulateNewMessage, icon: const Icon(Icons.sim_card), label: const Text('محاكاة استقبال رسالة')),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isOpen = conv['status'] == 'open';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => context.push('/chat', extra: {'id': conv['id'], 'name': conv['participant_name'] ?? 'عميل'}),
                        leading: CircleAvatar(backgroundColor: Colors.deepPurple.shade50, child: Text((conv['participant_name'] ?? 'ع')[0], style: const TextStyle(color: Colors.deepPurple))),
                        title: Text(conv['participant_name'] ?? 'عميل', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(conv['last_message_preview'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(isOpen ? 'مفتوحة' : 'مغلقة', style: TextStyle(color: isOpen ? Colors.green : Colors.grey, fontSize: 12)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _simulateNewMessage, icon: const Icon(Icons.add_comment), label: const Text('استقبال رسالة')),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 💬 10) شاشة الدردشة (Chat) - مع Realtime
// ═══════════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String participantName;

  const ChatScreen({super.key, required this.conversationId, required this.participantName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  String? _orgId;
  RealtimeChannel? _chatChannel;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupRealtime();
  }

  void _setupRealtime() {
    _chatChannel = _supabase.channel('chat_changes_${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            _fetchMessages();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final userData = await _supabase.from('users').select('organization_id').eq('id', user.id).single();
      _orgId = userData['organization_id'];

      final res = await _supabase.from('messages').select().eq('conversation_id', widget.conversationId).order('created_at', ascending: true);
      if (mounted) {
        setState(() { _messages = List<Map<String, dynamic>>.from(res); _isLoading = false; });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _orgId == null) return;

    _msgCtrl.clear();

    try {
      await _supabase.from('messages').insert({
        'organization_id': _orgId,
        'conversation_id': widget.conversationId,
        'sender_type': 'agent',
        'sender_user_id': _supabase.auth.currentUser?.id,
        'content': text,
      });

      await _supabase.from('conversations').update({
        'last_message_preview': text,
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.conversationId);

      // مش محتاجين نستدعي _fetchMessages، الـ Realtime هيعملها
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.participantName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('مباشر الآن', style: TextStyle(fontSize: 12, color: Colors.green)),
        ]),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_type'] == 'agent';
                      final time = DateTime.parse(msg['created_at']).toLocal();
                      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                      return Align(
                        alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.deepPurple : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? Radius.zero : const Radius.circular(16),
                              bottomRight: isMe ? const Radius.circular(16) : Radius.zero,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(msg['content'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(timeStr, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 👥 11) شاشة إدارة الفريق (Team Management)
// ═══════════════════════════════════════════════════════════
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _orgId = '';
  String _currentUserRole = '';
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _fetchTeamData();
  }

  Future<void> _fetchTeamData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final userData = await _supabase.from('users').select('organization_id, role').eq('id', user.id).single();
      _orgId = userData['organization_id'];
      _currentUserRole = userData['role'];

      final membersRes = await _supabase.from('users').select().eq('organization_id', _orgId).order('created_at', ascending: true);
      final invitesRes = await _supabase.from('invitations').select().eq('organization_id', _orgId).isFilter('accepted_at', null).order('created_at', ascending: false);

      if (mounted) setState(() { _members = List<Map<String, dynamic>>.from(membersRes); _invitations = List<Map<String, dynamic>>.from(invitesRes); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteUser(String email, String role) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('invitations').insert({'organization_id': _orgId, 'email': email.trim(), 'role': role, 'invited_by': user.id});
      await _fetchTeamData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال الدعوة')));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInviteDialog() {
    final emailCtrl = TextEditingController();
    String selectedRole = 'agent';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('دعوة عضو جديد'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'الصلاحية'),
                  items: const [DropdownMenuItem(value: 'admin', child: Text('مشرف')), DropdownMenuItem(value: 'agent', child: Text('موظف'))],
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                FilledButton(onPressed: () { if (emailCtrl.text.contains('@')) { Navigator.pop(context); _inviteUser(emailCtrl.text.trim(), selectedRole); } }, child: const Text('إرسال')),
              ],
            );
          },
        );
      },
    );
  }

  String _getRoleName(String r) => r == 'owner' ? 'مدير عام' : r == 'admin' ? 'مشرف' : 'موظف';
  Color _getRoleColor(String r) => r == 'owner' ? Colors.purple : r == 'admin' ? Colors.orange : Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الفريق'), backgroundColor: Colors.white),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('الأعضاء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._members.map((m) {
            final role = m['role'] ?? 'agent';
            final isMe = m['id'] == _supabase.auth.currentUser?.id;
            return Card(
              child: ListTile(
                leading: Icon(Icons.person, color: _getRoleColor(role)),
                title: Row(children: [Text(m['email'] ?? ''), if (isMe) const Text(' (أنت)', style: TextStyle(color: Colors.green))]),
                trailing: Text(_getRoleName(role), style: TextStyle(color: _getRoleColor(role), fontSize: 12)),
              ),
            );
          }),
          if (_invitations.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('دعوات معلقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._invitations.map((i) => Card(color: Colors.grey.shade50, child: ListTile(leading: const Icon(Icons.mail), title: Text(i['email']), subtitle: const Text('بانتظار القبول')))),
          ],
        ],
      ),
      floatingActionButton: (_currentUserRole == 'owner' || _currentUserRole == 'admin') ? FloatingActionButton.extended(onPressed: _showInviteDialog, icon: const Icon(Icons.person_add), label: const Text('دعوة عضو')) : null,
    );
  }
}