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
}
