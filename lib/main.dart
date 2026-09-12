import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fhmshhmklsqgiyvcdvbr.supabase.co',
    anonKey: 'sb_publishable_gTJUg-94UMGG7FF73Ey58g_ZLoeEZoW',
  );

  runApp(const DamadamApp());
}

final supabase = Supabase.instance.client;

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
        scaffoldBackgroundColor: const Color(0xfff5f7fb),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    if (session != null) {
      return const HomeScreen();
    }

    return const WelcomeScreen();
  }
}

// ============================================================
// WELCOME
// ============================================================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_alt_rounded,
                size: 90,
                color: Colors.blue,
              ),
              const SizedBox(height: 25),
              const Text(
                'Damadam',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Connect. Share. Chat.',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
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
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
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
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SIGN UP
// ============================================================

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final usernameController = TextEditingController();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    usernameController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    final username = usernameController.text.trim().toLowerCase();
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (username.isEmpty ||
        fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage('Please fill all fields.');
      return;
    }

    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      showMessage(
        'Username must be 3-20 characters and use only letters, numbers or _.',
      );
      return;
    }

    if (password.length < 6) {
      showMessage('Password must contain at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      showMessage('Passwords do not match.');
      return;
    }

    setState(() => loading = true);

    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        showMessage('Username already exists.');
        setState(() => loading = false);
        return;
      }

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Account could not be created.');
      }

      await supabase.from('profiles').insert({
        'id': user.id,
        'username': username,
        'full_name': fullName,
      });

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Account Created 🎉'),
          content: const Text(
            'Your account has been created successfully. '
            'Please verify your email if email verification is enabled.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join Damadam',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your account and connect with people.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword =
                            !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: loading ? null : signUp,
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 17),
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
// LOGIN
// ============================================================

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

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Login failed.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.lock_open_rounded,
                size: 70,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 17),
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
// FORGOT PASSWORD
// ============================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();

  bool loading = false;

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your email.');
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.resetPasswordForEmail(email);

      if (!mounted) return;

      showMessage(
        'Password reset email sent. Check your inbox.',
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Could not send reset email.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter your email and we will send you a password reset link.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: loading ? null : resetPassword,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Send Reset Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME FEED
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  List<Map<String, dynamic>> posts = [];

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    try {
      final result = await supabase
          .from('posts')
          .select(
            'id, user_id, content, image_url, created_at, '
            'profiles(username, full_name, avatar_url)',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        posts = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load posts: $e'),
        ),
      );
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> createPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePostScreen(),
      ),
    );

    if (result == true) {
      await loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Damadam',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        actions: [
          IconButton(
            onPressed: createPost,
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadPosts,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : posts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 180),
                      Icon(
                        Icons.dynamic_feed_outlined,
                        size: 70,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 15),
                      Center(
                        child: Text(
                          'No posts yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Be the first person to create a post.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(
                        post: posts[index],
                        onDeleted: loadPosts,
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createPost,
        child: const Icon(Icons.edit),
      ),
    );
  }
}

