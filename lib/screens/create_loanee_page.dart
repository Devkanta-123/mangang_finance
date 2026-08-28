// lib/screens/create_loanee_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/loanee_model.dart';
import '../providers/loanee_provider.dart';
import '../services/loanee_excel_import_service.dart';
import '../services/witness_excel_import_service.dart';
import '../widgets/loanee_excel_upload_dialog.dart';
import '../widgets/witness_excel_upload_dialog.dart';

class CreateLoaneePage extends StatefulWidget {
  final VoidCallback? onAccountCreated;

  const CreateLoaneePage({super.key, this.onAccountCreated});

  @override
  State<CreateLoaneePage> createState() => _CreateLoaneePageState();
}

class _CreateLoaneePageState extends State<CreateLoaneePage> {
  final _formKey = GlobalKey<FormState>();

  // Loanee Account Controllers
  late TextEditingController _customerIdController;
  late TextEditingController _accountNumberController;
  final TextEditingController _loaneeNameController = TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController(); // W/O, S/O, D/O
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _businessTypeController = TextEditingController();
  final TextEditingController _poController = TextEditingController(); // P/O
  final TextEditingController _psController = TextEditingController(); // P/S
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _pinController = TextEditingController(); // PIN
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _loanAmountController = TextEditingController();

  // Loan Sanction & Maturity Dates (5 Months Auto-calculated, can be edited)
  DateTime _loanSanctionDate = DateTime.now();
  late DateTime _loanMaturityDate;
  final TextEditingController _loanSanctionDateController = TextEditingController();
  final TextEditingController _loanMaturityDateController = TextEditingController();

  // Witness Controllers (11 Witness Details)
  final TextEditingController _witnessNameController = TextEditingController();
  final TextEditingController _witnessGuardianNameController = TextEditingController(); // W/O, S/O, D/O
  final TextEditingController _witnessAddressController = TextEditingController();
  final TextEditingController _witnessBusinessTypeController = TextEditingController();
  final TextEditingController _witnessPoController = TextEditingController(); // P/O
  final TextEditingController _witnessPsController = TextEditingController(); // P/S
  final TextEditingController _witnessDistrictController = TextEditingController();
  final TextEditingController _witnessPinController = TextEditingController(); // PIN
  final TextEditingController _witnessMobileController = TextEditingController();
  final TextEditingController _witnessAadharController = TextEditingController();
  final TextEditingController _witnessRelationshipController = TextEditingController();

  String _selectedBusinessType = 'Retail Grocery';
  bool _isCustomBusiness = false;

  String _selectedWitnessBusinessType = 'Retail Grocery';
  bool _isWitnessCustomBusiness = false;

  String _selectedWitnessRelationship = 'Friend';
  bool _isWitnessCustomRelationship = false;

  bool _isSubmitting = false;
  bool _isDownloadingTemplate = false;
  bool _isUploadingExcel = false;
  bool _isDownloadingWitnessTemplate = false;
  bool _isUploadingWitnessExcel = false;

  final List<String> _businessCategories = [
    'Retail Grocery',
    'Handicrafts & Handloom',
    'Agriculture & Farming',
    'Dairy & Livestock',
    'Food & Catering',
    'Vehicle & Transport',
    'Wholesale Trade',
    'Professional Services',
    'Salaried Employee',
    'Other Business',
  ];

  final List<String> _witnessRelationships = [
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
    'Other Relationship',
  ];

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
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    _customerIdController =
        TextEditingController(text: loaneeProvider.generateNextCustomerId());
    _accountNumberController =
        TextEditingController(text: loaneeProvider.generateNextAccountNumber());
    _districtController.text = _districts.first;
    _businessTypeController.text = _selectedBusinessType;

    _witnessDistrictController.text = _districts.first;
    _witnessBusinessTypeController.text = _selectedWitnessBusinessType;
    _witnessRelationshipController.text = _selectedWitnessRelationship;

