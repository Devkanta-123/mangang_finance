// lib/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/collection_payment_model.dart';
import '../models/investment_model.dart';
import '../services/supabase_service.dart';

class WeeklyBreakdown {
  final double weeklyInstallment;
  final double tenureWeeks;
  final double totalTenureAmount;
  final double totalPaid;
  final int weeksPaid;
  final int expectedWeeks;
  final int lateWeeks;
  final double lateFineRate;
  final double totalCalculatedFine;

  WeeklyBreakdown({
    required this.weeklyInstallment,
    required this.tenureWeeks,
    required this.totalTenureAmount,
    required this.totalPaid,
    required this.weeksPaid,
    required this.expectedWeeks,
    required this.lateWeeks,
    required this.lateFineRate,
    required this.totalCalculatedFine,
  });
}

/// Comprehensive breakdown for auto-calculated Late Payment Fee and Payable Amount
class CollectionLatePayableBreakdown {
  final double baseInstallment; // e.g. ₹100.00 / day or ₹650.00 / week
  final int lateUnits; // e.g. 2 late days or 1 late week
  final bool isDaily; // true if daily, false if weekly
  final String frequencyLabel; // 'Day' or 'Week'
  final double overdueMissedAmount; // lateUnits * baseInstallment (e.g. 2 * 100 = ₹200.00)
  final double currentInstallment; // today's installment = baseInstallment (e.g. ₹100.00)
  final double totalPayableAmount; // overdueMissedAmount + currentInstallment (e.g. ₹200 + ₹100 = ₹300.00)
  final double lateFineRate; // e.g. ₹3.00/day or ₹25.00/week
  final double calculatedLateFine; // lateUnits * lateFineRate (e.g. 2 * 3 = ₹6.00)
  final double grandTotalWithPenalty; // totalPayableAmount + calculatedLateFine (e.g. ₹306.00)
  final String explanation; // Plain-English rationale
  final String shortSummary; // Short summary for table chips

  CollectionLatePayableBreakdown({
    required this.baseInstallment,
    required this.lateUnits,
    required this.isDaily,
    required this.frequencyLabel,
    required this.overdueMissedAmount,
    required this.currentInstallment,
    required this.totalPayableAmount,
    required this.lateFineRate,
    required this.calculatedLateFine,
    required this.grandTotalWithPenalty,
    required this.explanation,
    required this.shortSummary,
  });

  bool get isOverdue => lateUnits > 0;
}

/// Comprehensive Status Model for Loanee Late Fine and Overdue Assessment
class LoaneeLateFineStatus {
  final String collectionId;
  final String customerId;
  final String accountNumber;
  final String loaneeName;
  final String collectionType; // 'Daily', 'Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat', 'Weekly'
  final bool isDaily;
  final bool hasPaymentsInTable; // True if data exists in ro_collection_payments
  final int paymentRecordsCount;
  final double totalPaidAmount;
  final DateTime? lastPaymentDate;
  final DateTime loanStartDate;
  final int overdueUnits; // Days overdue if daily, Weeks overdue if weekly
  final double lateFineRate; // ₹/day or ₹/week from Admin Settings
  final double calculatedLateFine; // overdueUnits * lateFineRate
  final double overdueEmiAmount; // Unpaid EMI principal
  final double totalOverdueAmount; // overdueEmiAmount + calculatedLateFine
  final String calculationExplanation;
  final WeeklyBreakdown? weeklyBreakdown;
  final CollectionLatePayableBreakdown? latePayableBreakdown;

  LoaneeLateFineStatus({
    required this.collectionId,
    required this.customerId,
    required this.accountNumber,
    required this.loaneeName,
    required this.collectionType,
    required this.isDaily,
    required this.hasPaymentsInTable,
    required this.paymentRecordsCount,
    required this.totalPaidAmount,
    this.lastPaymentDate,
    required this.loanStartDate,
    required this.overdueUnits,
    required this.lateFineRate,
    required this.calculatedLateFine,
    required this.overdueEmiAmount,
    required this.totalOverdueAmount,
    required this.calculationExplanation,
    this.weeklyBreakdown,
    this.latePayableBreakdown,
  });

