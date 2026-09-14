import 'package:supabase_flutter/supabase_flutter.dart';

class ExploreService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ============================================================
  // TRENDING POSTS (sorted by engagement)
  // ============================================================
  Future<List<Map<String, dynamic>>> getTrendingPosts({
    int limit = 30,
  }) async {
    try {
      final res = await _supabase
          .from('posts_with_stats')
          .select(
            'id, user_id, content, image_url, created_at, edited_at, '
            'like_count, comment_count, '
            'profiles(username, full_name, avatar_url)',
          )
          .order('like_count', ascending: false)
          .order('comment_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // HASHTAG HELPERS
  // ============================================================

  /// Extract hashtags from a text
  static List<String> extractHashtags(String content) {
    final regex = RegExp(r'#(\w{1,50})');
    return regex
        .allMatches(content.toLowerCase())
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  /// Get trending hashtags from last N days
  Future<List<MapEntry<String, int>>> getTrendingHashtags({
    int days = 7,
    int limit = 20,
  }) async {
    try {
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toUtc()
          .toIso8601String();

      final res = await _supabase
          .from('posts')
          .select('content')
          .gt('created_at', since)
          .order('created_at', ascending: false)
          .limit(300);

      final counts = <String, int>{};
      for (final p in List<Map<String, dynamic>>.from(res)) {
        final tags = extractHashtags(p['content']?.toString() ?? '');
        for (final t in tags) {
          counts[t] = (counts[t] ?? 0) + 1;
        }
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Search posts by hashtag
  Future<List<Map<String, dynamic>>> searchPostsByHashtag(
    String tag, {
    int limit = 50,
  }) async {
    try {
      final cleanTag = tag.replaceAll('#', '').toLowerCase();

      final res = await _supabase
          .from('posts')
          .select(
            'id, user_id, content, image_url, created_at, edited_at, '
            'profiles(username, full_name, avatar_url)',
          )
          .ilike('content', '%#$cleanTag%')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // PEOPLE YOU MAY KNOW
  // ============================================================

  /// Get suggested users (not followed yet)
  Future<List<Map<String, dynamic>>> getPeopleYouMayKnow({
    int limit = 20,
  }) async {
    final me = currentUserId;
    if (me == null) return [];

    try {
      // Get my following list
      final followsRes = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', me);

      final followingIds = List<Map<String, dynamic>>.from(followsRes)
          .map((r) => r['following_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // Add myself
      followingIds.add(me);

      // Fetch profiles — get more than needed so we can filter
      final res = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, bio, last_seen_at')
          .order('last_seen_at', ascending: false)
          .limit(60);

      final allProfiles = List<Map<String, dynamic>>.from(res);

      // Filter out ones already followed + self
      final filtered = allProfiles
          .where((p) => !followingIds.contains(p['id']?.toString()))
          .take(limit)
          .toList();

      return filtered;
    } catch (e) {
      return [];
    }
  }

  /// Check if I follow a user
  Future<bool> isFollowing(String userId) async {
    final me = currentUserId;
    if (me == null) return false;

    try {
      final res = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', me)
          .eq('following_id', userId)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// Follow a user
  Future<void> follow(String userId) async {
    final me = currentUserId;
    if (me == null || me == userId) return;

    try {
      await _supabase.from('follows').insert({
        'follower_id': me,
        'following_id': userId,
      });
    } catch (e) {
      // Ignore duplicate
      if (e is PostgrestException && e.code == '23505') return;
      rethrow;
    }
  }

  /// Unfollow a user
  Future<void> unfollow(String userId) async {
    final me = currentUserId;
    if (me == null) return;

    try {
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', me)
          .eq('following_id', userId);
    } catch (e) {
      rethrow;
    }
  }
}