// ============================================================
// CREATE POST
// ============================================================

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() =>
      _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final contentController = TextEditingController();
  final imageUrlController = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    contentController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  Future<void> submitPost() async {
    final content = contentController.text.trim();
    final imageUrl = imageUrlController.text.trim();

    if (content.isEmpty && imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write something or add an image URL.'),
        ),
      );
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
        'image_url': imageUrl.isEmpty ? null : imageUrl,
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: loading ? null : submitPost,
            child: const Text(
              'POST',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            TextField(
              controller: contentController,
              maxLines: 8,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: imageUrlController,
              decoration: InputDecoration(
                hintText: 'Image URL (optional)',
                prefixIcon: const Icon(Icons.image_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: loading ? null : submitPost,
                icon: const Icon(Icons.send),
                label: loading
                    ? const CircularProgressIndicator()
                    : const Text('Publish Post'),
              ),
            ),
          ],
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
  int likeCount = 0;
  int commentCount = 0;
  bool liked = false;
  bool loadingLike = false;

  @override
  void initState() {
    super.initState();
    loadInteractionData();
  }

  String get postId => widget.post['id'].toString();

  String get userId => widget.post['user_id'].toString();

  Future<void> loadInteractionData() async {
    try {
      final likes = await supabase
          .from('likes')
          .select('id, user_id')
          .eq('post_id', postId);

      final comments = await supabase
          .from('comments')
          .select('id')
          .eq('post_id', postId);

      final currentUser = supabase.auth.currentUser;

      if (!mounted) return;

      setState(() {
        likeCount = (likes as List).length;
        commentCount = (comments as List).length;

        liked = currentUser != null &&
            likes.any(
              (like) => like['user_id'] == currentUser.id,
            );
      });
    } catch (_) {}
  }

  Future<void> toggleLike() async {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null || loadingLike) return;

    setState(() => loadingLike = true);

    try {
      if (liked) {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUser.id);

        if (!mounted) return;

        setState(() {
          liked = false;
          likeCount = likeCount > 0 ? likeCount - 1 : 0;
        });
      } else {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': currentUser.id,
        });

        if (!mounted) return;

        setState(() {
          liked = true;
          likeCount++;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Like failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loadingLike = false);
      }
    }
  }

  Future<void> openComments() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsScreen(
          postId: postId,
        ),
      ),
    );

    if (result == true) {
      await loadInteractionData();
    }
  }

  Future<void> deletePost() async {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null || currentUser.id != userId) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
      ),
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('posts')
          .delete()
          .eq('id', postId);

      await widget.onDeleted();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.post['profiles'];

    final username =
        profile?['username']?.toString() ?? 'User';

    final fullName =
        profile?['full_name']?.toString() ?? username;

    final avatarUrl =
        profile?['avatar_url']?.toString();

    final content =
        widget.post['content']?.toString() ?? '';

    final imageUrl =
        widget.post['image_url']?.toString();

    final currentUser = supabase.auth.currentUser;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundImage: avatarUrl != null &&
                          avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null ||
                          avatarUrl.isEmpty
                      ? Text(
                          username.isNotEmpty
                              ? username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (currentUser?.id == userId)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        deletePost();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),

            if (content.isNotEmpty) ...[
              const SizedBox(height: 15),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],

            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 150,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 15),

            Row(
              children: [
                InkWell(
                  onTap: toggleLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color:
                              liked ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text('$likeCount'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: openComments,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text('$commentCount'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.share_outlined,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// COMMENTS
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

  bool loading = true;
  bool sending = false;

  List<Map<String, dynamic>> comments = [];

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
      final result = await supabase
          .from('comments')
          .select(
            'id, user_id, content, created_at, '
            'profiles(username, full_name, avatar_url)',
          )
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (!mounted) return;

      setState(() {
        comments = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load comments: $e'),
        ),
      );
    }
  }

  Future<void> sendComment() async {
    final content = commentController.text.trim();
    final user = supabase.auth.currentUser;

    if (content.isEmpty || user == null || sending) {
      return;
    }

    setState(() => sending = true);

    try {
      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'user_id': user.id,
        'content': content,
      });

      commentController.clear();

      await loadComments();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> deleteComment(String id) async {
    try {
      await supabase
          .from('comments')
          .delete()
          .eq('id', id);

      await loadComments();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete comment: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet.\nBe the first to comment!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: comments.length,
                        itemBuilder: (_, index) {
                          final comment = comments[index];
                          final profile =
                              comment['profiles'];

                          final username =
                              profile?['username']
                                      ?.toString() ??
                                  'User';

                          final fullName =
                              profile?['full_name']
                                      ?.toString() ??
                                  username;

                          final avatarUrl =
                              profile?['avatar_url']
                                  ?.toString();

                          final content =
                              comment['content']
                                  ?.toString() ??
                                  '';

                          final id =
                              comment['id'].toString();

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    avatarUrl != null &&
                                            avatarUrl.isNotEmpty
                                        ? NetworkImage(
                                            avatarUrl,
                                          )
                                        : null,
                                child: avatarUrl == null ||
                                        avatarUrl.isEmpty
                                    ? Text(
                                        username.isNotEmpty
                                            ? username[0]
                                                .toUpperCase()
                                            : 'U',
                                      )
                                    : null,
                              ),
                              title: Text(
                                fullName,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                content,
                              ),
                              trailing:
                                  currentUser?.id ==
                                          comment['user_id']
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () =>
                                              deleteComment(id),
                                        )
                                      : null,
                            ),
                          );
                        },
                      ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8,
              ),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted: (_) =>
                          sendComment(),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor:
                            const Color(0xfff1f3f6),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    child: IconButton(
                      onPressed:
                          sending ? null : sendComment,
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
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