  bool get isOverdue => overdueUnits > 0 || calculatedLateFine > 0;
}

class SettingsProvider extends ChangeNotifier {
  double _dailyLateFine = 3.0;
  double _weeklyLateFine = 25.0;
  double _weeklyInstallmentAmount = 650.0;
  double _weeklyTenureWeeks = 17.5;

  // Investment Settings (Single Source of Truth: Supabase system_settings table)
  // No localStorage or SharedPreferences used for calculation rules
  InvestmentSettingsModel _investmentSettings = const InvestmentSettingsModel(
    baseAmount: 10000.0,
    interestAmount: 1500.0,
    interestRate: 15.0,
  );

  bool _isLoading = true;
  DateTime? _lastUpdated;

  // SharedPreferences keys for late payment UI cache
  static const String _keyDailyLateFine = 'mangang_daily_late_fine';
  static const String _keyWeeklyLateFine = 'mangang_weekly_late_fine';
  static const String _keyWeeklyInstallment = 'mangang_weekly_installment_amt';
  static const String _keyWeeklyTenure = 'mangang_weekly_tenure_wks';
  static const String _keyLastUpdated = 'mangang_settings_last_updated';

  SettingsProvider() {
    loadSettings();
  }

  double get dailyLateFine => _dailyLateFine;
  double get weeklyLateFine => _weeklyLateFine;
  double get weeklyInstallmentAmount => _weeklyInstallmentAmount;
  double get weeklyTenureWeeks => _weeklyTenureWeeks;
  double get totalWeeklyTenureAmount => _weeklyInstallmentAmount * _weeklyTenureWeeks; // 650 * 17.5 = 11,375

  // Investment Settings Getters (Fetched from system_settings table)
  InvestmentSettingsModel get investmentSettings => _investmentSettings;
  double get investmentBaseAmount => _investmentSettings.baseAmount;
  double get investmentInterestAmount => _investmentSettings.interestAmount;
  double get investmentInterestRate => _investmentSettings.interestRate;

  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  /// Load settings with Supabase 'system_settings' table as single source of truth (Row-wise)
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch live row-wise settings directly from Supabase system_settings table
      try {
        final map = await SupabaseService.instance.fetchAllSystemSettings();

        // Investment Settings (row-wise scalar values)
        double base = 10000.0;
        double interest = 1500.0;
        double rate = 15.0;

        if (map.containsKey('investment_base_amount')) {
          base = double.tryParse(map['investment_base_amount']!) ?? base;
        }
        if (map.containsKey('investment_interest_amount')) {
          interest = double.tryParse(map['investment_interest_amount']!) ?? interest;
        }
        if (map.containsKey('investment_interest_rate')) {
          rate = double.tryParse(map['investment_interest_rate']!) ?? rate;
        }

        _investmentSettings = InvestmentSettingsModel(
          baseAmount: base,
          interestAmount: interest,
          interestRate: rate,
          updatedAt: DateTime.now(),
        );

        // Late Payment & Scheme Settings (row-wise scalar values)
        if (map.containsKey('daily_late_fine')) {
          _dailyLateFine = double.tryParse(map['daily_late_fine']!) ?? _dailyLateFine;
        }
        if (map.containsKey('weekly_late_fine')) {
          _weeklyLateFine = double.tryParse(map['weekly_late_fine']!) ?? _weeklyLateFine;
        }
        if (map.containsKey('weekly_installment_amount')) {
          _weeklyInstallmentAmount = double.tryParse(map['weekly_installment_amount']!) ?? _weeklyInstallmentAmount;
        }
        if (map.containsKey('weekly_tenure_weeks')) {
          _weeklyTenureWeeks = double.tryParse(map['weekly_tenure_weeks']!) ?? _weeklyTenureWeeks;
        }

        if (map.isNotEmpty) {
          _lastUpdated = DateTime.now();
        }
      } catch (e) {
        debugPrint('ℹ️ Note loading system_settings from Supabase: $e');
      }

