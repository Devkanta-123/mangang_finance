// lib/screens/add_loanee_collection_sheet_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/loanee_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/settings_provider.dart';
import '../services/bulk_collection_import_service.dart';
import '../widgets/bulk_collection_upload_dialog.dart';

class AddLoaneeCollectionSheetPage extends StatefulWidget {
  final VoidCallback? onViewCollectionSheet;

  const AddLoaneeCollectionSheetPage({
    super.key,
    this.onViewCollectionSheet,
  });

  @override
  State<AddLoaneeCollectionSheetPage> createState() =>
      _AddLoaneeCollectionSheetPageState();
}

class _AddLoaneeCollectionSheetPageState
    extends State<AddLoaneeCollectionSheetPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _customerIdController;
  late TextEditingController _accountNumberController;
  late TextEditingController _loaneeNameController;
  late TextEditingController _addressController;
  late TextEditingController _mobileNoController;

  LoaneeAccount? _selectedLoaneeAccount;
  String _selectedCollectionType = 'Daily';
  String? _selectedRoute;
  bool _isSubmitting = false;

  final List<String> _collectionTypes = [
    'Daily',
    'Mon',
    'Tue',
    'Wed',
    'Thur',
    'Fri',
    'Sat',
  ];

  @override
  void initState() {
    super.initState();
    _customerIdController = TextEditingController();
    _accountNumberController = TextEditingController();
    _loaneeNameController = TextEditingController();
    _addressController = TextEditingController();
    _mobileNoController = TextEditingController();

    // Auto setup route after frame render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CollectionSheetProvider>(context, listen: false);
      final routes = provider.routeNames;
      if (routes.isNotEmpty) {
        setState(() {
          _selectedRoute = routes.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _accountNumberController.dispose();
    _loaneeNameController.dispose();
    _addressController.dispose();
    _mobileNoController.dispose();
    super.dispose();
  }

  void _onLoaneeSelected(LoaneeAccount? selected) {
    setState(() {
      _selectedLoaneeAccount = selected;
      if (selected != null) {
        _customerIdController.text = selected.customerid;
        _accountNumberController.text = selected.accountnumber;
        _loaneeNameController.text = selected.loaneename;
        _addressController.text = selected.address;
        _mobileNoController.text = selected.mobileno;
      } else {
        _customerIdController.clear();
        _accountNumberController.clear();
        _loaneeNameController.clear();
        _addressController.clear();
        _mobileNoController.clear();
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final collectionProvider = Provider.of<CollectionSheetProvider>(context, listen: false);
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);
    final availableRoutes = collectionProvider.routeNames;

    if (_selectedLoaneeAccount == null && loaneeProvider.loanees.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an existing Loanee Account from the dropdown!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (availableRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No routes in master! Please create a Route first in Route Management.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedRoute == null || _selectedRoute!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid Route!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final double rawLoan = (_selectedLoaneeAccount != null && _selectedLoaneeAccount!.loanAmount > 0)
        ? _selectedLoaneeAccount!.loanAmount
        : 11500.0;

    final breakdown = LoanPrincipalBreakdown.calculate(
      loanAmount: rawLoan,
      interestRate: settingsProvider.investmentInterestRate,
      basePrincipal: settingsProvider.investmentBaseAmount,
      baseDailyAmount: settingsProvider.baseDailyAmount,
      baseWeeklyAmount: settingsProvider.weeklyInstallmentAmount,
    );

    final bool isDaily = _selectedCollectionType.toLowerCase().trim() == 'daily';
    final double payableAmt = isDaily ? breakdown.dailyPayable : breakdown.weeklyPayable;
    final String freq = isDaily ? 'Day' : 'Week';

    final entry = RoCollectionEntry(
      id: 'COL-${DateTime.now().millisecondsSinceEpoch}',
      customerId: _customerIdController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      loaneeName: _loaneeNameController.text.trim(),
      loaneeAddress: _addressController.text.trim(),
      collectionType: _selectedCollectionType,
      route: _selectedRoute!,
      mobileNo: _mobileNoController.text.trim(),
      payableAmount: payableAmt,
      loanAmount: breakdown.loanAmount,
      actualPrincipal: breakdown.actualPrincipal,
      interestAmount: breakdown.interestAmount,
      interestRate: breakdown.interestRate,
      frequency: freq,
    );

    final success = await collectionProvider.addCollectionEntry(entry);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (success) {
        _showSweetSuccessModal(entry);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save collection entry.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // SweetAlert style success modal
  void _showSweetSuccessModal(RoCollectionEntry entry) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final breakdown = entry.getLoanBreakdown(
      loaneeLoanAmount: _selectedLoaneeAccount?.loanAmount,
      configuredInterestRate: settingsProvider.investmentInterestRate,
      configuredBasePrincipal: settingsProvider.investmentBaseAmount,
      configuredBaseDailyAmount: settingsProvider.baseDailyAmount,
      configuredWeeklyInstallment: settingsProvider.weeklyInstallmentAmount,
    );
    final payableText = entry.getFormattedPayableAmount(
      loaneeLoanAmount: _selectedLoaneeAccount?.loanAmount,
      configuredInterestRate: settingsProvider.investmentInterestRate,
      configuredBasePrincipal: settingsProvider.investmentBaseAmount,
      configuredBaseDailyAmount: settingsProvider.baseDailyAmount,
      configuredWeeklyInstallment: settingsProvider.weeklyInstallmentAmount,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Icon(Icons.check_circle_rounded,
                  size: 56, color: Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Collection Card Registered!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Successfully added card profile for ${entry.loaneeName} on ${entry.route} Route.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Loanee Name', entry.loaneeName),
                  const Divider(height: 12),
                  _buildReceiptRow('Loan Amount (incl. interest)', '₹ ${breakdown.loanAmount.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _buildReceiptRow('Actual Principal', '₹ ${breakdown.actualPrincipal.toStringAsFixed(2)}'),
                  const Divider(height: 12),
                  _buildReceiptRow('Interest Amount', '₹ ${breakdown.interestAmount.toStringAsFixed(2)} (${breakdown.interestRate.toStringAsFixed(0)}%)'),
                  const Divider(height: 12),
                  _buildReceiptRow('Payable Amount', payableText),
                  const Divider(height: 12),
                  _buildReceiptRow('Collection Type', entry.collectionType),
                  const Divider(height: 12),
                  _buildReceiptRow('Account No.', entry.accountNumber),
                  const Divider(height: 12),
                  _buildReceiptRow('Mobile No.', entry.mobileNo),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text(
              'Add Another',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
              if (widget.onViewCollectionSheet != null) {
                widget.onViewCollectionSheet!();
              }
            },
            child: const Text('View Collection Sheet'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _selectedLoaneeAccount = null;
    _customerIdController.clear();
    _accountNumberController.clear();
    _loaneeNameController.clear();
    _addressController.clear();
    _mobileNoController.clear();
    setState(() {
      _selectedCollectionType = 'Daily';
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final loaneeProvider = Provider.of<LoaneeProvider>(context);

    final availableRoutes = collectionProvider.routeNames;
    final loaneeAccounts = loaneeProvider.loanees;

    // Ensure selected route is valid
    if (_selectedRoute == null || !availableRoutes.contains(_selectedRoute)) {
      if (availableRoutes.isNotEmpty) {
        _selectedRoute = availableRoutes.first;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dark Header matching Loanee Accounts design
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.post_add_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Add Loanee on R.O. Collection Sheet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Sync Loanee Accounts',
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        onPressed: () {
                          loaneeProvider.fetchFromSupabase();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Refreshing Loanee Accounts from Supabase...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select existing loanee account to auto-load details & record collection entry',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ),
            ),

            // Bulk Loanee Collection Card Actions Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B1A1A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8B1A1A).withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B1A1A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.post_add_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bulk Collection Card Import (Excel / CSV)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
                              ),
                            ),
                            Text(
                              'Download sample template or bulk upload multiple loanee cards to RO Collection Sheet',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
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
                            foregroundColor: const Color(0xFF8B1A1A),
                            side: const BorderSide(color: Color(0xFF8B1A1A)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.white,
                          ),
                          onPressed: () => BulkCollectionImportService.downloadTemplate(context),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text(
                            'Download Template',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B1A1A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                          onPressed: () async {
                            final parsed = await BulkCollectionImportService.pickAndParseBulkCollectionEntries(
                              context: context,
                              collectionProvider: collectionProvider,
                            );
                            if (parsed != null && parsed.isNotEmpty && context.mounted) {
                              await BulkCollectionUploadDialog.show(context, parsedRows: parsed);
                            }
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text(
                            'Upload Bulk Excel',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Form Content Container
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment_outlined, color: Color(0xFF1E1E1E), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Collection Entry Form',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // LOANEE SELECTOR DROPDOWN
                        _buildLoaneeAccountDropdown(loaneeAccounts),

                        const SizedBox(height: 16),

                        // Read-only indicator banner if loanee is selected
                        if (_selectedLoaneeAccount != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_rounded, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Loanee Name, Address & Mobile No. auto-loaded from profile (Read Only)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final settingsProvider = Provider.of<SettingsProvider>(context);
                              final bool isDaily = _selectedCollectionType.toLowerCase().trim() == 'daily';
                              final double rawLoan = _selectedLoaneeAccount!.loanAmount > 0
                                  ? _selectedLoaneeAccount!.loanAmount
                                  : 11500.0;
                              final breakdown = LoanPrincipalBreakdown.calculate(
                                loanAmount: rawLoan,
                                interestRate: settingsProvider.investmentInterestRate,
                                basePrincipal: settingsProvider.investmentBaseAmount,
                                baseDailyAmount: settingsProvider.baseDailyAmount,
                                baseWeeklyAmount: settingsProvider.weeklyInstallmentAmount,
                              );
                              final double payable = isDaily ? breakdown.dailyPayable : breakdown.weeklyPayable;
                              final String freq = isDaily ? 'Day' : 'Week';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Loan Amount (incl. interest)', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                            const SizedBox(height: 2),
                                            Text('₹ ${breakdown.loanAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A))),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('Payable Amount', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDaily ? Colors.blue.shade100 : Colors.purple.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '₹ ${payable.toStringAsFixed(0)} / $freq',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDaily ? Colors.blue.shade900 : Colors.purple.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Actual Principal: ₹ ${breakdown.actualPrincipal.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                        Text('Interest (${breakdown.interestRate.toStringAsFixed(0)}%): ₹ ${breakdown.interestAmount.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // CUSTOMER ID & ACCOUNT NUMBER (Read Only)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 500) {
                              return Row(
                                children: [
                                  Expanded(child: _buildCustomerIdField()),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildAccountNumberField()),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _buildCustomerIdField(),
                                const SizedBox(height: 14),
                                _buildAccountNumberField(),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // LOANEE NAME (Read Only)
                        _buildLabel('LOANEE NAME (AUTO-LOADED) *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _loaneeNameController,
                          readOnly: true,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Select Loanee Account above',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            prefixIcon: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF1E1E1E)),
                            suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please select a Loanee Account above';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // LOANEE ADDRESS (Read Only)
                        _buildLabel('LOANEE ADDRESS (AUTO-LOADED) *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressController,
                          readOnly: true,
                          maxLines: 2,
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                          decoration: InputDecoration(
                            hintText: 'Auto-loaded from Loanee profile',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF1E1E1E)),
                            ),
                            suffixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Address required (select loanee account)';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // COLLECTION TYPE & ROUTE (Responsive Layout)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 500) {
                              return Row(
                                children: [
                                  Expanded(child: _buildCollectionTypeDropdown()),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildRouteDropdown(availableRoutes)),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _buildCollectionTypeDropdown(),
                                const SizedBox(height: 14),
                                _buildRouteDropdown(availableRoutes),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // MOBILE NO (Read Only)
                        _buildMobileNoField(),

                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Save Collection Record',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLoaneeSearchModal(
      BuildContext context, List<LoaneeAccount> loaneeAccounts) async {
    final selected = await showModalBottomSheet<LoaneeAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LoaneeSearchBottomSheet(
        allLoanees: loaneeAccounts,
        selectedLoanee: _selectedLoaneeAccount,
      ),
    );

    if (selected != null) {
      _onLoaneeSelected(selected);
    }
  }

  Widget _buildLoaneeAccountDropdown(List<LoaneeAccount> loaneeAccounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('SELECT EXISTING LOANEE ACCOUNT *'),
            if (loaneeAccounts.isNotEmpty)
              Text(
                '${loaneeAccounts.length} Registered',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        loaneeAccounts.isEmpty
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No registered loanee accounts found in table. Please create a Loanee Account first.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              )
            : FormField<LoaneeAccount>(
                validator: (_) {
                  if (_selectedLoaneeAccount == null) {
                    return 'Please select an existing Loanee Account';
                  }
                  return null;
                },
                builder: (formFieldState) {
                  final hasError = formFieldState.hasError;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () async {
                          await _showLoaneeSearchModal(context, loaneeAccounts);
                          formFieldState.didChange(_selectedLoaneeAccount);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedLoaneeAccount != null
                                ? Colors.white
                                : Colors.amber.shade50
                                    .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasError
                                  ? Colors.red.shade700
                                  : (_selectedLoaneeAccount != null
                                      ? Colors.amber.shade700
                                      : Colors.amber.shade400),
                              width: _selectedLoaneeAccount != null ? 1.5 : 1.0,
                            ),
                            boxShadow: _selectedLoaneeAccount != null
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.shade100
                                          .withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: _selectedLoaneeAccount == null
                              ? Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person_search_rounded,
                                        color: Colors.amber.shade900,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Tap to Search & Select Loanee...',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1E1E1E),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Filter by Name, Customer ID, Account No, or Mobile',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.search_rounded,
                                              size: 14,
                                              color: Colors.amber.shade900),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Search',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFF1E1E1E),
                                      child: Text(
                                        _selectedLoaneeAccount!
                                                .loaneeName.isNotEmpty
                                            ? _selectedLoaneeAccount!
                                                .loaneeName[0]
                                                .toUpperCase()
                                            : 'L',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _selectedLoaneeAccount!
                                                      .loaneeName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1E1E1E),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                      color: Colors
                                                          .green.shade300),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        size: 11,
                                                        color: Colors
                                                            .green.shade700),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Selected',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .green.shade800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                      color: Colors
                                                          .grey.shade300),
                                                ),
                                                child: Text(
                                                  'ID: ${_selectedLoaneeAccount!.customerId}',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                      color: Colors
                                                          .amber.shade300),
                                                ),
                                                child: Text(
                                                  'Acc: ${_selectedLoaneeAccount!.accountNumber}',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.amber.shade900,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                      color:
                                                          Colors.blue.shade200),
                                                ),
                                                child: Text(
                                                  'Mob: ${_selectedLoaneeAccount!.mobileNo}',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.blue.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () async {
                                            await _showLoaneeSearchModal(
                                                context, loaneeAccounts);
                                            formFieldState.didChange(
                                                _selectedLoaneeAccount);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color:
                                                      Colors.amber.shade300),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.swap_horiz_rounded,
                                                    size: 13,
                                                    color:
                                                        Colors.amber.shade900),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'Change',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color:
                                                        Colors.amber.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () {
                                            _onLoaneeSelected(null);
                                            formFieldState.didChange(null);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Clear',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
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
                      if (hasError) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            formFieldState.errorText ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ],
    );
  }

  Widget _buildCustomerIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('CUSTOMER ID (AUTO) *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _customerIdController,
          readOnly: true,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Auto-loaded',
            filled: true,
            fillColor: Colors.grey.shade100,
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Customer ID required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAccountNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ACCOUNT NUMBER (AUTO) *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _accountNumberController,
          readOnly: true,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Auto-loaded',
            filled: true,
            fillColor: Colors.grey.shade100,
            prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
            suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Account No required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCollectionTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('TYPE OF COLLECTION *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedCollectionType,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.calendar_month_outlined, size: 20),
          ),
          items: _collectionTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(
                type,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCollectionType = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildRouteDropdown(List<String> availableRoutes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ROUTE *'),
        const SizedBox(height: 6),
        availableRoutes.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No routes in table. Create in Route Management.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : DropdownButtonFormField<String>(
                value: _selectedRoute,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.alt_route_rounded, size: 20),
                ),
                items: availableRoutes.map((route) {
                  return DropdownMenuItem<String>(
                    value: route,
                    child: Text(
                      route,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRoute = val;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select route';
                  }
                  return null;
                },
              ),
      ],
    );
  }



  Widget _buildMobileNoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('MOBILE NO (AUTO) *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _mobileNoController,
          readOnly: true,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Auto-loaded',
            filled: true,
            fillColor: Colors.grey.shade100,
            prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
            suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Mobile required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _LoaneeSearchBottomSheet extends StatefulWidget {
  final List<LoaneeAccount> allLoanees;
  final LoaneeAccount? selectedLoanee;

  const _LoaneeSearchBottomSheet({
    required this.allLoanees,
    this.selectedLoanee,
  });

  @override
  State<_LoaneeSearchBottomSheet> createState() =>
      _LoaneeSearchBottomSheetState();
}

class _LoaneeSearchBottomSheetState extends State<_LoaneeSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final query = _searchQuery.trim().toLowerCase();

    final filtered = widget.allLoanees.where((l) {
      if (query.isEmpty) return true;
      return l.loaneeName.toLowerCase().contains(query) ||
          l.customerId.toLowerCase().contains(query) ||
          l.accountNumber.toLowerCase().contains(query) ||
          l.mobileNo.contains(query) ||
          l.address.toLowerCase().contains(query) ||
          l.district.toLowerCase().contains(query);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_search_rounded,
                        color: Colors.amber.shade900, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Loanee Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        'Search by Name, Cust ID, Acc No, or Mobile',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Real-time Search Input
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type Name, Customer ID, Acc No, Mobile...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.amber.shade900, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.amber.shade700, width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),

          const SizedBox(height: 10),

          // Filter Count Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filtered.length} of ${widget.allLoanees.length} Loanees',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              if (_searchQuery.isNotEmpty)
                Text(
                  'Filtered by: "$_searchQuery"',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),

          const Divider(height: 16),

          // Results List
          Flexible(
            child: filtered.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          'No matching loanees found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching with a different Customer ID, Account Number, or Name.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      final isSelected = widget.selectedLoanee != null &&
                          (widget.selectedLoanee!.customerId ==
                                  item.customerId ||
                              widget.selectedLoanee!.accountNumber ==
                                  item.accountNumber);

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context, item);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.amber.shade50.withValues(alpha: 0.7)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: Colors.amber.shade400, width: 1.2)
                                : null,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isSelected
                                    ? Colors.amber.shade800
                                    : const Color(0xFF1E1E1E),
                                child: Text(
                                  item.loaneeName.isNotEmpty
                                      ? item.loaneeName[0].toUpperCase()
                                      : 'L',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.loaneeName,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E1E1E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                          ),
                                          child: Text(
                                            'ID: ${item.customerId}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: Colors.amber.shade300),
                                          ),
                                          child: Text(
                                            'Acc: ${item.accountNumber}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.phone,
                                                  size: 9,
                                                  color: Colors.blue.shade800),
                                              const SizedBox(width: 2),
                                              Text(
                                                item.mobileNo,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.address.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        item.address,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white),
                                )
                              else
                                Icon(Icons.chevron_right_rounded,
                                    size: 20, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
