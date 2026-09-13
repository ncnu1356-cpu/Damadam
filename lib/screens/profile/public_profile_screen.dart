import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/profile_service.dart';

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
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> posts = [];

  int followersCount = 0;
  int followingCount = 0;

  bool isFollowing = false;
  bool loading = true;
  bool followLoading = false;

  bool get isOwnProfile =>
      _supabase.auth.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final loadedProfile =
          await _profileService.getProfile(widget.userId);

      final postsResponse = await _supabase
          .from('posts')
          .select(
            'id, user_id, content, image_url, created_at',
          )
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

        posts = List<Map<String, dynamic>>.from(
          postsResponse,
        );

        followersCount = followersResponse.length;
        followingCount = followingResponse.length;

        isFollowing = following;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: $e'),
        ),
      );
    }
  }

  Future<void> toggleFollow() async {
    final currentUser = _supabase.auth.currentUser;

    if (currentUser == null) {
      return;
    }

    if (isOwnProfile || followLoading) {
      return;
    }

    setState(() {
      followLoading = true;
    });

    try {
      if (isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq(
              'follower_id',
              currentUser.id,
            )
            .eq(
              'following_id',
              widget.userId,
            );

        if (!mounted) return;

        setState(() {
          isFollowing = false;

          if (followersCount > 0) {
            followersCount--;
          }
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
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update follow status: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          followLoading = false;
        });
      }
    }
  }

  String getString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

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
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : profile == null
              ? const Center(
                  child: Text('Profile not found'),
                )
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

  Widget _buildProfileHeader() {
    final username =
        getString(profile?['username']);

    final fullName =
        getString(profile?['full_name']);

    final bio =
        getString(profile?['bio']);

    final avatarUrl =
        getString(profile?['avatar_url']);

    final coverUrl =
        getString(profile?['cover_url']);

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
                    backgroundColor:
                        Colors.grey.shade300,
                    backgroundImage:
                        avatarUrl.isNotEmpty
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
          padding:
              const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isNotEmpty
                    ? fullName
                    : username,
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
                  style: const TextStyle(
                    fontSize: 15,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              Row(
                children: [
                  _statItem(
                    posts.length.toString(),
                    'Posts',
                  ),
                  const SizedBox(width: 28),
                  _statItem(
                    followersCount.toString(),
                    'Followers',
                  ),
                  const SizedBox(width: 28),
                  _statItem(
                    followingCount.toString(),
                    'Following',
                  ),
                ],
              ),

              if (!isOwnProfile) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed:
                        followLoading
                            ? null
                            : toggleFollow,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                    child: followLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isFollowing
                                ? 'Following'
                                : 'Follow',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(
    String number,
    String label,
  ) {
    return Column(
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
  }

  Widget _buildPostsSection() {
    if (posts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        color: Colors.white,
        child: const Center(
          child: Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
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

  const _PublicPostCard({
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        post['content']?.toString() ?? '';

    final imageUrl =
        post['image_url']?.toString() ?? '';

    final createdAt =
        post['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (content.isNotEmpty)
              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),

            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) =>
                          const SizedBox(
                    height: 150,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                createdAt,
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