      final prefs = await SharedPreferences.getInstance();

      // Read from local persistent storage for late fines fallback if offline
      if (prefs.containsKey(_keyDailyLateFine) && _dailyLateFine == 3.0) {
        _dailyLateFine = prefs.getDouble(_keyDailyLateFine) ?? 3.0;
      }
      if (prefs.containsKey(_keyWeeklyLateFine) && _weeklyLateFine == 25.0) {
        _weeklyLateFine = prefs.getDouble(_keyWeeklyLateFine) ?? 25.0;
      }
      if (prefs.containsKey(_keyWeeklyInstallment) && _weeklyInstallmentAmount == 650.0) {
        _weeklyInstallmentAmount = prefs.getDouble(_keyWeeklyInstallment) ?? 650.0;
      }
      if (prefs.containsKey(_keyWeeklyTenure) && _weeklyTenureWeeks == 17.5) {
        _weeklyTenureWeeks = prefs.getDouble(_keyWeeklyTenure) ?? 17.5;
      }
      if (prefs.containsKey(_keyLastUpdated) && _lastUpdated == null) {
        final lastIso = prefs.getString(_keyLastUpdated);
        if (lastIso != null) {
          _lastUpdated = DateTime.tryParse(lastIso);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading SettingsProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save investment settings directly to Supabase 'system_settings' table row-wise (Single Source of Truth)
  Future<bool> saveInvestmentSettings({
    required double baseAmount,
    required double interestAmount,
    required double interestRate,
  }) async {
    if (baseAmount < 0 || interestAmount < 0 || interestRate < 0) {
      throw ArgumentError('Amounts and interest rate cannot be negative.');
    }

    try {
      final success = await SupabaseService.instance.saveInvestmentSettings(
        baseAmount: baseAmount,
        interestAmount: interestAmount,
        interestRate: interestRate,
      );

      _investmentSettings = InvestmentSettingsModel(
        baseAmount: baseAmount,
        interestAmount: interestAmount,
        interestRate: interestRate,
        updatedAt: DateTime.now(),
      );

      _lastUpdated = DateTime.now();
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('⚠️ Error saving investment settings: $e');
      return false;
    }
  }

  double get baseDailyAmount => investmentBaseAmount / 100.0; // ₹10,000 / 100 = ₹100

  /// Calculate principal, interest, and daily/weekly payable amount from entered loan amount (which includes interest)
  /// Formula: principal = loan_amount / (1 + interest_rate / 100)
  /// daily_payable = principal / base_principal * base_daily_amount
  LoanPrincipalBreakdown calculateLoanPrincipalBreakdown(double enteredLoanAmount) {
    return LoanPrincipalBreakdown.calculate(
      loanAmount: enteredLoanAmount,
      interestRate: investmentInterestRate,
      basePrincipal: investmentBaseAmount,
      baseDailyAmount: baseDailyAmount,
      baseWeeklyAmount: weeklyInstallmentAmount,
    );
  }

  /// Calculate investment plan dynamically for ANY amount based on system_settings rate
  /// Business rule: Interest = Investment Amount * 15% (or configured rate); Total = Investment Amount + Interest
  InvestmentCalculationResult calculateInvestmentPlan(double amount) {
    return InvestmentCalculationResult.calculate(
      amount: amount,
      settings: _investmentSettings,
      dailyTenureDays: 100,
      weeklyTenureWeeks: _weeklyTenureWeeks,
    );
  }

  /// Fetch live investment calculation result directly from Supabase system_settings API
  Future<InvestmentCalculationResult> fetchLiveInvestmentCalculation(double amount) async {
    return await SupabaseService.instance.calculateInvestment(amount);
  }

  /// Save late payment settings row-wise in 'system_settings'
  Future<bool> saveLatePaymentSettings({
    required double dailyFine,
    required double weeklyFine,
    double? weeklyInstallment,
    double? weeklyTenure,
  }) async {
    if (dailyFine < 0 || weeklyFine < 0) {
      throw ArgumentError('Fine amounts cannot be negative.');
    }

    final installment = weeklyInstallment ?? _weeklyInstallmentAmount;
    final tenure = weeklyTenure ?? _weeklyTenureWeeks;

    if (installment < 0 || tenure < 0) {
      throw ArgumentError('Installment and tenure cannot be negative.');
    }

    try {
      final now = DateTime.now();

      _dailyLateFine = dailyFine;
      _weeklyLateFine = weeklyFine;
      _weeklyInstallmentAmount = installment;
      _weeklyTenureWeeks = tenure;
      _lastUpdated = now;

      // Save row-wise in Supabase system_settings table
      final success = await SupabaseService.instance.saveLatePaymentSettings(
        dailyFine: dailyFine,
        weeklyFine: weeklyFine,
        weeklyInstallment: installment,
        weeklyTenure: tenure,
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_keyDailyLateFine, dailyFine);
        await prefs.setDouble(_keyWeeklyLateFine, weeklyFine);
        await prefs.setDouble(_keyWeeklyInstallment, installment);
        await prefs.setDouble(_keyWeeklyTenure, tenure);
        await prefs.setString(_keyLastUpdated, now.toIso8601String());
      } catch (_) {}

      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('⚠️ Error saving late payment settings: $e');
      return false;
    }
  }

  /// Comprehensive Weekly Calculation Breakdown (₹650/week for 17.5 weeks)
  WeeklyBreakdown getWeeklyBreakdown({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    DateTime? asOfDate,
  }) {
    final now = asOfDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);

    final double totalPaid = payments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final int weeksPaid = (_weeklyInstallmentAmount > 0)
        ? (totalPaid / _weeklyInstallmentAmount).floor()
        : 0;

    final int daysSinceStart = today.difference(entryDate).inDays;
    final int weeksElapsed = (daysSinceStart ~/ 7);
    final int maxTenureWeeks = _weeklyTenureWeeks.ceil(); // e.g. 18 weeks for 17.5
    final int expectedWeeks = weeksElapsed.clamp(0, maxTenureWeeks);

    final int lateWeeks = (expectedWeeks - weeksPaid).clamp(0, maxTenureWeeks);
    final double calculatedFine = lateWeeks * _weeklyLateFine;

    return WeeklyBreakdown(
      weeklyInstallment: _weeklyInstallmentAmount,
      tenureWeeks: _weeklyTenureWeeks,
      totalTenureAmount: _weeklyInstallmentAmount * _weeklyTenureWeeks,
      totalPaid: totalPaid,
      weeksPaid: weeksPaid,
      expectedWeeks: expectedWeeks,
      lateWeeks: lateWeeks,
      lateFineRate: _weeklyLateFine,
      totalCalculatedFine: calculatedFine,
    );
  }

