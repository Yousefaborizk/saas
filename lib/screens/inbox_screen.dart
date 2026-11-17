import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _inboxChannel = _supabase
        .channel('inbox_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) => _fetchConversations(),
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
      final userData = await _supabase
          .from('users')
          .select('organization_id')
          .eq('id', user.id)
          .single();

      // بنجيب بيانات المحادثة + بيانات الحساب المتصل عشان نعرف المنصة
      final res = await _supabase
          .from('conversations')
          .select('*, connected_accounts(platform)')
          .eq('organization_id', userData['organization_id'])
          .order('last_message_at', ascending: false);

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('صندوق الرسائل',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.circle, color: Colors.green, size: 10),
              SizedBox(width: 4),
              Text('مباشر',
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ]),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Text('لا توجد رسائل حتى الآن',
                      style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isOpen = conv['status'] == 'open';
                    final platform =
                        conv['connected_accounts']?['platform'] ?? 'whatsapp';
                    final isWhatsApp = platform == 'whatsapp';
                    final name = conv['participant_name'] ?? 'عميل';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        onTap: () => context.push('/chat', extra: {
                          'id': conv['id'],
                          'name': name,
                        }),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isWhatsApp
                                  ? Colors.green.shade50
                                  : Colors.blue.shade50,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'ع',
                                style: TextStyle(
                                  color:
                                      isWhatsApp ? Colors.green : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            // أيقونة المنصة
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isWhatsApp ? Icons.chat : Icons.facebook,
                                  color:
                                      isWhatsApp ? Colors.green : Colors.blue,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          conv['last_message_preview'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'مفتوحة',
                              style: TextStyle(
                                color: isOpen ? Colors.green : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(Icons.arrow_forward_ios,
                                size: 12, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
