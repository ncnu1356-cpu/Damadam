import 'package:flutter/material.dart';

import '../screens/profile/create_story_screen.dart';
import '../screens/profile/story_viewer_screen.dart';
import '../services/story_service.dart';

class StoriesStrip extends StatefulWidget {
  final VoidCallback? onStoryPublished;

  const StoriesStrip({super.key, this.onStoryPublished});

  @override
  State<StoriesStrip> createState() => _StoriesStripState();
}

class _StoriesStripState extends State<StoriesStrip> {
  final StoryService _storyService = StoryService();

  // ✅ My group separate
  Map<String, dynamic>? myGroup;
  List<Map<String, dynamic>> otherGroups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _storyService.getStoriesGroupedByUser();

    Map<String, dynamic>? mine;
    final others = <Map<String, dynamic>>[];

    for (final g in data) {
      if (g['is_me'] == true) {
        mine = g;
      } else {
        others.add(g);
      }
    }

    if (!mounted) return;
    setState(() {
      myGroup = mine;
      otherGroups = others;
      loading = false;
    });
  }

  Future<void> _openAddStory() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateStoryScreen(),
      ),
    );
    if (created == true) {
      await _load();
      widget.onStoryPublished?.call();
    }
  }

  void _openMyStory() {
    final g = myGroup;
    if (g == null) {
      _openAddStory();
      return;
    }
    final stories =
        List<Map<String, dynamic>>.from(g['stories'] as List);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          stories: stories,
          initialIndex: 0,
        ),
      ),
    ).then((_) => _load());
  }

  void _openOtherStory(int index) {
    final g = otherGroups[index];
    final stories =
        List<Map<String, dynamic>>.from(g['stories'] as List);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          stories: stories,
          initialIndex: 0,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 108,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final hasMyStory = myGroup != null;

    return Container(
      height: 108,
      color: cs.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: otherGroups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _myStoryTile(cs, hasMyStory);
          }
          return _storyTile(otherGroups[index - 1], cs, index - 1);
        },
      ),
    );
  }

  // ✅ My story tile — shows view + add
  Widget _myStoryTile(ColorScheme cs, bool hasMyStory) {
    final profile = myGroup?['profile'];
    String avatarUrl = '';
    if (profile is Map<String, dynamic>) {
      avatarUrl = profile['avatar_url']?.toString() ?? '';
    }

    final storyCount = myGroup != null
        ? (myGroup!['stories'] as List).length
        : 0;

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Stack(
            children: [
              // Tappable avatar area
              GestureDetector(
                onTap: _openMyStory,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasMyStory ? cs.primary : cs.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? Image.network(avatarUrl, fit: BoxFit.cover)
                        : Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
              ),

              // ✅ Small "+" badge always visible (bottom-right)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _openAddStory,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.add,
                      color: cs.onPrimary,
                      size: 14,
                    ),
                  ),
                ),
              ),

              // ✅ Story count badge (top-right) if multiple
              if (storyCount > 1)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.surface, width: 1.5),
                    ),
                    child: Text(
                      '$storyCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'My Story',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyTile(
    Map<String, dynamic> group,
    ColorScheme cs,
    int index,
  ) {
    final profile = group['profile'];
    String name = 'User';
    String avatarUrl = '';

    if (profile is Map<String, dynamic>) {
      final full = profile['full_name']?.toString().trim() ?? '';
      final uname = profile['username']?.toString().trim() ?? '';
      name = full.isNotEmpty ? full : (uname.isNotEmpty ? uname : 'User');
      avatarUrl = profile['avatar_url']?.toString() ?? '';
    }

    if (name.length > 10) {
      name = '${name.substring(0, 10)}…';
    }

    final storyCount = (group['stories'] as List).length;

    return GestureDetector(
      onTap: () => _openOtherStory(index),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        cs.primary,
                        Colors.purple.shade400,
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.surface,
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 28,
                              color: cs.onSurfaceVariant,
                            )
                          : null,
                    ),
                  ),
                ),
                // Story count badge
                if (storyCount > 1)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.surface, width: 1.5),
                      ),
                      child: Text(
                        '$storyCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
