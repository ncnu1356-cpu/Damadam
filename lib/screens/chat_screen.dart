import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/dm_service.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DmService _dm = DmService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool sending = false;

  RealtimeChannel? _channel;

  String get _me => _supabase.auth.currentUser?.id ?? '';

  String get _conversationId => widget.conversation['id'].toString();

  Map<String, dynamic> get _otherUser {
    final isReq = widget.conversation['requester_id']?.toString() == _me;
    final o = isReq ? widget.conversation['recipient'] : widget.conversation['requester'];
    if (o is Map<String, dynamic>) return o;
    return <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _dm.getMessages(_conversationId);
      if (!mounted) return;
      setState(() {
        messages = list;
        loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _show('Load failed: $e');
    }
  }

  void _subscribe() {
    _channel = _supabase
        .channel('dm:conv:$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId,
          ),
          callback: (_) {
            if (!mounted) return;
            _load();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);
    _controller.clear();

    try {
      await _dm.sendText(conversationId: _conversationId, text: text);
      await _load();
    } catch (e) {
      _show('Send failed: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (x == null) return;

      setState(() => sending = true);

      final bytes = await File(x.path).readAsBytes();
      final ext =
          x.path.contains('.') ? x.path.split('.').last.toLowerCase() : 'jpg';

      final url = await _dm.uploadChatImage(
        conversationId: _conversationId,
        bytes: bytes,
        extension: ext,
      );

      if (url == null) throw Exception('Upload failed');

      await _dm.sendImage(conversationId: _conversationId, imageUrl: url);
      await _load();
    } catch (e) {
      _show('Image failed: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  // ✅ FIX 3: delete with proper feedback
  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will delete the message for both of you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dm.deleteMessage(msg['id'].toString());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted')),
      );
    } catch (e) {
      _show('Delete failed: $e');
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _displayName(Map<String, dynamic> u) {
    final full = u['full_name']?.toString().trim() ?? '';
    if (full.isNotEmpty) return full;
    final name = u['username']?.toString().trim() ?? '';
    if (name.isNotEmpty) return '@$name';
    return 'Damadam User';
  }

  // ✅ FIX 4: proper time format
  String _timeLabel(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final other = _otherUser;
    final avatar = other['avatar_url']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _displayName(other),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['sender_id']?.toString() == _me;
                          return _bubble(msg, isMe);
                        },
                      ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waving_hand_rounded, size: 60, color: Colors.amber.shade400),
            const SizedBox(height: 16),
            Text(
              'Say hi to ${_displayName(_otherUser)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Long-press your own message to delete it',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> msg, bool isMe) {
    final deleted = msg['deleted_at'] != null;
    final content = msg['content']?.toString() ?? '';
    final imageUrl = msg['image_url']?.toString() ?? '';
    final time = _timeLabel(msg['created_at']?.toString());

    final bubbleColor = isMe ? Colors.blue.shade500 : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: isMe && !deleted ? () => _deleteMessage(msg) : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (deleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block,
                              size: 14,
                              color: isMe ? Colors.white70 : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'This message was deleted',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: isMe ? Colors.white70 : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      if (content.isNotEmpty)
                        Text(
                          content,
                          style: TextStyle(
                              color: textColor, fontSize: 15, height: 1.35),
                        ),
                      if (imageUrl.isNotEmpty) ...[
                        if (content.isNotEmpty) const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            width: 220,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                height: 140,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.broken_image, color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: [
            IconButton(
              onPressed: sending ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              color: Colors.blueGrey,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  filled: true,
                  fillColor: const Color(0xFFF2F3F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: sending ? null : _send,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
