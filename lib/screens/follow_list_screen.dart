import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile/public_profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  /// The user whose followers/following we're showing.
  final String userId;

  /// true = followers list, false = following list.
  final bool showFollowers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  State<FollowListScreen> createState() =>
      _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  bool get _isOwnList => _currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      // Get the row IDs in the `follows` table.
      // If showing followers → everyone whose `following_id` = userId
      // If showing following → everyone whose `follower_id`  = userId
      final followsResponse = await _supabase
          .from('follows')
          .select('follower_id, following_id')
          .eq(
            widget.showFollowers ? 'following_id' : 'follower_id',
            widget.userId,
          );

      final list = List<Map<String, dynamic>>.from(followsResponse);

      final ids = list
          .map((r) => widget.showFollowers
              ? r['follower_id']?.toString()
              : r['following_id']?.toString())
          .whereType<String>()
          .toList();

      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          users = [];
          isLoading = false;
        });
        return;
      }

      // Fetch the profile rows for those user IDs
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', ids);

      final profileList =
          List<Map<String, dynamic>>.from(profilesResponse);

      if (!mounted) return;
      setState(() {
        users = profileList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _show('Failed to load list: $e');
    }
  }

  Future<void> _removeConnection(
      Map<String, dynamic> user) async {
    final otherId = user['id']?.toString();
    if (otherId == null || _currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.showFollowers
              ? 'Remove follower?'
              : 'Unfollow user?',
        ),
        content: Text(
          widget.showFollowers
              ? 'They will no longer follow you.'
              : 'You will no longer follow them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (widget.showFollowers) {
        // Delete row where they follow ME
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', otherId)
            .eq('following_id', widget.userId);
      } else {
        // Delete row where I follow THEM
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', otherId);
      }

      if (!mounted) return;
      setState(() {
        users.removeWhere((u) => u['id'] == otherId);
      });
    } catch (e) {
      if (!mounted) return;
      _show('Action failed: $e');
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: userId),
      ),
    ).then((_) => loadUsers());
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _displayName(Map<String, dynamic> user) {
    final username = user['username']?.toString().trim() ?? '';
    final fullName = user['full_name']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    if (username.isNotEmpty) return '@$username';
    return 'Damadam User';
  }

  String _subtitle(Map<String, dynamic> user) {
    final username = user['username']?.toString().trim() ?? '';
    if (username.isEmpty) return '';
    return '@$username';
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.showFollowers ? 'Followers' : 'Following';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: loadUsers,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : users.isEmpty
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 150),
                      Icon(
                        widget.showFollowers
                            ? Icons.people_outline
                            : Icons.person_add_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: Text(
                          widget.showFollowers
                              ? 'No followers yet'
                              : 'Not following anyone yet',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final avatarUrl =
                          user['avatar_url']?.toString() ?? '';
                      final userId =
                          user['id']?.toString() ?? '';

                      final showRemoveButton = _isOwnList &&
                          userId != _currentUserId;

                      return ListTile(
                        tileColor: Colors.white,
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              Colors.blueGrey.shade100,
                          backgroundImage:
                              avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        title: Text(
                          _displayName(user),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: _subtitle(user).isEmpty
                            ? null
                            : Text(
                                _subtitle(user),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                        onTap: () => _openProfile(userId),
                        trailing: showRemoveButton
                            ? OutlinedButton(
                                onPressed: () =>
                                    _removeConnection(user),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  foregroundColor:
                                      widget.showFollowers
                                          ? Colors.red
                                          : Colors.blue,
                                  side: BorderSide(
                                    color: widget.showFollowers
                                        ? Colors.red.shade200
                                        : Colors.blue.shade200,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  widget.showFollowers
                                      ? 'Remove'
                                      : 'Unfollow',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
      ),
    );
  }
}
