// lib/widgets/edit_ro_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ro_model.dart';
import '../providers/ro_provider.dart';
import '../providers/collection_sheet_provider.dart';

class EditRoDialog extends StatefulWidget {
  final RoAccount ro;

  const EditRoDialog({super.key, required this.ro});

  static Future<bool?> show(BuildContext context, RoAccount ro) async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditRoDialog(ro: ro),
    );
  }

  @override
  State<EditRoDialog> createState() => _EditRoDialogState();
}

class _EditRoDialogState extends State<EditRoDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _guardianController;
  late TextEditingController _mobileController;
  late TextEditingController _aadharController;
  late TextEditingController _addressController;
  late TextEditingController _poController;
  late TextEditingController _psController;
  late TextEditingController _pinController;
  late TextEditingController _designationController;
  late String _selectedDistrict;
  late String _selectedRoute;
  late String _selectedStatus;

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

  final List<String> _statuses = [
    'Active',
    'Inactive',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.ro;

    _nameController = TextEditingController(text: r.roname);
    _guardianController = TextEditingController(text: r.guardianname);
    _mobileController = TextEditingController(text: r.mobileno);
    _aadharController = TextEditingController(text: r.aadharno);
    _addressController = TextEditingController(text: r.address);
    _poController = TextEditingController(text: r.postoffice);
    _psController = TextEditingController(text: r.policestation);
    _pinController = TextEditingController(text: r.pincode);
    _designationController = TextEditingController(text: r.designation.isNotEmpty ? r.designation : 'RO Officer');

    _selectedDistrict = _districts.contains(r.district) ? r.district : _districts.first;
    _selectedStatus = _statuses.contains(r.status) ? r.status : 'Active';
    _selectedRoute = r.route.isNotEmpty ? r.route : 'Office';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _guardianController.dispose();
    _mobileController.dispose();
    _aadharController.dispose();
    _addressController.dispose();
    _poController.dispose();
    _psController.dispose();
    _pinController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the validation errors in the form.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedRo = widget.ro.copyWith(
      roname: _nameController.text.trim(),
      guardianname: _guardianController.text.trim(),
      mobileno: _mobileController.text.trim(),
      aadharno: _aadharController.text.trim(),
      address: _addressController.text.trim(),
      postoffice: _poController.text.trim(),
      policestation: _psController.text.trim(),
      district: _selectedDistrict,
      pincode: _pinController.text.trim(),
      designation: _designationController.text.trim(),
      route: _selectedRoute,
      status: _selectedStatus,
    );

    final provider = Provider.of<RoProvider>(context, listen: false);
    final success = await provider.updateRo(updatedRo);

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
                Expanded(child: Text('RO ${updatedRo.roName} updated successfully')),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save updated RO to database.'),
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
                  colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
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
                    backgroundColor: Colors.amber.shade700,
                    child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit RO Account (Admin)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Cust ID: ${widget.ro.customerId} • Acc: ${widget.ro.accountNumber}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
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
                        controller: _nameController,
                        label: 'RO Officer Full Name *',
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _designationController,
                              label: 'Designation / Post *',
                              icon: Icons.badge_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Designation required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: routeList.contains(_selectedRoute) ? _selectedRoute : routeList.first,
                              decoration: InputDecoration(
                                labelText: 'Assigned Route Zone *',
                                prefixIcon: const Icon(Icons.alt_route_rounded, color: Colors.amber, size: 20),
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
                                prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.blueGrey, size: 20),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'RO Account Status (Login Access) *',
                          prefixIcon: const Icon(Icons.verified_user_outlined, color: Colors.green, size: 20),
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
                      backgroundColor: Colors.amber.shade800,
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
        prefixIcon: Icon(icon, color: Colors.grey.shade800, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
