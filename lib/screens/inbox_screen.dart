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

      final res = await _supabase
          .from('conversations')
          .select()
          .eq('organization_id', userData['organization_id'])
          .order('last_message_at', ascending: false);

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isOpen = conv['status'] == 'open';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => context.push('/chat', extra: {
                          'id': conv['id'],
                          'name': conv['participant_name'] ?? 'عميل',
                        }),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Text((conv['participant_name'] ?? 'ع')[0],
                              style: const TextStyle(color: Colors.deepPurple)),
                        ),
                        title: Text(conv['participant_name'] ?? 'عميل',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(conv['last_message_preview'] ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(isOpen ? 'مفتوحة' : 'مغلقة',
                            style: TextStyle(
                                color: isOpen ? Colors.green : Colors.grey,
                                fontSize: 12)),
                      ),
                    );
                  },
                ),
    );
  }
}
