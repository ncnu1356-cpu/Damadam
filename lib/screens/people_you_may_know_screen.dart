import 'package:flutter/material.dart';

import '../services/explore_service.dart';
import 'profile/public_profile_screen.dart';

class PeopleYouMayKnowScreen extends StatefulWidget {
  const PeopleYouMayKnowScreen({super.key});

  @override
  State<PeopleYouMayKnowScreen> createState() =>
      _PeopleYouMayKnowScreenState();
}

class _PeopleYouMayKnowScreenState
    extends State<PeopleYouMayKnowScreen> {
  final ExploreService _explore = ExploreService();

  List<Map<String, dynamic>> users = [];
  Set<String> followingNow = {};
  Set<String> loadingIds = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await _explore.getPeopleYouMayKnow(limit: 30);
    if (!mounted) return;
    setState(() {
      users = data;
      loading = false;
    });
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    final uid = user['id']?.toString();
    if (uid == null || uid.isEmpty) return;

    if (loadingIds.contains(uid)) return;
    setState(() => loadingIds.add(uid));

    final isFollowing = followingNow.contains(uid);

    try {
      if (isFollowing) {
        await _explore.unfollow(uid);
        if (!mounted) return;
        setState(() => followingNow.remove(uid));
      } else {
        await _explore.follow(uid);
        if (!mounted) return;
        setState(() => followingNow.add(uid));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loadingIds.remove(uid));
    }
  }

  String _displayName(Map<String, dynamic> u) {
    final full = u['full_name']?.toString().trim() ?? '';
    if (full.isNotEmpty) return full;
    final uname = u['username']?.toString().trim() ?? '';
    if (uname.isNotEmpty) return '@$uname';
    return 'Damadam User';
  }

  String _subtitle(Map<String, dynamic> u) {
    final uname = u['username']?.toString().trim() ?? '';
    final bio = u['bio']?.toString().trim() ?? '';
    if (bio.isNotEmpty) return bio;
    if (uname.isNotEmpty) return '@$uname';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'People You May Know',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: users.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 140),
                        Icon(
                          Icons.people_outline,
                          size: 70,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'No suggestions right now',
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Try following more people to get suggestions',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _userTile(user, cs);
                      },
                    ),
            ),
    );
  }

  Widget _userTile(Map<String, dynamic> user, ColorScheme cs) {
    final uid = user['id']?.toString() ?? '';
    final avatar = user['avatar_url']?.toString() ?? '';
    final isFollowing = followingNow.contains(uid);
    final isBusy = loadingIds.contains(uid);

    return Container(
      color: cs.surface,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicProfileScreen(userId: uid),
            ),
          ).then((_) => _load());
        },
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.blueGrey.shade100,
          backgroundImage:
              avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(
          _displayName(user),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: _subtitle(user).isEmpty
            ? null
            : Text(
                _subtitle(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
        trailing: SizedBox(
          width: 100,
          height: 36,
          child: isFollowing
              ? OutlinedButton(
                  onPressed: isBusy ? null : () => _toggleFollow(user),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: cs.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Following',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                )
              : FilledButton(
                  onPressed: isBusy ? null : () => _toggleFollow(user),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Follow',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
        ),
      ),
    );
  }
}
