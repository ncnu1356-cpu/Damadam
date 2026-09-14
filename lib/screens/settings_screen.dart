import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'blocked_users_screen.dart';
import 'change_password_screen.dart';
import 'saved_posts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    final confirmText = await showDialog<String>(
      context: context,
      builder: (context) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your account, posts, messages, and all data. This cannot be undone.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Type DELETE to confirm:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: c,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmText != 'DELETE') {
      if (confirmText != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confirmation text did not match')),
        );
      }
      return;
    }

    setState(() => _deleting = true);

    try {
      await Supabase.instance.client.rpc('delete_my_account');
      await Supabase.instance.client.auth.signOut();
      // MainShell will rebuild and WelcomeScreen will appear
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          _sectionHeader('Activity'),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Saved posts'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            tileColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedPostsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Blocked users'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            tileColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BlockedUsersScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _sectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            tileColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _sectionHeader('Danger zone'),
          ListTile(
            leading: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete my account',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('Permanently remove all your data'),
            tileColor: Colors.white,
            onTap: _deleting ? null : _deleteAccount,
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
