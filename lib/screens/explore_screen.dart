import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/explore_service.dart';
import 'hashtag_feed_screen.dart';
import 'profile/public_profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ExploreService _explore = ExploreService();

  List<Map<String, dynamic>> posts = [];
  List<MapEntry<String, int>> hashtags = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final postsData = await _explore.getTrendingPosts(limit: 30);
    final hashtagData = await _explore.getTrendingHashtags();

    if (!mounted) return;
    setState(() {
      posts = postsData;
      hashtags = hashtagData;
      loading = false;
    });
  }

  Future<void> _refresh() async {
    await _load();
  }

  void _openHashtag(String tag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HashtagFeedScreen(tag: tag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'Explore',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  if (hashtags.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Trending Hashtags',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: hashtags.length,
                        itemBuilder: (context, index) {
                          final tag = hashtags[index].key;
                          final count = hashtags[index].value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            child: ActionChip(
                              avatar: Icon(
                                Icons.tag,
                                size: 16,
                                color: cs.primary,
                              ),
                              label: Text(
                                '$tag  ·  $count',
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              backgroundColor: cs.surfaceContainerHighest,
                              onPressed: () => _openHashtag(tag),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: cs.outlineVariant),
                  ],

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Trending Posts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),

                  if (posts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 60,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No trending posts yet',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  else
                    ...posts.map((p) => _ExplorePostCard(
                          post: p,
                          onTapTag: _openHashtag,
                        )),
                ],
              ),
            ),
    );
  }
}

// ============================================================
// SIMPLE POST CARD (read-only for explore)
// ============================================================

class _ExplorePostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final void Function(String tag) onTapTag;

  const _ExplorePostCard({
    required this.post,
    required this.onTapTag,
  });

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
    final cs = Theme.of(context).colorScheme;
    final content = post['content']?.toString() ?? '';
    final imageUrl = post['image_url']?.toString();
    final likeCount = post['like_count'] ?? 0;
    final commentCount = post['comment_count'] ?? 0;

    final profile = post['profiles'];
    String name = 'Damadam User';
    String avatar = '';
    if (profile is Map<String, dynamic>) {
      final full = profile['full_name']?.toString().trim() ?? '';
      final uname = profile['username']?.toString().trim() ?? '';
      name = full.isNotEmpty
          ? full
          : (uname.isNotEmpty ? '@$uname' : 'Damadam User');
      avatar = profile['avatar_url']?.toString() ?? '';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final uid = post['user_id']?.toString();
                    if (uid != null && uid.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(userId: uid),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blueGrey.shade100,
                    backgroundImage:
                        avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? const Icon(Icons.person,
                            size: 20, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _timeAgo(post['created_at']?.toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildContentWithHashtags(content, cs),
            ],
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 150,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  size: 16,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.comment_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$commentCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: no WidgetSpan — uses TextSpan + TapGestureRecognizer
  Widget _buildContentWithHashtags(String content, ColorScheme cs) {
    final regex = RegExp(r'#(\w{1,50})');
    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(content)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
        ));
      }
      final tag = match.group(1)!;
      spans.add(
        TextSpan(
          text: '#$tag',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTapTag(tag),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastMatchEnd),
      ));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 15,
          color: cs.onSurface,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}
