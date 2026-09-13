import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/profile/profile_screen.dart';
import 'screens/profile/public_profile_screen.dart';

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
          return const HomeScreen();
        }

        return const WelcomeScreen();
      },
    );
  }
}

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
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    size: 55,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
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
    final username =
        usernameController.text.trim().toLowerCase();
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
      showMessage(
        'Password must be at least 6 characters.',
      );
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
        showMessage(
          'Account could not be created.',
        );
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

      showMessage(
        'Account created successfully.',
        success: true,
      );

      Navigator.pop(context);
    } on AuthException catch (e) {
      showMessage(e.message);
    } on PostgrestException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage(
        'Something went wrong: $e',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      } 
    }
  }

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: fullNameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon:
                      Icon(Icons.person_outline),
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
                  prefixIcon:
                      Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon:
                      Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      const Icon(Icons.lock_outline),
                  border:
                      const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(
                        () => obscurePassword =
                            !obscurePassword,
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
                  onPressed:
                      loading ? null : signUp,
                  child: loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style:
                              TextStyle(fontSize: 16),
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
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController =
      TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email =
        emailController.text.trim();
    final password =
        passwordController.text;

    if (email.isEmpty ||
        password.isEmpty) {
      showMessage(
        'Please enter email and password.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.popUntil(
        context,
        (route) => route.isFirst,
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage(
        'Login failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
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
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.lock_open_rounded,
                size: 70,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration:
                    const InputDecoration(
                  labelText: 'Email',
                  prefixIcon:
                      Icon(Icons.email_outlined),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      const Icon(Icons.lock_outline),
                  border:
                      const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(
                        () => obscurePassword =
                            !obscurePassword,
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
                alignment:
                    Alignment.centerRight,
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
                  child:
                      const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed:
                      loading ? null : login,
                  child: loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Login',
                          style:
                              TextStyle(fontSize: 16),
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

class ForgotPasswordScreen
    extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final emailController =
      TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendResetEmail() async {
    final email =
        emailController.text.trim();

    if (email.isEmpty) {
      showMessage(
        'Please enter your email.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth
          .resetPasswordForEmail(email);

      if (!mounted) return;

      showMessage(
        'Password reset email sent.',
        success: true,
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage(
        'Something went wrong: $e',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Forgot Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.lock_reset,
                size: 70,
              ),
              const SizedBox(height: 25),
              const Text(
                'Enter your email and we will send you a password reset link.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration:
                    const InputDecoration(
                  labelText: 'Email',
                  prefixIcon:
                      Icon(Icons.email_outlined),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: loading
                      ? null
                      : sendResetEmail,
                  child: loading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Send Reset Link',
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

class HomeScreen
    extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  List<Map<String, dynamic>> posts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    try {
      final response = await supabase
          .from('posts')
          .select(
            'id, user_id, content, image_url, created_at, '
            'profiles(username, full_name, avatar_url)',
          )
          .order(
            'created_at',
            ascending: false,
          );

      if (!mounted) return;

      setState(() {
        posts =
            List<Map<String, dynamic>>.from(
          response,
        );
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Could not load posts: $e'),
        ),
      );
    }
  }

  Future<void> refreshPosts() async {
    await loadPosts();
  }

  Future<void> createPost() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CreatePostScreen(),
      ),
    );

    if (!mounted) return;

    await loadPosts();
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Logout failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Damadam',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'My Profile',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ProfileScreen(),
                ),
              );

              if (!mounted) return;

              await loadPosts();
            },
            icon: const Icon(
              Icons.person_outline,
            ),
          ),
          IconButton(
            tooltip: 'Create Post',
            onPressed: createPost,
            icon: const Icon(
              Icons.add_circle_outline,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshPosts,
        child: loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : posts.isEmpty
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(
                        child: Text(
                          'No posts yet.\nCreate the first post!',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(fontSize: 17),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                      bottom: 20,
                    ),
                    itemCount: posts.length,
                    itemBuilder:
                        (context, index) {
                      return PostCard(
                        post: posts[index],
                        onDeleted: loadPosts,
                      );
                    },
                  ),
      ),
      floatingActionButton:
          FloatingActionButton(
        onPressed: createPost,
        tooltip: 'Create Post',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CreatePostScreen
    extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() =>
      _CreatePostScreenState();
}

class _CreatePostScreenState
    extends State<CreatePostScreen> {
  final contentController =
      TextEditingController();

  final ImagePicker picker =
      ImagePicker();

  File? selectedImage;
  bool uploading = false;

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  Future<void> pickFromGallery() async {
    try {
      final XFile? image =
          await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(
        () => selectedImage =
            File(image.path),
      );
    } catch (e) {
      showMessage(
        'Could not select image: $e',
      );
    }
  }

  Future<void> pickFromCamera() async {
    try {
      final XFile? image =
          await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(
        () => selectedImage =
            File(image.path),
      );
    } catch (e) {
      showMessage(
        'Could not open camera: $e',
      );
    }
  }

  Future<String?> uploadPostImage(
    File image,
  ) async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final fileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final path = 'posts/$fileName';

    await supabase.storage
        .from('post-images')
        .upload(
          path,
          image,
          fileOptions:
              const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );

    return supabase.storage
        .from('post-images')
        .getPublicUrl(path);
  }

  Future<void> publishPost() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      showMessage(
        'Please login again.',
      );
      return;
    }

    final content =
        contentController.text.trim();

    if (content.isEmpty &&
        selectedImage == null) {
      showMessage(
        'Write something or select an image.',
      );
      return;
    }

    setState(
      () => uploading = true,
    );

    try {
      String? imageUrl;

      if (selectedImage != null) {
        imageUrl =
            await uploadPostImage(
          selectedImage!,
        );
      }

      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
        'image_url': imageUrl,
      });

      if (!mounted) return;

      showMessage(
        'Post published successfully.',
        success: true,
      );

      Navigator.pop(context);
    } on StorageException catch (e) {
      showMessage(
        'Image upload failed: ${e.message}',
      );
    } on PostgrestException catch (e) {
      showMessage(
        'Post could not be published: ${e.message}',
      );
    } catch (e) {
      showMessage(
        'Something went wrong: $e',
      );
    } finally {
      if (mounted) {
        setState(
          () => uploading = false,
        );
      }
    }
  }

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Create Post'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller:
                    contentController,
                maxLines: 6,
                maxLength: 1000,
                decoration:
                    const InputDecoration(
                  hintText:
                      "What's on your mind?",
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      child: Image.file(
                        selectedImage!,
                        width:
                            double.infinity,
                        height: 260,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor:
                            Colors.black54,
                        child: IconButton(
                          onPressed: () {
                            setState(
                              () =>
                                  selectedImage =
                                      null,
                            );
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
                    child:
                        OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : pickFromGallery,
                      icon: const Icon(
                        Icons
                            .photo_library_outlined,
                      ),
                      label:
                          const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : pickFromCamera,
                      icon: const Icon(
                        Icons
                            .camera_alt_outlined,
                      ),
                      label:
                          const Text('Camera'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: uploading
                      ? null
                      : publishPost,
                  child: uploading
                      ? const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color:
                                    Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                                'Publishing...'),
                          ],
                        )
                      : const Text(
                          'Publish Post',
                          style:
                              TextStyle(
                            fontSize: 16,
                          ),
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

class PostCard
    extends StatefulWidget {
  final Map<String, dynamic> post;
  final Future<void> Function() onDeleted;

  const PostCard({
    super.key,
    required this.post,
    required this.onDeleted,
  });

  @override
  State<PostCard> createState() =>
      _PostCardState();
}

class _PostCardState
    extends State<PostCard> {
  bool liked = false;
  bool likeLoading = false;
  int likeCount = 0;

  String _timeAgo(String? iso) {
    if (iso == null) return '';

    final dt =
        DateTime.tryParse(iso)?.toLocal();

    if (dt == null) return '';

    final diff =
        DateTime.now().difference(dt);

    if (diff.inSeconds < 60) {
      return 'just now';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    loadLikeStatus();
  }

  Future<void> loadLikeStatus() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    try {
      final likes = await supabase
          .from('likes')
          .select('id, user_id')
          .eq(
            'post_id',
            widget.post['id'],
          );

      final list =
          List<Map<String, dynamic>>.from(
        likes,
      );

      if (!mounted) return;

      setState(() {
        likeCount = list.length;

        liked = list.any(
          (item) =>
              item['user_id'] == user.id,
        );
      });
    } catch (_) {}
  }

  Future<void> toggleLike() async {
    final user =
        supabase.auth.currentUser;

    if (user == null ||
        likeLoading) {
      return;
    }

    setState(
      () => likeLoading = true,
    );

    try {
      final existing = await supabase
          .from('likes')
          .select('id')
          .eq(
            'post_id',
            widget.post['id'],
          )
          .eq(
            'user_id',
            user.id,
          )
          .maybeSingle();

      if (existing != null) {
        await supabase
            .from('likes')
            .delete()
            .eq(
              'id',
              existing['id'],
            );

        if (!mounted) return;

        setState(() {
          liked = false;

          if (likeCount > 0) {
            likeCount--;
          }
        });
      } else {
        await supabase
            .from('likes')
            .insert({
          'post_id':
              widget.post['id'],
          'user_id': user.id,
        });

        if (!mounted) return;

        setState(() {
          liked = true;
          likeCount++;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Like action failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(
          () => likeLoading = false,
        );
      }
    }
  }

  Future<void> deletePost() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    if (widget.post['user_id'] !=
        user.id) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text('Delete Post?'),
          content: const Text(
            'This post will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text('Delete'),
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
          .eq(
            'id',
            widget.post['id'],
          )
          .eq(
            'user_id',
            user.id,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Post deleted.'),
        ),
      );

      await widget.onDeleted();
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete post: ${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete post: $e',
          ),
        ),
      );
    }
  }

  String getUsername() {
    final profile =
        widget.post['profiles'];

    if (profile is Map<String, dynamic>) {
      final username =
          profile['username'];

      if (username != null &&
          username.toString().isNotEmpty) {
        return '@${username.toString()}';
      }

      final fullName =
          profile['full_name'];

      if (fullName != null &&
          fullName.toString().isNotEmpty) {
        return fullName.toString();
      }
    }

    return 'Damadam User';
  }

  String? getAvatarUrl() {
    final profile =
        widget.post['profiles'];

    if (profile is Map<String, dynamic>) {
      final avatar =
          profile['avatar_url'];

      if (avatar != null &&
          avatar.toString().isNotEmpty) {
        return avatar.toString();
      }
    }

    return null;
  }

  void openPublicProfile() {
    final userId =
        widget.post['user_id']?.toString();

    if (userId == null ||
        userId.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PublicProfileScreen(
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content =
        widget.post['content']
                ?.toString() ??
            '';

    final imageUrl =
        widget.post['image_url']
            ?.toString();

    final userId =
        widget.post['user_id']
            ?.toString();

    final currentUserId =
        supabase.auth.currentUser?.id;

    final isOwner =
        userId == currentUserId;

    final avatarUrl =
        getAvatarUrl();

    return Card(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              10,
              6,
              8,
            ),
            child: Row(
              children: [
                // PROFILE PHOTO CLICKABLE
                GestureDetector(
                  onTap: openPublicProfile,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage:
                        avatarUrl != null
                            ? NetworkImage(
                                avatarUrl,
                              )
                            : null,
                    child: avatarUrl ==
                            null
                        ? const Icon(
                            Icons.person,
                          )
                        : null,
                  ),
                ),

                const SizedBox(width: 10),

                // USERNAME CLICKABLE
                Expanded(
                  child: GestureDetector(
                    onTap:
                        openPublicProfile,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            getUsername(),
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          _timeAgo(
                            widget.post[
                                    'created_at']
                                ?.toString(),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isOwner)
                  PopupMenuButton<
                      String>(
                    onSelected:
                        (value) {
                      if (value ==
                          'delete') {
                        deletePost();
                      }
                    },
                    itemBuilder:
                        (context) =>
                            const [
                      PopupMenuItem(
                        value:
                            'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .delete_outline,
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Text(
                                'Delete'),
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
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                4,
                12,
                12,
              ),
              child: Text(
                content,
                style:
                    const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),

          if (imageUrl != null &&
              imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              width:
                  double.infinity,
              fit: BoxFit.cover,
              loadingBuilder:
                  (
                context,
                child,
                loadingProgress,
              ) {
                if (loadingProgress ==
                    null) {
                  return child;
                }

                return const SizedBox(
                  height: 250,
                  child: Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                );
              },
              errorBuilder:
                  (
                context,
                error,
                stackTrace,
              ) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons
                          .broken_image_outlined,
                      size: 50,
                    ),
                  ),
                );
              },
            ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed:
                      likeLoading
                          ? null
                          : toggleLike,
                  icon: Icon(
                    liked
                        ? Icons.favorite
                        : Icons
                            .favorite_border,
                    color: liked
                        ? Colors.red
                        : null,
                  ),
                ),
                Text(
                  '$likeCount',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CommentsScreen(
                          postId:
                              widget.post[
                                  'id'],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons
                        .comment_outlined,
                  ),
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

class CommentsScreen
    extends StatefulWidget {
  final String postId;

  const CommentsScreen({
    super.key,
    required this.postId,
  });

  @override
  State<CommentsScreen> createState() =>
      _CommentsScreenState();
}

class _CommentsScreenState
    extends State<CommentsScreen> {
  final commentController =
      TextEditingController();

  List<Map<String, dynamic>>
      comments = [];

  bool loading = true;
  bool sending = false;

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
            'id, post_id, user_id, content, created_at, '
            'profiles(username, full_name, avatar_url)',
          )
          .eq(
            'post_id',
            widget.postId,
          )
          .order(
            'created_at',
            ascending: true,
          );

      if (!mounted) return;

      setState(() {
        comments =
            List<Map<String, dynamic>>.from(
          response,
        );
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      showMessage(
        'Could not load comments: $e',
      );
    }
  }

  Future<void> addComment() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      showMessage(
        'Please login again.',
      );
      return;
    }

    final text =
        commentController.text.trim();

    if (text.isEmpty) return;

    setState(
      () => sending = true,
    );

    try {
      await supabase
          .from('comments')
          .insert({
        'post_id':
            widget.postId,
        'user_id':
            user.id,
        'content':
            text,
      });

      commentController.clear();

      await loadComments();
    } on PostgrestException catch (e) {
      showMessage(
        'Comment failed: ${e.message}',
      );
    } catch (e) {
      showMessage(
        'Comment failed: $e',
      );
    } finally {
      if (mounted) {
        setState(
          () => sending = false,
        );
      }
    }
  }

  String getUsername(
    Map<String, dynamic> comment,
  ) {
    final profile =
        comment['profiles'];

    if (profile is Map<String, dynamic>) {
      final username =
          profile['username'];

      if (username != null &&
          username.toString().isNotEmpty) {
        return '@${username.toString()}';
      }

      final fullName =
          profile['full_name'];

      if (fullName != null &&
          fullName.toString().isNotEmpty) {
        return fullName.toString();
      }
    }

    return 'Damadam User';
  }

  String? getAvatar(
    Map<String, dynamic> comment,
  ) {
    final profile =
        comment['profiles'];

    if (profile is Map<String, dynamic>) {
      final avatar =
          profile['avatar_url'];

      if (avatar != null &&
          avatar.toString().isNotEmpty) {
        return avatar.toString();
      }
    }

    return null;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet.',
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets
                                .all(10),
                        itemCount:
                            comments.length,
                        itemBuilder:
                            (context, index) {
                          final comment =
                              comments[index];

                          final avatar =
                              getAvatar(
                            comment,
                          );

                          return Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 12,
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      avatar !=
                                              null
                                          ? NetworkImage(
                                              avatar,
                                            )
                                          : null,
                                  child: avatar ==
                                          null
                                      ? const Icon(
                                          Icons
                                              .person,
                                          size:
                                              20,
                                        )
                                      : null,
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                      Container(
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      10,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: Theme
                                              .of(
                                                  context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        14,
                                      ),
                                    ),
                                    child:
                                        Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          getUsername(
                                            comment,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                        const SizedBox(
                                            height:
                                                4),
                                        Text(
                                          comment[
                                                      'content']
                                                  ?.toString() ??
                                              '',
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
                  const EdgeInsets.fromLTRB(
                10,
                6,
                10,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          commentController,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction:
                          TextInputAction
                              .newline,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Write a comment...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(
                      width: 8),
                  IconButton.filled(
                    onPressed:
                        sending
                            ? null
                            : addComment,
                    icon: sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons.send,
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
