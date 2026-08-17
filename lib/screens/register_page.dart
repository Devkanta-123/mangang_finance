import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/app_logo.dart';

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
    UserType.admin: 'Admin',
    UserType.ro: 'RO',
    UserType.loanee: 'Loanee',
  };

  final Map<UserType, IconData> _userTypeIcons = {
    UserType.admin: Icons.admin_panel_settings,
    UserType.ro: Icons.person_outline,
    UserType.loanee: Icons.person,
  };

  Future<void> _handleRegisterAndCreatePin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      String userName;
      if (_selectedUserType == UserType.admin) {
        userName = _nameController.text.trim();
      } else if (_selectedUserType == UserType.ro) {
        userName = _roNameController.text.trim().isNotEmpty
            ? _roNameController.text.trim()
            : 'RO Officer';
      } else {
        userName = _accountNameController.text.trim().isNotEmpty
            ? _accountNameController.text.trim()
            : 'Loanee Account';
      }

      // Register user in AuthProvider
      User user = User(
        name: userName,
        mobileNo: _mobileController.text.trim(),
        userType: _selectedUserType,
        customerId: _selectedUserType != UserType.admin ? _customerIdController.text.trim() : null,
        roName: _selectedUserType == UserType.ro ? _roNameController.text.trim() : null,
        accountName: _selectedUserType == UserType.loanee ? _accountNameController.text.trim() : null,
      );

      if (!mounted) return;
      await Provider.of<AuthProvider>(context, listen: false).registerUser(user);
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('Account registered! Set your 6-digit Security PIN.')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Directly navigate to Login page for PIN setup
      Navigator.pushReplacementNamed(context, '/login');
    }
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
              items: UserType.values.map((UserType type) {
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
        // Full Name Field (ONLY for Admin)
        if (_selectedUserType == UserType.admin) ...[
          _buildFieldLabel('Full Name'),
          CustomTextField(
            controller: _nameController,
            hintText: 'Enter your full name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
        ],
        
        // Customer ID (for RO and Loanee)
        if (_selectedUserType != UserType.admin) ...[
          _buildFieldLabel('Customer ID'),
          CustomTextField(
            controller: _customerIdController,
            hintText: 'Enter customer ID',
            icon: Icons.badge_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter Customer ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
        ],
        
        // RO Name (only for RO)
        if (_selectedUserType == UserType.ro) ...[
          _buildFieldLabel('RO Name'),
          CustomTextField(
            controller: _roNameController,
            hintText: 'Enter RO name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter RO Name';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
        ],
        
        // Loanee Name (only for Loanee)
        if (_selectedUserType == UserType.loanee) ...[
          _buildFieldLabel('Loanee Name'),
          CustomTextField(
            controller: _accountNameController,
            hintText: 'Enter loanee name',
            icon: Icons.person_outline,
            validator: (value) {
              if (_selectedUserType == UserType.loanee && (value == null || value.trim().isEmpty)) {
                return 'Please enter Loanee Name';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
        ],
        
        // Mobile Number
        _buildFieldLabel('Mobile Number'),
        CustomTextField(
          controller: _mobileController,
          hintText: 'Enter 10-digit mobile number',
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter mobile number';
            }
            if (value.trim().length != 10) {
              return 'Please enter valid 10-digit number';
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