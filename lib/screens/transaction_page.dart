// lib/screens/transaction_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _custIdController = TextEditingController(text: 'CUST-1001');
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  String _selectedPaymentMode = 'Cash';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _sampleTransactions = [
    {
      'id': 'TXN-9021',
      'loaneeName': 'Nongthombam Ibomcha',
      'custId': 'CUST-1001',
      'amount': '₹ 4,500',
      'type': 'Collection',
      'mode': 'Cash (RO Collected)',
      'date': '04 Aug 2026, 10:15 AM',
      'status': 'Verified',
    },
    {
      'id': 'TXN-9020',
      'loaneeName': 'Thokchom Sanatombi Devi',
      'custId': 'CUST-1002',
      'amount': '₹ 3,000',
      'type': 'Collection',
      'mode': 'UPI Direct',
      'date': '03 Aug 2026, 04:30 PM',
      'status': 'Verified',
    },
    {
      'id': 'TXN-9019',
      'loaneeName': 'Yumnam Ranbir Singh',
      'custId': 'CUST-1003',
      'amount': '₹ 5,000',
      'type': 'Collection',
      'mode': 'Cash (RO Collected)',
      'date': '02 Aug 2026, 11:45 AM',
      'status': 'Verified',
    },
  ];

  @override
  void dispose() {
    _custIdController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _recordPaymentEntry() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final newTxn = {
        'id': 'TXN-${9022 + _sampleTransactions.length}',
        'loaneeName': 'Customer ${_custIdController.text.trim()}',
        'custId': _custIdController.text.trim(),
        'amount': '₹ ${_amountController.text.trim()}',
        'type': 'Collection',
        'mode': '$_selectedPaymentMode (RO Entry)',
        'date': 'Today, ${TimeOfDay.now().format(context)}',
        'status': 'Recorded',
      };

      setState(() {
        _sampleTransactions.insert(0, newTxn);
        _isSubmitting = false;
        _amountController.clear();
        _remarksController.clear();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('Payment Entry recorded for ${newTxn['custId']}!'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.activeRole;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Page Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role == UserType.ro
                        ? 'RO Payment Collection Entry'
                        : (role == UserType.loanee
                            ? 'My Payment Transactions (Read-Only)'
                            : 'All Transactions & Collection Records'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role == UserType.loanee
                        ? 'View-only passbook statement and verified payment history'
                        : (role == UserType.ro
                            ? 'Record field cash/UPI collection from loanees'
                            : 'Complete audit log of all system payments'),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FOR RO: SHOW PAYMENT ENTRY FORM ONLY
                  if (role == UserType.ro) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade400, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.add_card_rounded,
                                    color: Colors.amber.shade900, size: 22),
                                const SizedBox(width: 8),
                                const Text(
                                  'Record Field Collection Payment',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B1A1A),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _custIdController,
                                    decoration: InputDecoration(
                                      labelText: 'CUSTOMER ID *',
                                      prefixIcon: const Icon(Icons.badge,
                                          color: Color(0xFF8B1A1A), size: 18),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'COLLECTED AMOUNT (₹) *',
                                      prefixIcon: const Icon(
                                          Icons.currency_rupee,
                                          color: Color(0xFF8B1A1A),
                                          size: 18),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Enter amount';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedPaymentMode,
                                    decoration: const InputDecoration(
                                      labelText: 'PAYMENT MODE',
                                      prefixIcon: Icon(Icons.payment,
                                          color: Color(0xFF8B1A1A), size: 18),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                    ),
                                    items: ['Cash', 'UPI App', 'Cheque']
                                        .map((mode) => DropdownMenuItem(
                                              value: mode,
                                              child: Text(mode,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedPaymentMode = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B1A1A),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed:
                                  _isSubmitting ? null : _recordPaymentEntry,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.check_circle_outline,
                                      color: Colors.white),
                              label: Text(
                                _isSubmitting
                                    ? 'Saving Entry...'
                                    : 'Submit Collection Entry',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // FOR LOANEE: SHOW READ-ONLY NOTICE
                  if (role == UserType.loanee) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.blue.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'READ-ONLY VIEW: Loanees can view verified payment receipts & passbook ledger details only.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // TRANSACTION LIST (READ ONLY FOR LOANEE & ADMIN VIEW)
                  Text(
                    role == UserType.loanee
                        ? 'My Payment History Ledger'
                        : 'Recent Collection Logs',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sampleTransactions.length,
                    itemBuilder: (context, index) {
                      final txn = _sampleTransactions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.green.shade50,
                              child: Icon(Icons.arrow_downward_rounded,
                                  color: Colors.green.shade700, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    txn['loaneeName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${txn['id']} • ${txn['mode']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    txn['date'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  txn['amount'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    txn['status'],
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}