// lib/widgets/edit_loanee_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/loanee_model.dart';
import '../providers/loanee_provider.dart';

class EditLoaneeDialog extends StatefulWidget {
  final LoaneeAccount loanee;

  const EditLoaneeDialog({super.key, required this.loanee});

  static Future<bool?> show(BuildContext context, LoaneeAccount loanee) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditLoaneeDialog(loanee: loanee),
    );
  }

  @override
  State<EditLoaneeDialog> createState() => _EditLoaneeDialogState();
}

class _EditLoaneeDialogState extends State<EditLoaneeDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Personal controllers
  late TextEditingController _nameController;
  late TextEditingController _guardianController;
  late TextEditingController _mobileController;
  late TextEditingController _aadharController;
  late TextEditingController _addressController;
  late TextEditingController _poController;
  late TextEditingController _psController;
  late TextEditingController _pinController;
  late String _selectedDistrict;
  late String _selectedStatus;

  // Business & Financial controllers
  late TextEditingController _businessTypeController;
  late TextEditingController _loanAmountController;
  late DateTime _sanctionDate;
  late DateTime _maturityDate;
  late TextEditingController _sanctionDateController;
  late TextEditingController _maturityDateController;

  // Witness controllers
  late TextEditingController _witnessNameController;
  late TextEditingController _witnessGuardianController;
  late TextEditingController _witnessMobileController;
  late TextEditingController _witnessAadharController;
  late TextEditingController _witnessAddressController;
  late TextEditingController _witnessPoController;
  late TextEditingController _witnessPsController;
  late TextEditingController _witnessPinController;
  late TextEditingController _witnessBusinessTypeController;
  late String _witnessDistrict;
  late String _witnessRelationship;

  bool _isSaving = false;

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

  final List<String> _relationships = [
    'Friend',
    'Brother',
    'Sister',
    'Father',
    'Mother',
    'Spouse',
    'Cousin',
    'Neighbor',
    'Business Partner',
    'Relative',
    'Other',
  ];

  final List<String> _statuses = [
    'Active',
    'Inactive',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final l = widget.loanee;

    _nameController = TextEditingController(text: l.loaneename);
    _guardianController = TextEditingController(text: l.guardianname);
    _mobileController = TextEditingController(text: l.mobileno);
    _aadharController = TextEditingController(text: l.aadharno);
    _addressController = TextEditingController(text: l.address);
    _poController = TextEditingController(text: l.postoffice);
    _psController = TextEditingController(text: l.policestation);
    _pinController = TextEditingController(text: l.pincode);

    _selectedDistrict = _districts.contains(l.district) ? l.district : _districts.first;
    _selectedStatus = _statuses.contains(l.status) ? l.status : 'Active';

    _businessTypeController = TextEditingController(text: l.businesstype);
    _loanAmountController = TextEditingController(text: l.loanamount > 0 ? l.loanamount.toStringAsFixed(0) : '');

    _sanctionDate = l.loansanctiondate ?? l.createdat;
    _maturityDate = l.loanmaturitydate ?? LoaneeAccount.calculateMaturityDate(_sanctionDate);

    _sanctionDateController = TextEditingController(
        text: '${_sanctionDate.day.toString().padLeft(2, '0')}/${_sanctionDate.month.toString().padLeft(2, '0')}/${_sanctionDate.year}');
    _maturityDateController = TextEditingController(
        text: '${_maturityDate.day.toString().padLeft(2, '0')}/${_maturityDate.month.toString().padLeft(2, '0')}/${_maturityDate.year}');

    _witnessNameController = TextEditingController(text: l.witnessname);
    _witnessGuardianController = TextEditingController(text: l.witnessguardianname);
    _witnessMobileController = TextEditingController(text: l.witnessmobileno);
    _witnessAadharController = TextEditingController(text: l.witnessaadharno);
    _witnessAddressController = TextEditingController(text: l.witnessaddress);
    _witnessPoController = TextEditingController(text: l.witnesspostoffice);
    _witnessPsController = TextEditingController(text: l.witnesspolicestation);
    _witnessPinController = TextEditingController(text: l.witnesspincode);
    _witnessBusinessTypeController = TextEditingController(text: l.witnessbusinesstype);
    _witnessDistrict = _districts.contains(l.witnessdistrict) ? l.witnessdistrict : _districts.first;
    _witnessRelationship = _relationships.contains(l.witnessrelationship) ? l.witnessrelationship : _relationships.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _guardianController.dispose();
    _mobileController.dispose();
    _aadharController.dispose();
    _addressController.dispose();
    _poController.dispose();
    _psController.dispose();
    _pinController.dispose();
    _businessTypeController.dispose();
    _loanAmountController.dispose();
    _sanctionDateController.dispose();
    _maturityDateController.dispose();
    _witnessNameController.dispose();
    _witnessGuardianController.dispose();
    _witnessMobileController.dispose();
    _witnessAadharController.dispose();
    _witnessAddressController.dispose();
    _witnessPoController.dispose();
    _witnessPsController.dispose();
    _witnessPinController.dispose();
    _witnessBusinessTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickSanctionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sanctionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      helpText: 'Select Loan Sanction Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B1A1A),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _sanctionDate = picked;
        _sanctionDateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        _maturityDate = LoaneeAccount.calculateMaturityDate(picked);
        _maturityDateController.text =
            '${_maturityDate.day.toString().padLeft(2, '0')}/${_maturityDate.month.toString().padLeft(2, '0')}/${_maturityDate.year}';
      });
    }
  }

  Future<void> _pickMaturityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _maturityDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      helpText: 'Select Loan Maturity Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B1A1A),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _maturityDate = picked;
        _maturityDateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  void _copyAddressToWitness() {
    setState(() {
      _witnessAddressController.text = _addressController.text;
      _witnessPoController.text = _poController.text;
      _witnessPsController.text = _psController.text;
      _witnessDistrict = _selectedDistrict;
      _witnessPinController.text = _pinController.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Loanee address copied to Witness!'),
        backgroundColor: Colors.indigo.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the validation errors in all tabs.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final loanAmt = double.tryParse(_loanAmountController.text.trim()) ?? widget.loanee.loanamount;

    final updatedLoanee = widget.loanee.copyWith(
      loaneename: _nameController.text.trim(),
      guardianname: _guardianController.text.trim(),
      mobileno: _mobileController.text.trim(),
      aadharno: _aadharController.text.trim(),
      address: _addressController.text.trim(),
      postoffice: _poController.text.trim(),
      policestation: _psController.text.trim(),
      district: _selectedDistrict,
      pincode: _pinController.text.trim(),
      status: _selectedStatus,
      businesstype: _businessTypeController.text.trim(),
      loanamount: loanAmt,
      loansanctiondate: _sanctionDate,
      loanmaturitydate: _maturityDate,
      witnessname: _witnessNameController.text.trim(),
      witnessguardianname: _witnessGuardianController.text.trim(),
      witnessmobileno: _witnessMobileController.text.trim(),
      witnessaadharno: _witnessAadharController.text.trim(),
      witnessaddress: _witnessAddressController.text.trim(),
      witnesspostoffice: _witnessPoController.text.trim(),
      witnesspolicestation: _witnessPsController.text.trim(),
      witnessdistrict: _witnessDistrict,
      witnesspincode: _witnessPinController.text.trim(),
      witnessbusinesstype: _witnessBusinessTypeController.text.trim(),
      witnessrelationship: _witnessRelationship,
    );

    final provider = Provider.of<LoaneeProvider>(context, listen: false);
    final success = await provider.updateLoanee(updatedLoanee);

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Loanee ${updatedLoanee.loaneeName} updated successfully')),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save updated loanee to database.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: size.height * 0.88),
        child: Column(
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Loanee Record (Admin)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Cust ID: ${widget.loanee.customerId} • Acc: ${widget.loanee.accountNumber}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.grey.shade100,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF8B1A1A),
                unselectedLabelColor: Colors.grey.shade700,
                indicatorColor: const Color(0xFF8B1A1A),
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.person_rounded, size: 18), text: 'Personal'),
                  Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Loan & Dates'),
                  Tab(icon: Icon(Icons.handshake_outlined, size: 18), text: 'Witness'),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Personal Details
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Loanee Full Name *',
                            icon: Icons.person_outline,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _guardianController,
                            label: 'W/O, S/O, D/O (Guardian Name) *',
                            icon: Icons.family_restroom_outlined,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Guardian name required' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _mobileController,
                                  label: 'Mobile No (10 digits) *',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  validator: (v) => v == null || v.trim().length != 10 ? '10 digits required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _aadharController,
                                  label: 'Aadhar No (12 digits) *',
                                  icon: Icons.credit_card_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(12),
                                  ],
                                  validator: (v) => v == null || v.trim().length != 12 ? '12 digits required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Residential Address *',
                            icon: Icons.home_outlined,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Address required' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _poController,
                                  label: 'Post Office (P/O) *',
                                  icon: Icons.markunread_mailbox_outlined,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'P/O required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _psController,
                                  label: 'Police Station (P/S) *',
                                  icon: Icons.local_police_outlined,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'P/S required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedDistrict,
                                  decoration: InputDecoration(
                                    labelText: 'District *',
                                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF8B1A1A), size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _districts
                                      .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedDistrict = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _pinController,
                                  label: 'PIN Code (6 digits) *',
                                  icon: Icons.pin_drop_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  validator: (v) => v == null || v.trim().length != 6 ? '6 digits required' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: Loan Details & Dates
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _businessTypeController,
                            label: 'Business / Occupation *',
                            icon: Icons.storefront_outlined,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Business type required' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _loanAmountController,
                                  label: 'Sanctioned Loan Amount (₹) *',
                                  icon: Icons.currency_rupee_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Loan amount required';
                                    final amt = double.tryParse(v.trim());
                                    if (amt == null || amt <= 0) return 'Invalid amount';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Account Status *',
                                    prefixIcon: const Icon(Icons.verified_user_outlined, color: Color(0xFF8B1A1A), size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _statuses
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedStatus = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          const Text(
                            'LOAN SANCTION & MATURITY SCHEDULE',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _sanctionDateController,
                                  readOnly: true,
                                  onTap: _pickSanctionDate,
                                  decoration: InputDecoration(
                                    labelText: 'Loan Sanction Date *',
                                    prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF8B1A1A), size: 20),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.date_range_rounded, size: 20),
                                      onPressed: _pickSanctionDate,
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _maturityDateController,
                                  readOnly: true,
                                  onTap: _pickMaturityDate,
                                  decoration: InputDecoration(
                                    labelText: 'Loan Maturity Date *',
                                    prefixIcon: const Icon(Icons.event_available_rounded, color: Colors.teal, size: 20),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.edit_calendar_rounded, color: Colors.teal, size: 20),
                                      onPressed: _pickMaturityDate,
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.teal.shade800),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Maturity date auto-defaults to 5 months from Sanction Date, but can be customized.',
                                  style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  setState(() {
                                    _maturityDate = LoaneeAccount.calculateMaturityDate(_sanctionDate);
                                    _maturityDateController.text =
                                        '${_maturityDate.day.toString().padLeft(2, '0')}/${_maturityDate.month.toString().padLeft(2, '0')}/${_maturityDate.year}';
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.teal),
                                label: const Text('Reset +5m', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tab 3: Witness Details
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'GUARANTOR / WITNESS DETAILS',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                              TextButton.icon(
                                onPressed: _copyAddressToWitness,
                                icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.indigo),
                                label: const Text('Copy Loanee Address', style: TextStyle(fontSize: 11, color: Colors.indigo)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: _witnessNameController,
                            label: 'Witness Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _witnessGuardianController,
                            label: 'Witness W/O, S/O, D/O',
                            icon: Icons.family_restroom_outlined,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _witnessMobileController,
                                  label: 'Witness Mobile No',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _witnessAadharController,
                                  label: 'Witness Aadhar No',
                                  icon: Icons.credit_card_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _witnessAddressController,
                            label: 'Witness Address',
                            icon: Icons.home_outlined,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _witnessPoController,
                                  label: 'Witness P/O',
                                  icon: Icons.markunread_mailbox_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _witnessPsController,
                                  label: 'Witness P/S',
                                  icon: Icons.local_police_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _witnessDistrict,
                                  decoration: InputDecoration(
                                    labelText: 'Witness District',
                                    prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.indigo, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _districts
                                      .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _witnessDistrict = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _witnessPinController,
                                  label: 'Witness PIN Code',
                                  icon: Icons.pin_drop_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _witnessBusinessTypeController,
                                  label: 'Witness Business',
                                  icon: Icons.work_outline,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _witnessRelationship,
                                  decoration: InputDecoration(
                                    labelText: 'Relationship with Loanee',
                                    prefixIcon: const Icon(Icons.handshake_outlined, color: Colors.indigo, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: _relationships
                                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _witnessRelationship = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dialog Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 15),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8B1A1A), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
