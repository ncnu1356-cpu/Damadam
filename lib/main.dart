import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ------------------------------------------------------------
// AUTH GATE
// ------------------------------------------------------------

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

// ------------------------------------------------------------
// WELCOME
// ------------------------------------------------------------

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

// ------------------------------------------------------------
// SIGN UP
// ------------------------------------------------------------

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
      // Check username
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

      // Create Auth account
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Account could not be created.');
      }

      // Create profile
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

// ------------------------------------------------------------
// LOGIN
// ------------------------------------------------------------

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
      appBar: AppBar(
        title: const Text('Login'),
      ),
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
                        builder: (_) => const ForgotPasswordScreen(),
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

// ------------------------------------------------------------
// FORGOT PASSWORD
// ------------------------------------------------------------

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
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
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

// ------------------------------------------------------------
// HOME
// ------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> logout(BuildContext context) async {
    await supabase.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

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
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_rounded,
              size: 80,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'Welcome to Damadam! 🎉',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              user?.email ?? '',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Home Feed Coming Next...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
