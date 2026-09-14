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

  List<Map<String, dynamic>> groups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _storyService.getStoriesGroupedByUser();
    if (!mounted) return;
    setState(() {
      groups = data;
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

  void _openViewer(int index) {
    final group = groups[index];
    final stories =
        List<Map<String, dynamic>>.from(group['stories'] as List);

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

    return Container(
      height: 108,
      color: cs.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: groups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _addStoryTile(cs);
          return _storyTile(groups[index - 1], cs);
        },
      ),
    );
  }

  Widget _addStoryTile(ColorScheme cs) {
    final myIndex = groups.indexWhere((g) => g['is_me'] == true);
    final hasMyStory = myIndex >= 0;

    return GestureDetector(
      onTap: hasMyStory ? () => _openViewer(myIndex) : _openAddStory,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
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
                    child: Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: Icon(
                      hasMyStory ? Icons.visibility : Icons.add,
                      color: cs.onPrimary,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasMyStory ? 'My Story' : 'Add Story',
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

  Widget _storyTile(Map<String, dynamic> group, ColorScheme cs) {
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

    final idx = groups.indexOf(group);

    return GestureDetector(
      onTap: () => _openViewer(idx),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
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
