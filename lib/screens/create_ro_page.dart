// lib/screens/create_ro_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ro_model.dart';
import '../providers/ro_provider.dart';
import '../providers/collection_sheet_provider.dart';

class CreateRoPage extends StatefulWidget {
  final VoidCallback? onAccountCreated;

  const CreateRoPage({super.key, this.onAccountCreated});

  @override
  State<CreateRoPage> createState() => _CreateRoPageState();
}

class _CreateRoPageState extends State<CreateRoPage> {
  final _formKey = GlobalKey<FormState>();

  // 12 Required Input Controllers
  late TextEditingController _customerIdController;
  late TextEditingController _accountNumberController;
  final TextEditingController _roNameController = TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController(); // W/O, S/O, D/O
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _designationController = TextEditingController(); // Text input, NOT dropdown
  String? _selectedRoute; // Master table route dropdown
  final TextEditingController _poController = TextEditingController(); // P/O
  final TextEditingController _psController = TextEditingController(); // P/S
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _pinController = TextEditingController(); // PIN
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();

  bool _isSubmitting = false;

  final List<String> _districts = [
    'Imphal West',
    'Imphal East',
    'Thoubal',
    'Bishnupur',
    'Kakching',
    'Churachandpur',
    'Ukhrul',
    'Senapati',
    'Tamenglong',
    'Jiribam',
    'Kangpokpi',
    'Tengnoupal',
    'Pherzawl',
    'Noney',
    'Kamjong',
    'Chandel',
  ];

