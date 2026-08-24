import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';

class LoginPage extends StatefulWidget {
  final bool initialSetPinMode;
  final String? registeredMobile;
  final UserType? registeredRole;
  final User? registeredUser;

  const LoginPage({
    super.key,
    this.initialSetPinMode = false,
    this.registeredMobile,
    this.registeredRole,
    this.registeredUser,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _loginMobileController = TextEditingController();
  final TextEditingController _loginPinController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _setMobileController = TextEditingController();

  bool _isSetPinMode = false;
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureSetPin = true;
  bool _obscureConfirmPin = true;

  UserType _selectedSetPinRole = UserType.admin;
  bool _initializedFromRoute = false;

  @override
  void initState() {
    super.initState();
    _isSetPinMode = widget.initialSetPinMode;
    if (widget.registeredMobile != null && widget.registeredMobile!.isNotEmpty) {
      _setMobileController.text = widget.registeredMobile!;
      _loginMobileController.text = widget.registeredMobile!;
    }
    if (widget.registeredRole != null) {
      _selectedSetPinRole = widget.registeredRole!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromRoute) {
      _initializedFromRoute = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['initialSetPinMode'] == true) {
          _isSetPinMode = true;
        }
        if (args['registeredMobile'] != null) {
          final mob = args['registeredMobile'].toString();
          _setMobileController.text = mob;
          _loginMobileController.text = mob;
        }
        if (args['registeredRole'] is UserType) {
          _selectedSetPinRole = args['registeredRole'] as UserType;
        }
      }
    }
  }

  @override
  void dispose() {
    _loginMobileController.dispose();
    _loginPinController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _setMobileController.dispose();
    super.dispose();
  }

  Future<void> _handleSetPin() async {
    final mobile = _setMobileController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registered mobile number is required'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number must be exactly 10 digits'),
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

    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.setPin(
      pin,
      userType: _selectedSetPinRole,
      mobileNo: mobile,
    );

