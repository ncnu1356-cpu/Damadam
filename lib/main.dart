import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/notifications_screen.dart';
import 'screens/search_screen.dart';
import 'screens/dm_tab.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/public_profile_screen.dart';
import 'services/notification_service.dart';

const String supabaseUrl =
    'https://fhmshhmklsqgiyvcdvbr.supabase.co';

const String supabasePublishableKey =
    'sb_publishable_gTJUg-94UMGG7FF73Ey58g_ZLoeEZoW';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );
  runApp(const DamadamApp());
}

class DamadamApp extends StatelessWidget {
  const DamadamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Damadam',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? supabase.auth.currentSession;

        if (session != null) {
          return const MainShell();
        }
        return const WelcomeScreen();
      },
    );
  }
}

// ============================================================
// MAIN SHELL — bottom navigation
// ============================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    HomeTab(),
    DmTab(),
    ProfileScreen(),
    MoreTab(),
  ];

  void _onTap(int i) {
    // Middle "Share" button → open create post, don't change tab
    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreatePostScreen(),
        ),
      );
      return;
    }

    // Map index: 0=Home, 1=DM, 3=Profile, 4=More → pageIndex
    final pageIndex = i < 2 ? i : i - 1;
    setState(() => _index = pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Map state index to visible bottom nav item index
    final navIndex = _index < 2 ? _index : _index + 1;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '1on1',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Share',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME TAB — feed with For You / For Me toggle
// ============================================================

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Map<String, dynamic>> allPosts = [];
  List<Map<String, dynamic>> forMePosts = [];

  List<String> _followingIds = [];

  bool loading = true;
  bool showForYou = true;
  int unreadNotificationCount = 0;

  RealtimeChannel? _postsChannel;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeToPosts();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _postsChannel?.unsubscribe();
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadFollowingIds(),
      _loadPosts(),
      _loadUnreadNotificationCount(),
    ]);
    _rebuildForMe();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _loadFollowingIds() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id);

      _followingIds = List<Map<String, dynamic>>.from(res)
          .map((r) => r['following_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Load following error: $e');
    }
  }

  Future<void> _loadPosts() async {
    try {
      final response = await supabase
          .from('posts')
          .select(
            'id, user_id, content, image_url, created_at, '
            'profiles(username, full_name, avatar_url)',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        allPosts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load posts: $e')),
      );
    }
  }

  void _rebuildForMe() {
    forMePosts = allPosts.where((p) {
      final uid = p['user_id']?.toString() ?? '';
      return _followingIds.contains(uid) ||
          uid == _currentUserId();
    }).toList();
  }

  String _currentUserId() =>
      supabase.auth.currentUser?.id ?? '';

  Future<void> _loadUnreadNotificationCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (!mounted) return;
      setState(() => unreadNotificationCount = response.length);
    } catch (e) {
      debugPrint('Notification count error: $e');
    }
  }

  void _subscribeToPosts() {
    _postsChannel = supabase
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) async {
            final newPostId =
                payload.newRecord['id']?.toString();
            if (newPostId == null) return;

            if (allPosts.any(
              (p) => p['id']?.toString() == newPostId,
            )) {
              return;
            }

            try {
              final full = await supabase
                  .from('posts')
                  .select(
                    'id, user_id, content, image_url, created_at, '
                    'profiles(username, full_name, avatar_url)',
                  )
                  .eq('id', newPostId)
                  .maybeSingle();

              if (full == null) return;
              if (!mounted) return;

              final post = Map<String, dynamic>.from(full);
              setState(() {
                allPosts.insert(0, post);
                _rebuildForMe();
              });
            } catch (e) {
              debugPrint('Realtime post fetch error: $e');
            }
          },
        )
        .subscribe();
  }

  void _subscribeToNotifications() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _notificationsChannel = supabase
        .channel('public:notifications:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() => unreadNotificationCount++);
          },
        )
        .subscribe();
  }

  Future<void> refreshFeed() async {
    await _loadFollowingIds();
    await _loadPosts();
    await _loadUnreadNotificationCount();
    _rebuildForMe();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> openSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (!mounted) return;
    await refreshFeed();
  }

  Future<void> openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          onOpenPost: (postId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommentsScreen(postId: postId),
              ),
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    await _loadUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = showForYou ? allPosts : forMePosts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Damadam',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: openSearch,
            icon: const Icon(Icons.search),
          ),
          Stack(
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: openNotifications,
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (unreadNotificationCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unreadNotificationCount > 99
                          ? '99+'
                          : '$unreadNotificationCount',
                      textAlign: TextAlign.center,
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
        ],
      ),
      body: Column(
        children: [
          // Toggle row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                _toggleButton(
                  label: 'For You',
                  active: showForYou,
                  onTap: () =>
                      setState(() => showForYou = true),
                ),
                const SizedBox(width: 8),
                _toggleButton(
                  label: 'For Me',
                  active: !showForYou,
                  onTap: () =>
                      setState(() => showForYou = false),
                ),
                const Spacer(),
                Text(
                  '${visiblePosts.length}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshFeed,
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : visiblePosts.isEmpty
                      ? ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 140),
                            Icon(
                              showForYou
                                  ? Icons.article_outlined
                                  : Icons.people_outline,
                              size: 70,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                showForYou
                                    ? 'No posts yet.\nCreate the first post!'
                                    : _followingIds.isEmpty
                                        ? 'Follow people to see their posts here'
                                        : 'No posts from people you follow yet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 20,
                          ),
                          itemCount: visiblePosts.length,
                          itemBuilder: (context, index) {
                            final post = visiblePosts[index];
                            return PostCard(
                              key: ValueKey(post['id']),
                              post: post,
                              onDeleted: refreshFeed,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MORE TAB — menu
// ============================================================

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  void _show(String label, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will be signed out of Damadam.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'More',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          _sectionHeader('Discover'),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Groups'),
            subtitle: const Text('Join communities'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _show('Groups', context),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Recommended for you'),
            subtitle: const Text('People you may know'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _show('Recommended', context),
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: const Text('Explore'),
            subtitle: const Text('Trending posts'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _show('Explore', context),
          ),

          const Divider(height: 30),

          _sectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark mode'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _show('Dark mode', context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _show('Settings', context),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _show('Privacy', context),
          ),

          const Divider(height: 30),

          _sectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Damadam'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _show('About', context),
          ),
          ListTile(
            leading:
                const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _logout(context),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'Damadam v1.0.0',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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

// ============================================================
// AUTH SCREENS
// ============================================================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    size: 55,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Damadam',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect. Share. Chat.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 45),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  final fullNameController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    fullNameController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final username = usernameController.text.trim().toLowerCase();
    final fullName = fullNameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        username.isEmpty ||
        fullName.isEmpty) {
      showMessage('Please fill all fields.');
      return;
    }

    final usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');

    if (!usernameRegex.hasMatch(username)) {
      showMessage(
        'Username must be 3-20 characters and use only a-z, 0-9 or _.',
      );
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters.');
      return;
    }

    setState(() => loading = true);

    try {
      final existingUsername = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (existingUsername != null) {
        showMessage('Username already exists.');
        return;
      }

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
        },
      );

      final user = response.user;
      if (user == null) {
        showMessage('Account could not be created.');
        return;
      }

      try {
        final existing = await supabase
            .from('profiles')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (existing == null) {
          await supabase.from('profiles').insert({
            'id': user.id,
            'username': username,
            'full_name': fullName,
            'bio': '',
            'avatar_url': null,
            'cover_url': null,
          });
        }
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }

      if (!mounted) return;

      showMessage('Account created successfully.', success: true);
      Navigator.pop(context);
    } on AuthException catch (e) {
      showMessage(e.message);
    } on PostgrestException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: fullNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: usernameController,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'username',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(
                        () => obscurePassword = !obscurePassword,
                      );
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: loading ? null : signUp,
                  child: loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter email and password.');
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.lock_open_rounded, size: 70),
              const SizedBox(height: 30),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(
                        () => obscurePassword = !obscurePassword,
                      );
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Please enter your email.');
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      showMessage('Password reset email sent.', success: true);
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.lock_reset, size: 70),
              const SizedBox(height: 25),
              const Text(
                'Enter your email and we will send you a password reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: loading ? null : sendResetEmail,
                  child: loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Send Reset Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CREATE POST SCREEN
// ============================================================

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() =>
      _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final contentController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  File? selectedImage;
  bool uploading = false;

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  Future<void> pickFromGallery() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() => selectedImage = File(image.path));
    } catch (e) {
      showMessage('Could not select image: $e');
    }
  }

  Future<void> pickFromCamera() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() => selectedImage = File(image.path));
    } catch (e) {
      showMessage('Could not open camera: $e');
    }
  }

  Future<String?> uploadPostImage(File image) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final fileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'posts/$fileName';

    await supabase.storage.from('post-images').upload(
          path,
          image,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );

    return supabase.storage.from('post-images').getPublicUrl(path);
  }

  Future<void> publishPost() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      showMessage('Please login again.');
      return;
    }

    final content = contentController.text.trim();
    if (content.isEmpty && selectedImage == null) {
      showMessage('Write something or select an image.');
      return;
    }

    setState(() => uploading = true);

    try {
      String? imageUrl;
      if (selectedImage != null) {
        imageUrl = await uploadPostImage(selectedImage!);
      }

      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
        'image_url': imageUrl,
      });

      if (!mounted) return;
      showMessage('Post published successfully.', success: true);
      Navigator.pop(context);
    } on StorageException catch (e) {
      showMessage('Image upload failed: ${e.message}');
    } on PostgrestException catch (e) {
      showMessage('Post could not be published: ${e.message}');
    } catch (e) {
      showMessage('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: contentController,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        selectedImage!,
                        width: double.infinity,
                        height: 260,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          onPressed: () {
                            setState(() => selectedImage = null);
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          uploading ? null : pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          uploading ? null : pickFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: uploading ? null : publishPost,
                  child: uploading
                      ? const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Publishing...'),
                          ],
                        )
                      : const Text(
                          'Publish Post',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// POST CARD
// ============================================================

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Future<void> Function() onDeleted;

  const PostCard({
    super.key,
    required this.post,
    required this.onDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool liked = false;
  bool likeLoading = false;
  int likeCount = 0;

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
  void initState() {
    super.initState();
    loadLikeStatus();
  }

  Future<void> loadLikeStatus() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final likes = await supabase
          .from('likes')
          .select('id, user_id')
          .eq('post_id', widget.post['id']);

      final list = List<Map<String, dynamic>>.from(likes);

      if (!mounted) return;
      setState(() {
        likeCount = list.length;
        liked = list.any((item) => item['user_id'] == user.id);
      });
    } catch (_) {}
  }

  Future<void> _sendLikeNotification() async {
    final currentUser = supabase.auth.currentUser;
    final postOwnerId = widget.post['user_id']?.toString();
    final postId = widget.post['id']?.toString();

    if (currentUser == null ||
        postOwnerId == null ||
        postId == null ||
        postOwnerId == currentUser.id) {
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('username, full_name')
          .eq('id', currentUser.id)
          .maybeSingle();

      final username =
          profile?['username']?.toString().trim();

      final displayName =
          username != null && username.isNotEmpty
              ? '@$username'
              : (profile?['full_name']
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? profile!['full_name'].toString().trim()
                  : 'Someone');

      await NotificationService().createNotification(
        userId: postOwnerId,
        senderId: currentUser.id,
        type: 'like',
        postId: postId,
        message: '$displayName liked your post',
      );
    } catch (e) {
      debugPrint('Like notification error: $e');
    }
  }

  Future<void> toggleLike() async {
    final user = supabase.auth.currentUser;
    if (user == null || likeLoading) return;

    setState(() => likeLoading = true);

    try {
      final existing = await supabase
          .from('likes')
          .select('id')
          .eq('post_id', widget.post['id'])
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('likes')
            .delete()
            .eq('id', existing['id']);

        if (!mounted) return;
        setState(() {
          liked = false;
          if (likeCount > 0) likeCount--;
        });
      } else {
        await supabase.from('likes').insert({
          'post_id': widget.post['id'],
          'user_id': user.id,
        });

        if (!mounted) return;
        setState(() {
          liked = true;
          likeCount++;
        });

        await _sendLikeNotification();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like action failed: $e')),
      );
    } finally {
      if (mounted) setState(() => likeLoading = false);
    }
  }

  Future<void> deletePost() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (widget.post['user_id'] != user.id) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post?'),
          content: const Text(
            'This post will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('posts')
          .delete()
          .eq('id', widget.post['id'])
          .eq('user_id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
      await widget.onDeleted();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete post: ${e.message}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete post: $e')),
      );
    }
  }

  String getUsername() {
    final profile = widget.post['profiles'];
    if (profile is Map<String, dynamic>) {
      final username = profile['username'];
      if (username != null && username.toString().isNotEmpty) {
        return '@${username.toString()}';
      }
      final fullName = profile['full_name'];
      if (fullName != null && fullName.toString().isNotEmpty) {
        return fullName.toString();
      }
    }
    return 'Damadam User';
  }

  String? getAvatarUrl() {
    final profile = widget.post['profiles'];
    if (profile is Map<String, dynamic>) {
      final avatar = profile['avatar_url'];
      if (avatar != null && avatar.toString().isNotEmpty) {
        return avatar.toString();
      }
    }
    return null;
  }

  void openPublicProfile() {
    final userId = widget.post['user_id']?.toString();
    if (userId == null || userId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.post['content']?.toString() ?? '';
    final imageUrl = widget.post['image_url']?.toString();
    final userId = widget.post['user_id']?.toString();
    final currentUserId = supabase.auth.currentUser?.id;
    final isOwner = userId == currentUserId;
    final avatarUrl = getAvatarUrl();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: openPublicProfile,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: openPublicProfile,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            getUsername(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(
                            widget.post['created_at']?.toString(),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') deletePost();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                content,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 340,
              ),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder:
                    (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed:
                      likeLoading ? null : toggleLike,
                  icon: Icon(
                    liked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: liked ? Colors.red : null,
                  ),
                ),
                Text(
                  '$likeCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(
                          postId: widget.post['id'],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.comment_outlined),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMMENTS SCREEN
// ============================================================

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({
    super.key,
    required this.postId,
  });

  @override
  State<CommentsScreen> createState() =>
      _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final commentController = TextEditingController();

  List<Map<String, dynamic>> comments = [];
  bool loading = true;
  bool sending = false;

  Map<String, dynamic>? _replyTo;

  @override
  void initState() {
    super.initState();
    loadComments();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> loadComments() async {
    try {
      final response = await supabase
          .from('comments')
          .select(
            'id, post_id, user_id, content, created_at, parent_id, '
            'profiles(username, full_name, avatar_url)',
          )
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        comments = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('Could not load comments: $e');
    }
  }

  Future<void> _sendCommentNotification(
    String commentText,
    Map<String, dynamic>? parentComment,
  ) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final post = await supabase
          .from('posts')
          .select('user_id')
          .eq('id', widget.postId)
          .maybeSingle();

      final postOwnerId = post?['user_id']?.toString();

      final parentAuthorId =
          parentComment?['user_id']?.toString();

      final profile = await supabase
          .from('profiles')
          .select('username, full_name')
          .eq('id', currentUser.id)
          .maybeSingle();

      final username =
          profile?['username']?.toString().trim();

      final displayName =
          username != null && username.isNotEmpty
              ? '@$username'
              : (profile?['full_name']
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? profile!['full_name'].toString().trim()
                  : 'Someone');

      final notified = <String>{};

      if (parentAuthorId != null &&
          parentAuthorId != currentUser.id &&
          !notified.contains(parentAuthorId)) {
        await NotificationService().createNotification(
          userId: parentAuthorId,
          senderId: currentUser.id,
          type: 'reply',
          postId: widget.postId,
          message: '$displayName replied to your comment',
        );
        notified.add(parentAuthorId);
      }

      if (postOwnerId != null &&
          postOwnerId != currentUser.id &&
          !notified.contains(postOwnerId)) {
        await NotificationService().createNotification(
          userId: postOwnerId,
          senderId: currentUser.id,
          type: 'comment',
          postId: widget.postId,
          message: parentComment != null
              ? '$displayName replied on your post'
              : '$displayName commented on your post',
        );
      }
    } catch (e) {
      debugPrint('Comment notification error: $e');
    }
  }

  Future<void> addComment() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      showMessage('Please login again.');
      return;
    }

    final text = commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => sending = true);

    try {
      String finalContent = text;

      if (_replyTo != null) {
        final replyUsername = getUsername(_replyTo!);
        if (!text.startsWith(replyUsername)) {
          finalContent = '$replyUsername $text';
        }
      }

      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'user_id': user.id,
        'content': finalContent,
        'parent_id': _replyTo?['id'],
      });

      final parentForNotification = _replyTo;

      commentController.clear();

      if (!mounted) return;
      setState(() => _replyTo = null);

      await _sendCommentNotification(text, parentForNotification);
      await loadComments();
    } on PostgrestException catch (e) {
      showMessage('Comment failed: ${e.message}');
    } catch (e) {
      showMessage('Comment failed: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String getUsername(Map<String, dynamic> comment) {
    final profile = comment['profiles'];
    if (profile is Map<String, dynamic>) {
      final username = profile['username'];
      if (username != null && username.toString().isNotEmpty) {
        return '@${username.toString()}';
      }
      final fullName = profile['full_name'];
      if (fullName != null && fullName.toString().isNotEmpty) {
        return fullName.toString();
      }
    }
    return 'Damadam User';
  }

  String? getAvatar(Map<String, dynamic> comment) {
    final profile = comment['profiles'];
    if (profile is Map<String, dynamic>) {
      final avatar = profile['avatar_url'];
      if (avatar != null && avatar.toString().isNotEmpty) {
        return avatar.toString();
      }
    }
    return null;
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                    ? const Center(
                        child: Text('No comments yet.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final avatar = getAvatar(comment);
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: avatar != null
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: avatar == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          getUsername(comment),
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment['content']
                                                  ?.toString() ??
                                              '',
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _replyTo = comment,
                                          ),
                                          child: Text(
                                            'Reply',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              )
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to ${getUsername(_replyTo!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(
                              () => _replyTo = null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          maxLines: 3,
                          minLines: 1,
                          textInputAction:
                              TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Write a comment...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed:
                            sending ? null : addComment,
                        icon: sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
