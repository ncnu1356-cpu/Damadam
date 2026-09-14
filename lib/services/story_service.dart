import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class StoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Get all non-expired stories (mine + followed users)
  Future<List<Map<String, dynamic>>> getActiveStories() async {
    try {
      final me = currentUserId;
      if (me == null) return [];

      final followsRes = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', me);

      final followingIds = List<Map<String, dynamic>>.from(followsRes)
          .map((r) => r['following_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      followingIds.add(me);

      final res = await _supabase
          .from('stories')
          .select()
          .inFilter('user_id', followingIds)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(res);
      if (list.isEmpty) return [];

      final userIds =
          list.map((s) => s['user_id']?.toString() ?? '').toSet().toList();

      final profilesRes = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', userIds);

      final profilesMap = <String, Map<String, dynamic>>{};
      for (final p in List<Map<String, dynamic>>.from(profilesRes)) {
        profilesMap[p['id'].toString()] = p;
      }

      for (final s in list) {
        s['profile'] = profilesMap[s['user_id']?.toString()];
      }

      return list;
    } catch (e) {
      return [];
    }
  }

  /// Group stories by user for the horizontal strip
  Future<List<Map<String, dynamic>>> getStoriesGroupedByUser() async {
    final stories = await getActiveStories();
    if (stories.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in stories) {
      final uid = s['user_id']?.toString() ?? '';
      grouped.putIfAbsent(uid, () => []).add(s);
    }

    final me = currentUserId;
    final result = <Map<String, dynamic>>[];

    for (final entry in grouped.entries) {
      final userStories = entry.value
        ..sort((a, b) {
          final at = a['created_at']?.toString() ?? '';
          final bt = b['created_at']?.toString() ?? '';
          return at.compareTo(bt);
        });

      result.add({
        'user_id': entry.key,
        'profile': userStories.first['profile'],
        'stories': userStories,
        'is_me': entry.key == me,
      });
    }

    result.sort((a, b) {
      if (a['is_me'] == true) return -1;
      if (b['is_me'] == true) return 1;
      final aLatest =
          (a['stories'] as List).last['created_at']?.toString() ?? '';
      final bLatest =
          (b['stories'] as List).last['created_at']?.toString() ?? '';
      return bLatest.compareTo(aLatest);
    });

    return result;
  }

  /// Create new story
  Future<void> createStory({
    required File image,
    String? caption,
  }) async {
    final me = currentUserId;
    if (me == null) throw Exception('User is not logged in.');

    final ext = image.path.contains('.')
        ? image.path.split('.').last.toLowerCase()
        : 'jpg';

    final fileName =
        '${me}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final path = 'stories/$fileName';

    await _supabase.storage.from('post-images').upload(
          path,
          image,
          fileOptions: FileOptions(
            upsert: false,
            contentType: 'image/$ext',
          ),
        );

    final url =
        _supabase.storage.from('post-images').getPublicUrl(path);

    await _supabase.from('stories').insert({
      'user_id': me,
      'image_url': url,
      'caption': caption,
    });
  }

  /// Delete a story
  Future<void> deleteStory(String storyId) async {
    await _supabase.from('stories').delete().eq('id', storyId);
  }

  /// Cleanup expired stories of the current user
  Future<void> cleanMyExpiredStories() async {
    final me = currentUserId;
    if (me == null) return;

    try {
      await _supabase
          .from('stories')
          .delete()
          .eq('user_id', me)
          .lt(
            'expires_at',
            DateTime.now().toUtc().toIso8601String(),
          );
    } catch (_) {}
  }

  // ============================================================
  // VIEWS
  // ============================================================

  Future<void> markAsViewed(String storyId) async {
    final me = currentUserId;
    if (me == null) return;

    try {
      await _supabase.from('story_views').upsert(
        {
          'story_id': storyId,
          'viewer_id': me,
        },
        onConflict: 'story_id,viewer_id',
        ignoreDuplicates: true,
      );
    } catch (_) {}
  }

  Future<int> getViewCount(String storyId) async {
    try {
      final res = await _supabase
          .from('story_views')
          .select('id')
          .eq('story_id', storyId);
      return res.length;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  Future<void> reactToStory({
    required String storyId,
    required String emoji,
    required String ownerId,
  }) async {
    final me = currentUserId;
    if (me == null || me == ownerId) return;

    try {
      await _supabase.from('story_reactions').upsert(
        {
          'story_id': storyId,
          'user_id': me,
          'emoji': emoji,
        },
        onConflict: 'story_id,user_id',
      );

      final profile = await _supabase
          .from('profiles')
          .select('username, full_name')
          .eq('id', me)
          .maybeSingle();

      final username = profile?['username']?.toString().trim();
      final displayName = username != null && username.isNotEmpty
          ? '@$username'
          : (profile?['full_name']?.toString().trim().isNotEmpty == true
              ? profile!['full_name'].toString().trim()
              : 'Someone');

      await _supabase.from('notifications').insert({
        'user_id': ownerId,
        'sender_id': me,
        'type': 'story_reaction',
        'message': '$displayName reacted $emoji to your story',
        'is_read': false,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getMyReaction(String storyId) async {
    final me = currentUserId;
    if (me == null) return null;

    try {
      final res = await _supabase
          .from('story_reactions')
          .select()
          .eq('story_id', storyId)
          .eq('user_id', me)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<int> getReactionCount(String storyId) async {
    try {
      final res = await _supabase
          .from('story_reactions')
          .select('id')
          .eq('story_id', storyId);
      return res.length;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // REPLY
  // ============================================================

  Future<void> sendStoryReply({
    required String storyId,
    required String ownerId,
    required String content,
  }) async {
    final me = currentUserId;
    if (me == null) throw Exception('User is not logged in.');
    if (me == ownerId) return;

    final profile = await _supabase
        .from('profiles')
        .select('username, full_name')
        .eq('id', me)
        .maybeSingle();

    final username = profile?['username']?.toString().trim();
    final displayName = username != null && username.isNotEmpty
        ? '@$username'
        : (profile?['full_name']?.toString().trim().isNotEmpty == true
            ? profile!['full_name'].toString().trim()
            : 'Someone');

    await _supabase.from('notifications').insert({
      'user_id': ownerId,
      'sender_id': me,
      'type': 'story_reply',
      'message': '$displayName replied to your story: $content',
      'is_read': false,
    });
  }
}