  /// Calculate late units (days for daily, weeks for weekly based on ₹650/17.5 wks scheme)
  int calculateLateUnits({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    DateTime? asOfDate,
  }) {
    final now = asOfDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final type = entry.collectionType.toLowerCase().trim();
    final isDaily = type == 'daily';

    if (isDaily) {
      DateTime baseDate;
      bool hasPreviousPayment = false;

      if (payments.isNotEmpty) {
        final sortedPayments = List<CollectionPaymentModel>.from(payments)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        baseDate = sortedPayments.first.createdAt;
        hasPreviousPayment = true;
      } else {
        baseDate = entry.createdAt;
      }

      final cleanBaseDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
      final daysDifference = today.difference(cleanBaseDate).inDays;

      if (hasPreviousPayment) {
        return (daysDifference - 1).clamp(0, 365);
      } else {
        return daysDifference.clamp(0, 365);
      }
    } else {
      // Weekly Collection based on ₹650/week for 17.5 weeks tenure
      final breakdown = getWeeklyBreakdown(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
      );
      return breakdown.lateWeeks;
    }
  }

  /// Calculate the recommended late fine amount for an entry
  double calculateLateFineForEntry({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    DateTime? asOfDate,
  }) {
    final type = entry.collectionType.toLowerCase().trim();
    final isDaily = type == 'daily';

    if (isDaily) {
      final int lateDays = calculateLateUnits(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
      );
      return lateDays * _dailyLateFine;
    } else {
      final breakdown = getWeeklyBreakdown(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
      );
      return breakdown.totalCalculatedFine;
    }
  }

