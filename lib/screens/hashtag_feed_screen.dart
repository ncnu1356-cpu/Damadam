
import 'package:flutter/material.dart';

import '../services/explore_service.dart';
import 'profile/public_profile_screen.dart';

class HashtagFeedScreen extends StatefulWidget {
  final String tag;

  const HashtagFeedScreen({
    super.key,
    required this.tag,
  });

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  final ExploreService _explore = ExploreService();

  List<Map<String, dynamic>> posts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await _explore.searchPostsByHashtag(widget.tag);
    if (!mounted) return;
    setState(() {
      posts = data;
      loading = false;
    });
  }

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

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          '#${widget.tag}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 140),
                        Icon(
                          Icons.tag,
                          size: 60,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'No posts with #${widget.tag}',
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final content = post['content']?.toString() ?? '';
                        final imageUrl = post['image_url']?.toString();
                        final profile = post['profiles'];

                        String name = 'Damadam User';
                        String avatar = '';
                        if (profile is Map<String, dynamic>) {
                          final full =
                              profile['full_name']?.toString().trim() ?? '';
                          final uname =
                              profile['username']?.toString().trim() ?? '';
                          name = full.isNotEmpty
                              ? full
                              : (uname.isNotEmpty
                                  ? '@$uname'
                                  : 'Damadam User');
                          avatar = profile['avatar_url']?.toString() ?? '';
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final uid =
                                            post['user_id']?.toString();
                                        if (uid != null && uid.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PublicProfileScreen(
                                                userId: uid,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            Colors.blueGrey.shade100,
                                        backgroundImage: avatar.isNotEmpty
                                            ? NetworkImage(avatar)
                                            : null,
                                        child: avatar.isEmpty
                                            ? const Icon(
                                                Icons.person,
                                                size: 20,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(
                                        post['created_at']?.toString(),
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                if (content.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    content,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: cs.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                if (imageUrl != null &&
                                    imageUrl.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(
                                        height: 150,
                                        child: Center(
                                          child:
                                              Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
