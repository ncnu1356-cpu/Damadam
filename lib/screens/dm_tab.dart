import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/dm_service.dart';
import 'chat_screen.dart';

class DmTab extends StatefulWidget {
  const DmTab({super.key});

  @override
  State<DmTab> createState() => _DmTabState();
}

class _DmTabState extends State<DmTab> {
  final DmService _dm = DmService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> conversations = [];

  bool loading = true;

  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _messagesChannel;

  String get _me => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    _conversationsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadRequests(), _loadConversations()]);
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _loadRequests() async {
    try {
      final list = await _dm.getIncomingRequests();
      if (!mounted) return;
      setState(() => requests = list);
    } catch (e) {
      debugPrint('Load requests error: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final list = await _dm.getAcceptedConversations();
      if (!mounted) return;
      setState(() => conversations = list);
    } catch (e) {
      debugPrint('Load conversations error: $e');
    }
  }

  void _subscribeRealtime() {
    if (_me.isEmpty) return;

    // Watch for any request/conversation change involving me
    _requestsChannel = _supabase
        .channel('dm:requests:$_me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dm_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: _me,
          ),
          callback: (_) => _loadAll(),
        )
        .subscribe();

    _conversationsChannel = _supabase
        .channel('dm:conversations:$_me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dm_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'requester_id',
            value: _me,
          ),
          callback: (_) => _loadAll(),
        )
        .subscribe();

    // Watch for new messages in any of my conversations
    // (fallback refresh — the ChatScreen subscribes in detail)
    _messagesChannel = _supabase
        .channel('dm:messages:$_me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dm_messages',
          callback: (payload) {
            final convId = payload.newRecord['conversation_id']?.toString();
            if (convId == null) return;
            if (conversations.any((c) => c['id']?.toString() == convId)) {
              if (mounted) setState(() {});
            }
          },
        )
        .subscribe();
  }

  Future<void> _accept(Map<String, dynamic> req) async {
    try {
      await _dm.acceptRequest(req['id'].toString());
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat accepted')),
      );
    } catch (e) {
      _show('Accept failed: $e');
    }
  }

  Future<void> _decline(Map<String, dynamic> req) async {
    try {
      await _dm.declineRequest(req['id'].toString());
      await _loadAll();
    } catch (e) {
      _show('Decline failed: $e');
    }
  }

  Future<void> _openChat(Map<String, dynamic> conv) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conv),
      ),
    );
    if (!mounted) return;
    await _loadAll();
  }

  // ✅ Leave / delete the conversation
  Future<void> _deleteConversation(Map<String, dynamic> conv) async {
    final other = _otherUser(conv);
    final name = _displayName(other);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave chat with $name?'),
        content: const Text(
          'All messages in this chat will be permanently deleted for both of you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dm.deleteConversation(conv['id'].toString());
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat removed')),
      );
    } catch (e) {
      _show('Delete failed: $e');
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Map<String, dynamic> _otherUser(Map<String, dynamic> conv) {
    final isRequester = conv['requester_id']?.toString() == _me;
    final other = isRequester ? conv['recipient'] : conv['requester'];
    if (other is Map<String, dynamic>) return other;
    return <String, dynamic>{};
  }

  String _displayName(Map<String, dynamic> user) {
    final full = user['full_name']?.toString().trim() ?? '';
    if (full.isNotEmpty) return full;
    final u = user['username']?.toString().trim() ?? '';
    if (u.isNotEmpty) return '@$u';
    return 'Damadam User';
  }

  // ✅ FIX 4: proper "1m ago" time format
  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          '1on1',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final hasAny = requests.isNotEmpty || conversations.isNotEmpty;

    if (!hasAny) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Follow someone who follows you back,\nthen tap the 1on1 button on their profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (requests.isNotEmpty) ...[
          _sectionHeader('Requests (${requests.length})'),
          ...requests.map(_requestCard),
          const SizedBox(height: 8),
        ],
        if (conversations.isNotEmpty) ...[
          _sectionHeader('Chats (${conversations.length})'),
          ...conversations.map(_conversationTile),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final profile = req['profiles'];
    final Map<String, dynamic> user =
        profile is Map<String, dynamic> ? profile : <String, dynamic>{};
    final avatarUrl = user['avatar_url']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.blueGrey.shade100,
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(user),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'wants to chat',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            onPressed: () => _decline(req),
            icon: const Icon(Icons.close, color: Colors.red),
          ),
          FilledButton(
            onPressed: () => _accept(req),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Widget _conversationTile(Map<String, dynamic> conv) {
    final other = _otherUser(conv);
    final avatarUrl = other['avatar_url']?.toString() ?? '';
    final convId = conv['id'].toString();

    return FutureBuilder<Map<String, dynamic>?>(
      future: DmService().getLastMessage(convId),
      builder: (context, snap) {
        final last = snap.data;
        final preview = _preview(last);

        return Container(
          color: Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            title: Text(
              _displayName(other),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            trailing: Text(
              _timeAgo(last?['created_at']?.toString()),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            onTap: () => _openChat(conv),
            onLongPress: () => _deleteConversation(conv),
          ),
        );
      },
    );
  }

  String _preview(Map<String, dynamic>? last) {
    if (last == null) return 'Say hi 👋';
    if (last['deleted_at'] != null) return 'This message was deleted';
    final content = last['content']?.toString().trim() ?? '';
    if (content.isNotEmpty) return content;
    if ((last['image_url']?.toString() ?? '').isNotEmpty) return '📷 Photo';
    return 'Say hi 👋';
  }
}