    setState(() {
      _isLoading = false;
      _isSetPinMode = false;
      _loginMobileController.text = mobile;
      _loginPinController.clear();
      _pinController.clear();
      _confirmPinController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('PIN created & saved successfully! Please sign in with your 6-digit PIN.'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    final mobile = _loginMobileController.text.trim();
    final pin = _loginPinController.text.trim();

    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your 10-digit Mobile Number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number must be exactly 10 digits'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    final result = await Provider.of<AuthProvider>(context, listen: false).loginWithMobileAndPin(
      mobileNo: mobile,
      pin: pin,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted) {
      if (result.isInactive) {
        _showInactiveAccountDialog(result.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty
                ? result.message
                : 'Invalid Mobile Number or Security PIN.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInactiveAccountDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
              child: Icon(Icons.person_off_rounded, color: Colors.red.shade900, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Account Inactive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isSetPinMode = !_isSetPinMode;
      _loginMobileController.clear();
      _loginPinController.clear();
      _pinController.clear();
      _confirmPinController.clear();
      _isLoading = false;
    });
  }

  static const Map<UserType, String> _roleLabels = {
    UserType.admin: 'Admin',
    UserType.manager: ' Manager',
    UserType.ro: 'RO',
    UserType.loanee: 'Loanee',
  };

  void _showResetPinDialog() {
    final mobileController = TextEditingController();
    final customerIdController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmNewPinController = TextEditingController();
    UserType resetRole = _selectedSetPinRole;
    bool isSubmitting = false;

    if (_loginMobileController.text.trim().isNotEmpty) {
      mobileController.text = _loginMobileController.text.trim();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
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
                            Text('Reset Security PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A))),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Text(
                      'Select your Role, enter your Customer ID and Registered Mobile Number to verify your account and reset your 6-digit PIN.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          UserType.admin,
                          UserType.manager,
                          UserType.ro,
                          UserType.loanee,
                        ].map((role) {
                          final isSelected = resetRole == role;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                _roleLabels[role] ?? role.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF8B1A1A),
                              backgroundColor: Colors.grey.shade100,
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    resetRole = role;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: customerIdController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Customer ID',
                        hintText: resetRole == UserType.admin ? 'e.g. ADM-01' : (resetRole == UserType.manager ? 'e.g. MGR-01' : (resetRole == UserType.ro ? 'e.g. 26R001' : 'e.g. 26LA000001')),
                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF8B1A1A)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      decoration: InputDecoration(
                        labelText: 'Registered Mobile Number',
                        hintText: 'Enter 10-digit registered mobile',
                        counterText: '',
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF8B1A1A)),
                        prefixText: '+91 ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPinController,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      decoration: InputDecoration(
                        labelText: 'Confirm New PIN',
                        hintText: '••••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8B1A1A)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1A1A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final custId = customerIdController.text.trim();
                                final mobile = mobileController.text.trim();
                                final newPin = newPinController.text.trim();
                                final confirmPin = confirmNewPinController.text.trim();

                                if (custId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Customer ID is required'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                if (mobile.length != 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Registered Mobile number must be 10 digits'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                if (newPin.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('New PIN must be exactly 6 digits'), backgroundColor: Colors.orange),
                                  );
                                  return;
                                }

                                if (newPin != confirmPin) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('PINs do not match'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }

                                setModalState(() { isSubmitting = true; });

                                final resetResult = await Provider.of<AuthProvider>(context, listen: false)
                                    .resetPinWithCustomerIdAndMobile(
                                      customerId: custId,
                                      mobileNo: mobile,
                                      newPin: newPin,
                                      userType: resetRole,
                                    );

                                setModalState(() { isSubmitting = false; });
                                if (!context.mounted) return;

                                if (resetResult['success'] == true) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedSetPinRole = resetRole;
                                    _loginMobileController.text = mobile;
                                    _loginPinController.text = newPin;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(resetResult['message'] ?? 'PIN Reset Successful!')),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (errCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      title: Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 24),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Verification Mismatch',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                      content: Text(
                                        resetResult['message'] ?? 'Customer ID and Mobile Number do not match.',
                                        style: const TextStyle(fontSize: 13.5, height: 1.4),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(errCtx),
                                          child: const Text('Try Again'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('RESET PIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const AppLogo(width: 80, height: 80, backgroundColor: Colors.white),
                  const SizedBox(height: 12),
                  const Text('MANGANG FINANCE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('MICROFINANCE ENTERPRISE PORTAL', style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isSetPinMode ? Icons.lock_open_rounded : Icons.login_rounded, size: 14, color: Colors.amber.shade300),
                        const SizedBox(width: 6),
                        Text(_isSetPinMode ? 'CREATE SECURITY PIN' : 'SIGN IN', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSetPinMode ? 'Set your confidential 6-digit PIN for your account' : 'Enter your registered 10-digit mobile number & 6-digit PIN to sign in',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  if (_isSetPinMode) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF8B1A1A).withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8B1A1A).withOpacity(0.15))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF8B1A1A), shape: BoxShape.circle), child: const Icon(Icons.lock_rounded, color: Colors.white, size: 16)),
                              const SizedBox(width: 8),
                              const Text('Set Security PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A))),
                              const Spacer(),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF8B1A1A), borderRadius: BorderRadius.circular(10)), child: Text(_selectedSetPinRole.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _setMobileController,
                      readOnly: _setMobileController.text.trim().isNotEmpty,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Registered Mobile Number',
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF8B1A1A)),
                        filled: true,
                        fillColor: _setMobileController.text.trim().isNotEmpty ? Colors.grey.shade100 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      obscureText: _obscureSetPin,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Enter 6-Digit PIN',
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF8B1A1A)),
                        suffixIcon: IconButton(icon: Icon(_obscureSetPin ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _obscureSetPin = !_obscureSetPin)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPinController,
                      obscureText: _obscureConfirmPin,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Confirm 6-Digit PIN',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8B1A1A)),
                        suffixIcon: IconButton(icon: Icon(_obscureConfirmPin ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: _isLoading ? null : _handleSetPin,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('CREATE & SAVE PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    // SIGN IN FORM: Mobile Number + 6-Digit PIN (No User Type selection)
                    TextField(
                      controller: _loginMobileController,
                      maxLength: 10,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.0),
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter 10-digit mobile number',
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF8B1A1A)),
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        counterText: '',
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: _loginPinController,
                      obscureText: _obscurePin,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Enter 6-Digit Security PIN',
                        hintText: '••••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF8B1A1A)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                        ),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'SIGN IN',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Toggle between Create PIN and Sign In
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

                  // Link to Register Page
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
                        icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFF8B1A1A)),
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