  /// Format date helper for human-readable calculation explanations
  static String formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  /// Comprehensive calculation of Late Payment Fee and Payable Amount Breakdown
  /// e.g. Base Payable ₹100, 2 days late -> Missed 2 days (₹200) + Today (₹100) = ₹300 Total Payable (+ Late Fine: 2 * ₹3 = ₹6)
  CollectionLatePayableBreakdown getLatePayableBreakdownForEntry({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    double? loaneeLoanAmount,
    DateTime? asOfDate,
  }) {
    final type = entry.collectionType.toLowerCase().trim();
    final isDaily = type == 'daily';
    final freq = entry.frequencyLabel;

    final double baseInstallment = entry.getCalculatedPayableAmount(
      loaneeLoanAmount: loaneeLoanAmount,
      configuredInterestRate: investmentInterestRate,
      configuredBasePrincipal: investmentBaseAmount,
      configuredBaseDailyAmount: baseDailyAmount,
      configuredWeeklyInstallment: weeklyInstallmentAmount,
    );

    final int lateUnits = calculateLateUnits(
      entry: entry,
      payments: payments,
      asOfDate: asOfDate,
    );

    final double overdueMissedAmount = lateUnits * baseInstallment;
    final double currentInstallment = baseInstallment;
    final double totalPayable = overdueMissedAmount + currentInstallment;

    final double fineRate = isDaily ? _dailyLateFine : _weeklyLateFine;
    final double calculatedFine = lateUnits * fineRate;
    final double grandTotal = totalPayable + calculatedFine;

    final String unitName = isDaily ? (lateUnits == 1 ? 'day' : 'days') : (lateUnits == 1 ? 'week' : 'weeks');

    final String explanation;
    final String shortSummary;

    if (lateUnits > 0) {
      explanation = '$lateUnits $unitName late: $lateUnits missed ${isDaily ? "days" : "weeks"} (₹${overdueMissedAmount.toStringAsFixed(2)}) + ${isDaily ? "Today's" : "This week's"} installment (₹${currentInstallment.toStringAsFixed(2)}) = ₹${totalPayable.toStringAsFixed(2)} Total Due Today. System Late Payment Fee: $lateUnits $unitName × ₹${fineRate.toStringAsFixed(2)}/${isDaily ? "day" : "wk"} = ₹${calculatedFine.toStringAsFixed(2)} penalty.';
      shortSummary = '₹${totalPayable.toStringAsFixed(0)} ($lateUnits $unitName late + today)';
    } else {
      explanation = 'On Time: Scheduled ${isDaily ? "daily" : "weekly"} installment = ₹${currentInstallment.toStringAsFixed(2)}. Late Payment Fee: ₹0.00.';
      shortSummary = '₹${currentInstallment.toStringAsFixed(0)} / $freq';
    }

    return CollectionLatePayableBreakdown(
      baseInstallment: baseInstallment,
      lateUnits: lateUnits,
      isDaily: isDaily,
      frequencyLabel: freq,
      overdueMissedAmount: overdueMissedAmount,
      currentInstallment: currentInstallment,
      totalPayableAmount: totalPayable,
      lateFineRate: fineRate,
      calculatedLateFine: calculatedFine,
      grandTotalWithPenalty: grandTotal,
      explanation: explanation,
      shortSummary: shortSummary,
    );
  }

  /// Get comprehensive late fine & overdue status for an individual collection entry
  LoaneeLateFineStatus getLateFineStatusForEntry({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    double? loaneeLoanAmount,
    DateTime? asOfDate,
  }) {
    final now = asOfDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final type = entry.collectionType.toLowerCase().trim();
    final isDaily = type == 'daily';
    final hasPayments = payments.isNotEmpty;
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.paymentAmount);