    _loanMaturityDate = LoaneeAccount.calculateMaturityDate(_loanSanctionDate);
    _loanSanctionDateController.text =
        '${_loanSanctionDate.day.toString().padLeft(2, '0')}/${_loanSanctionDate.month.toString().padLeft(2, '0')}/${_loanSanctionDate.year}';
    _loanMaturityDateController.text =
        '${_loanMaturityDate.day.toString().padLeft(2, '0')}/${_loanMaturityDate.month.toString().padLeft(2, '0')}/${_loanMaturityDate.year}';
  }

  Future<void> _pickLoanSanctionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _loanSanctionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      helpText: 'Select Loan Sanction Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
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
        _loanSanctionDate = picked;
        _loanSanctionDateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        // Auto calculate +5 months
        _loanMaturityDate = LoaneeAccount.calculateMaturityDate(picked);
        _loanMaturityDateController.text =
            '${_loanMaturityDate.day.toString().padLeft(2, '0')}/${_loanMaturityDate.month.toString().padLeft(2, '0')}/${_loanMaturityDate.year}';
      });
    }
  }

  Future<void> _pickLoanMaturityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _loanMaturityDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      helpText: 'Select Loan Maturity Date (Custom / Edited)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
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
        _loanMaturityDate = picked;
        _loanMaturityDateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  void _copyAddressFromLoanee() {
    setState(() {
      _witnessAddressController.text = _addressController.text;
      _witnessPoController.text = _poController.text;
      _witnessPsController.text = _psController.text;
      _witnessDistrictController.text = _districtController.text;
      _witnessPinController.text = _pinController.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.copy_all_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Address details copied from Loanee to Witness!'),
          ],
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleDownloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    await LoaneeExcelImportService.downloadTemplate(context);
    if (mounted) {
      setState(() => _isDownloadingTemplate = false);
    }
  }

  Future<void> _handleUploadExcel() async {
    setState(() => _isUploadingExcel = true);
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    final parsedResult = await LoaneeExcelImportService.pickAndParseLoaneeExcel(
      context: context,
      existingLoanees: loaneeProvider.loanees,
    );
    if (mounted) {
      setState(() => _isUploadingExcel = false);
    }

    if (parsedResult != null && mounted) {
      await LoaneeExcelUploadDialog.show(
        context,
        previewResult: parsedResult,
        onImportSuccess: () {
          if (widget.onAccountCreated != null) {
            widget.onAccountCreated!();
          }
        },
      );
    }
  }

  Future<void> _handleDownloadWitnessTemplate() async {
    setState(() => _isDownloadingWitnessTemplate = true);
    await WitnessExcelImportService.downloadTemplate(context);
    if (mounted) {
      setState(() => _isDownloadingWitnessTemplate = false);
    }
  }

  Future<void> _handleUploadWitnessExcel() async {
    setState(() => _isUploadingWitnessExcel = true);
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    final parsedResult =
        await WitnessExcelImportService.pickAndParseWitnessExcel(
      context: context,
      existingLoanees: loaneeProvider.loanees,
    );
    if (mounted) {
      setState(() => _isUploadingWitnessExcel = false);
    }

    if (parsedResult != null && mounted) {
      await WitnessExcelUploadDialog.show(
        context,
        previewResult: parsedResult,
        onImportSuccess: () {
          if (widget.onAccountCreated != null) {
            widget.onAccountCreated!();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _accountNumberController.dispose();
    _loaneeNameController.dispose();
    _guardianNameController.dispose();
    _addressController.dispose();
    _businessTypeController.dispose();
    _poController.dispose();
    _psController.dispose();
    _districtController.dispose();
    _pinController.dispose();
    _mobileController.dispose();
    _aadharController.dispose();
    _loanAmountController.dispose();
    _loanSanctionDateController.dispose();
    _loanMaturityDateController.dispose();

    // Dispose witness controllers
    _witnessNameController.dispose();
    _witnessGuardianNameController.dispose();
    _witnessAddressController.dispose();
    _witnessBusinessTypeController.dispose();
    _witnessPoController.dispose();
    _witnessPsController.dispose();
    _witnessDistrictController.dispose();
    _witnessPinController.dispose();
    _witnessMobileController.dispose();
    _witnessAadharController.dispose();
    _witnessRelationshipController.dispose();

    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final loanAmount = double.tryParse(_loanAmountController.text.trim()) ?? 0.0;

      final newLoanee = LoaneeAccount(
        customerid: _customerIdController.text.trim(),
        accountnumber: _accountNumberController.text.trim(),
        loaneename: _loaneeNameController.text.trim(),
        guardianname: _guardianNameController.text.trim(),
        address: _addressController.text.trim(),
        businesstype: _isCustomBusiness
            ? _businessTypeController.text.trim()
            : _selectedBusinessType,
        postoffice: _poController.text.trim(),
        policestation: _psController.text.trim(),
        district: _districtController.text.trim(),
        pincode: _pinController.text.trim(),
        mobileno: _mobileController.text.trim(),
        aadharno: _aadharController.text.trim(),
        loanamount: loanAmount,
        paidamount: 0.0,
        dueamount: loanAmount,
        loansanctiondate: _loanSanctionDate,
        loanmaturitydate: _loanMaturityDate,

        // Witness Details
        witnessname: _witnessNameController.text.trim(),
        witnessguardianname: _witnessGuardianNameController.text.trim(),
        witnessaddress: _witnessAddressController.text.trim(),
        witnessbusinesstype: _isWitnessCustomBusiness
            ? _witnessBusinessTypeController.text.trim()
            : _selectedWitnessBusinessType,
        witnesspostoffice: _witnessPoController.text.trim(),
        witnesspolicestation: _witnessPsController.text.trim(),
        witnessdistrict: _witnessDistrictController.text.trim(),
        witnesspincode: _witnessPinController.text.trim(),
        witnessmobileno: _witnessMobileController.text.trim(),
        witnessaadharno: _witnessAadharController.text.trim(),
        witnessrelationship: _isWitnessCustomRelationship
            ? _witnessRelationshipController.text.trim()
            : _selectedWitnessRelationship,
      );

      final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
      
      // Perform pre-flight connection check and direct Supabase insertion
      final result = await loaneeProvider.addLoaneeWithConnectionCheck(newLoanee);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        _showSuccessDialog(newLoanee);
      } else {
        _showErrorDialog(result['message'] ?? 'Failed to insert to Supabase.');
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
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    _formKey.currentState?.reset();
    _customerIdController.text = loaneeProvider.generateNextCustomerId();
    _accountNumberController.text = loaneeProvider.generateNextAccountNumber();

    _loaneeNameController.clear();
    _guardianNameController.clear();
    _addressController.clear();
    _poController.clear();
    _psController.clear();
    _pinController.clear();
    _mobileController.clear();
    _aadharController.clear();
    _loanAmountController.clear();

    _loanSanctionDate = DateTime.now();
    _loanMaturityDate = LoaneeAccount.calculateMaturityDate(_loanSanctionDate);
    _loanSanctionDateController.text =
        '${_loanSanctionDate.day.toString().padLeft(2, '0')}/${_loanSanctionDate.month.toString().padLeft(2, '0')}/${_loanSanctionDate.year}';
    _loanMaturityDateController.text =
        '${_loanMaturityDate.day.toString().padLeft(2, '0')}/${_loanMaturityDate.month.toString().padLeft(2, '0')}/${_loanMaturityDate.year}';

    // Clear witness fields
    _witnessNameController.clear();
    _witnessGuardianNameController.clear();
    _witnessAddressController.clear();
    _witnessPoController.clear();
    _witnessPsController.clear();
    _witnessPinController.clear();
    _witnessMobileController.clear();
    _witnessAadharController.clear();

    setState(() {
      _selectedBusinessType = _businessCategories.first;
      _isCustomBusiness = false;
      _districtController.text = _districts.first;

      _selectedWitnessBusinessType = _businessCategories.first;
      _isWitnessCustomBusiness = false;
      _witnessDistrictController.text = _districts.first;
      _selectedWitnessRelationship = _witnessRelationships.first;
      _isWitnessCustomRelationship = false;
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

  void _showSuccessDialog(LoaneeAccount loanee) {
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
              'Account & Witness Created!',
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
                        '✅ Loanee & Witness Saved to Supabase (loanee_accounts)',
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
                'Loanee & Witness details recorded live:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _buildDetailRow('Customer ID:', loanee.customerId),
              _buildDetailRow('Account No:', loanee.accountNumber),
              _buildDetailRow('Loanee Name:', loanee.loaneeName),
              _buildDetailRow('Loanee Mobile:', loanee.mobileNo),
              const Divider(height: 16),
              _buildDetailRow('Witness Name:', loanee.witnessName),
              _buildDetailRow('Relationship:', loanee.witnessRelationship),
              _buildDetailRow('Witness Mobile:', loanee.witnessMobileNo),
              _buildDetailRow('Witness District:', loanee.witnessDistrict),
              _buildDetailRow('Loan Sanction:', '₹ ${loanee.loanAmount.toStringAsFixed(0)}'),
              _buildDetailRow('Sanction Date:', loanee.formattedSanctionDate),
              _buildDetailRow('Maturity Date (+5m):', loanee.formattedMaturityDate),
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
            child: const Text('View List', style: TextStyle(color: Colors.white)),
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
              value.isNotEmpty ? value : 'N/A',
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
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: SingleChildScrollView(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
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
                                    'Create Loanee & Witness Account',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Enter official loanee details & witness information for registration',
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
                      ],
                    ),
                  ),

                  // Excel Bulk Import & Template Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.table_view_rounded,
                                  color: Colors.black87,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bulk Loanee Excel Import / Export',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Download standard loanee Excel template or upload basic loanee records in bulk',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    side: BorderSide(color: Colors.grey.shade400),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _isDownloadingTemplate ? null : _handleDownloadTemplate,
                                  icon: _isDownloadingTemplate
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                        )
                                      : const Icon(Icons.download_rounded, size: 16, color: Colors.black87),
                                  label: const Text(
                                    'Download Template',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _isUploadingExcel ? null : _handleUploadExcel,
                                  icon: _isUploadingExcel
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.upload_file_rounded, size: 16),
                                  label: const Text(
                                    'Upload Excel',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Witness Excel Bulk Import & Template Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.handshake_outlined,
                                  color: Colors.indigo,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bulk Loanee Witness Excel Import / Export',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Download witness Excel template or upload witness details mapped to Customer ID + Account No',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    side: BorderSide(color: Colors.indigo.shade300),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _isDownloadingWitnessTemplate ? null : _handleDownloadWitnessTemplate,
                                  icon: _isDownloadingWitnessTemplate
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
                                        )
                                      : const Icon(Icons.download_rounded, size: 16, color: Colors.indigo),
                                  label: const Text(
                                    'Download Witness Template',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _isUploadingWitnessExcel ? null : _handleUploadWitnessExcel,
                                  icon: _isUploadingWitnessExcel
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.upload_file_rounded, size: 16),
                                  label: const Text(
                                    'Upload Witness Excel',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                            title: '1. Account & System Identifiers',
                            icon: Icons.qr_code_rounded,
                            children: [
                              _buildResponsivePair(
                                isWide: isWide,
                                first: _buildFormField(
                                  controller: _customerIdController,
                                  label: 'CUSTOMER ID *',
                                  hint: 'e.g. 2026LA000001',
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
                                  hint: 'e.g. MF2026A000001',
                                  icon: Icons.account_balance_wallet_outlined,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Account Number required';
                                    }
                                    if (val.trim().length < 5) {
                                      return 'Min 5 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section 2: Loanee Personal Details
                          _buildFormCard(
                            title: '2. Loanee Personal Details',
                            icon: Icons.person_outline_rounded,
                            children: [
                              _buildFormField(
                                controller: _loaneeNameController,
                                label: 'LOANEE NAME *',
                                hint: 'Enter full name of loanee',
                                icon: Icons.person,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Loanee name is required';
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

                          // Section 3: Loanee Address Details
                          _buildFormCard(
                            title: '3. Loanee Address & Area Details',
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
                                    isExpanded: true,
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

                          const SizedBox(height: 16),

                          // Section 4: Loanee Business & Financial Information
                          _buildFormCard(
                            title: '4. Loanee Business & Financial Details',
                            icon: Icons.storefront_rounded,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TYPES OF BUSINESS *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedBusinessType,
                                    decoration: _getInputDecoration(
                                      hint: 'Select Business Category',
                                      icon: Icons.business_center_outlined,
                                    ),
                                    items: _businessCategories
                                        .map((cat) => DropdownMenuItem(
                                              value: cat,
                                              child: Text(
                                                cat,
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
                                          _selectedBusinessType = val;
                                          _isCustomBusiness = (val == 'Other Business');
                                          if (!_isCustomBusiness) {
                                            _businessTypeController.text = val;
                                          } else {
                                            _businessTypeController.clear();
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  if (_isCustomBusiness) ...[
                                    const SizedBox(height: 10),
                                    _buildFormField(
                                      controller: _businessTypeController,
                                      label: 'SPECIFY BUSINESS TYPE *',
                                      hint: 'Enter detailed business type',
                                      icon: Icons.edit_note_rounded,
                                      validator: (val) {
                                        if (_isCustomBusiness &&
                                            (val == null || val.trim().isEmpty)) {
                                          return 'Please specify business type';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildFormField(
                                controller: _loanAmountController,
                                label: 'SANCTIONED LOAN AMOUNT (₹) *',
                                hint: 'Enter loan amount',
                                icon: Icons.currency_rupee_rounded,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Loan amount required';
                                  }
                                  final amount = double.tryParse(val.trim());
                                  if (amount == null || amount <= 0) {
                                    return 'Enter valid loan amount';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildResponsivePair(
                                isWide: isWide,
                                first: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'LOAN SANCTION DATE *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _loanSanctionDateController,
                                      readOnly: true,
                                      onTap: _pickLoanSanctionDate,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                      decoration: _getInputDecoration(
                                        hint: 'dd/mm/yyyy',
                                        icon: Icons.calendar_today_rounded,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.date_range_rounded, color: Colors.black87, size: 20),
                                          onPressed: _pickLoanSanctionDate,
                                          tooltip: 'Pick Sanction Date',
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Loan sanction date is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Defaults to today, tap to change',
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                second: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        const Text(
                                          'LOAN MATURITY DATE *',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.teal.shade200),
                                          ),
                                          child: Text(
                                            '+5 Months',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _loanMaturityDateController,
                                      readOnly: true,
                                      onTap: _pickLoanMaturityDate,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                      decoration: _getInputDecoration(
                                        hint: 'dd/mm/yyyy',
                                        icon: Icons.event_available_rounded,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.edit_calendar_rounded, color: Colors.teal, size: 20),
                                          onPressed: _pickLoanMaturityDate,
                                          tooltip: 'Edit Maturity Date',
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Loan maturity date is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Auto-calculated (5 months), tap to edit',
                                      style: TextStyle(fontSize: 10.5, color: Colors.teal.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Section 5: Witness / Guarantor Details (REQUIRED BY USER)
                          _buildFormCard(
                            title: '5. Witness Details',
                            icon: Icons.handshake_outlined,
                            headerTrailing: TextButton.icon(
                              onPressed: _copyAddressFromLoanee,
                              icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.indigo),
                              label: const Text(
                                'Same Address as Loanee',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            children: [
                              _buildFormField(
                                controller: _witnessNameController,
                                label: 'WITNESS NAME *',
                                hint: 'Enter full name of witness',
                                icon: Icons.person_pin_rounded,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Witness name is required';
                                  }
                                  if (val.trim().length < 3) {
                                    return 'Must be at least 3 letters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildFormField(
                                controller: _witnessGuardianNameController,
                                label: 'WITNESS W/O, S/O, D/O *',
                                hint: 'Wife of / Son of / Daughter of name',
                                icon: Icons.family_restroom_rounded,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Witness guardian name (W/O, S/O, D/O) is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Relationship with Loanee
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'RELATIONSHIP WITH LOANEE *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedWitnessRelationship,
                                    decoration: _getInputDecoration(
                                      hint: 'Select Relationship',
                                      icon: Icons.people_outline_rounded,
                                    ),
                                    items: _witnessRelationships
                                        .map((rel) => DropdownMenuItem(
                                              value: rel,
                                              child: Text(
                                                rel,
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
                                          _selectedWitnessRelationship = val;
                                          _isWitnessCustomRelationship = (val == 'Other Relationship');
                                          if (!_isWitnessCustomRelationship) {
                                            _witnessRelationshipController.text = val;
                                          } else {
                                            _witnessRelationshipController.clear();
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  if (_isWitnessCustomRelationship) ...[
                                    const SizedBox(height: 10),
                                    _buildFormField(
                                      controller: _witnessRelationshipController,
                                      label: 'SPECIFY RELATIONSHIP *',
                                      hint: 'e.g. Mentor, In-law, Business Colleague',
                                      icon: Icons.edit_note_rounded,
                                      validator: (val) {
                                        if (_isWitnessCustomRelationship &&
                                            (val == null || val.trim().isEmpty)) {
                                          return 'Please specify relationship with loanee';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 14),
                              _buildResponsivePair(
                                isWide: isWide,
                                first: _buildFormField(
                                  controller: _witnessMobileController,
                                  label: 'WITNESS MOBILE NO *',
                                  hint: '10 digit mobile number',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Witness mobile number required';
                                    }
                                    final clean = val.trim();
                                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
                                      return 'Valid 10-digit mobile required';
                                    }
                                    return null;
                                  },
                                ),
                                second: _buildFormField(
                                  controller: _witnessAadharController,
                                  label: 'WITNESS AADHAR NO *',
                                  hint: '12 digit Aadhar',
                                  icon: Icons.credit_card_rounded,
                                  keyboardType: TextInputType.number,
                                  maxLength: 14,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Witness Aadhar number required';
                                    }
                                    final clean = val.replaceAll(' ', '').trim();
                                    if (!RegExp(r'^\d{12}$').hasMatch(clean)) {
                                      return 'Must be 12 digits';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 14),
                              _buildFormField(
                                controller: _witnessAddressController,
                                label: 'WITNESS ADDRESS *',
                                hint: 'Witness House No, Village/Leikai, Street Name',
                                icon: Icons.home_work_outlined,
                                maxLines: 2,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Witness full address is required';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),
                              _buildResponsivePair(
                                isWide: isWide,
                                first: _buildFormField(
                                  controller: _witnessPoController,
                                  label: 'WITNESS P/O (Post Office) *',
                                  hint: 'Witness Post Office',
                                  icon: Icons.markunread_mailbox_outlined,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Witness P/O required';
                                    }
                                    return null;
                                  },
                                ),
                                second: _buildFormField(
                                  controller: _witnessPsController,
                                  label: 'WITNESS P/S (Police Station) *',
                                  hint: 'Witness Police Station',
                                  icon: Icons.local_police_outlined,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Witness P/S required';
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
                                      'WITNESS DISTRICT *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                    isExpanded: true,
                                      value: _witnessDistrictController.text.isNotEmpty &&
                                              _districts.contains(_witnessDistrictController.text)
                                          ? _witnessDistrictController.text
                                          : _districts.first,
                                      decoration: _getInputDecoration(
                                        hint: 'Select Witness District',
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
                                            _witnessDistrictController.text = val;
                                          });
                                        }
                                      },
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return 'Select Witness District';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                second: _buildFormField(
                                  controller: _witnessPinController,
                                  label: 'WITNESS PIN (Pincode) *',
                                  hint: '6 digit PIN',
                                  icon: Icons.pin_drop_outlined,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Witness PIN required';
                                    }
                                    final clean = val.trim();
                                    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(clean)) {
                                      return 'Valid 6-digit PIN required';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 14),
                              // Witness Types of Business
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WITNESS TYPES OF BUSINESS *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedWitnessBusinessType,
                                    decoration: _getInputDecoration(
                                      hint: 'Select Witness Business Category',
                                      icon: Icons.business_center_outlined,
                                    ),
                                    items: _businessCategories
                                        .map((cat) => DropdownMenuItem(
                                              value: cat,
                                              child: Text(
                                                cat,
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
                                          _selectedWitnessBusinessType = val;
                                          _isWitnessCustomBusiness = (val == 'Other Business');
                                          if (!_isWitnessCustomBusiness) {
                                            _witnessBusinessTypeController.text = val;
                                          } else {
                                            _witnessBusinessTypeController.clear();
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  if (_isWitnessCustomBusiness) ...[
                                    const SizedBox(height: 10),
                                    _buildFormField(
                                      controller: _witnessBusinessTypeController,
                                      label: 'SPECIFY WITNESS BUSINESS TYPE *',
                                      hint: 'Enter witness business / occupation',
                                      icon: Icons.edit_note_rounded,
                                      validator: (val) {
                                        if (_isWitnessCustomBusiness &&
                                            (val == null || val.trim().isEmpty)) {
                                          return 'Please specify witness business type';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
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
                                        : 'Create Account',
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
            ),
      ),
    );
  }

  /// Helper to render fields side-by-side on wide screens, stacked on narrow screens
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
    Widget? headerTrailing,
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
              Icon(icon, color: Colors.black, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (headerTrailing != null) ...[
            const SizedBox(height: 4),
            headerTrailing,
          ],
          const Divider(height: 18),
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
