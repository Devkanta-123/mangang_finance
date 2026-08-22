// lib/screens/transaction_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ro_provider.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/settings_provider.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final _formKey = GlobalKey<FormState>();

  RoCollectionEntry? _selectedCard;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _lateFineController = TextEditingController(text: '0.00');
  final TextEditingController _passcodeController = TextEditingController();
  String _selectedPaymentMode = 'Cash';
  String _selectedRouteFilter = 'All Routes';
  bool _isSubmitting = false;
  String _lateFineFormulaText = '';

  final List<String> _paymentModes = [
    'Cash',
    'Paytm',
    'Gpay',
    'Phonepay',
    'Other',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _lateFineController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _recordPaymentEntry(CollectionSheetProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a collection card account!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roProvider = Provider.of<RoProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final isAdmin = authProvider.activeRole == UserType.admin ||
        currentUser?.userType == UserType.admin;
    final isOfficeRoute = CollectionSheetProvider.isOfficeRoute(_selectedCard!.route);

    // RULE: Master Route "Office" is restricted to Administrator only!
    if (isOfficeRoute && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Access Restricted: "${_selectedCard!.route}" is a Master Route. Only Administrator can record payment entries for Office accounts.'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final passCode = _passcodeController.text.trim();
    if (passCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdmin ? 'Admin Security PIN must be exactly 6 digits!' : 'RO Passcode must be exactly 6 digits!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final roAcc = !isAdmin
        ? roProvider.getRoForUser(
            customerId: currentUser?.customerId,
            mobileNo: currentUser?.mobileNo,
            name: currentUser?.name,
          )
        : null;

    final roName = isAdmin
        ? (currentUser?.name.isNotEmpty == true ? currentUser!.name : 'Administrator')
        : (currentUser?.name ?? (roAcc?.roName ?? 'RO Officer'));
    final roId = isAdmin
        ? (currentUser?.customerId ?? 'ADM-01')
        : (currentUser?.customerId ?? (roAcc?.customerId ?? ''));
    final roRoute = isAdmin ? 'Office' : (roAcc?.route ?? '');
    final cardRoute = _selectedCard!.route;
    final isCrossRoute = !isAdmin &&
        roRoute.isNotEmpty &&
        cardRoute.isNotEmpty &&
        roRoute.toLowerCase().trim() != cardRoute.toLowerCase().trim();

    final remarks = isAdmin
        ? (isOfficeRoute
            ? 'Office Master Entry: Recorded directly by Administrator ($roName)'
            : 'Admin Entry: Direct Office Collection by Administrator ($roName) for $cardRoute')
        : (isCrossRoute
            ? 'Cross-Route Entry: Collected by $roName (Assigned to $roRoute) for $cardRoute'
            : null);

    final paymentAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final lateFine = double.tryParse(_lateFineController.text.trim()) ?? 0.0;
    final currentBal = provider.getLatestRemainingBalance(_selectedCard!.id);
    final newRemainingBalance = (currentBal - paymentAmount).clamp(0.0, 999999.0);

    final payment = CollectionPaymentModel(
      id: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
      collectionId: _selectedCard!.id,
      paymentAmount: paymentAmount,
      remainingBalance: newRemainingBalance,
      lateFine: lateFine,
      paymentType: _selectedPaymentMode,
      roPasscode: passCode,
      roName: roName,
      roId: roId,
      roRoute: roRoute,
      remarks: remarks,
    );

    final success = await provider.addCollectionPayment(payment);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        _amountController.clear();
        _passcodeController.clear();
        _lateFineController.text = '0.00';
        _selectedCard = null;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text('Payment entry ₹${paymentAmount.toStringAsFixed(2)} recorded successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save payment record to Supabase.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final collectionProvider = Provider.of<CollectionSheetProvider>(context);
    final role = authProvider.activeRole;
    final currentUser = authProvider.currentUser;

    final routeList = ['All Routes', ...collectionProvider.routeNames];

    // Calculate real-time filtered transactions based on role
    List<CollectionPaymentModel> paymentsList;
    List<RoCollectionEntry> loaneeCards = [];

    if (role == UserType.loanee) {
      loaneeCards = collectionProvider.getEntriesForLoanee(
        currentUser?.mobileNo ?? '',
        currentUser?.name ?? '',
        currentUser?.customerId ?? '',
      );
      paymentsList = collectionProvider.getPaymentsForEntries(
        loaneeCards,
        selectedRoute: _selectedRouteFilter,
      );
    } else {
      paymentsList = collectionProvider.payments.where((p) {
        if (_selectedRouteFilter == 'All' || _selectedRouteFilter == 'All Routes') {
          return true;
        }
        final card = collectionProvider.getCardForPayment(p);
        if (card == null) return false;
        return card.route.toLowerCase().trim() == _selectedRouteFilter.toLowerCase().trim();
      }).toList();
    }

    final double totalPaidAmt = paymentsList.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final double totalLateFineAmt = paymentsList.fold(0.0, (sum, p) => sum + p.lateFine);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Page Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
                        ? 'RO Collection Entry & Transactions'
                        : (role == UserType.loanee
                            ? 'My Payment Transactions Passbook'
                            : 'All Real-Time Transactions Ledger'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role == UserType.loanee
                        ? 'Real-time verified payment receipts & route-wise passbook statement'
                        : 'Real-time database transactions log across all route zones',
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
                  // ROUTE FILTER & DASHBOARD STATS BAR
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.filter_alt_rounded, color: Color(0xFF8B1A1A), size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Filter Route Zone:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: routeList.contains(_selectedRouteFilter)
                                      ? _selectedRouteFilter
                                      : 'All Routes',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B1A1A),
                                  ),
                                  items: routeList.map((r) {
                                    return DropdownMenuItem(
                                      value: r,
                                      child: Text(r),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedRouteFilter = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Stats Summary Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                title: 'Total Paid',
                                value: '₹ ${totalPaidAmt.toStringAsFixed(2)}',
                                icon: Icons.payments_rounded,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatItem(
                                title: 'Late Fine Paid',
                                value: '₹ ${totalLateFineAmt.toStringAsFixed(2)}',
                                icon: Icons.warning_amber_rounded,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatItem(
                                title: 'Txn Count',
                                value: '${paymentsList.length}',
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFF8B1A1A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // FOR RO AND ADMIN ROLES: SHOW QUICK PAYMENT ENTRY FORM
                  if (role == UserType.ro || role == UserType.admin) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: role == UserType.admin ? const Color(0xFF8B1A1A).withValues(alpha: 0.5) : Colors.amber.shade400,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.08),
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
                                Icon(
                                  role == UserType.admin ? Icons.domain_add_rounded : Icons.add_card_rounded,
                                  color: const Color(0xFF8B1A1A),
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  role == UserType.admin
                                      ? 'Record Office / Admin Collection Payment'
                                      : 'Record Field Collection Payment',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B1A1A),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            DropdownButtonFormField<RoCollectionEntry>(
                              value: _selectedCard,
                              decoration: const InputDecoration(
                                labelText: 'SELECT COLLECTION CARD *',
                                prefixIcon: Icon(Icons.credit_card, color: Color(0xFF8B1A1A), size: 18),
                              ),
                              items: collectionProvider.collectionEntries.map((entry) {
                                return DropdownMenuItem(
                                  value: entry,
                                  child: Text(
                                    '${entry.loaneeName} (Cust: ${entry.customerId} • Acc: ${entry.accountNumber})',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCard = val;
                                  if (val != null) {
                                    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                                    final payments = collectionProvider.getPaymentsForCollection(val.id);
                                    final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
                                      entry: val,
                                      payments: payments,
                                    );
                                    _amountController.text = breakdown.totalPayableAmount.toStringAsFixed(2);
                                    _lateFineController.text = breakdown.calculatedLateFine.toStringAsFixed(2);
                                    _lateFineFormulaText = breakdown.explanation;
                                  } else {
                                    _lateFineFormulaText = '';
                                    _lateFineController.text = '0.00';
                                    _amountController.clear();
                                  }
                                });
                              },
                              validator: (val) => val == null ? 'Please select collection card' : null,
                            ),
                            if (_selectedCard != null) ...[
                              Builder(
                                builder: (context) {
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  final roProvider = Provider.of<RoProvider>(context, listen: false);
                                  final currentUser = authProvider.currentUser;
                                  final roAcc = roProvider.getRoForUser(
                                    customerId: currentUser?.customerId,
                                    mobileNo: currentUser?.mobileNo,
                                    name: currentUser?.name,
                                  );
                                  final String roRoute = roAcc?.route ?? '';
                                  final String cardRoute = _selectedCard!.route;
                                  final bool isCross = roRoute.isNotEmpty &&
                                      cardRoute.isNotEmpty &&
                                      roRoute.toLowerCase().trim() != cardRoute.toLowerCase().trim();

                                  if (!isCross) return const SizedBox.shrink();

                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.deepPurple.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.alt_route_rounded, size: 15, color: Colors.deepPurple.shade700),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '⚡ Cross-Route Notice: You ($roRoute) are collecting for Route "$cardRoute". Transaction ledger will acknowledge this.',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'PAYMENT AMOUNT (₹) *',
                                      prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF8B1A1A), size: 18),
                                    ),
                                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _lateFineController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'LATE FINE (₹)',
                                          prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                        ),
                                      ),
                                      if (_lateFineFormulaText.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          _lateFineFormulaText,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ],
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
                                      labelText: 'PAYMENT TYPE',
                                      prefixIcon: Icon(Icons.payment, color: Color(0xFF8B1A1A), size: 18),
                                    ),
                                    items: _paymentModes
                                        .map((mode) => DropdownMenuItem(
                                              value: mode,
                                              child: Text(mode, style: const TextStyle(fontSize: 13)),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _passcodeController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: role == UserType.admin ? 'ADMIN PIN (6 Digits) *' : 'RO PASSCODE (6 Digits) *',
                                      counterText: '',
                                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF8B1A1A), size: 18),
                                    ),
                                    validator: (val) => (val == null || val.trim().length != 6) ? 'Enter 6 digits' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B1A1A),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _isSubmitting ? null : () => _recordPaymentEntry(collectionProvider),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_outline, color: Colors.white),
                                label: Text(
                                  _isSubmitting ? 'Saving Entry...' : 'Submit Collection Payment',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // TRANSACTION LIST TITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        role == UserType.loanee
                            ? 'My Verified Passbook Statement'
                            : 'Real-Time Transaction Ledger',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B1A1A),
                        ),
                      ),
                      Text(
                        '${paymentsList.length} Transactions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // REAL-TIME TRANSACTIONS LIST
                  if (paymentsList.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No Payments Recorded Yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role == UserType.loanee
                                ? 'No payment entries found for your account under the selected route.'
                                : 'No payment transaction entries present in Supabase ro_collection_payments.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paymentsList.length,
                      itemBuilder: (context, index) {
                        final p = paymentsList[index];
                        final card = collectionProvider.getCardForPayment(p);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.green.shade50,
                                    child: Icon(
                                      Icons.arrow_downward_rounded,
                                      color: Colors.green.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card?.loaneeName ?? 'Collection Card #${p.collectionId}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Acc: ${card?.accountNumber ?? 'N/A'} • Cust: ${card?.customerId ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${p.createdAt.toString().split('.')[0]} • Mode: ${p.paymentType}',
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
                                        '₹ ${p.paymentAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.green,
                                        ),
                                      ),
                                      if (p.lateFine > 0)
                                        Text(
                                          'Fine: ₹${p.lateFine.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Text(
                                          card?.route ?? 'Route',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Remaining Bal: ₹ ${p.remainingBalance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                      if (p.lateFine > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Late Fine: ₹ ${p.lateFine.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (p.roName != null && p.roName!.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: p.isAdminOrOfficeEntry
                                                ? const Color(0xFF8B1A1A).withValues(alpha: 0.1)
                                                : Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: p.isAdminOrOfficeEntry
                                                  ? const Color(0xFF8B1A1A).withValues(alpha: 0.3)
                                                  : Colors.amber.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (p.isAdminOrOfficeEntry) ...[
                                                const Icon(Icons.shield_rounded, size: 10, color: Color(0xFF8B1A1A)),
                                                const SizedBox(width: 3),
                                              ],
                                              Text(
                                                p.isAdminOrOfficeEntry ? 'Admin: ${p.roName} (Office)' : 'RO: ${p.roName}',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: p.isAdminOrOfficeEntry ? const Color(0xFF8B1A1A) : Colors.amber.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        'Status: ${p.status}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (p.roRoute != null &&
                                  p.roRoute!.isNotEmpty &&
                                  (card?.route ?? '').isNotEmpty &&
                                  p.roRoute!.toLowerCase().trim() !=
                                      (card?.route ?? '').toLowerCase().trim()) ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.deepPurple.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.alt_route_rounded,
                                          size: 14,
                                          color: Colors.deepPurple.shade700),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '⚡ Cross-Route Acknowledgment: Collected by ${p.roName ?? 'RO'} (Assigned Route: "${p.roRoute}") for Entry Route ("${card?.route}")',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}