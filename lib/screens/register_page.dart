import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/ro_model.dart';
import '../models/loanee_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/loanee_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/app_logo.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  UserType _selectedUserType = UserType.loanee;
  bool _isLoading = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _roNameController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();

  final Map<UserType, String> _userTypeLabels = {
    UserType.ro: 'Recovery Officer (RO)',
    UserType.loanee: 'Loanee Account',
  };

  final Map<UserType, IconData> _userTypeIcons = {
    UserType.ro: Icons.badge_outlined,
    UserType.loanee: Icons.person_outline_rounded,
  };

  Future<void> _handleRegisterAndCreatePin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final cleanMobile = _mobileController.text.trim();
      final enteredCustId = _customerIdController.text.trim();
      final enteredName = _selectedUserType == UserType.ro
          ? _roNameController.text.trim()
          : _accountNameController.text.trim();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 1. Mandatory Table Match Check: Check CustomerID, Name, and Mobile No against corresponding table
      if (_selectedUserType == UserType.ro) {
        final roProvider = Provider.of<RoProvider>(context, listen: false);
        final verifResult = await authProvider.verifyRoAccountForRegistration(
          customerId: enteredCustId,
          roName: enteredName,
          mobileNo: cleanMobile,
          localRos: roProvider.roAccounts,
        );

        if (verifResult['matched'] != true) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _showVerificationFailedDialog(
            enteredId: enteredCustId,
            enteredName: enteredName,
            enteredMobile: cleanMobile,
            role: UserType.ro,
            customMessage: verifResult['message'],
          );
          return;
        }

        if (verifResult['isInactive'] == true) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _showAccountInactiveDialog(
            verifResult['message'] ?? 'Your RO account is currently marked as Inactive. Login access is disabled. Please contact the administrator.',
          );
          return;
        }
      } else if (_selectedUserType == UserType.loanee) {
        final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
        final verifResult = await authProvider.verifyLoaneeAccountForRegistration(
          customerId: enteredCustId,
          loaneeName: enteredName,
          mobileNo: cleanMobile,
          localLoanees: loaneeProvider.loanees,
        );

        if (verifResult['matched'] != true) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _showVerificationFailedDialog(
            enteredId: enteredCustId,
            enteredName: enteredName,
            enteredMobile: cleanMobile,
            role: UserType.loanee,
            customMessage: verifResult['message'],
          );
          return;
        }

        if (verifResult['isInactive'] == true) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _showAccountInactiveDialog(
            verifResult['message'] ?? 'Your Loanee account is currently marked as Inactive. Login access is disabled. Please contact the administrator.',
          );
          return;
        }
      }

      // 2. Check duplicate (mobile_no, user_type) & customerId in user_auth table
      if (!mounted) return;
      final dupResult = await authProvider.checkDuplicateUserDetailed(
        mobileNo: cleanMobile,
        userType: _selectedUserType,
        customerId: enteredCustId.isNotEmpty ? enteredCustId : null,
      );

      if (dupResult['isDuplicate'] == true) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        _showDuplicateUserDialog(
          mobile: cleanMobile,
          role: _selectedUserType,
          customMessage: dupResult['message'],
        );
        return;
      }

      String userName = enteredName;
      String? assignedCustId = enteredCustId;

      // 3. Register user in AuthProvider
      User user = User(
        name: userName,
        mobileNo: cleanMobile,
        userType: _selectedUserType,
        customerId: assignedCustId,
        roName: _selectedUserType == UserType.ro ? _roNameController.text.trim() : null,
        accountName: _selectedUserType == UserType.loanee ? _accountNameController.text.trim() : null,
      );

      final regResult = await authProvider.registerUser(user);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (regResult['success'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(regResult['message'] ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Account verified & registered as ${_userTypeLabels[_selectedUserType]}! Create your 6-digit Security PIN.'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to Set PIN page with registered mobile number and user identity
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            initialSetPinMode: true,
            registeredMobile: cleanMobile,
            registeredRole: _selectedUserType,
            registeredUser: user,
          ),
        ),
      );
    }
  }

  void _showDuplicateUserDialog({
    required String mobile,
    required UserType role,
    String? customMessage,
  }) {
    final roleName = _userTypeLabels[role] ?? role.name.toUpperCase();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off_rounded, color: Colors.red.shade900, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Duplicate Registration',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customMessage ?? 'An account with mobile number +91 $mobile is already registered as $roleName.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              'A single mobile number or Customer ID cannot be duplicated for the same account. You can sign in using your existing PIN or reset your PIN if forgotten.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    );
  }

  void _showVerificationFailedDialog({
    required String enteredId,
    required String enteredName,
    required String enteredMobile,
    required UserType role,
    String? customMessage,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: Colors.red.shade900, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Records Not Match',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF8B1A1A),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'records not match',
          style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    );
  }

  void _showAccountInactiveDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.block_rounded, color: Colors.red.shade900, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Inactive',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _customerIdController.dispose();
    _roNameController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Professional Header Section
            _buildHeader(),
            
            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Type Dropdown
                    _buildUserTypeDropdown(),
                    
                    const SizedBox(height: 24),
                    
                    // Dynamic Fields
                    _buildDynamicFields(),
                    
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    _buildSubmitButton(),
                    
                    const SizedBox(height: 16),
                    
                    // Login Link
                    _buildLoginLink(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 30),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const AppLogo(
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mangang Finance',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Direct account registration & security PIN setup',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserType>(
              value: _selectedUserType,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              dropdownColor: Colors.white,
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B1A1A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF8B1A1A),
                  size: 24,
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
              items: [
                UserType.loanee,
                UserType.ro,
              ].map((UserType type) {
                return DropdownMenuItem<UserType>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        _userTypeIcons[type],
                        color: const Color(0xFF8B1A1A),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(_userTypeLabels[type]!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (UserType? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedUserType = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer ID (for RO and Loanee)
        _buildFieldLabel('Customer ID'),
        CustomTextField(
          controller: _customerIdController,
          hintText: _selectedUserType == UserType.ro ? 'Enter RO Customer ID (e.g. 26R001)' : 'Enter Loanee Customer ID (e.g. 26LA000001)',
          icon: Icons.badge_outlined,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter Customer ID';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        
        // Full Name (RO Name if RO)
        if (_selectedUserType == UserType.ro) ...[
          _buildFieldLabel('Full Name (as registered in RO Account)'),
          CustomTextField(
            controller: _roNameController,
            hintText: 'Enter official RO officer name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter official RO Name';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
        ],
        
        // Full Name (Loanee Name if Loanee)
        if (_selectedUserType == UserType.loanee) ...[
          _buildFieldLabel('Full Name (as registered in Loan Account)'),
          CustomTextField(
            controller: _accountNameController,
            hintText: 'Enter official loanee name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter official Loanee Name';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
        ],
        
        // Mobile Number
        _buildFieldLabel('Mobile Number (as registered in record)'),
        CustomTextField(
          controller: _mobileController,
          hintText: 'Enter 10-digit mobile number',
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter mobile number';
            }
            final digits = value.replaceAll(RegExp(r'\D'), '');
            if (digits.length != 10) {
              return 'Please enter valid 10-digit mobile number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegisterAndCreatePin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'PROCEED TO CREATE PIN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Column(
      children: [
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: Color(0xFF8B1A1A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
      ],
    );
  }
}