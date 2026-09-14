
import 'package:flutter/material.dart';

import '../services/block_service.dart';
import 'profile/public_profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final BlockService _block = BlockService();

  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _block.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        items = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    }
  }

  Future<void> _unblock(String userId) async {
    try {
      await _block.unblock(userId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unblocked')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  String _displayName(Map<String, dynamic> p) {
    final full = p['full_name']?.toString().trim() ?? '';
    if (full.isNotEmpty) return full;
    final uname = p['username']?.toString().trim() ?? '';
    if (uname.isNotEmpty) return '@$uname';
    return 'Damadam User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Blocked Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 140),
                      Icon(Icons.block, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No blocked users',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final row = items[index];
                      final profile = row['profiles'];
                      final Map<String, dynamic> p =
                          profile is Map<String, dynamic>
                              ? profile
                              : <String, dynamic>{};

                      final userId = p['id']?.toString() ?? '';
                      final avatar = p['avatar_url']?.toString() ?? '';

                      return ListTile(
                        tileColor: Colors.white,
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.blueGrey.shade100,
                          backgroundImage:
                              avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        title: Text(
                          _displayName(p),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: userId.isEmpty
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PublicProfileScreen(
                                      userId: userId,
                                    ),
                                  ),
                                );
                              },
                        trailing: OutlinedButton(
                          onPressed: userId.isEmpty
                              ? null
                              : () => _unblock(userId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: BorderSide(color: Colors.blue.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'Unblock',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
