import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _me => _supabase.auth.currentUser?.id;

  // Have I blocked this user?
  Future<bool> hasBlocked(String otherUserId) async {
    final me = _me;
    if (me == null) return false;

    try {
      final res = await _supabase
          .from('blocks')
          .select('id')
          .eq('blocker_id', me)
          .eq('blocked_id', otherUserId)
          .maybeSingle();

      return res != null;
    } catch (_) {
      return false;
    }
  }

  // Has this user blocked me?
  Future<bool> isBlockedBy(String otherUserId) async {
    final me = _me;
    if (me == null) return false;

    try {
      final res = await _supabase
          .from('blocks')
          .select('id')
          .eq('blocker_id', otherUserId)
          .eq('blocked_id', me)
          .maybeSingle();

      return res != null;
    } catch (_) {
      return false;
    }
  }

  // Either direction?
  Future<bool> isBlockedEitherWay(String otherUserId) async {
    final a = await hasBlocked(otherUserId);
    if (a) return true;
    return await isBlockedBy(otherUserId);
  }

  Future<void> block(String otherUserId) async {
    final me = _me;
    if (me == null || me == otherUserId) return;

    await _supabase.from('blocks').insert({
      'blocker_id': me,
      'blocked_id': otherUserId,
    });
  }

  Future<void> unblock(String otherUserId) async {
    final me = _me;
    if (me == null) return;

    await _supabase
        .from('blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', otherUserId);
  }

  // List of users I've blocked
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final me = _me;
    if (me == null) return [];

    final res = await _supabase
        .from('blocks')
        .select(
          'id, created_at, blocked_id, '
          'profiles!blocks_blocked_id_fkey(id, username, full_name, avatar_url)',
        )
        .eq('blocker_id', me)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }
}