    final sortedPayments = List<CollectionPaymentModel>.from(payments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final lastPaymentDate = sortedPayments.isNotEmpty ? sortedPayments.first.createdAt : null;

    final payableBreakdown = getLatePayableBreakdownForEntry(
      entry: entry,
      payments: payments,
      loaneeLoanAmount: loaneeLoanAmount,
      asOfDate: asOfDate,
    );

    if (isDaily) {
      DateTime baseDate;
      int overdueDays = payableBreakdown.lateUnits;

      if (hasPayments && lastPaymentDate != null) {
        baseDate = lastPaymentDate;
        final cleanBaseDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
        final daysDiff = today.difference(cleanBaseDate).inDays;
        overdueDays = (daysDiff - 1).clamp(0, 365);
      } else {
        baseDate = entry.createdAt;
        final cleanBaseDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
        final daysDiff = today.difference(cleanBaseDate).inDays;
        overdueDays = daysDiff.clamp(0, 365);
      }

      final lateFine = overdueDays * _dailyLateFine;
      final String explanation = hasPayments
          ? 'Payment data found in ro_collection_payments (${payments.length} payments, last on ${formatDate(lastPaymentDate!)}). $overdueDays overdue days: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Today\'s ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee: $overdueDays days × ₹${_dailyLateFine.toStringAsFixed(2)}/day = ₹${lateFine.toStringAsFixed(2)} penalty.'
          : 'No payment record found in ro_collection_payments table since account creation on ${formatDate(entry.createdAt)}. $overdueDays overdue days: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Today\'s ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee: $overdueDays days × ₹${_dailyLateFine.toStringAsFixed(2)}/day = ₹${lateFine.toStringAsFixed(2)} penalty.';

      return LoaneeLateFineStatus(
        collectionId: entry.id,
        customerId: entry.customerId,
        accountNumber: entry.accountNumber,
        loaneeName: entry.loaneeName,
        collectionType: entry.collectionType,
        isDaily: true,
        hasPaymentsInTable: hasPayments,
        paymentRecordsCount: payments.length,
        totalPaidAmount: totalPaid,
        lastPaymentDate: lastPaymentDate,
        loanStartDate: entry.createdAt,
        overdueUnits: overdueDays,
        lateFineRate: _dailyLateFine,
        calculatedLateFine: lateFine,
        overdueEmiAmount: payableBreakdown.overdueMissedAmount,
        totalOverdueAmount: payableBreakdown.totalPayableAmount + lateFine,
        calculationExplanation: explanation,
        weeklyBreakdown: null,
        latePayableBreakdown: payableBreakdown,
      );
    } else {
      // Weekly scheme
      final breakdown = getWeeklyBreakdown(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
      );

      final overdueEmi = breakdown.lateWeeks * breakdown.weeklyInstallment;
      final totalOverdue = payableBreakdown.totalPayableAmount + breakdown.totalCalculatedFine;

      final String explanation = hasPayments
          ? 'Payment data found in ro_collection_payments (₹${breakdown.totalPaid.toStringAsFixed(2)} paid across ${payments.length} transactions, covering ${breakdown.weeksPaid}/${breakdown.expectedWeeks} expected weeks). ${breakdown.lateWeeks} overdue weeks: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Current ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee: ${breakdown.lateWeeks} wks × ₹${breakdown.lateFineRate.toStringAsFixed(2)}/wk = ₹${breakdown.totalCalculatedFine.toStringAsFixed(2)} penalty.'
          : 'No payment record found in ro_collection_payments table since account creation on ${formatDate(entry.createdAt)}. ${breakdown.lateWeeks} overdue weeks: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Current ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee: ${breakdown.lateWeeks} wks × ₹${breakdown.lateFineRate.toStringAsFixed(2)}/wk = ₹${breakdown.totalCalculatedFine.toStringAsFixed(2)} penalty.';

      return LoaneeLateFineStatus(
        collectionId: entry.id,
        customerId: entry.customerId,
        accountNumber: entry.accountNumber,
        loaneeName: entry.loaneeName,
        collectionType: entry.collectionType,
        isDaily: false,
        hasPaymentsInTable: hasPayments,
        paymentRecordsCount: payments.length,
        totalPaidAmount: totalPaid,
        lastPaymentDate: lastPaymentDate,
        loanStartDate: entry.createdAt,
        overdueUnits: breakdown.lateWeeks,
        lateFineRate: breakdown.lateFineRate,
        calculatedLateFine: breakdown.totalCalculatedFine,
        overdueEmiAmount: overdueEmi,
        totalOverdueAmount: totalOverdue,
        calculationExplanation: explanation,
        weeklyBreakdown: breakdown,
        latePayableBreakdown: payableBreakdown,
      );
    }
  }

