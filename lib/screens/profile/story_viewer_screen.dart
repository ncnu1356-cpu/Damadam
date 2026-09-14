import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/story_service.dart';
import 'public_profile_screen.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  final StoryService _storyService = StoryService();
  final TextEditingController _replyController = TextEditingController();

  late PageController _pageController;
  late AnimationController _progressController;
  Timer? _autoAdvanceTimer;

  // ✅ Local copy so we can delete individual stories
  late List<Map<String, dynamic>> _stories;

  int _currentIndex = 0;
  bool _paused = false;

  int _viewCount = 0;
  String? _myReaction;

  String? get _me => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _stories = List<Map<String, dynamic>>.from(widget.stories);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _startStory();
  }

  void _startStory() {
    if (_stories.isEmpty) return;

    _progressController.reset();
    _progressController.forward();
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(seconds: 5), _next);

    // Mark as viewed
    _markViewed();
    // Load stats
    _loadStats();
  }

  Future<void> _markViewed() async {
    if (_currentIndex >= _stories.length) return;
    final story = _stories[_currentIndex];
    final storyId = story['id']?.toString();
    if (storyId == null) return;

    await _storyService.markAsViewed(storyId);
  }

  Future<void> _loadStats() async {
    if (_currentIndex >= _stories.length) return;
    final story = _stories[_currentIndex];
    final storyId = story['id']?.toString();
    if (storyId == null) return;

    final isMine = story['user_id']?.toString() == _me;

    int views = 0;
    if (isMine) {
      views = await _storyService.getViewCount(storyId);
    }

    final reaction = await _storyService.getMyReaction(storyId);

    if (!mounted) return;
    setState(() {
      _viewCount = views;
      _myReaction = reaction?['emoji']?.toString();
    });
  }

  void _next() {
    if (_currentIndex < _stories.length - 1) {
      setState(() => _currentIndex++);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      // End of all stories
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pause() {
    _paused = true;
    _progressController.stop();
    _autoAdvanceTimer?.cancel();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    final remaining = Duration(
      milliseconds: (5000 * (1 - _progressController.value)).round(),
    );
    _progressController.animateTo(1, duration: remaining);
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(remaining, _next);
  }

  // ✅ DELETE — removes only current story, moves next or pops
  Future<void> _deleteCurrentStory() async {
    if (_currentIndex >= _stories.length) return;

    final story = _stories[_currentIndex];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete story?'),
        content: const Text('This will remove it permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _storyService.deleteStory(story['id'].toString());

      if (!mounted) return;

      // Remove from local list
      _stories.removeAt(_currentIndex);

      if (_stories.isEmpty) {
        Navigator.pop(context);
        return;
      }

      // Adjust index
      if (_currentIndex >= _stories.length) {
        _currentIndex = _stories.length - 1;
      }

      setState(() {});

      // Jump page controller to correct index
      _pageController.jumpToPage(_currentIndex);
      _startStory();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  // ✅ Open story owner's profile
  void _openProfile() {
    if (_currentIndex >= _stories.length) return;
    final story = _stories[_currentIndex];
    final userId = story['user_id']?.toString();
    if (userId == null || userId.isEmpty) return;
    if (userId == _me) return;

    _pause();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: userId),
      ),
    ).then((_) => _resume());
  }

  // ✅ Send reply → DM-style notification
  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    if (_currentIndex >= _stories.length) return;

    final story = _stories[_currentIndex];
    final storyId = story['id']?.toString();
    final ownerId = story['user_id']?.toString();

    if (storyId == null || ownerId == null) return;
    if (ownerId == _me) return;

    _replyController.clear();

    try {
      await _storyService.sendStoryReply(
        storyId: storyId,
        ownerId: ownerId,
        content: text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply sent'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reply failed: $e')),
      );
    }
  }

  // ✅ React with emoji
  Future<void> _react(String emoji) async {
    if (_currentIndex >= _stories.length) return;
    final story = _stories[_currentIndex];
    final storyId = story['id']?.toString();
    final ownerId = story['user_id']?.toString();
    if (storyId == null || ownerId == null) return;
    if (ownerId == _me) return;

    try {
      await _storyService.reactToStory(
        storyId: storyId,
        emoji: emoji,
        ownerId: ownerId,
      );

      if (!mounted) return;
      setState(() => _myReaction = emoji);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reacted $emoji'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaction failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _progressController.dispose();
    _pageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No stories',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story content
          GestureDetector(
            onTapDown: (_) => _pause(),
            onTapUp: (_) => _resume(),
            onTapCancel: () => _resume(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _stories.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return _storyContent(_stories[index]);
              },
            ),
          ),

          // Top bars + header
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: List.generate(
                      _stories.length,
                      (i) => Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, _) {
                              double value;
                              if (i < _currentIndex) {
                                value = 1.0;
                              } else if (i > _currentIndex) {
                                value = 0.0;
                              } else {
                                value = _progressController.value;
                              }
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                                minHeight: 3,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _storyHeader(),
              ],
            ),
          ),

          // Left / Right tap zones
          Positioned.fill(
            top: 100,
            bottom: 100,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _prev,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _next,
                  ),
                ),
              ],
            ),
          ),

          // Bottom: reply + reactions (only if not my story)
          if (_stories[_currentIndex]['user_id']?.toString() != _me)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _bottomBar(),
            ),

          // Own story: view count
          if (_stories[_currentIndex]['user_id']?.toString() == _me)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _viewsBadge(),
            ),
        ],
      ),
    );
  }

  Widget _storyContent(Map<String, dynamic> story) {
    final imageUrl = story['image_url']?.toString() ?? '';
    final caption = story['caption']?.toString() ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: imageUrl.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
        ),
        if (caption.isNotEmpty)
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _storyHeader() {
    final story = _stories[_currentIndex];
    final profile = story['profile'];
    String name = 'Damadam User';
    String avatarUrl = '';
    if (profile is Map<String, dynamic>) {
      final full = profile['full_name']?.toString().trim() ?? '';
      final uname = profile['username']?.toString().trim() ?? '';
      name = full.isNotEmpty
          ? full
          : (uname.isNotEmpty ? '@$uname' : 'Damadam User');
      avatarUrl = profile['avatar_url']?.toString() ?? '';
    }

    final isMine = story['user_id']?.toString() == _me;
    final timeAgo = _timeAgo(story['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // ✅ Tap avatar → profile
          GestureDetector(
            onTap: isMine ? null : _openProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // ✅ Tap name → profile
          Expanded(
            child: GestureDetector(
              onTap: isMine ? null : _openProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteCurrentStory,
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _viewsBadge() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_viewCount ${_viewCount == 1 ? 'view' : 'views'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji reactions row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😮', '😢', '👏']
                  .map((e) => _emojiButton(e))
                  .toList(),
            ),
            const SizedBox(height: 10),
            // Reply input
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white38, width: 1),
                    ),
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Reply to story...',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12),
                      ),
                      onTap: _pause,
                      onSubmitted: (_) {
                        _sendReply();
                        _resume();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    _sendReply();
                    _resume();
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiButton(String emoji) {
    final selected = _myReaction == emoji;
    return GestureDetector(
      onTap: () => _react(emoji),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: selected ? 28 : 24,
          ),
        ),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
