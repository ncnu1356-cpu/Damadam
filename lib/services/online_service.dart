import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Get online users sorted alphabetically.
  /// Online = last_seen_at within last `window` (default 10 min)
  Future<List<Map<String, dynamic>>> getOnlineUsers({
    Duration window = const Duration(minutes: 10),
  }) async {
    try {
      final cutoff = DateTime.now()
          .subtract(window)
          .toUtc()
          .toIso8601String();

      final me = currentUserId;

      final res = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, last_seen_at')
          .gt('last_seen_at', cutoff)
          .order('last_seen_at', ascending: false)
          .limit(500);

      final list = List<Map<String, dynamic>>.from(res);

      // Remove self
      final filtered = list
          .where((p) => p['id']?.toString() != me)
          .toList();

      // Sort alphabetically by display name
      filtered.sort((a, b) {
        final aKey = _displayKey(a);
        final bKey = _displayKey(b);
        return aKey.compareTo(bKey);
      });

      return filtered;
    } catch (e) {
      return [];
    }
  }

  /// Key for sorting: prefer full_name, fallback to username
  String _displayKey(Map<String, dynamic> u) {
    final full = u['full_name']?.toString().trim() ?? '';
    if (full.isNotEmpty) return full.toLowerCase();
    return (u['username']?.toString().trim() ?? '').toLowerCase();
  }

  /// True if last seen within last 60 seconds
  bool isOnlineNow(String? lastSeenIso) {
    if (lastSeenIso == null) return false;
    final dt = DateTime.tryParse(lastSeenIso)?.toLocal();
    if (dt == null) return false;
    return DateTime.now().difference(dt).inSeconds < 60;
  }

  /// "online" or "X min ago" label
  String lastSeenLabel(String? lastSeenIso) {
    if (lastSeenIso == null) return '';
    final dt = DateTime.tryParse(lastSeenIso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'online';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Group users by first letter of display name
  /// Returns List of {letter, users}
  List<Map<String, dynamic>> groupByLetter(
    List<Map<String, dynamic>> users,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final u in users) {
      final name = _displayKey(u);
      final first = name.isEmpty ? '#' : name[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
      grouped.putIfAbsent(key, () => []).add(u);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return sortedKeys
        .map((k) => {
              'letter': k,
              'users': grouped[k]!,
            })
        .toList();
  }
}
