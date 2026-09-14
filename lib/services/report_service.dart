import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _me => _supabase.auth.currentUser?.id;

  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    final me = _me;
    if (me == null) return;

    await _supabase.from('reports').insert({
      'reporter_id': me,
      'reported_user_id': userId,
      'reason': reason,
      'details': details,
    });
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    final me = _me;
    if (me == null) return;

    // Get post owner so we can also attach reported_user_id
    String? ownerId;
    try {
      final p = await _supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .maybeSingle();
      ownerId = p?['user_id']?.toString();
    } catch (_) {}

    await _supabase.from('reports').insert({
      'reporter_id': me,
      'reported_user_id': ownerId,
      'post_id': postId,
      'reason': reason,
      'details': details,
    });
  }

  Future<void> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    final me = _me;
    if (me == null) return;

    String? ownerId;
    try {
      final c = await _supabase
          .from('comments')
          .select('user_id')
          .eq('id', commentId)
          .maybeSingle();
      ownerId = c?['user_id']?.toString();
    } catch (_) {}

    await _supabase.from('reports').insert({
      'reporter_id': me,
      'reported_user_id': ownerId,
      'comment_id': commentId,
      'reason': reason,
      'details': details,
    });
  }
}
