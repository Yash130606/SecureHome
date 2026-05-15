import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _sent       = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>()
      .forgotPassword(_emailCtrl.text.trim());
    if (ok && mounted) setState(() => _sent = true);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _sent ? _successView() : _formView(auth),
        ),
      ),
    );
  }

  Widget _successView() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withOpacity(0.15),
          shape: BoxShape.circle),
        child: Icon(Icons.mark_email_read_outlined,
          size: 40, color: AppColors.accentGreen),
      ),
      const SizedBox(height: 24),
      const Text('Email Sent!',
        style: TextStyle(fontSize: 24,
          fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 12),
      Text('Password reset link sent to\n${_emailCtrl.text}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 14)),
      const SizedBox(height: 40),
      SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
          child: const Text('Back to Login',
            style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: Colors.black)),
        ),
      ),
    ],
  );

  Widget _formView(AuthProvider auth) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('Forgot Password',
          style: TextStyle(fontSize: 28,
            fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Enter your email to reset password',
          style: TextStyle(fontSize: 14, color: Colors.white54)),
        const SizedBox(height: 48),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: const Icon(Icons.email_outlined,
              color: Colors.white38, size: 20),
            filled: true,
            fillColor: const Color(0xFF1E1E2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.accentGreen, width: 1.5)),
          ),
          validator: (v) => (v == null || !v.contains('@'))
            ? 'Enter valid email' : null,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: auth.status == AuthStatus.loading
              ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
            child: auth.status == AuthStatus.loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
              : const Text('Send Reset Link',
                  style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ),
        ),
      ],
    ),
  );
}