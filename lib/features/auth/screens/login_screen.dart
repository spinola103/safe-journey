import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _continueAsDemo() async {
    setState(() => _loading = true);

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Icon(
                Icons.shield_rounded,
                color: AppColors.teal,
                size: 48,
              ),

              const SizedBox(height: 20),

              const Text(
                'SafeJourney',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Smart travel safety companion',
                style: TextStyle(
                  color: AppColors.tealMid,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 48),

              Text(
                'Phone Number (Optional)',
                style: TextStyle(
                  color: AppColors.tealMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  prefixText: '+91  ',
                  prefixStyle: TextStyle(
                    color: AppColors.tealMid,
                  ),
                  hintText: '9876543210',
                  hintStyle: TextStyle(
                    color: AppColors.gray,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1D2D3E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _continueAsDemo,
                  icon: const Icon(Icons.login),
                  label: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue as Demo User'),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  'Hackathon Demo Mode',
                  style: TextStyle(
                    color: AppColors.tealMid,
                    fontSize: 12,
                  ),
                ),
              ),

              const Spacer(),

              Center(
                child: Text(
                  'No signup required',
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 12,
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