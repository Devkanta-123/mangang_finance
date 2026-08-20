// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/investment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _investmentFormKey = GlobalKey<FormState>();

  late TextEditingController _dailyFineController;
  late TextEditingController _weeklyFineController;
  late TextEditingController _weeklyInstallmentController;
  late TextEditingController _weeklyTenureController;

  // Investment settings controllers (Single Source of Truth: system_settings)
  late TextEditingController _investmentBaseAmountController;
  late TextEditingController _investmentInterestAmountController;
  late TextEditingController _investmentInterestRateController;
  late TextEditingController _simulatedAmountController;

  bool _isSaving = false;
  bool _isSavingInvestment = false;
  bool _initialized = false;

  double _previewDailyFine = 3.0;
  double _previewWeeklyFine = 25.0;
  double _previewWeeklyInstallment = 650.0;
  double _previewWeeklyTenure = 17.5;

  double _previewInvestmentBase = 10000.0;
  double _previewInvestmentInterest = 1500.0;
  double _previewInvestmentRate = 15.0;
  double _simulatedAmount = 10000.0;

  @override
  void initState() {
    super.initState();
    _dailyFineController = TextEditingController();
    _weeklyFineController = TextEditingController();
    _weeklyInstallmentController = TextEditingController();
    _weeklyTenureController = TextEditingController();

    _investmentBaseAmountController = TextEditingController();
    _investmentInterestAmountController = TextEditingController();
    _investmentInterestRateController = TextEditingController();
    _simulatedAmountController = TextEditingController(text: '10000');

    _dailyFineController.addListener(() {
      final val = double.tryParse(_dailyFineController.text.trim()) ?? 0.0;
      if (val >= 0 && mounted) {
        setState(() {
          _previewDailyFine = val;
        });
      }
    });

    _weeklyFineController.addListener(() {
      final val = double.tryParse(_weeklyFineController.text.trim()) ?? 0.0;
      if (val >= 0 && mounted) {
        setState(() {
          _previewWeeklyFine = val;
        });
      }
    });

    _weeklyInstallmentController.addListener(() {
      final val = double.tryParse(_weeklyInstallmentController.text.trim()) ?? 0.0;
      if (val >= 0 && mounted) {
        setState(() {
          _previewWeeklyInstallment = val;
        });
      }
    });

    _weeklyTenureController.addListener(() {
      final val = double.tryParse(_weeklyTenureController.text.trim()) ?? 0.0;
      if (val >= 0 && mounted) {
        setState(() {
          _previewWeeklyTenure = val;
        });
      }
    });

    _investmentBaseAmountController.addListener(() {
      final base = double.tryParse(_investmentBaseAmountController.text.trim()) ?? 10000.0;
      final rate = double.tryParse(_investmentInterestRateController.text.trim()) ?? 15.0;
      final interest = base * (rate / 100.0);
      if (mounted) {
        setState(() {
          _previewInvestmentBase = base;
          _previewInvestmentInterest = interest;
        });
      }
    });

    _investmentInterestRateController.addListener(() {
      final rate = double.tryParse(_investmentInterestRateController.text.trim()) ?? 15.0;
      final base = double.tryParse(_investmentBaseAmountController.text.trim()) ?? 10000.0;
      final interest = base * (rate / 100.0);
      if (mounted) {
        setState(() {
          _previewInvestmentRate = rate;
          _previewInvestmentInterest = interest;
        });
      }
    });

    _simulatedAmountController.addListener(() {
      final val = double.tryParse(_simulatedAmountController.text.trim()) ?? 0.0;
      if (mounted) {
        setState(() {
          _simulatedAmount = val;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final settings = Provider.of<SettingsProvider>(context);
      _dailyFineController.text = settings.dailyLateFine.toStringAsFixed(2);
      _weeklyFineController.text = settings.weeklyLateFine.toStringAsFixed(2);
      _weeklyInstallmentController.text = settings.weeklyInstallmentAmount.toStringAsFixed(2);
      _weeklyTenureController.text = settings.weeklyTenureWeeks.toStringAsFixed(1);

      _investmentBaseAmountController.text = settings.investmentBaseAmount.toStringAsFixed(0);
      _investmentInterestAmountController.text = settings.investmentInterestAmount.toStringAsFixed(0);
      _investmentInterestRateController.text = settings.investmentInterestRate.toStringAsFixed(0);

      _previewDailyFine = settings.dailyLateFine;
      _previewWeeklyFine = settings.weeklyLateFine;
      _previewWeeklyInstallment = settings.weeklyInstallmentAmount;
      _previewWeeklyTenure = settings.weeklyTenureWeeks;

      _previewInvestmentBase = settings.investmentBaseAmount;
      _previewInvestmentInterest = settings.investmentInterestAmount;
      _previewInvestmentRate = settings.investmentInterestRate;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _dailyFineController.dispose();
    _weeklyFineController.dispose();
    _weeklyInstallmentController.dispose();
    _weeklyTenureController.dispose();
    _investmentBaseAmountController.dispose();
    _investmentInterestAmountController.dispose();
    _investmentInterestRateController.dispose();
    _simulatedAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveInvestmentSettings() async {
    if (!_investmentFormKey.currentState!.validate()) {
      return;
    }

    final base = double.tryParse(_investmentBaseAmountController.text.trim());
    final rate = double.tryParse(_investmentInterestRateController.text.trim());

    if (base == null || base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Investment base amount must be greater than 0.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    if (rate == null || rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Interest rate cannot be negative.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    final interest = base * (rate / 100.0);

    setState(() {
      _isSavingInvestment = true;
    });

    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final success = await settingsProvider.saveInvestmentSettings(
      baseAmount: base,
      interestAmount: interest,
      interestRate: rate,
    );

    if (!mounted) return;

    setState(() {
      _isSavingInvestment = false;
      _investmentInterestAmountController.text = interest.toStringAsFixed(0);
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green.shade800,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Investment Settings Saved to system_settings Table',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Rate: $rate% • Base: ₹${base.toStringAsFixed(0)} • Interest: ₹${interest.toStringAsFixed(0)} • Total: ₹${(base + interest).toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save investment settings to system_settings table.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dailyFine = double.tryParse(_dailyFineController.text.trim());
    final weeklyFine = double.tryParse(_weeklyFineController.text.trim());
    final weeklyInstallment = double.tryParse(_weeklyInstallmentController.text.trim());
    final weeklyTenure = double.tryParse(_weeklyTenureController.text.trim());

    if (dailyFine == null || dailyFine < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Daily late fine cannot be negative.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    if (weeklyFine == null || weeklyFine < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Weekly late fine cannot be negative.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    if (weeklyInstallment == null || weeklyInstallment <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Weekly installment must be greater than 0.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    if (weeklyTenure == null || weeklyTenure <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Weekly tenure must be greater than 0.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    final success = await settingsProvider.saveLatePaymentSettings(
      dailyFine: dailyFine,
      weeklyFine: weeklyFine,
      weeklyInstallment: weeklyInstallment,
      weeklyTenure: weeklyTenure,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green.shade800,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Late Payment Settings Saved Successfully',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Daily: ₹${dailyFine.toStringAsFixed(2)}/day • Weekly: ₹${weeklyFine.toStringAsFixed(2)}/wk (₹${weeklyInstallment.toStringAsFixed(0)}/wk for ${weeklyTenure.toStringAsFixed(1)} wks)',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save settings. Please try again.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _confirmResetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFF8B1A1A)),
            SizedBox(width: 8),
            Text('Reset to Defaults?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'This will reset late payment and weekly scheme settings to system defaults:\n• Daily Late Fine: ₹3.00 per day\n• Weekly Late Fine: ₹25.00 per week\n• Weekly Installment: ₹650.00 / week\n• Weekly Tenure: 17.5 weeks\n\nDo you want to proceed?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 36),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.resetToDefaults();
      setState(() {
        _dailyFineController.text = settings.dailyLateFine.toStringAsFixed(2);
        _weeklyFineController.text = settings.weeklyLateFine.toStringAsFixed(2);
        _weeklyInstallmentController.text = settings.weeklyInstallmentAmount.toStringAsFixed(2);
        _weeklyTenureController.text = settings.weeklyTenureWeeks.toStringAsFixed(1);

        _previewDailyFine = settings.dailyLateFine;
        _previewWeeklyFine = settings.weeklyLateFine;
        _previewWeeklyInstallment = settings.weeklyInstallmentAmount;
        _previewWeeklyTenure = settings.weeklyTenureWeeks;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.blueGrey.shade800,
          content: const Text('Settings reset to default values (₹3/day, ₹25/wk, ₹650 for 17.5 wks).'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.activeRole == UserType.admin;
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final double previewTotalWeeklyRepayment = _previewWeeklyInstallment * _previewWeeklyTenure;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System & Penalty Settings',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Configure fine rates and operational defaults permanently',
                          style: TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ADMIN ONLY',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Settings Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Non-admin warning banner
                  if (!isAdmin) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded, color: Colors.orange.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Read-Only Mode: Only Administrator can modify penalty rules and settings.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ==========================================
                  // SECTION 1: INVESTMENT & INTEREST CALCULATION ENGINE
                  // (Single Source of Truth: system_settings table)
                  // ==========================================
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B1A1A).withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B1A1A).withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _investmentFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_rounded,
                                    color: Color(0xFF8B1A1A),
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Investment & Interest Rate Rules',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Text(
                                  'system_settings DB',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Database table "system_settings" is the single source of truth for all investment calculations and plans.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                          const Divider(height: 20),

                          // Business Rule Formula Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                                  const Color(0xFF5E0F0F).withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF8B1A1A).withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.functions_rounded, size: 16, color: Color(0xFF8B1A1A)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Active Business Calculation Rules',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '• Interest = Investment Amount × ${_previewInvestmentRate.toStringAsFixed(0)}%\n• Total = Investment Amount + Interest',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E1E1E),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Editable Settings Row (Base Amount, Interest Rate, Interest Amount)
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _investmentBaseAmountController,
                                  enabled: isAdmin && !_isSavingInvestment,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'BASE AMOUNT (₹) *',
                                    hintText: '10000',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    filled: true,
                                    fillColor: isAdmin ? Colors.white : Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _investmentInterestRateController,
                                  enabled: isAdmin && !_isSavingInvestment,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'RATE % *',
                                    hintText: '15',
                                    suffixText: '%',
                                    isDense: true,
                                    filled: true,
                                    fillColor: isAdmin ? Colors.white : Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _investmentInterestAmountController,
                                  enabled: false,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'INTEREST (₹)',
                                    hintText: '1500',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.green.shade50,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Standard Reference Examples Grid
                          const Text(
                            'Configured Standard Calculation Examples:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                          ),
                          const SizedBox(height: 8),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _buildExampleRow(10000, _previewInvestmentRate),
                                const Divider(height: 1),
                                _buildExampleRow(50000, _previewInvestmentRate),
                                const Divider(height: 1),
                                _buildExampleRow(100000, _previewInvestmentRate),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Interactive Amount Calculator Simulator
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.tune_rounded, size: 15, color: Colors.blue),
                                    SizedBox(width: 6),
                                    Text(
                                      'Live Any-Amount Investment Calculator',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _simulatedAmountController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          labelText: 'ENTER ANY INVESTMENT AMOUNT (₹)',
                                          hintText: 'e.g. 25000',
                                          prefixText: '₹ ',
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final simulatedInterest = _simulatedAmount * (_previewInvestmentRate / 100.0);
                                    final simulatedTotal = _simulatedAmount + simulatedInterest;
                                    final dailyInstallment = simulatedTotal / 100.0;
                                    final weeklyInstallment = simulatedTotal / (_previewWeeklyTenure > 0 ? _previewWeeklyTenure : 17.5);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade100),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            alignment: WrapAlignment.spaceBetween,
                                            runSpacing: 4,
                                            spacing: 8,
                                            children: [
                                              Text('Investment: ₹${_simulatedAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                              Text('+ Interest (${_previewInvestmentRate.toStringAsFixed(0)}%): ₹${simulatedInterest.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                              Text('Total: ₹${simulatedTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A))),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          const Divider(height: 1),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            alignment: WrapAlignment.spaceBetween,
                                            runSpacing: 4,
                                            spacing: 8,
                                            children: [
                                              Text('• Daily Plan (100 days): ₹${dailyInstallment.toStringAsFixed(2)} / day', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800)),
                                              Text('• Weekly Plan (${_previewWeeklyTenure.toStringAsFixed(1)} wks): ₹${weeklyInstallment.toStringAsFixed(2)} / wk', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800)),
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

                          const SizedBox(height: 16),

                          if (isAdmin) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B1A1A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isSavingInvestment ? null : _saveInvestmentSettings,
                              icon: _isSavingInvestment
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.cloud_upload_rounded, size: 18),
                              label: Text(
                                _isSavingInvestment ? 'Saving to system_settings...' : 'Save Investment Settings to Database',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // SECTION: LATE PAYMENT SETTINGS
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    color: Color(0xFF8B1A1A),
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Late Payment Settings',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8B1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  'CALCULATION ENGINE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure penalty fine rates and collection schemes for daily & weekly repayment schedules.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                          const Divider(height: 24),

                          // FIELD 1: DAILY LATE FINE
                          _buildFieldHeader(
                            title: '1. Daily Late Fine',
                            badgeText: 'Default: ₹3 / day',
                            badgeColor: Colors.blue.shade100,
                            badgeTextColor: Colors.blue.shade900,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Applied to daily collection accounts when an installment date is missed.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _dailyFineController,
                            enabled: isAdmin && !_isSaving,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                            decoration: InputDecoration(
                              labelText: 'DAILY LATE FINE AMOUNT (₹) *',
                              hintText: '3.00',
                              prefixIcon: const Icon(Icons.today_rounded, color: Color(0xFF8B1A1A), size: 20),
                              prefixText: '₹ ',
                              prefixStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
                              ),
                              suffixText: 'per day',
                              suffixStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              filled: true,
                              fillColor: isAdmin ? Colors.white : Colors.grey.shade100,
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
                                borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter daily late fine';
                              }
                              final amt = double.tryParse(val.trim());
                              if (amt == null) {
                                return 'Please enter a valid numeric amount';
                              }
                              if (amt < 0) {
                                return 'Fine amount cannot be negative';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),
                          // Daily calculation explanation note & preview
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calculate_rounded, size: 14, color: Colors.blue.shade800),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Daily Formula: Daily Late Fine (₹${_previewDailyFine.toStringAsFixed(2)}) × number of late days\n• 1 day late = ₹${(1 * _previewDailyFine).toStringAsFixed(2)} | 2 days = ₹${(2 * _previewDailyFine).toStringAsFixed(2)} | 5 days = ₹${(5 * _previewDailyFine).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // FIELD 2: WEEKLY LATE FINE & WEEKLY COLLECTION SCHEME
                          _buildFieldHeader(
                            title: '2. Weekly Late Fine & Scheme Engine',
                            badgeText: '₹650/wk • 17.5 wks',
                            badgeColor: Colors.amber.shade100,
                            badgeTextColor: Colors.amber.shade900,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Weekly collection scheme (Mon, Tue, Wed, Thur, Fri, Sat) calculates overdue weeks based on ₹650/week installments over 17.5 weeks tenure.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),

                          // Weekly Late Fine Field
                          TextFormField(
                            controller: _weeklyFineController,
                            enabled: isAdmin && !_isSaving,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                            decoration: InputDecoration(
                              labelText: 'WEEKLY LATE FINE (₹ PER WEEK) *',
                              hintText: '25.00',
                              prefixIcon: const Icon(Icons.date_range_rounded, color: Color(0xFF8B1A1A), size: 20),
                              prefixText: '₹ ',
                              prefixStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
                              ),
                              suffixText: 'per week',
                              suffixStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              filled: true,
                              fillColor: isAdmin ? Colors.white : Colors.grey.shade100,
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
                                borderSide: const BorderSide(color: Color(0xFF8B1A1A), width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter weekly late fine';
                              }
                              final amt = double.tryParse(val.trim());
                              if (amt == null) {
                                return 'Please enter a valid numeric amount';
                              }
                              if (amt < 0) {
                                return 'Fine amount cannot be negative';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Row for Weekly Installment & Tenure Configuration
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _weeklyInstallmentController,
                                  enabled: isAdmin && !_isSaving,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'WEEKLY INSTALMENT (₹)',
                                    hintText: '650.00',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    filled: true,
                                    fillColor: isAdmin ? Colors.white : Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _weeklyTenureController,
                                  enabled: isAdmin && !_isSaving,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                                  ],
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: 'TENURE (WEEKS)',
                                    hintText: '17.5',
                                    suffixText: 'wks',
                                    isDense: true,
                                    filled: true,
                                    fillColor: isAdmin ? Colors.white : Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Weekly calculation explanation note & preview with 650 / 17.5 weeks details
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet_rounded, size: 15, color: Colors.amber.shade900),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Weekly Scheme: ₹${_previewWeeklyInstallment.toStringAsFixed(0)}/week for ${_previewWeeklyTenure.toStringAsFixed(1)} weeks (Total: ₹${previewTotalWeeklyRepayment.toStringAsFixed(2)})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• Overdue Weeks = Expected Instalments (Elapsed Wks) − Paid Instalments (Total Paid ÷ ₹${_previewWeeklyInstallment.toStringAsFixed(0)})\n• Late Fine = Overdue Weeks × ₹${_previewWeeklyFine.toStringAsFixed(2)}\n• Example: 1 week late = ₹${(1 * _previewWeeklyFine).toStringAsFixed(2)} | 2 weeks late = ₹${(2 * _previewWeeklyFine).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.brown.shade800,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Persistent Storage Status Bar
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storage_rounded, size: 16, color: Color(0xFF8B1A1A)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Permanent Persistent Storage',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E1E1E),
                                        ),
                                      ),
                                      Text(
                                        settingsProvider.lastUpdated != null
                                            ? 'Last updated: ${settingsProvider.lastUpdated.toString().split('.')[0]}'
                                            : 'Default system rates active (₹3/day, ₹25/wk, ₹650 for 17.5 wks)',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons for Admin
                          if (isAdmin) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B1A1A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                              onPressed: _isSaving ? null : _saveSettings,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_rounded, size: 20),
                              label: Text(
                                _isSaving ? 'Saving Settings...' : 'Save Settings',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade800,
                                side: BorderSide(color: Colors.grey.shade400),
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isSaving ? null : _confirmResetToDefaults,
                              icon: const Icon(Icons.restart_alt_rounded, size: 18),
                              label: const Text(
                                'Reset to System Defaults (₹3 / ₹25 / ₹650)',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildFieldHeader({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: badgeTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExampleRow(double amount, double rate) {
    final interest = amount * (rate / 100.0);
    final total = amount + interest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '₹${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
          Text(
            '₹${interest.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} interest',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green.shade800),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
          Text(
            '₹${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} total',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A)),
          ),
        ],
      ),
    );
  }
}
