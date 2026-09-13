import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile/public_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController =
      TextEditingController();

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

  // ──────────────────────────────────────────────
  // SUGGESTED USERS (shown when search is empty)
  // ──────────────────────────────────────────────
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

  // ──────────────────────────────────────────────
  // SEARCH
  // ──────────────────────────────────────────────
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Container(
            color: Colors.white,
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
                fillColor: const Color(0xFFF2F3F7),
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
                ? _buildResults()
                : _buildSuggestions(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (loadingResults) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.search_off,
            size: 70,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No users found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Text(
              'Try a different username',
              style: TextStyle(color: Colors.grey),
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
        color: Colors.grey.shade200,
      ),
      itemBuilder: (context, index) =>
          _userTile(results[index]),
    );
  }

  Widget _buildSuggestions() {
    if (loadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (suggestions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.people_outline,
            size: 70,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No other users yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Text(
              'Invite friends to join Damadam',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: suggestions.length + 1,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: const Text(
              'Suggested people',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          );
        }
        return _userTile(suggestions[index - 1]);
      },
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final avatarUrl = user['avatar_url']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';

    return ListTile(
      tileColor: Colors.white,
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
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
      onTap: () => _openProfile(userId),
    );
  }
}
