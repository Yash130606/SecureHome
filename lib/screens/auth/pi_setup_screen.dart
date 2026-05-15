import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../home/main_shell.dart';

class PiSetupScreen extends StatefulWidget {
  const PiSetupScreen({super.key});
  @override
  State<PiSetupScreen> createState() => _PiSetupScreenState();
}

class _PiSetupScreenState extends State<PiSetupScreen> {
  final _ipCtrl  = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving   = false;

  @override
  void dispose() { _ipCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ip = _ipCtrl.text.trim();
    final ok = await context.read<AuthProvider>().savePiIp(ip);
    if (ok && mounted) {
      await context.read<AppProvider>().connectToPi(ip);
    }
    if (mounted) {
      if (ok) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not connect to Raspberry Pi. Check the IP address and try again.',
            ),
          ),
        );
      }
    }
  }

  void _skip() => Navigator.pushReplacement(context,
    MaterialPageRoute(builder: (_) => const MainShell()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.router_outlined,
                    size: 40, color: AppColors.accentGreen),
                ),
                const SizedBox(height: 24),
                const Text('Connect Your Pi',
                  style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text(
                  'Enter your Raspberry Pi IP address to connect your security camera',
                  style: TextStyle(fontSize: 14, color: Colors.white54)),
                const SizedBox(height: 48),

                const Text('Raspberry Pi IP Address',
                  style: TextStyle(color: Colors.white70,
                    fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ipCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. 192.168.1.100',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(Icons.lan_outlined,
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
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'IP required';
                    final parts = v.split('.');
                    if (parts.length != 4) return 'Invalid IP format';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                      color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Find Pi IP: run "hostname -I" in Pi terminal',
                        style: TextStyle(
                          color: Colors.blue.shade300, fontSize: 12)),
                    ),
                  ]),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                    child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                      : const Text('Connect & Continue',
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _skip,
                    child: Text('Skip for now',
                      style: TextStyle(
                        color: Colors.white38, fontSize: 14)),
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
}
