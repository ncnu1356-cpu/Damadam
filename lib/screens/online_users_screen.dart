import 'dart:async';

import 'package:flutter/material.dart';

import '../services/online_service.dart';
import 'profile/public_profile_screen.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  State<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> {
  final OnlineService _online = OnlineService();
  final TextEditingController _filterController = TextEditingController();

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> grouped = [];
  bool loading = true;
  String filter = '';

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();

    // Auto-refresh every 30 seconds (online status changes fast)
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(silent: true),
    );

    _filterController.addListener(() {
      setState(() => filter = _filterController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);

    final list = await _online.getOnlineUsers();
    if (!mounted) return;

    setState(() {
      users = list;
      grouped = _online.groupByLetter(list);
      loading = false;
    });
  }

  List<Map<String, dynamic>> _filteredGrouped() {
    if (filter.isEmpty) return grouped;

    final result = <Map<String, dynamic>>[];
    for (final group in grouped) {
      final letter = group['letter'] as String;
      final groupUsers = (group['users'] as List).where((u) {
        final full = u['full_name']?.toString().toLowerCase() ?? '';
        final uname = u['username']?.toString().toLowerCase() ?? '';
        return full.contains(filter) ||
            uname.contains(filter) ||
            letter.toLowerCase().contains(filter);
      }).toList();

      if (groupUsers.isNotEmpty) {
        result.add({
          'letter': letter,
          'users': groupUsers,
        });
      }
    }
    return result;
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: userId),
      ),
    ).then((_) => _load());
  }

  String _displayName(Map<String, dynamic> u) {
    final full = u['full_name']?.toString().trim() ?? '';
    if (full.isNotEmpty) return full;
    final uname = u['username']?.toString().trim() ?? '';
    if (uname.isNotEmpty) return '@$uname';
    return 'Damadam User';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final view = _filteredGrouped();

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'Online Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _filterController,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Search online users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _filterController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),

          // List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : view.isEmpty
                    ? _emptyState(cs)
                    : RefreshIndicator(
                        onRefresh: () => _load(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: view.length,
                          itemBuilder: (context, index) {
                            final group = view[index];
                            final letter = group['letter'] as String;
                            final groupUsers =
                                group['users'] as List<dynamic>;

                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _letterHeader(letter, cs),
                                ...groupUsers.map((u) =>
                                    _userTile(u as Map<String, dynamic>, cs)),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _letterHeader(String letter, ColorScheme cs) {
    return Container(
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, ColorScheme cs) {
    final uid = user['id']?.toString() ?? '';
    final avatar = user['avatar_url']?.toString() ?? '';
    final lastSeen = user['last_seen_at']?.toString();
    final online = _online.isOnlineNow(lastSeen);
    final label = _online.lastSeenLabel(lastSeen);

    return Container(
      color: cs.surface,
      child: ListTile(
        onTap: () => _openProfile(uid),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage:
                  avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            // Green dot for truly online users
            if (online)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          _displayName(user),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          online ? 'online' : label,
          style: TextStyle(
            fontSize: 12,
            color: online ? Colors.green.shade700 : cs.onSurfaceVariant,
            fontWeight: online ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Icon(
          Icons.person_off_outlined,
          size: 70,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            filter.isEmpty ? 'No one is online right now' : 'No users found',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            filter.isEmpty
                ? 'Users appear here when active in the last 10 min'
                : 'Try a different search',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