  @override
  void initState() {
    super.initState();
    final roProvider = Provider.of<RoProvider>(context, listen: false);
    _customerIdController =
        TextEditingController(text: roProvider.generateNextCustomerId());
    _accountNumberController =
        TextEditingController(text: roProvider.generateNextAccountNumber());
    _districtController.text = _districts.first;
    _designationController.text = 'Recovery Officer';
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _accountNumberController.dispose();
    _roNameController.dispose();
    _guardianNameController.dispose();
    _addressController.dispose();
    _designationController.dispose();
    _poController.dispose();
    _psController.dispose();
    _districtController.dispose();
    _pinController.dispose();
    _mobileController.dispose();
    _aadharController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final newRo = RoAccount(
        customerid: _customerIdController.text.trim(),
        accountnumber: _accountNumberController.text.trim(),
        roname: _roNameController.text.trim(),
        guardianname: _guardianNameController.text.trim(),
        address: _addressController.text.trim(),
        designation: _designationController.text.trim(),
        route: _selectedRoute ?? '',
        postoffice: _poController.text.trim(),
        policestation: _psController.text.trim(),
        district: _districtController.text.trim(),
        pincode: _pinController.text.trim(),
        mobileno: _mobileController.text.trim(),
        aadharno: _aadharController.text.trim(),
      );

      final roProvider = Provider.of<RoProvider>(context, listen: false);
      final result = await roProvider.addRoWithConnectionCheck(newRo);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        _showSuccessDialog(newRo);
      } else {
        _showErrorDialog(result['message'] ?? 'Failed to insert RO to Supabase.');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('Please fix errors in the form before submitting'),
              ),
            ],
          ),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _resetForm() {
    final roProvider = Provider.of<RoProvider>(context, listen: false);
    _formKey.currentState?.reset();
    _customerIdController.text = roProvider.generateNextCustomerId();
    _accountNumberController.text = roProvider.generateNextAccountNumber();
    _roNameController.clear();
    _guardianNameController.clear();
    _addressController.clear();
    _designationController.text = 'Recovery Officer';
    _selectedRoute = null;
    _poController.clear();
    _psController.clear();
    _pinController.clear();
    _mobileController.clear();
    _aadharController.clear();
    setState(() {
      _districtController.text = _districts.first;
    });
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.cloud_off_rounded, color: Colors.white, size: 32),
            ),
            SizedBox(height: 12),
            Text(
              'Supabase Connection Failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'Table insertion was aborted because Supabase is unreachable. Please verify network connectivity or API credentials.',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(RoAccount ro) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.black87,
              child: Icon(Icons.check, color: Colors.white, size: 36),
            ),
            SizedBox(height: 12),
            Text(
              'RO Account Created!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: Colors.green.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '✅ RO Account Inserted to Supabase (ro_accounts)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'RO Officer details have been recorded:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _buildDetailRow('Customer ID:', ro.customerId),
              _buildDetailRow('Account No:', ro.accountNumber),
              _buildDetailRow('RO Name:', ro.roName),
              _buildDetailRow('Guardian (W/O, S/O, D/O):', ro.guardianName),
              _buildDetailRow('Designation:', ro.designation),
              _buildDetailRow('Assigned Route:', ro.route.isNotEmpty ? ro.route : 'Not assigned'),
              _buildDetailRow('Mobile:', ro.mobileNo),
              _buildDetailRow('District:', ro.district),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            child: const Text(
              'Create Another',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(120, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onAccountCreated != null) {
                widget.onAccountCreated!();
              }
            },
            child: const Text('View RO List', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final activeRoutes = collectionProvider.routes
        .where((r) => r.isActive)
        .map((r) => r.name)
        .toList();
    if (activeRoutes.isEmpty) {
      activeRoutes.addAll(collectionProvider.routeNames);
    }
    if (activeRoutes.isEmpty) {
      activeRoutes.addAll(['Route 1', 'Route 2', 'Route 3']);
    }
    if (_selectedRoute == null || !activeRoutes.contains(_selectedRoute)) {
      _selectedRoute = activeRoutes.first;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Page Top Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create RO Account',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Enter official Relationship Officer details for account creation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Responsive Form Area
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Section 1: Identifiers
                          _buildFormCard(
                            title: '1. RO Account & System Identifiers',
                            icon: Icons.qr_code_rounded,
                            children: [
                              _buildResponsivePair(
                                isWide: isWide,
                                first: _buildFormField(
                                  controller: _customerIdController,
                                  label: 'CUSTOMER ID *',
                                  hint: 'e.g. RO-CUST-5001',
                                  icon: Icons.badge_outlined,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Customer ID required';
                                    }
                                    return null;
                                  },
                                ),
                                second: _buildFormField(
                                  controller: _accountNumberController,
                                  label: 'ACCOUNT NUMBER *',
                                  hint: 'e.g. RO-ACC-991001',
                                  icon: Icons.account_balance_wallet_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Account Number required';
                                    }
                                    if (val.trim().length < 5) {
                                      return 'Min 5 digits';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section 2: RO Personal Details
                          _buildFormCard(
                            title: '2. RO Officer Personal Details',
                            icon: Icons.person_outline_rounded,
                            children: [
                              _buildFormField(
                                controller: _roNameController,
                                label: 'RO NAME *',
                                hint: 'Enter full official name of RO officer',
                                icon: Icons.person,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'RO Name is required';
                                  }
                                  if (val.trim().length < 3) {
                                    return 'Must be at least 3 letters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildFormField(
                                controller: _guardianNameController,
                                label: 'W/O, S/O, D/O *',
                                hint: 'Wife of / Son of / Daughter of name',
                                icon: Icons.family_restroom_rounded,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Guardian name (W/O, S/O, D/O) is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildResponsivePair(
                                isWide: isWide,
                                first: _buildFormField(
                                  controller: _mobileController,
                                  label: 'MOBILE NO *',
                                  hint: '10 digit number',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Mobile number required';
                                    }
                                    final clean = val.trim();
                                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
                                      return 'Valid 10-digit mobile required';
                                    }
                                    return null;
                                  },
                                ),
                                second: _buildFormField(
                                  controller: _aadharController,
                                  label: 'AADHAR NO *',
                                  hint: '12 digit Aadhar',
                                  icon: Icons.credit_card_rounded,
                                  keyboardType: TextInputType.number,
                                  maxLength: 14,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Aadhar number required';
                                    }
                                    final clean = val.replaceAll(' ', '').trim();
                                    if (!RegExp(r'^\d{12}$').hasMatch(clean)) {
                                      return 'Must be 12 digits';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section 3: Official Position / Designation (TEXT INPUT) & Assigned Route (MASTER TABLE DROPDOWN)
                          _buildFormCard(
                            title: '3. Official Designation & Route Details',
                            icon: Icons.work_outline_rounded,
                            children: [
                              _buildFormField(
                                controller: _designationController,
                                label: 'DESIGNATION * (Text Input)',
                                hint: 'e.g. Senior Recovery Officer, Field Supervisor',
                                icon: Icons.badge_rounded,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Designation is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ASSIGNED ROUTE * (From Master Table)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedRoute != null &&
                                            activeRoutes.contains(_selectedRoute)
                                        ? _selectedRoute
                                        : (activeRoutes.isNotEmpty
                                            ? activeRoutes.first
                                            : null),
                                    decoration: _getInputDecoration(
                                      hint: 'Select Assigned Route',
                                      icon: Icons.alt_route_rounded,
                                    ),
                                    items: activeRoutes
                                        .map((r) => DropdownMenuItem(
                                              value: r,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.alt_route_rounded,
                                                      size: 15,
                                                      color: Colors.amber.shade900),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    r,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedRoute = val;
                                        });
                                      }
                                    },
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Please select an assigned route';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section 4: Address Details
                          _buildFormCard(
                            title: '4. Address & Area Details',
                            icon: Icons.location_on_outlined,
                            children: [
                              _buildFormField(
                                controller: _addressController,
                                label: 'ADDRESS *',
                                hint: 'House No, Village/Leikai, Street Name',
                                icon: Icons.home_work_outlined,
                                maxLines: 2,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Full address is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildResponsivePair(
                                isWide: isWide,
                                first: _buildFormField(
                                  controller: _poController,
                                  label: 'P/O (Post Office) *',
                                  hint: 'Post office name',
                                  icon: Icons.markunread_mailbox_outlined,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'P/O required';
                                    }
                                    return null;
                                  },
                                ),
                                second: _buildFormField(
                                  controller: _psController,
                                  label: 'P/S (Police Station) *',
                                  hint: 'Police station name',
                                  icon: Icons.local_police_outlined,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'P/S required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildResponsivePair(
                                isWide: isWide,
                                first: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DISTRICT *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _districtController.text.isNotEmpty &&
                                              _districts.contains(_districtController.text)
                                          ? _districtController.text
                                          : _districts.first,
                                      decoration: _getInputDecoration(
                                        hint: 'Select District',
                                        icon: Icons.map_outlined,
                                      ),
                                      items: _districts
                                          .map((d) => DropdownMenuItem(
                                                value: d,
                                                child: Text(
                                                  d,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _districtController.text = val;
                                          });
                                        }
                                      },
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return 'Select District';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                second: _buildFormField(
                                  controller: _pinController,
                                  label: 'PIN (Pincode) *',
                                  hint: '6 digit PIN',
                                  icon: Icons.pin_drop_outlined,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'PIN required';
                                    }
                                    final clean = val.trim();
                                    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(clean)) {
                                      return 'Valid 6-digit PIN required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons (Clear & Submit)
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Colors.black87),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _resetForm,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.black87,
                                  ),
                                  label: const Text(
                                    'Clear Form',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isSubmitting ? null : _submitForm,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.cloud_upload_rounded,
                                          color: Colors.white,
                                        ),
                                  label: Text(
                                    _isSubmitting
                                        ? 'Verifying & Saving...'
                                        : 'Create RO Account',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsivePair({
    required bool isWide,
    required Widget first,
    required Widget second,
  }) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          const SizedBox(height: 14),
          second,
        ],
      );
    }
  }

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: _getInputDecoration(
            hint: hint,
            icon: icon,
          ),
        ),
      ],
    );
  }

  InputDecoration _getInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.black87, size: 20),
      isDense: true,
      errorMaxLines: 2,
      filled: true,
      fillColor: Colors.grey.shade50,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.8),
      ),
    );
  }
}
