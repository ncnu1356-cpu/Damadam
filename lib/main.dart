import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fhmshhmklsqgiyvcdvbr.supabase.co',
    anonKey: 'sb_publishable_gTJUg-94UMGG7FF73Ey58g_ZLoeEZoW',
  );

  runApp(const DamadamApp());
}

final SupabaseClient supabase = Supabase.instance.client;

// ============================================================
// APP
// ============================================================

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
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
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

    setState(() {
      loading = true;
    });

    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        showMessage('Username already exists.');
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

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: const Text('Account Created'),
            content: const Text(
              'Your account has been created successfully. '
              'Please verify your email if email verification is enabled.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pop(context);
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
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
        title: const Text('Create Account'),
      ),
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
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: fullNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
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
                  border: const OutlineInputBorder(),
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

    setState(() {
      loading = true;
    });

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
      showMessage('Login failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
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
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
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

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your email.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await supabase.auth.resetPasswordForEmail(email);

      if (!mounted) return;

      showMessage(
        'Password reset email sent. Check your inbox.',
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Could not send reset email: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
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
        title: const Text('Forgot Password'),
      ),
      body: SafeArea(
        child: Padding(
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
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: loading ? null : resetPassword,
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
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
      final data = await supabase
          .from('posts')
          .select(
            'id, user_id, content, image_url, created_at, '
            'profiles(username, full_name, avatar_url)',
          )
          .order(
            'created_at',
            ascending: false,
          );

      final result = List<Map<String, dynamic>>.from(data);

      if (!mounted) return;

      setState(() {
        posts = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Could not load posts: $e',
      );
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      showMessage('Logout failed: $e');
    }
  }

  Future<void> createPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePostScreen(),
      ),
    );

    if (result == true && mounted) {
      await loadPosts();
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
            icon: const Icon(
              Icons.add_circle_outline,
            ),
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
                    physics:
                        const AlwaysScrollableScrollPhysics(),
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
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(
                        key: ValueKey(posts[index]['id']),
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

class _CreatePostScreenState
    extends State<CreatePostScreen> {
  final TextEditingController contentController =
      TextEditingController();

  final ImagePicker picker = ImagePicker();

  File? selectedImage;

  bool loading = false;

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  // ==========================================================
  // PICK IMAGE
  // ==========================================================

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        selectedImage = File(image.path);
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not select image: $e',
      );
    }
  }

  // ==========================================================
  // IMAGE OPTIONS
  // ==========================================================

  void showImageOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.photo_library_outlined,
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.camera_alt_outlined,
                  ),
                ),
                title: const Text(
                  'Take a Photo',
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // REMOVE IMAGE
  // ==========================================================

  void removeImage() {
    if (!mounted) return;

    setState(() {
      selectedImage = null;
    });
  }

  // ==========================================================
  // SUBMIT POST
  // ==========================================================

  Future<void> submitPost() async {
    if (loading) return;

    final content = contentController.text.trim();
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('Please login first.');
      return;
    }

    if (content.isEmpty && selectedImage == null) {
      showMessage(
        'Write something or add a photo.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      String? imageUrl;

      // ------------------------------------------------------
      // IMAGE UPLOAD
      // ------------------------------------------------------

      if (selectedImage != null) {
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage
            .from('post-images')
            .upload(
              fileName,
              selectedImage!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );

        imageUrl = supabase.storage
            .from('post-images')
            .getPublicUrl(fileName);
      }

      // ------------------------------------------------------
      // INSERT POST
      // ------------------------------------------------------

      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
        'image_url': imageUrl,
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Post failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : submitPost,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'POST',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              TextField(
                controller: contentController,
                maxLines: 8,
                maxLength: 1000,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      "What's on your mind?",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ------------------------------------------------
              // IMAGE PREVIEW
              // ------------------------------------------------

              if (selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(18),
                      child: Image.file(
                        selectedImage!,
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                      ),
                    ),

                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor:
                            Colors.black.withAlpha(170),
                        child: IconButton(
                          onPressed: loading
                              ? null
                              : removeImage,
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

              // ------------------------------------------------
              // ADD PHOTO
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : showImageOptions,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                  ),
                  label: Text(
                    selectedImage == null
                        ? 'Add Photo'
                        : 'Change Photo',
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ------------------------------------------------
              // PUBLISH
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed:
                      loading ? null : submitPost,
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    loading
                        ? 'Uploading...'
                        : 'Publish Post',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  String get postId {
    return widget.post['id'].toString();
  }

  String get userId {
    return widget.post['user_id'].toString();
  }

  // ==========================================================
  // LOAD LIKES / COMMENTS
  // ==========================================================

  Future<void> loadInteractionData() async {
    try {
      final likesData = await supabase
          .from('likes')
          .select('id, user_id')
          .eq('post_id', postId);

      final commentsData = await supabase
          .from('comments')
          .select('id')
          .eq('post_id', postId);

      final List<Map<String, dynamic>> likes =
          List<Map<String, dynamic>>.from(
        likesData,
      );

      final List<Map<String, dynamic>> comments =
          List<Map<String, dynamic>>.from(
        commentsData,
      );

      final currentUser =
          supabase.auth.currentUser;

      if (!mounted) return;

      setState(() {
        likeCount = likes.length;
        commentCount = comments.length;

        liked = currentUser != null &&
            likes.any(
              (like) =>
                  like['user_id'] == currentUser.id,
            );
      });
    } catch (_) {
      // Ignore interaction loading errors.
    }
  }

  // ==========================================================
  // LIKE
  // ==========================================================

  Future<void> toggleLike() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null || loadingLike) {
      return;
    }

    setState(() {
      loadingLike = true;
    });

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

          if (likeCount > 0) {
            likeCount--;
          }
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
          content: Text(
            'Like failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingLike = false;
        });
      }
    }
  }

  // ==========================================================
  // COMMENTS
  // ==========================================================

  Future<void> openComments() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsScreen(
          postId: postId,
        ),
      ),
    );

    if (result == true && mounted) {
      await loadInteractionData();
    }
  }

  // ==========================================================
  // DELETE POST
  // ==========================================================

  Future<void> deletePost() async {
    final currentUser =
        supabase.auth.currentUser;

    if (currentUser == null ||
        currentUser.id != userId) {
      return;
    }

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Delete Post?',
          ),
          content: const Text(
            'This post will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('posts')
          .delete()
          .eq('id', postId);

      if (!mounted) return;

      await widget.onDeleted();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: $e',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // POST UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final dynamic profileData =
        widget.post['profiles'];

    final Map<String, dynamic>? profile =
        profileData is Map
            ? Map<String, dynamic>.from(
                profileData,
              )
            : null;

    final username =
        profile?['username']?.toString() ??
            'User';

    final fullName =
        profile?['full_name']?.toString() ??
            username;

    final avatarUrl =
        profile?['avatar_url']?.toString();

    final content =
        widget.post['content']?.toString() ?? '';

    final imageUrl =
        widget.post['image_url']?.toString();

    final currentUser =
        supabase.auth.currentUser;

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
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // USER HEADER
            // --------------------------------------------------

            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundImage:
                      avatarUrl != null &&
                              avatarUrl.isNotEmpty
                          ? NetworkImage(
                              avatarUrl,
                            )
                          : null,
                  child:
                      avatarUrl == null ||
                              avatarUrl.isEmpty
                          ? Text(
                              username.isNotEmpty
                                  ? username[0]
                                      .toUpperCase()
                                  : 'U',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
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
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '@$username',
                        style:
                            const TextStyle(
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
                    itemBuilder: (_) {
                      return const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(
                            'Delete',
                          ),
                        ),
                      ];
                    },
                  ),
              ],
            ),

            // --------------------------------------------------
            // TEXT
            // --------------------------------------------------

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

            // --------------------------------------------------
            // IMAGE
            // --------------------------------------------------

            if (imageUrl != null &&
                imageUrl.isNotEmpty) ...[
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(15),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder:
                      (
                    context,
                    child,
                    progress,
                  ) {
                    if (progress == null) {
                      return child;
                    }

                    return Container(
                      height: 220,
                      color:
                          Colors.grey.shade100,
                      child: const Center(
                        child:
                            CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color:
                          Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons
                              .broken_image_outlined,
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 15),

            // --------------------------------------------------
            // ACTIONS
            // --------------------------------------------------

            Row(
              children: [
                InkWell(
                  onTap: toggleLike,
                  borderRadius:
                      BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: liked
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$likeCount',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                InkWell(
                  onTap: openComments,
                  borderRadius:
                      BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .chat_bubble_outline,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$commentCount',
                        ),
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

class _CommentsScreenState
    extends State<CommentsScreen> {
  final TextEditingController commentController =
      TextEditingController();

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

  // ==========================================================
  // LOAD COMMENTS
  // ==========================================================

  Future<void> loadComments() async {
    try {
      final data = await supabase
          .from('comments')
          .select(
            'id, user_id, content, created_at, '
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

      final result =
          List<Map<String, dynamic>>.from(data);

      if (!mounted) return;

      setState(() {
        comments = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Could not load comments: $e',
      );
    }
  }

  // ==========================================================
  // SEND COMMENT
  // ==========================================================

  Future<void> sendComment() async {
    final content =
        commentController.text.trim();

    final user =
        supabase.auth.currentUser;

    if (content.isEmpty ||
        user == null ||
        sending) {
      return;
    }

    setState(() {
      sending = true;
    });

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

      showMessage(
        'Comment failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  // ==========================================================
  // DELETE COMMENT
  // ==========================================================

  Future<void> deleteComment(
    String commentId,
  ) async {
    try {
      await supabase
          .from('comments')
          .delete()
          .eq(
            'id',
            commentId,
          );

      await loadComments();
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not delete comment: $e',
      );
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final currentUser =
        supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Comments',
        ),
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
                          'No comments yet.\n'
                          'Be the first to comment!',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(12),
                        itemCount:
                            comments.length,
                        itemBuilder:
                            (context, index) {
                          final comment =
                              comments[index];

                          final dynamic profileData =
                              comment['profiles'];

                          final Map<String, dynamic>?
                              profile =
                              profileData is Map
                                  ? Map<String,
                                      dynamic>.from(
                                      profileData,
                                    )
                                  : null;

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
                              comment['id']
                                  .toString();

                          final commentUserId =
                              comment['user_id']
                                  ?.toString();

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            child: ListTile(
                              leading:
                                  CircleAvatar(
                                backgroundImage:
                                    avatarUrl !=
                                                null &&
                                            avatarUrl
                                                .isNotEmpty
                                        ? NetworkImage(
                                            avatarUrl,
                                          )
                                        : null,
                                child:
                                    avatarUrl ==
                                                null ||
                                            avatarUrl
                                                .isEmpty
                                        ? Text(
                                            username
                                                    .isNotEmpty
                                                ? username[0]
                                                    .toUpperCase()
                                                : 'U',
                                          )
                                        : null,
                              ),

                              title: Text(
                                fullName,
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              subtitle:
                                  Text(content),

                              trailing:
                                  currentUser?.id ==
                                          commentUserId
                                      ? IconButton(
                                          icon:
                                              const Icon(
                                            Icons
                                                .delete_outline,
                                          ),
                                          onPressed: () {
                                            deleteComment(
                                              id,
                                            );
                                          },
                                        )
                                      : null,
                            ),
                          );
                        },
                      ),
          ),

          // ----------------------------------------------------
          // COMMENT INPUT
          // ----------------------------------------------------

          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.fromLTRB(
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
                      controller:
                          commentController,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted: (_) {
                        sendComment();
                      },
                      decoration:
                          InputDecoration(
                        hintText:
                            'Write a comment...',
                        filled: true,
                        fillColor:
                            const Color(
                          0xFFF1F3F6,
                        ),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            25,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  CircleAvatar(
                    radius: 24,
                    child: IconButton(
                      onPressed: sending
                          ? null
                          : sendComment,
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send,
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
  }
}
