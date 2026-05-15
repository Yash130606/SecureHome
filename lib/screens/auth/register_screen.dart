import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'pi_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  bool _obscure1   = true;
  bool _obscure2   = true;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    if (ok && mounted) {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const PiSetupScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
            color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text('Create Account',
                  style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Join SecureHome today',
                  style: TextStyle(fontSize: 14, color: Colors.white54)),
                const SizedBox(height: 40),

                _label('Full Name'),
                _field(_nameCtrl, 'Enter your name',
                  Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty)
                    ? 'Name required' : null),
                const SizedBox(height: 20),

                _label('Email'),
                _field(_emailCtrl, 'Enter your email',
                  Icons.email_outlined,
                  type: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                    ? 'Valid email required' : null),
                const SizedBox(height: 20),

                _label('Password'),
                _field(_passCtrl, 'Min 6 characters',
                  Icons.lock_outline,
                  obscure: _obscure1,
                  toggleObscure: () =>
                    setState(() => _obscure1 = !_obscure1),
                  validator: (v) => (v == null || v.length < 6)
                    ? 'Min 6 characters' : null),
                const SizedBox(height: 20),

                _label('Confirm Password'),
                _field(_confCtrl, 'Repeat password',
                  Icons.lock_outline,
                  obscure: _obscure2,
                  toggleObscure: () =>
                    setState(() => _obscure2 = !_obscure2),
                  validator: (v) => v != _passCtrl.text
                    ? 'Passwords do not match' : null),
                const SizedBox(height: 32),

                if (auth.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                        color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(auth.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red, fontSize: 13))),
                    ]),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: auth.status == AuthStatus.loading
                      ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    ),
                    child: auth.status == AuthStatus.loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
      color: Colors.white70, fontSize: 13,
      fontWeight: FontWeight.w500)),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: toggleObscure != null
          ? IconButton(
              icon: Icon(obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
                color: Colors.white38, size: 20),
              onPressed: toggleObscure)
          : null,
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.accentGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.red, width: 1.5)),
      ),
    );
  }
}