  /// Aggregate late fine assessment across all collection entries for a loanee account
  LoaneeLateFineStatus getAggregateLateFineStatus({
    required List<RoCollectionEntry> entries,
    required List<CollectionPaymentModel> payments,
    String? customerId,
    String? loaneeName,
    String? accountNumber,
    DateTime? fallbackStartDate,
    double fallbackLoanAmount = 0.0,
    DateTime? asOfDate,
  }) {
    if (entries.isEmpty) {
      // Fallback if loanee exists in loanee_accounts table but collection entry is not created yet
      final now = asOfDate ?? DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = fallbackStartDate ?? now;
      final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
      final daysDiff = today.difference(cleanStart).inDays.clamp(0, 365);
      final fine = daysDiff * _dailyLateFine;
      final baseAmt = baseDailyAmount;
      final overdueMissed = daysDiff * baseAmt;
      final totalPayable = overdueMissed + baseAmt;

      final fallbackBreakdown = CollectionLatePayableBreakdown(
        baseInstallment: baseAmt,
        lateUnits: daysDiff,
        isDaily: true,
        frequencyLabel: 'Day',
        overdueMissedAmount: overdueMissed,
        currentInstallment: baseAmt,
        totalPayableAmount: totalPayable,
        lateFineRate: _dailyLateFine,
        calculatedLateFine: fine,
        grandTotalWithPenalty: totalPayable + fine,
        explanation: 'Calculated from registration date ${formatDate(startDate)}: $daysDiff days late × ₹${baseAmt.toStringAsFixed(2)} = ₹${overdueMissed.toStringAsFixed(2)} missed + Today ₹${baseAmt.toStringAsFixed(2)} = ₹${totalPayable.toStringAsFixed(2)} payable. Late fine: $daysDiff days × ₹${_dailyLateFine.toStringAsFixed(2)} = ₹${fine.toStringAsFixed(2)}.',
        shortSummary: '₹${totalPayable.toStringAsFixed(0)} ($daysDiff days late + today)',
      );

      return LoaneeLateFineStatus(
        collectionId: 'PENDING-ENTRY',
        customerId: customerId ?? 'N/A',
        accountNumber: accountNumber ?? 'N/A',
        loaneeName: loaneeName ?? 'Loanee Account',
        collectionType: 'Daily',
        isDaily: true,
        hasPaymentsInTable: false,
        paymentRecordsCount: 0,
        totalPaidAmount: 0.0,
        lastPaymentDate: null,
        loanStartDate: startDate,
        overdueUnits: daysDiff,
        lateFineRate: _dailyLateFine,
        calculatedLateFine: fine,
        overdueEmiAmount: overdueMissed,
        totalOverdueAmount: totalPayable + fine,
        calculationExplanation: fallbackBreakdown.explanation,
        weeklyBreakdown: null,
        latePayableBreakdown: fallbackBreakdown,
      );
    }

    if (entries.length == 1) {
      final entryPayments = payments.where((p) => p.collectionId == entries.first.id).toList();
      return getLateFineStatusForEntry(
        entry: entries.first,
        payments: entryPayments,
        loaneeLoanAmount: fallbackLoanAmount,
        asOfDate: asOfDate,
      );
    }

    // Multiple entries: aggregate
    double totalFine = 0.0;
    double totalOverdueEmi = 0.0;
    double totalPaid = 0.0;
    int totalPaymentsCount = 0;
    int totalOverdueUnits = 0;
    DateTime? latestPaymentDate;
    final List<String> types = [];
    CollectionLatePayableBreakdown? firstBreakdown;

    for (final entry in entries) {
      final entryPayments = payments.where((p) => p.collectionId == entry.id).toList();
      final status = getLateFineStatusForEntry(
        entry: entry,
        payments: entryPayments,
        loaneeLoanAmount: fallbackLoanAmount,
        asOfDate: asOfDate,
      );
      firstBreakdown ??= status.latePayableBreakdown;
      totalFine += status.calculatedLateFine;
      totalOverdueEmi += status.overdueEmiAmount;
      totalPaid += status.totalPaidAmount;
      totalPaymentsCount += status.paymentRecordsCount;
      totalOverdueUnits += status.overdueUnits;
      types.add(entry.collectionType);

      if (status.lastPaymentDate != null) {
        if (latestPaymentDate == null || status.lastPaymentDate!.isAfter(latestPaymentDate)) {
          latestPaymentDate = status.lastPaymentDate;
        }
      }
    }

    final hasPaymentsInTable = totalPaymentsCount > 0;
    final primaryEntry = entries.first;

    return LoaneeLateFineStatus(
      collectionId: entries.map((e) => e.id).join(', '),
      customerId: customerId ?? primaryEntry.customerId,
      accountNumber: accountNumber ?? entries.map((e) => e.accountNumber).toSet().join(', '),
      loaneeName: loaneeName ?? primaryEntry.loaneeName,
      collectionType: types.toSet().join(', '),
      isDaily: types.every((t) => t.toLowerCase().trim() == 'daily'),
      hasPaymentsInTable: hasPaymentsInTable,
      paymentRecordsCount: totalPaymentsCount,
      totalPaidAmount: totalPaid,
      lastPaymentDate: latestPaymentDate,
      loanStartDate: primaryEntry.createdAt,
      overdueUnits: totalOverdueUnits,
      lateFineRate: types.first.toLowerCase().trim() == 'daily' ? _dailyLateFine : _weeklyLateFine,
      calculatedLateFine: totalFine,
      overdueEmiAmount: totalOverdueEmi,
      totalOverdueAmount: totalOverdueEmi + totalFine,
      calculationExplanation: 'Combined assessment across ${entries.length} loan accounts: ₹${totalFine.toStringAsFixed(2)} late fine penalty total.',
      weeklyBreakdown: null,
      latePayableBreakdown: firstBreakdown,
    );
  }

