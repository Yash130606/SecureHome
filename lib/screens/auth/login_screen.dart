import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../home/main_shell.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    if (ok && mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // ── Logo ──────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.accentGreen, width: 2),
                    ),
                    child: Icon(Icons.shield,
                        size: 40, color: AppColors.accentGreen),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: Text('Welcome Back',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Sign in to your SecureHome',
                      style: TextStyle(fontSize: 14, color: Colors.white54)),
                ),
                const SizedBox(height: 48),

                // ── Email ─────────────────────────
                Text('Email',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                      'Enter your email', Icons.email_outlined),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter valid email'
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Password ──────────────────────
                Text('Password',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Enter your password',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 12),

                // ── Forgot Password ───────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen())),
                    child: Text('Forgot Password?',
                        style: TextStyle(
                            color: AppColors.accentGreen, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Error Message ─────────────────
                if (auth.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(auth.errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13))),
                    ]),
                  ),

                // ── Login Button ──────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        auth.status == AuthStatus.loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: auth.status == AuthStatus.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Sign In',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Register Link ─────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: TextStyle(color: Colors.white54)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen())),
                      child: Text('Sign Up',
                          style: TextStyle(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon,
      {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1E1E2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.accentGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
