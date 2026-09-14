
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/profile_service.dart';
import '../../services/notification_service.dart';
import '../../services/dm_service.dart';
import '../../services/block_service.dart';
import '../../services/report_service.dart';
import '../chat_screen.dart';
import '../follow_list_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState
    extends State<PublicProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final DmService _dm = DmService();
  final BlockService _blockService = BlockService();
  final ReportService _reportService = ReportService();
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> posts = [];

  int followersCount = 0;
  int followingCount = 0;

  bool isFollowing = false;
  bool loading = true;
  bool followLoading = false;

  // DM state
  Map<String, dynamic>? _conversation;
  bool _canMessage = false;
  bool _checkingDm = true;
  bool _sendingRequest = false;

  // Block state
  bool _iBlocked = false;
  bool _theyBlockedMe = false;
  bool _blockLoading = false;

  bool get isOwnProfile =>
      _supabase.auth.currentUser?.id == widget.userId;

  bool get _isBlocked => _iBlocked || _theyBlockedMe;

  @override
  void initState() {
    super.initState();
    loadProfile();
    _loadDmState();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    if (isOwnProfile) {
      setState(() {
        _iBlocked = false;
        _theyBlockedMe = false;
      });
      return;
    }

    try {
      final mine = await _blockService.hasBlocked(widget.userId);
      final theirs = await _blockService.isBlockedBy(widget.userId);
      if (!mounted) return;
      setState(() {
        _iBlocked = mine;
        _theyBlockedMe = theirs;
      });
    } catch (e) {
      debugPrint('Block state error: $e');
    }
  }

  Future<void> loadProfile() async {
    try {
      final loadedProfile =
          await _profileService.getProfile(widget.userId);

      final postsResponse = await _supabase
          .from('posts')
          .select('id, user_id, content, image_url, created_at')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      final followersResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('following_id', widget.userId);

      final followingResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', widget.userId);

      bool following = false;

      final currentUser = _supabase.auth.currentUser;

      if (currentUser != null && !isOwnProfile) {
        final existing = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', currentUser.id)
            .eq('following_id', widget.userId)
            .maybeSingle();

        following = existing != null;
      }

      if (!mounted) return;

      setState(() {
        profile = loadedProfile;
        posts = List<Map<String, dynamic>>.from(postsResponse);
        followersCount = followersResponse.length;
        followingCount = followingResponse.length;
        isFollowing = following;
        loading = false;
      });

      await _loadDmState();
      await _loadBlockState();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> _loadDmState() async {
    if (isOwnProfile || _isBlocked) {
      if (!mounted) return;
      setState(() => _checkingDm = false);
      return;
    }

    try {
      final conv = await _dm.findConversation(widget.userId);
      final canMsg = await _dm.canMessage(widget.userId);
      if (!mounted) return;
      setState(() {
        _conversation = conv;
        _canMessage = canMsg;
        _checkingDm = false;
      });
    } catch (e) {
      debugPrint('DM state error: $e');
      if (!mounted) return;
      setState(() => _checkingDm = false);
    }
  }

  Future<void> _sendDmRequest() async {
    setState(() => _sendingRequest = true);
    try {
      await _dm.sendRequest(widget.userId);
      await _loadDmState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent — waiting for approval'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _acceptAndOpenChat() async {
    if (_conversation == null) return;
    setState(() => _sendingRequest = true);
    try {
      await _dm.acceptRequest(_conversation!['id'].toString());
      await _loadDmState();
      if (!mounted) return;
      _openChatWithCurrent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Map<String, dynamic> _prepareConversation(
    Map<String, dynamic> conv,
  ) {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return conv;

    final result = Map<String, dynamic>.from(conv);

    if (conv['requester_id']?.toString() == me) {
      result['recipient'] = profile;
    } else {
      result['requester'] = profile;
    }
    return result;
  }

  void _openChatWithCurrent() {
    if (_conversation == null) return;
    final conv = _prepareConversation(_conversation!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conv),
      ),
    ).then((_) => _loadDmState());
  }

  Future<void> _sendFollowNotification() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || currentUser.id == widget.userId) return;

    try {
      final senderProfile = await _supabase
          .from('profiles')
          .select('username, full_name')
          .eq('id', currentUser.id)
          .maybeSingle();

      final username =
          senderProfile?['username']?.toString().trim() ?? '';
      final fullName =
          senderProfile?['full_name']?.toString().trim() ?? '';

      final displayName = fullName.isNotEmpty
          ? fullName
          : (username.isNotEmpty ? username : 'Someone');

      await NotificationService().createNotification(
        userId: widget.userId,
        senderId: currentUser.id,
        type: 'follow',
        message: '$displayName started following you',
      );
    } catch (e) {
      debugPrint('Follow notification error: $e');
    }
  }

  Future<void> toggleFollow() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;
    if (isOwnProfile || followLoading || _isBlocked) return;

    setState(() => followLoading = true);

    try {
      if (isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUser.id)
            .eq('following_id', widget.userId);

        if (!mounted) return;
        setState(() {
          isFollowing = false;
          if (followersCount > 0) followersCount--;
        });
      } else {
        await _supabase.from('follows').insert({
          'follower_id': currentUser.id,
          'following_id': widget.userId,
        });

        if (!mounted) return;
        setState(() {
          isFollowing = true;
          followersCount++;
        });

        await _sendFollowNotification();
      }

      await _loadDmState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update follow: $e')),
      );
    } finally {
      if (mounted) setState(() => followLoading = false);
    }
  }

  Future<void> _openFollowList({required bool showFollowers}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: widget.userId,
          showFollowers: showFollowers,
        ),
      ),
    );
    await loadProfile();
  }

  // ============================================================
  // BLOCK
  // ============================================================

  Future<void> _toggleBlock() async {
    setState(() => _blockLoading = true);

    try {
      if (_iBlocked) {
        await _blockService.unblock(widget.userId);
        if (!mounted) return;
        setState(() => _iBlocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unblocked')),
        );
      } else {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block this user?'),
            content: const Text(
              'They will not be able to message you or see your posts. Any follow/chat between you will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Block'),
              ),
            ],
          ),
        );

        if (confirm != true) {
          if (mounted) setState(() => _blockLoading = false);
          return;
        }

        await _blockService.block(widget.userId);

        // Clean up follow/chat
        final me = _supabase.auth.currentUser?.id;
        if (me != null) {
          try {
            await _supabase
                .from('follows')
                .delete()
                .or('and(follower_id.eq.$me,following_id.eq.${widget.userId}),'
                    'and(follower_id.eq.${widget.userId},following_id.eq.$me)');
          } catch (_) {}

          try {
            final conv = await _dm.findConversation(widget.userId);
            if (conv != null) {
              await _dm
                  .deleteConversation(conv['id'].toString());
            }
          } catch (_) {}
        }

        if (!mounted) return;
        setState(() {
          _iBlocked = true;
          _conversation = null;
          _canMessage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Block failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _blockLoading = false);
    }
  }

  Future<void> _reportUser() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Report this user',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            for (final r in const [
              'Spam or scam',
              'Nudity',
              'Hate speech',
              'Harassment',
              'Impersonation',
              'Other',
            ])
              ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(context, r),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (reason == null) return;

    try {
      await _reportService.reportUser(
        userId: widget.userId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted — thanks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report failed: $e')),
      );
    }
  }

  String getString(dynamic v) => v?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          profile?['username'] != null
              ? '@${profile!['username']}'
              : 'Profile',
        ),
        centerTitle: true,
        actions: [
          if (!isOwnProfile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'block') _toggleBlock();
                if (value == 'report') _reportUser();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  enabled: !_blockLoading,
                  child: Row(
                    children: [
                      Icon(
                        _iBlocked ? Icons.lock_open : Icons.block,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(_iBlocked ? 'Unblock' : 'Block'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined),
                      SizedBox(width: 8),
                      Text('Report'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? const Center(child: Text('Profile not found'))
              : _isBlocked
                  ? _blockedBanner()
                  : RefreshIndicator(
                      onRefresh: loadProfile,
                      child: ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildProfileHeader(),
                          const SizedBox(height: 10),
                          _buildPostsSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _blockedBanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _iBlocked
                  ? 'You blocked this user'
                  : 'This user is unavailable',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _iBlocked
                  ? 'Unblock from the menu above to see their profile.'
                  : '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final username = getString(profile?['username']);
    final fullName = getString(profile?['full_name']);
    final bio = getString(profile?['bio']);
    final avatarUrl = getString(profile?['avatar_url']);
    final coverUrl = getString(profile?['cover_url']);

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 175,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  image: coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(coverUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: coverUrl.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.image,
                          size: 55,
                          color: Colors.white70,
                        ),
                      )
                    : null,
              ),
              Positioned(
                left: 20,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 55,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isNotEmpty ? fullName : username,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (username.isNotEmpty)
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bio,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  _statItem(posts.length.toString(), 'Posts'),
                  const SizedBox(width: 28),
                  _statItem(
                    followersCount.toString(),
                    'Followers',
                    onTap: () =>
                        _openFollowList(showFollowers: true),
                  ),
                  const SizedBox(width: 28),
                  _statItem(
                    followingCount.toString(),
                    'Following',
                    onTap: () =>
                        _openFollowList(showFollowers: false),
                  ),
                ],
              ),
              if (!isOwnProfile) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: followLoading ? null : toggleFollow,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: followLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_shouldShowDmButton()) ...[
                      const SizedBox(width: 10),
                      Expanded(child: _buildDmButton()),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowDmButton() {
    if (_checkingDm || _isBlocked) return false;
    if (_conversation != null) return true;
    return _canMessage;
  }

  Widget _buildDmButton() {
    final me = _supabase.auth.currentUser?.id;

    if (_conversation == null) {
      if (!_canMessage) return const SizedBox.shrink();

      return SizedBox(
        height: 45,
        child: OutlinedButton.icon(
          onPressed: _sendingRequest ? null : _sendDmRequest,
          icon: _sendingRequest
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text(
            '1on1',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    final status = _conversation!['status']?.toString();
    final requesterId = _conversation!['requester_id']?.toString();
    final isRequester = requesterId == me;

    if (status == 'pending' && isRequester) {
      return SizedBox(
        height: 45,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text(
            'Pending',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (status == 'pending' && !isRequester) {
      return SizedBox(
        height: 45,
        child: ElevatedButton.icon(
          onPressed: _sendingRequest ? null : _acceptAndOpenChat,
          icon: _sendingRequest
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text(
            'Accept chat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (status == 'accepted') {
      return SizedBox(
        height: 45,
        child: ElevatedButton.icon(
          onPressed: _openChatWithCurrent,
          icon: const Icon(Icons.chat_bubble, size: 18),
          label: const Text(
            'Message',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _statItem(
    String number,
    String label, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: content,
      ),
    );
  }

  Widget _buildPostsSection() {
    if (posts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        color: Colors.white,
        child: const Center(
          child: Text(
            'No posts yet',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: posts.map((post) {
        return _PublicPostCard(post: post);
      }).toList(),
    );
  }
}

class _PublicPostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PublicPostCard({required this.post});

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final content = post['content']?.toString() ?? '';
    final imageUrl = post['image_url']?.toString() ?? '';
    final createdAt = post['created_at']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.isNotEmpty)
              Text(content, style: const TextStyle(fontSize: 16)),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 150,
                    child: Center(
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            ],
            if (createdAt != null && createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _timeAgo(createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
