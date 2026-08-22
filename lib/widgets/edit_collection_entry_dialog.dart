// lib/widgets/edit_collection_entry_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';

class EditCollectionEntryDialog extends StatefulWidget {
  final RoCollectionEntry entry;

  const EditCollectionEntryDialog({super.key, required this.entry});

  static Future<bool?> show(BuildContext context, RoCollectionEntry entry) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditCollectionEntryDialog(entry: entry),
    );
  }

  @override
  State<EditCollectionEntryDialog> createState() => _EditCollectionEntryDialogState();
}

class _EditCollectionEntryDialogState extends State<EditCollectionEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _loaneeNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _customerIdController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _initialBalanceController;

  late String _selectedRoute;
  late String _selectedCollectionType;

  bool _isSaving = false;

  final List<String> _collectionTypes = [
    'Daily',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.entry;

    _loaneeNameController = TextEditingController(text: e.loaneeName);
    _accountNumberController = TextEditingController(text: e.accountNumber);
    _customerIdController = TextEditingController(text: e.customerId);
    _mobileController = TextEditingController(text: e.mobileNo);
    _addressController = TextEditingController(text: e.loaneeAddress);
    _initialBalanceController = TextEditingController(
        text: e.initialBalance > 0 ? e.initialBalance.toStringAsFixed(0) : '');

    _selectedRoute = e.route.isNotEmpty ? e.route : 'Office';
    _selectedCollectionType = _collectionTypes.contains(e.collectionType)
        ? e.collectionType
        : _collectionTypes.first;
  }

  @override
  void dispose() {
    _loaneeNameController.dispose();
    _accountNumberController.dispose();
    _customerIdController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix validation errors before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final initialBal = double.tryParse(_initialBalanceController.text.trim()) ?? widget.entry.initialBalance;

    final updatedEntry = widget.entry.copyWith(
      loaneeName: _loaneeNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      customerId: _customerIdController.text.trim(),
      mobileNo: _mobileController.text.trim(),
      loaneeAddress: _addressController.text.trim(),
      route: _selectedRoute,
      collectionType: _selectedCollectionType,
      initialBalance: initialBal,
    );

    final provider = Provider.of<CollectionSheetProvider>(context, listen: false);
    final success = await provider.updateCollectionEntry(updatedEntry);

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
                Expanded(
                  child: Text(
                    'Collection sheet entry for "${updatedEntry.loaneeName}" updated in Supabase!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update collection entry in Supabase.'),
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
    final collectionProvider = Provider.of<CollectionSheetProvider>(context, listen: false);
    final routeList = collectionProvider.routeNames;
    if (!routeList.contains(_selectedRoute) && _selectedRoute.isNotEmpty) {
      routeList.insert(0, _selectedRoute);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: 650,
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
                    child: const Icon(Icons.edit_document, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Collection Sheet Card (Admin)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Card ID: ${widget.entry.id} • Acc: ${widget.entry.accountNumber}',
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

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _loaneeNameController,
                        label: 'Loanee Full Name *',
                        icon: Icons.person_outline,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _customerIdController,
                              label: 'Customer ID *',
                              icon: Icons.badge_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Customer ID required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _accountNumberController,
                              label: 'Account Number *',
                              icon: Icons.account_balance_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Account number required' : null,
                            ),
                          ),
                        ],
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
                              controller: _initialBalanceController,
                              label: 'Initial Principal / Loan (₹) *',
                              icon: Icons.currency_rupee_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Principal required';
                                final amt = double.tryParse(v.trim());
                                if (amt == null || amt <= 0) return 'Enter valid amount';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Loanee Address *',
                        icon: Icons.location_on_outlined,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Address required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: routeList.contains(_selectedRoute) ? _selectedRoute : routeList.first,
                              decoration: InputDecoration(
                                labelText: 'Route Zone *',
                                prefixIcon: const Icon(Icons.alt_route_rounded, color: Color(0xFF8B1A1A), size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: routeList
                                  .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedRoute = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCollectionType,
                              decoration: InputDecoration(
                                labelText: 'Collection Type / Day *',
                                prefixIcon: const Icon(Icons.calendar_month_outlined, color: Colors.purple, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: _collectionTypes
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCollectionType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
