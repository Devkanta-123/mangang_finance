// lib/screens/add_loanee_collection_sheet_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';

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
  late TextEditingController _collectedAmountController;
  late TextEditingController _mobileNoController;

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
    _collectedAmountController = TextEditingController();
    _mobileNoController = TextEditingController();

    // Auto generate initial Customer ID and Account Number after frame render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CollectionSheetProvider>(context, listen: false);
      _customerIdController.text = provider.generateNextCustomerId();
      _accountNumberController.text = provider.generateNextAccountNumber();
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
    _collectedAmountController.dispose();
    _mobileNoController.dispose();
    super.dispose();
  }

  void _generateNewIds() {
    final provider = Provider.of<CollectionSheetProvider>(context, listen: false);
    setState(() {
      _customerIdController.text = provider.generateNextCustomerId();
      _accountNumberController.text = provider.generateNextAccountNumber();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final collectionProvider = Provider.of<CollectionSheetProvider>(context, listen: false);
    final availableRoutes = collectionProvider.routeNames;

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

    final entry = RoCollectionEntry(
      id: 'COL-${DateTime.now().millisecondsSinceEpoch}',
      customerId: _customerIdController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      loaneeName: _loaneeNameController.text.trim(),
      loaneeAddress: _addressController.text.trim(),
      collectionType: _selectedCollectionType,
      collectedAmount: double.tryParse(_collectedAmountController.text.trim()) ?? 0.0,
      route: _selectedRoute!,
      mobileNo: _mobileNoController.text.trim(),
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
              'Collection Recorded!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Successfully added entry for ${entry.loaneeName} on ${entry.route} Route.',
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
                  _buildReceiptRow('Collected Amount', '₹ ${entry.collectedAmount.toStringAsFixed(2)}'),
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
            child: const Text('View Collection View'),
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
    _loaneeNameController.clear();
    _addressController.clear();
    _collectedAmountController.clear();
    _mobileNoController.clear();
    _generateNewIds();
    setState(() {
      _selectedCollectionType = 'Daily';
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final availableRoutes = collectionProvider.routeNames;

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
                            'Loanee Collection Sheet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _generateNewIds,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Auto ID',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Record loanee payment collection entry by route and type',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
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
                              'Collection Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // CUSTOMER ID & ACCOUNT NUMBER (Responsive Layout)
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

                        // LOANEE NAME
                        _buildLabel('LOANEE NAME *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _loaneeNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Enter full loanee name',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter loanee name';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // LOANEE ADDRESS
                        _buildLabel('LOANEE ADDRESS *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Enter locality, street, house no, district',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Icon(Icons.location_on_outlined, size: 20),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter loanee address';
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

                        // COLLECTED AMOUNT & MOBILE NO (Responsive Layout)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 500) {
                              return Row(
                                children: [
                                  Expanded(child: _buildCollectedAmountField()),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildMobileNoField()),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _buildCollectedAmountField(),
                                const SizedBox(height: 14),
                                _buildMobileNoField(),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // Quick Amount Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [100, 200, 500, 1000, 2000, 5000].map((amt) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ActionChip(
                                  label: Text('₹ $amt'),
                                  backgroundColor: Colors.grey.shade100,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                  onPressed: () {
                                    _collectedAmountController.text =
                                        amt.toDouble().toStringAsFixed(0);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),

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

  Widget _buildCustomerIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('CUSTOMER ID *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _customerIdController,
          decoration: const InputDecoration(
            hintText: 'e.g. CUST-1001',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
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
        _buildLabel('ACCOUNT NUMBER *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _accountNumberController,
          decoration: const InputDecoration(
            hintText: 'e.g. ACC-88239101',
            prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
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

  Widget _buildCollectedAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('COLLECTED AMOUNT (₹) *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _collectedAmountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            hintText: '0.00',
            prefixIcon: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Amount required';
            }
            final amt = double.tryParse(value);
            if (amt == null || amt <= 0) {
              return 'Enter valid amount';
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
        _buildLabel('MOBILE NO *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _mobileNoController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: const InputDecoration(
            counterText: '',
            hintText: '10-digit mobile',
            prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Mobile required';
            }
            if (value.trim().length != 10) {
              return 'Must be 10 digits';
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
