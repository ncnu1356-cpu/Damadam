import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class DmService {
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseClient get supabase => _supabase;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ============================================================
  // REQUESTS
  // ============================================================

  Future<bool> canMessage(String otherUserId) async {
    final me = currentUserId;
    if (me == null || me == otherUserId) return false;

    try {
      final iFollow = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', me)
          .eq('following_id', otherUserId)
          .maybeSingle();

      final theyFollow = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', otherUserId)
          .eq('following_id', me)
          .maybeSingle();

      return iFollow != null && theyFollow != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns existing conversation (any status) or null
  Future<Map<String, dynamic>?> findConversation(
    String otherUserId,
  ) async {
    final me = currentUserId;
    if (me == null) return null;

    try {
      final res = await _supabase
          .from('dm_conversations')
          .select()
          .or(
            'and(requester_id.eq.$me,recipient_id.eq.$otherUserId),'
            'and(requester_id.eq.$otherUserId,recipient_id.eq.$me)',
          )
          .maybeSingle();

      return res;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendRequest(
    String otherUserId,
  ) async {
    final me = currentUserId;
    if (me == null) return null;

    final existing = await findConversation(otherUserId);
    if (existing != null) return existing;

    final res = await _supabase
        .from('dm_conversations')
        .insert({
          'requester_id': me,
          'recipient_id': otherUserId,
          'status': 'pending',
        })
        .select()
        .maybeSingle();

    return res;
  }

  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final me = currentUserId;
    if (me == null) return [];

    final res = await _supabase
        .from('dm_conversations')
        .select(
          'id, requester_id, recipient_id, status, created_at, '
          'profiles!dm_conversations_requester_id_fkey(id, username, full_name, avatar_url)',
        )
        .eq('recipient_id', me)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> acceptRequest(String conversationId) async {
    await _supabase
        .from('dm_conversations')
        .update({
          'status': 'accepted',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', conversationId);
  }

  Future<void> declineRequest(String conversationId) async {
    await _supabase
        .from('dm_conversations')
        .delete()
        .eq('id', conversationId);
  }

  // ============================================================
  // CONVERSATIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getAcceptedConversations() async {
    final me = currentUserId;
    if (me == null) return [];

    final res = await _supabase
        .from('dm_conversations')
        .select(
          'id, requester_id, recipient_id, status, accepted_at, '
          'requester:profiles!dm_conversations_requester_id_fkey(id, username, full_name, avatar_url), '
          'recipient:profiles!dm_conversations_recipient_id_fkey(id, username, full_name, avatar_url)',
        )
        .or('requester_id.eq.$me,recipient_id.eq.$me')
        .eq('status', 'accepted')
        .order('accepted_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>?> getLastMessage(
    String conversationId,
  ) async {
    try {
      final res = await _supabase
          .from('dm_messages')
          .select('content, image_url, sender_id, created_at, deleted_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return res;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId,
  ) async {
    final res = await _supabase
        .from('dm_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> sendText({
    required String conversationId,
    required String text,
  }) async {
    final me = currentUserId;
    if (me == null) return;

    await _supabase.from('dm_messages').insert({
      'conversation_id': conversationId,
      'sender_id': me,
      'content': text,
    });
  }

  Future<String?> uploadChatImage({
    required String conversationId,
    required List<int> bytes,
    required String extension,
  }) async {
    final me = currentUserId;
    if (me == null) return null;

    final path =
        'dm/$conversationId/${me}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _supabase.storage.from('post-images').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            upsert: false,
            contentType: 'image/$extension',
          ),
        );

    return _supabase.storage
        .from('post-images')
        .getPublicUrl(path);
  }

  Future<void> sendImage({
    required String conversationId,
    required String imageUrl,
  }) async {
    final me = currentUserId;
    if (me == null) return;

    await _supabase.from('dm_messages').insert({
      'conversation_id': conversationId,
      'sender_id': me,
      'image_url': imageUrl,
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _supabase
        .from('dm_messages')
        .update({
          'deleted_at': DateTime.now().toIso8601String(),
          'content': null,
          'image_url': null,
        })
        .eq('id', messageId);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _supabase
        .from('dm_conversations')
        .delete()
        .eq('id', conversationId);
  }
}
