import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/explore_service.dart';
import 'people_you_may_know_screen.dart';
import 'profile/public_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ExploreService _explore = ExploreService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> results = [];
  List<Map<String, dynamic>> suggestions = [];

  bool loadingResults = false;
  bool loadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, bio')
          .neq('id', currentUserId ?? '')
          .limit(30);

      if (!mounted) return;
      setState(() {
        suggestions = List<Map<String, dynamic>>.from(response);
        loadingSuggestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingSuggestions = false);
      _show('Could not load users: $e');
    }
  }

  Future<void> _search(String query) async {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      setState(() {
        results = [];
        loadingResults = false;
      });
      return;
    }

    setState(() => loadingResults = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, bio')
          .or('username.ilike.%$q%,full_name.ilike.%$q%')
          .neq('id', currentUserId ?? '')
          .limit(30);

      if (!mounted) return;
      setState(() {
        results = List<Map<String, dynamic>>.from(response);
        loadingResults = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingResults = false);
      _show('Search failed: $e');
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: userId),
      ),
    ).then((_) => _loadSuggestions());
  }

  String _displayName(Map<String, dynamic> user) {
    final full = user['full_name']?.toString().trim() ?? '';
    if (full.isNotEmpty) return full;
    final username = user['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return 'Damadam User';
  }

  String _subtitle(Map<String, dynamic> user) {
    final username = user['username']?.toString().trim() ?? '';
    final bio = user['bio']?.toString().trim() ?? '';

    if (bio.isNotEmpty) return bio;
    if (username.isNotEmpty) return '@$username';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final showingResults = _searchController.text.trim().isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              autocorrect: false,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by username or name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                          setState(() {});
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

          // RESULTS / SUGGESTIONS
          Expanded(
            child: showingResults
                ? _buildResults(cs)
                : _buildSuggestions(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme cs) {
    if (loadingResults) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.search_off,
            size: 70,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No users found',
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
              'Try a different username',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: cs.outlineVariant,
      ),
      itemBuilder: (context, index) =>
          _userTile(results[index], cs),
    );
  }

  Widget _buildSuggestions(ColorScheme cs) {
    if (loadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ✅ People You May Know button
        Container(
          color: cs.surface,
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PeopleYouMayKnowScreen(),
                ),
              ).then((_) => _loadSuggestions());
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add_alt_1,
                color: cs.primary,
                size: 22,
              ),
            ),
            title: const Text(
              'People You May Know',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              'Follow more people to see their posts',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'All Users',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),

        if (suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 60,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No other users yet',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          )
        else
          ...suggestions.map((u) => _userTile(u, cs)),
      ],
    );
  }

  Widget _userTile(Map<String, dynamic> user, ColorScheme cs) {
    final avatarUrl = user['avatar_url']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';

    return Container(
      color: cs.surface,
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blueGrey.shade100,
          backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(
          _displayName(user),
          style: const TextStyle(fontWeight: FontWeight.w600),
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
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
        onTap: () => _openProfile(userId),
      ),
    );
  }
}