  // ==========================================
  // LOANEE ACKNOWLEDGMENT PERSISTENCE
  // ==========================================
  static String _ackKey(String customerId, DateTime date) {
    return 'mangang_ack_${customerId.trim().toLowerCase()}_${date.year}_${date.month}_${date.day}';
  }

  static String _ackTimeKey(String customerId) {
    return 'mangang_ack_time_${customerId.trim().toLowerCase()}';
  }

  /// Check if Loanee has acknowledged the late fine notice today
  Future<bool> isFineAcknowledgedToday(String customerId) async {
    if (customerId.trim().isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _ackKey(customerId, DateTime.now());
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Record loanee acknowledgment for today with exact timestamp
  Future<void> acknowledgeFineForToday(String customerId) async {
    if (customerId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setBool(_ackKey(customerId, now), true);
      await prefs.setString(_ackTimeKey(customerId), now.toIso8601String());
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error recording fine acknowledgment: $e');
    }
  }

  /// Get the last recorded acknowledgment timestamp string
  Future<String?> getAcknowledgmentTimestamp(String customerId) async {
    if (customerId.trim().isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_ackTimeKey(customerId));
    } catch (_) {
      return null;
    }
  }

  /// Reset to default settings (Row-wise)
  Future<void> resetToDefaults() async {
    await saveLatePaymentSettings(
      dailyFine: 3.0,
      weeklyFine: 25.0,
      weeklyInstallment: 650.0,
      weeklyTenure: 17.5,
    );
    await saveInvestmentSettings(
      baseAmount: 10000.0,
      interestAmount: 1500.0,
      interestRate: 15.0,
    );
  }
}
