import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _loginPinController = TextEditingController();
  bool _isSetPinMode = false; // Default to Sign In mode on start and after logout
  bool _isLoading = false;

  Future<void> _handleSetPin() async {
    if (_pinController.text.trim().isEmpty || _confirmPinController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both PIN fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pinController.text.trim() != _confirmPinController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_pinController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN must be exactly 6 digits'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Provider.of<AuthProvider>(context, listen: false).setPin(_pinController.text.trim());

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('PIN created & synced with Supabase table!')),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _handleLogin() async {
    final pin = _loginPinController.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your 6-digit Security PIN'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN must be exactly 6 digits'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool isValid = await Provider.of<AuthProvider>(context, listen: false).loginWithPin(pin);

    setState(() {
      _isLoading = false;
    });

    if (isValid && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Security PIN. No matching user account found in table.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _isSetPinMode = !_isSetPinMode;
      _pinController.clear();
      _confirmPinController.clear();
      _loginPinController.clear();
      _isLoading = false;
    });
  }

  void _showResetPinDialog() {
    UserType selectedRole = UserType.loanee;
    final mobileController = TextEditingController();
    final customerIdController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmNewPinController = TextEditingController();

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_reset_rounded, color: Color(0xFF8B1A1A), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Reset Security PIN',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Text(
                      'Select your Role and reset your Security PIN in Supabase table',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Role Selector
                    Text(
                      'Select Account Role',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: UserType.values.map((role) {
                        final isSelected = selectedRole == role;
                        final label = role == UserType.admin ? 'Admin' : (role == UserType.ro ? 'RO' : 'Loanee');
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedRole = role;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Customer ID (for RO & Loanee)
                    if (selectedRole != UserType.admin) ...[
                      TextField(
                        controller: customerIdController,
                        decoration: InputDecoration(
                          labelText: 'Customer ID',
                          hintText: 'Enter Customer ID',
                          prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF8B1A1A)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Mobile Number
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter 10-digit registered mobile',
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF8B1A1A)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: newPinController,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'New 6-Digit PIN',
                        hintText: '••••••',
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF8B1A1A)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmNewPinController,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Confirm New PIN',
                        hintText: '••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8B1A1A)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1A1A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final mobile = mobileController.text.trim();
                                final customerId = customerIdController.text.trim();
                                final newPin = newPinController.text.trim();
                                final confirmPin = confirmNewPinController.text.trim();

                                if (mobile.length != 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter valid 10-digit mobile number')),
                                  );
                                  return;
                                }

                                if (newPin.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('PIN must be 6 digits')),
                                  );
                                  return;
                                }
                                if (newPin != confirmPin) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('PINs do not match')),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                });

                                bool success = await Provider.of<AuthProvider>(context, listen: false).resetPinForRole(
                                  role: selectedRole,
                                  mobileNo: mobile,
                                  customerId: customerId,
                                  newPin: newPin,
                                );

                                setModalState(() {
                                  isSubmitting = false;
                                });

                                if (success && context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'PIN updated in Supabase table for ${selectedRole.name.toUpperCase()}!',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('RESET PIN'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Rich Brand Red Organic Header (Matching Register Page)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo container with crisp white circular ring and soft shadow
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const AppLogo(
                      width: 95,
                      height: 95,
                      fallbackIcon: Icons.security_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mangang Finance',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Dynamic Mode Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSetPinMode ? Icons.key_rounded : Icons.lock_person_rounded,
                          color: Colors.amber.shade300,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSetPinMode ? 'CREATE SECURITY PIN' : 'SIGN IN TO PORTAL',
                          style: TextStyle(
                            color: Colors.amber.shade300,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSetPinMode
                        ? 'Set a custom 6-digit PIN for your account'
                        : 'Enter your 6-digit security PIN to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),

            // Form Section with Soft Organic Rounded Shapes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  if (_isSetPinMode) ...[
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Enter 6-Digit PIN',
                        hintText: '••••••',
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF8B1A1A)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPinController,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Confirm PIN',
                        hintText: 'Re-enter 6-digit PIN',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8B1A1A)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1A1A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleSetPin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'SET PIN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _loginPinController,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, letterSpacing: 4),
                      decoration: InputDecoration(
                        labelText: 'Enter 6-Digit Security PIN',
                        hintText: '••••••',
                        prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF8B1A1A)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Reset PIN Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _showResetPinDialog,
                        icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFF8B1A1A)),
                        label: const Text(
                          'Forgot / Reset PIN?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8B1A1A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1A1A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'SIGN IN TO PORTAL',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 1. Toggle between Create PIN and Sign In
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSetPinMode ? 'Already have a PIN?' : 'Need to set a PIN?',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _toggleMode,
                        child: Text(
                          _isSetPinMode ? 'Sign In with PIN' : 'Create PIN',
                          style: const TextStyle(
                            color: Color(0xFF8B1A1A),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Link to Register Page
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          'Register Here',
                          style: TextStyle(
                            color: Color(0xFF8B1A1A),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_isSetPinMode) ...[
                    Center(
                      child: TextButton.icon(
                        onPressed: _showResetPinDialog,
                        icon: const Icon(Icons.lock_reset_rounded,
                            size: 16, color: Color(0xFF8B1A1A)),
                        label: const Text(
                          'Forgot / Reset Existing PIN?',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B1A1A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(color: Colors.black12),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Developed by Devkanta Singh',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '© 2026 Mangang Finance. All Rights Reserved. • Terms & Conditions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}