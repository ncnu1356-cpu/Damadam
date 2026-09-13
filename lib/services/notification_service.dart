import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create notification
  Future<void> createNotification({
    required String userId,
    required String senderId,
    required String type,
    String? postId,
    required String message,
  }) async {
    // Don't notify yourself
    if (userId == senderId) {
      return;
    }

    await _supabase.from('notifications').insert({
      'user_id': userId,
      'sender_id': senderId,
      'type': type,
      'post_id': postId,
      'message': message,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      return [];
    }

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      return 0;
    }

    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', currentUser.id)
        .eq('is_read', false);

    return response.length;
  }

  // Mark one notification as read
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({
          'is_read': true,
        })
        .eq('id', notificationId);
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      return;
    }

    await _supabase
        .from('notifications')
        .update({
          'is_read': true,
        })
        .eq('user_id', currentUser.id)
        .eq('is_read', false);
  }

  // Delete one notification
  Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }
}
