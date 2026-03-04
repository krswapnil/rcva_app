import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final auth = AuthService();
  bool loading = false;

  Future<void> _login({bool forceChooser = false}) async {
    setState(() => loading = true);
    try {
      if (forceChooser) {
        await auth.signInWithGoogleForceChooser();
      } else {
        await auth.signInWithGoogle();
      }
      // authStateChanges will auto-navigate via main routing
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 14),
              const Text(
                'Sign in to continue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : () => _login(),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(loading ? 'Signing in...' : 'Sign in with Google'),
                ),
              ),

              const SizedBox(height: 10),

              // Optional: only if you want manual “switch account”
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: loading ? null : () => _login(forceChooser: true),
                  child: const Text('Use another account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
