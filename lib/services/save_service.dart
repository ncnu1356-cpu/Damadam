import 'package:supabase_flutter/supabase_flutter.dart';

class SaveService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _me => _supabase.auth.currentUser?.id;

  // Is this post saved by me?
  Future<bool> isSaved(String postId) async {
    final me = _me;
    if (me == null) return false;

    try {
      final res = await _supabase
          .from('saved_posts')
          .select('id')
          .eq('user_id', me)
          .eq('post_id', postId)
          .maybeSingle();

      return res != null;
    } catch (_) {
      return false;
    }
  }

  // Save or unsave
  Future<bool> toggleSave(String postId) async {
    final me = _me;
    if (me == null) return false;

    try {
      final existing = await _supabase
          .from('saved_posts')
          .select('id')
          .eq('user_id', me)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('saved_posts')
            .delete()
            .eq('id', existing['id']);
        return false; // not saved now
      } else {
        await _supabase.from('saved_posts').insert({
          'user_id': me,
          'post_id': postId,
        });
        return true; // saved now
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get all saved posts (with their post data)
  Future<List<Map<String, dynamic>>> getSavedPosts() async {
    final me = _me;
    if (me == null) return [];

    final res = await _supabase
        .from('saved_posts')
        .select(
          'id, created_at, '
          'posts(id, user_id, content, image_url, created_at, '
          'profiles(username, full_name, avatar_url))',
        )
        .eq('user_id', me)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }
}
