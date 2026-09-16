// lib/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/collection_payment_model.dart';
import '../models/investment_model.dart';
import '../models/loanee_model.dart';
import '../models/holiday_model.dart';
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

/// Represents a single month's compounding step in post-maturity overdue calculation
class PostMaturityMonthlyStep {
  final int monthNumber;
  final double startingBalance;
  final double interestRate; // e.g. 7.0%
  final double interestAmount;
  final double endingBalance;

  const PostMaturityMonthlyStep({
    required this.monthNumber,
    required this.startingBalance,
    required this.interestRate,
    required this.interestAmount,
    required this.endingBalance,
  });
}

/// Breakdown for Post-Maturity Overdue Assessment (3% Normal vs 7% Post-Maturity on Remaining Balance)
class PostMaturityInterestBreakdown {
  final bool isPastMaturity;
  final DateTime maturityDate;
  final DateTime sanctionDate;
  final double remainingBalance; // Base unpaid remaining balance before overdue interest
  final double normalInterestRate; // 3.0%
  final double postMaturityInterestRate; // 7.0% per month
  final int overdueMonths; // Applicable overdue periods/months
  final int overdueExtraDays; // 0 (no partial days)
  final int daysPastMaturity; // 0
  final double totalOverdueMonths; // overdueMonths as double
  final double postMaturityInterestAmount; // Current applicable period's overdue interest ONLY (e.g. ₹2,561.58)
  final double cumulativeInterestAmount; // Cumulative overdue interest across all periods (e.g. ₹4,955.58)
  final double normalInterestAmount; // Comparison 3% normal rate interest
  final double postMaturityPayableAmount; // Total compounded payable amount (e.g. ₹39,155.58)
  final double standardInstallment; // Base scheduled installment
  final List<PostMaturityMonthlyStep> monthlySteps;
  final String explanation;

  const PostMaturityInterestBreakdown({
    required this.isPastMaturity,
    required this.maturityDate,
    required this.sanctionDate,
    required this.remainingBalance,
    required this.normalInterestRate,
    required this.postMaturityInterestRate,
    required this.overdueMonths,
    this.overdueExtraDays = 0,
    this.daysPastMaturity = 0,
    required this.totalOverdueMonths,
    required this.postMaturityInterestAmount,
    this.cumulativeInterestAmount = 0.0,
    required this.normalInterestAmount,
    required this.postMaturityPayableAmount,
    required this.standardInstallment,
    required this.monthlySteps,
    required this.explanation,
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
  final double lateFineRate; // e.g. ₹3.00/day, ₹6.00/day, ₹9.00/day or ₹25.00/week
  final double calculatedLateFine; // Total fine (current interval + previous unpaid carried forward)
  final double grandTotalWithPenalty; // totalPayableAmount + calculatedLateFine
  final String explanation; // Plain-English rationale
  final String shortSummary; // Short summary for table chips
  final double previousUnpaidLateFee; // Carried forward unpaid late fee from previous payments
  final double currentIntervalLateFine; // Assessed fee for current interval (lateUnits * rate)
  final double effectiveLoanAmount; // Loan amount used for dynamic slab calculation
  final double totalOutstandingDue; // Remaining loan balance + previous unpaid late fee
  final String? carriedForwardExplanation;
  final PostMaturityInterestBreakdown? postMaturityBreakdown;

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
    this.previousUnpaidLateFee = 0.0,
    this.currentIntervalLateFine = 0.0,
    this.effectiveLoanAmount = 0.0,
    this.totalOutstandingDue = 0.0,
    this.carriedForwardExplanation,
    this.postMaturityBreakdown,
  });

  bool get isOverdue => lateUnits > 0 || previousUnpaidLateFee > 0;
  bool get isPastMaturity => postMaturityBreakdown?.isPastMaturity ?? false;
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
  final PostMaturityInterestBreakdown? postMaturityBreakdown;

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
    this.postMaturityBreakdown,
  });

  bool get isOverdue => overdueUnits > 0 || calculatedLateFine > 0;
  bool get isPastMaturity => postMaturityBreakdown?.isPastMaturity ?? false;
}

class SettingsProvider extends ChangeNotifier {
  double _dailyLateFine = 3.0;
  double _weeklyLateFine = 25.0;
  double _lateFinePercentage = 3.0; // 3% of base installment for both daily and weekly schedules
  double _weeklyInstallmentAmount = 650.0;
  double _weeklyTenureWeeks = 17.5;
  double _normalInterestRate = 3.0; // 3% normal rate during 5-month maturity
  double _postMaturityInterestRate = 7.0; // 7% post-maturity rate on remaining balance

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
  static const String _keyLateFinePercentage = 'mangang_late_fine_percentage';
  static const String _keyWeeklyInstallment = 'mangang_weekly_installment_amt';
  static const String _keyWeeklyTenure = 'mangang_weekly_tenure_wks';
  static const String _keyNormalInterestRate = 'mangang_normal_interest_rate';
  static const String _keyPostMaturityInterestRate = 'mangang_post_maturity_interest_rate';
  static const String _keyLastUpdated = 'mangang_settings_last_updated';

  SettingsProvider() {
    loadSettings();
  }

  double get dailyLateFine => _dailyLateFine;
  double get weeklyLateFine => _weeklyLateFine;
  double get lateFinePercentage => _lateFinePercentage;
  double get weeklyInstallmentAmount => _weeklyInstallmentAmount;
  double get weeklyTenureWeeks => _weeklyTenureWeeks;
  double get totalWeeklyTenureAmount => _weeklyInstallmentAmount * _weeklyTenureWeeks; // 650 * 17.5 = 11,375

  // Normal & Post-Maturity Interest Rates
  double get normalInterestRate => _normalInterestRate;
  double get postMaturityInterestRate => _postMaturityInterestRate;

  // Investment Settings Getters (Fetched from system_settings table)
  InvestmentSettingsModel get investmentSettings => _investmentSettings;
  double get investmentBaseAmount => _investmentSettings.baseAmount;
  double get investmentInterestAmount => _investmentSettings.interestAmount;
  double get investmentInterestRate => _investmentSettings.interestRate;

  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  // Holidays state
  List<Holiday> _holidays = [];
  List<Holiday> get holidays => List.unmodifiable(_holidays);
  List<DateTime> get holidayDates => _holidays
      .map((h) => DateTime(h.date.year, h.date.month, h.date.day))
      .toList();

  /// Check if a specific date is a registered holiday
  bool isHoliday(DateTime date) {
    return _holidays.any((h) =>
        h.date.year == date.year &&
        h.date.month == date.month &&
        h.date.day == date.day);
  }

  /// Get holiday instance for a specific date if one exists
  Holiday? getHolidayForDate(DateTime date) {
    for (final h in _holidays) {
      if (h.date.year == date.year &&
          h.date.month == date.month &&
          h.date.day == date.day) {
        return h;
      }
    }
    return null;
  }

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
        if (map.containsKey('late_fine_percentage')) {
          _lateFinePercentage = double.tryParse(map['late_fine_percentage']!) ?? _lateFinePercentage;
        }
        if (map.containsKey('weekly_installment_amount')) {
          _weeklyInstallmentAmount = double.tryParse(map['weekly_installment_amount']!) ?? _weeklyInstallmentAmount;
        }
        if (map.containsKey('weekly_tenure_weeks')) {
          _weeklyTenureWeeks = double.tryParse(map['weekly_tenure_weeks']!) ?? _weeklyTenureWeeks;
        }
        if (map.containsKey('normal_interest_rate')) {
          _normalInterestRate = double.tryParse(map['normal_interest_rate']!) ?? _normalInterestRate;
        }
        if (map.containsKey('post_maturity_interest_rate')) {
          _postMaturityInterestRate = double.tryParse(map['post_maturity_interest_rate']!) ?? _postMaturityInterestRate;
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
      if (prefs.containsKey(_keyLateFinePercentage) && _lateFinePercentage == 3.0) {
        _lateFinePercentage = prefs.getDouble(_keyLateFinePercentage) ?? 3.0;
      }
      if (prefs.containsKey(_keyWeeklyInstallment) && _weeklyInstallmentAmount == 650.0) {
        _weeklyInstallmentAmount = prefs.getDouble(_keyWeeklyInstallment) ?? 650.0;
      }
      if (prefs.containsKey(_keyWeeklyTenure) && _weeklyTenureWeeks == 17.5) {
        _weeklyTenureWeeks = prefs.getDouble(_keyWeeklyTenure) ?? 17.5;
      }
      if (prefs.containsKey(_keyNormalInterestRate) && _normalInterestRate == 3.0) {
        _normalInterestRate = prefs.getDouble(_keyNormalInterestRate) ?? 3.0;
      }
      if (prefs.containsKey(_keyPostMaturityInterestRate) && _postMaturityInterestRate == 7.0) {
        _postMaturityInterestRate = prefs.getDouble(_keyPostMaturityInterestRate) ?? 7.0;
      }
      if (prefs.containsKey(_keyLastUpdated) && _lastUpdated == null) {
        final lastIso = prefs.getString(_keyLastUpdated);
        if (lastIso != null) {
          _lastUpdated = DateTime.tryParse(lastIso);
        }
      }

      // Load registered holidays
      await loadHolidays();
    } catch (e) {
      debugPrint('⚠️ Error loading SettingsProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load holidays from Supabase 'holidays' table
  Future<void> loadHolidays() async {
    try {
      final list = await SupabaseService.instance.fetchHolidays();
      _holidays = list;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading holidays in SettingsProvider: $e');
    }
  }

  /// Add a new official holiday and dispatch real-time broadcast notification to all users
  Future<bool> addHoliday({
    required DateTime date,
    required String description,
    String? createdBy,
    bool saveToRemote = true,
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);
    if (isHoliday(cleanDate)) {
      debugPrint('⚠️ Holiday already registered for $cleanDate');
      return false;
    }

    final holiday = Holiday(
      id: 'HOL-${cleanDate.year}${cleanDate.month.toString().padLeft(2, '0')}${cleanDate.day.toString().padLeft(2, '0')}',
      date: cleanDate,
      description: description.trim(),
      createdBy: createdBy ?? 'Administrator',
      createdAt: DateTime.now(),
    );

    try {
      bool saved = true;
      if (saveToRemote && SupabaseService.instance.isInitialized) {
        saved = await SupabaseService.instance.saveHoliday(holiday);
      }

      if (saved) {
        _holidays.removeWhere((h) =>
            h.date.year == cleanDate.year &&
            h.date.month == cleanDate.month &&
            h.date.day == cleanDate.day);
        _holidays.add(holiday);
        _holidays.sort((a, b) => a.date.compareTo(b.date));
        notifyListeners();

        // Broadcast real-time notification to all users
        if (saveToRemote && SupabaseService.instance.isInitialized) {
          await SupabaseService.instance.createHolidayNotification(
            holiday: holiday,
            createdBy: createdBy ?? 'Administrator',
          );
        }

        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error adding holiday: $e');
    }
    return false;
  }

  /// Delete a holiday from 'holidays' table
  Future<bool> deleteHoliday(String id, {bool saveToRemote = true}) async {
    try {
      bool ok = true;
      if (saveToRemote && SupabaseService.instance.isInitialized) {
        ok = await SupabaseService.instance.deleteHoliday(id);
      }
      if (ok) {
        _holidays.removeWhere((h) => h.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting holiday: $e');
    }
    return false;
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
    double? lateFinePercentage,
  }) async {
    if (dailyFine < 0 || weeklyFine < 0 || (lateFinePercentage != null && lateFinePercentage < 0)) {
      throw ArgumentError('Fine amounts cannot be negative.');
    }

    final installment = weeklyInstallment ?? _weeklyInstallmentAmount;
    final tenure = weeklyTenure ?? _weeklyTenureWeeks;
    final finePct = lateFinePercentage ?? _lateFinePercentage;

    if (installment < 0 || tenure < 0) {
      throw ArgumentError('Installment and tenure cannot be negative.');
    }

    try {
      final now = DateTime.now();

      _dailyLateFine = dailyFine;
      _weeklyLateFine = weeklyFine;
      _lateFinePercentage = finePct;
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
        await SupabaseService.instance.setSystemSetting('late_fine_percentage', finePct);
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_keyDailyLateFine, dailyFine);
        await prefs.setDouble(_keyWeeklyLateFine, weeklyFine);
        await prefs.setDouble(_keyLateFinePercentage, finePct);
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
    double? loaneeLoanAmount,
  }) {
    final now = asOfDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);

    final double effectiveWeeklyInstallment = entry.getCalculatedPayableAmount(
      loaneeLoanAmount: loaneeLoanAmount,
      configuredInterestRate: investmentInterestRate,
      configuredBasePrincipal: investmentBaseAmount,
      configuredBaseDailyAmount: baseDailyAmount,
      configuredWeeklyInstallment: weeklyInstallmentAmount,
    );
    final double weeklyInstallmentToUse = effectiveWeeklyInstallment > 0
        ? effectiveWeeklyInstallment
        : _weeklyInstallmentAmount;

    final double totalPaid = payments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final int weeksPaid = (weeklyInstallmentToUse > 0)
        ? (totalPaid / weeklyInstallmentToUse).floor()
        : 0;

    final int daysSinceStart = today.difference(entryDate).inDays;
    final int weeksElapsed = (daysSinceStart ~/ 7);
    final int maxTenureWeeks = _weeklyTenureWeeks.ceil(); // e.g. 18 weeks for 17.5
    final int expectedWeeks = weeksElapsed.clamp(0, maxTenureWeeks);

    final int lateWeeks = (expectedWeeks - weeksPaid).clamp(0, maxTenureWeeks);
    final double weeklyRate = weeklyInstallmentToUse * (_lateFinePercentage / 100.0);
    final double calculatedFine = lateWeeks > 0 ? (lateWeeks * weeklyRate) : 0.0;

    return WeeklyBreakdown(
      weeklyInstallment: weeklyInstallmentToUse,
      tenureWeeks: _weeklyTenureWeeks,
      totalTenureAmount: weeklyInstallmentToUse * _weeklyTenureWeeks,
      totalPaid: totalPaid,
      weeksPaid: weeksPaid,
      expectedWeeks: expectedWeeks,
      lateWeeks: lateWeeks,
      lateFineRate: weeklyRate,
      totalCalculatedFine: calculatedFine,
    );
  }

  /// Calculate late days between a base date (or due date) and the collection/current date,
  /// skipping every Sunday and registered Holiday encountered in the date range.
  ///
  /// Business Rules:
  /// 1. Sunday is NOT a collection / working day.
  /// 2. Registered Holidays are NOT collection / working days.
  /// 3. If [hasPreviousPayment] is true, [baseDate] is the previous payment date (which was settled),
  ///    so missed collection days start checking from the day after [baseDate].
  /// 4. If [hasPreviousPayment] is false, [baseDate] is the loan start / due date.
  /// 5. Every Sunday and Holiday encountered between the start checking date and [asOfDate] is excluded.
  /// 6. If due date was Saturday and collection date is Sunday, 0 late days.
  /// 7. If due date was Sunday, Sunday itself is not counted as a late day.
  static int calculateDailyLateDays({
    required DateTime baseDate,
    required DateTime asOfDate,
    bool hasPreviousPayment = false,
    List<DateTime>? holidays,
  }) {
    final cleanBaseDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final cleanToday = DateTime(asOfDate.year, asOfDate.month, asOfDate.day);

    if (!cleanToday.isAfter(cleanBaseDate)) {
      return 0;
    }

    // Special rule: Due date Saturday, Collection date Sunday -> 0 late days
    if (cleanToday.weekday == DateTime.sunday &&
        cleanBaseDate.weekday == DateTime.saturday &&
        cleanToday.difference(cleanBaseDate).inDays == 1) {
      return 0;
    }

    // If there was a previous payment, that payment covered baseDate.
    // The next installment was due on the next day.
    // If no previous payment, installment was due on baseDate itself.
    final firstCheckDate = hasPreviousPayment
        ? cleanBaseDate.add(const Duration(days: 1))
        : cleanBaseDate;

    int lateDays = 0;
    DateTime current = firstCheckDate;

    while (current.isBefore(cleanToday)) {
      final isSunday = current.weekday == DateTime.sunday;
      final isHoliday = holidays != null &&
          holidays.any((h) =>
              h.year == current.year &&
              h.month == current.month &&
              h.day == current.day);

      if (!isSunday && !isHoliday) {
        lateDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return lateDays.clamp(0, 365);
  }

  /// Calculate late days between a due date and collection date, excluding Sundays & Holidays.
  static int calculateLateDaysBetween({
    required DateTime dueDate,
    required DateTime collectionDate,
    List<DateTime>? holidays,
  }) {
    return calculateDailyLateDays(
      baseDate: dueDate,
      asOfDate: collectionDate,
      hasPreviousPayment: false,
      holidays: holidays,
    );
  }

  /// Dynamic Loan-Amount-Based Late Fee Slab Rate:
  /// - Loan amount <= ₹10,000 → ₹3 per late day (or configured base rate)
  /// - Loan amount > ₹10,000 and < ₹30,000 → ₹6 per late day (or configured base rate * 2)
  /// - Loan amount >= ₹30,000 → ₹9 per late day (or configured base rate * 3)
  static double getLateFeeRateForLoanAmount(double loanAmount, {double? baseDailyFine}) {
    final base = (baseDailyFine != null && baseDailyFine > 0) ? baseDailyFine : 3.0;
    if (loanAmount <= 10000.0) {
      return base;
    } else if (loanAmount < 30000.0) {
      return base * 2.0;
    } else {
      return base * 3.0;
    }
  }

  /// Calculates unpaid late fees carried forward across historical payment intervals for an entry.
  /// Inspects payment records chronologically (most recent first) for carried-forward notes in remarks,
  /// accounting for any subsequent fees cleared via p.lateFine.
  static double calculatePreviousUnpaidLateFee({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    double? loaneeLoanAmount,
    DateTime? sanctionDate,
  }) {
    if (payments.isEmpty) {
      return 0.0;
    }

    final sortedDesc = List<CollectionPaymentModel>.from(payments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double clearedSince = 0.0;
    for (final p in sortedDesc) {
      if (p.remarks != null && p.remarks!.isNotEmpty) {
        final match = RegExp(
          r'₹?\s*([0-9]+(?:\.[0-9]+)?)\s*carried\s*forward',
          caseSensitive: false,
        ).firstMatch(p.remarks!);
        if (match != null) {
          final amt = double.tryParse(match.group(1) ?? '0') ?? 0.0;
          return (amt - clearedSince).clamp(0.0, double.infinity);
        }
      }
      clearedSince += p.effectiveLateFine;
    }

    return 0.0;
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

      // Filter all valid non-cancelled payment and fee transactions
      final validTransactions = payments.where((p) {
        final s = p.status.toLowerCase().trim();
        final hasFeeOrPayment = p.paymentAmount > 0 ||
            p.lateFine > 0 ||
            p.interest > 0 ||
            p.postMaturityInterest > 0;
        return s != 'failed' && s != 'cancelled' && hasFeeOrPayment;
      }).toList();

      // Separate regular payments / historical transactions from auto-assessed late-fee records
      final regularPayments = validTransactions.where((p) {
        final isAuto = p.id.startsWith('PAY-LATE-') ||
            (p.remarks != null && p.remarks!.contains('Auto assessed'));
        return !isAuto;
      }).toList();

      if (regularPayments.isNotEmpty) {
        final sorted = List<CollectionPaymentModel>.from(regularPayments)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        baseDate = sorted.first.createdAt;
        hasPreviousPayment = true;
      } else {
        baseDate = entry.createdAt;
        hasPreviousPayment = false;
      }

      final cleanBaseDate = DateTime(baseDate.year, baseDate.month, baseDate.day);

      // Identify active auto-assessed records after baseDate and strictly before today
      final autoAssessedInInterval = validTransactions.where((p) {
        final isAuto = p.id.startsWith('PAY-LATE-') ||
            (p.remarks != null && p.remarks!.contains('Auto assessed'));
        final cleanDate = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
        return isAuto && cleanDate.isAfter(cleanBaseDate) && cleanDate.isBefore(today);
      }).toList();

      if (autoAssessedInInterval.isNotEmpty) {
        final sortedAuto = List<CollectionPaymentModel>.from(autoAssessedInInterval)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latestAutoDate = sortedAuto.first.createdAt;

        // Pending unrecorded completed days after latest auto-assessed record
        final pendingDays = calculateDailyLateDays(
          baseDate: latestAutoDate,
          asOfDate: today,
          hasPreviousPayment: true,
          holidays: holidayDates,
        );

        return autoAssessedInInterval.length + pendingDays;
      }

      return calculateDailyLateDays(
        baseDate: baseDate,
        asOfDate: today,
        hasPreviousPayment: hasPreviousPayment,
        holidays: holidayDates,
      );
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

  /// Percentage-based Late Fee Rate: 3% of base installment for both Daily & Weekly schemes (only when late)
  double getLateFeeRateForBaseInstallment(double baseInstallment) {
    return baseInstallment * (_lateFinePercentage / 100.0);
  }

  /// Calculate the recommended late fine amount for an entry (3% of base installment when late + carried forward unpaid fees)
  double calculateLateFineForEntry({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    DateTime? asOfDate,
    double? loaneeLoanAmount,
    DateTime? sanctionDate,
  }) {
    final type = entry.collectionType.toLowerCase().trim();
    final isDaily = type == 'daily';
    final double baseInstallment = entry.getCalculatedPayableAmount(
      loaneeLoanAmount: loaneeLoanAmount,
      configuredInterestRate: investmentInterestRate,
      configuredBasePrincipal: investmentBaseAmount,
      configuredBaseDailyAmount: baseDailyAmount,
      configuredWeeklyInstallment: weeklyInstallmentAmount,
    );

    if (isDaily) {
      final int lateDays = calculateLateUnits(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
      );
      final double rate = baseInstallment * (_lateFinePercentage / 100.0);
      final double currentIntervalFee = lateDays > 0 ? (lateDays * rate) : 0.0;
      final double previousUnpaid = calculatePreviousUnpaidLateFee(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: loaneeLoanAmount,
        sanctionDate: sanctionDate ?? entry.createdAt,
      );
      return currentIntervalFee + previousUnpaid;
    } else {
      final breakdown = getWeeklyBreakdown(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
        loaneeLoanAmount: loaneeLoanAmount,
      );
      final double previousUnpaid = calculatePreviousUnpaidLateFee(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: loaneeLoanAmount,
        sanctionDate: sanctionDate ?? entry.createdAt,
      );
      return breakdown.totalCalculatedFine + previousUnpaid;
    }
  }

  /// Add calendar months to a date, clamping day to end of month if necessary
  static DateTime addMonths(DateTime date, int monthsToAdd) {
    int year = date.year;
    int month = date.month + monthsToAdd;
    while (month > 12) {
      year += 1;
      month -= 12;
    }
    while (month < 1) {
      year -= 1;
      month += 12;
    }
    int day = date.day;
    int daysInTargetMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInTargetMonth) {
      day = daysInTargetMonth;
    }
    return DateTime(year, month, day);
  }

  /// Format date helper for human-readable calculation explanations
  static String formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  /// Evaluates Post-Maturity Overdue Assessment (7%/month Compound Overdue Interest on Remaining Balance)
  PostMaturityInterestBreakdown getPostMaturityBreakdown({
    required DateTime sanctionDate,
    DateTime? maturityDate,
    required double remainingBalance,
    required double standardInstallment,
    DateTime? asOfDate,
    bool isDaily = true,
    List<CollectionPaymentModel>? payments,
    double? initialLoanAmount,
  }) {
    final now = asOfDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final calculatedMaturity = maturityDate ?? LoaneeAccount.calculateMaturityDate(sanctionDate);
    final cleanMaturity = DateTime(calculatedMaturity.year, calculatedMaturity.month, calculatedMaturity.day);

    final double normalRate = _normalInterestRate;
    final double postRate = _postMaturityInterestRate;

    // Rule 1: If current date <= maturity date, loan is NOT overdue:
    if (!today.isAfter(cleanMaturity)) {
      final double normalInterest = (remainingBalance * normalRate / 100.0);
      final String explanation = 'Loan Due Date: ${formatDate(calculatedMaturity)}. Loan is not overdue. Overdue interest: ₹0.00. Total Payable Amount = ₹${remainingBalance.toStringAsFixed(2)}.';

      return PostMaturityInterestBreakdown(
        isPastMaturity: false,
        maturityDate: calculatedMaturity,
        sanctionDate: sanctionDate,
        remainingBalance: remainingBalance,
        normalInterestRate: normalRate,
        postMaturityInterestRate: postRate,
        overdueMonths: 0,
        overdueExtraDays: 0,
        daysPastMaturity: 0,
        totalOverdueMonths: 0.0,
        postMaturityInterestAmount: 0.0,
        cumulativeInterestAmount: 0.0,
        normalInterestAmount: double.parse(normalInterest.toStringAsFixed(2)),
        postMaturityPayableAmount: remainingBalance > 0 ? remainingBalance : standardInstallment,
        standardInstallment: standardInstallment,
        monthlySteps: const [],
        explanation: explanation,
      );
    }

    // Rule 2: If current date > maturity date, 1st overdue period triggers immediately on the first day after maturity.
    // Subsequent periods trigger after each monthly boundary.
    int overduePeriods = 1;
    for (int k = 1; k < 120; k++) {
      final nextBoundary = addMonths(cleanMaturity, k);
      if (today.isAfter(nextBoundary)) {
        overduePeriods = k + 1;
      } else {
        break;
      }
    }

    if (remainingBalance <= 0) {
      return PostMaturityInterestBreakdown(
        isPastMaturity: false,
        maturityDate: calculatedMaturity,
        sanctionDate: sanctionDate,
        remainingBalance: 0.0,
        normalInterestRate: normalRate,
        postMaturityInterestRate: postRate,
        overdueMonths: 0,
        overdueExtraDays: 0,
        daysPastMaturity: 0,
        totalOverdueMonths: 0.0,
        postMaturityInterestAmount: 0.0,
        cumulativeInterestAmount: 0.0,
        normalInterestAmount: 0.0,
        postMaturityPayableAmount: 0.0,
        standardInstallment: standardInstallment,
        monthlySteps: const [],
        explanation: 'Loan Due Date: ${formatDate(calculatedMaturity)}. Loan is fully settled. Overdue interest: ₹0.00.',
      );
    }

    // Loan is past maturity and has an outstanding remaining balance.
    // Total Payable Today must be based on the actual current outstanding loan balance,
    // including only the applicable accrued late/post-maturity amounts from the database.
    // Remaining Balance = (initialLoan + totalInterest - totalPaid).clamp(0.0, infinity)
    final double cumulativeRecordedPostMat = payments != null
        ? payments.fold(0.0, (sum, p) => sum + p.postMaturityInterest)
        : 0.0;

    double lastRecordedPostMat = 0.0;
    if (payments != null && payments.isNotEmpty) {
      final sortedPayments = List<CollectionPaymentModel>.from(payments)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final paymentsWithPostMat = sortedPayments.where((p) => p.postMaturityInterest > 0).toList();
      if (paymentsWithPostMat.isNotEmpty) {
        lastRecordedPostMat = paymentsWithPostMat.last.postMaturityInterest;
      }
    }

    final double normalInterest = (remainingBalance * normalRate / 100.0);
    final String explanation = 'Loan Due Date: ${formatDate(calculatedMaturity)} (Period $overduePeriods past maturity). '
        'Outstanding balance: ₹${remainingBalance.toStringAsFixed(2)}${cumulativeRecordedPostMat > 0 ? " (includes ₹${cumulativeRecordedPostMat.toStringAsFixed(2)} accrued post-maturity interest)" : ""}. '
        'Total Payable Amount = ₹${remainingBalance.toStringAsFixed(2)}.';

    return PostMaturityInterestBreakdown(
      isPastMaturity: true,
      maturityDate: calculatedMaturity,
      sanctionDate: sanctionDate,
      remainingBalance: remainingBalance,
      normalInterestRate: normalRate,
      postMaturityInterestRate: postRate,
      overdueMonths: overduePeriods,
      overdueExtraDays: 0,
      daysPastMaturity: 0,
      totalOverdueMonths: overduePeriods.toDouble(),
      postMaturityInterestAmount: lastRecordedPostMat,
      cumulativeInterestAmount: cumulativeRecordedPostMat,
      normalInterestAmount: double.parse(normalInterest.toStringAsFixed(2)),
      postMaturityPayableAmount: remainingBalance,
      standardInstallment: standardInstallment,
      monthlySteps: const [],
      explanation: explanation,
    );
  }

  /// Comprehensive calculation of Late Payment Fee and Payable Amount Breakdown
  /// For active tenure: Base installment + missed daily/weekly installments + late fine
  /// For past maturity: Total Payable = Remaining Due + Newly Calculated Overdue Interest
  CollectionLatePayableBreakdown getLatePayableBreakdownForEntry({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    double? loaneeLoanAmount,
    double? loaneeDueAmount,
    DateTime? maturityDate,
    DateTime? sanctionDate,
    DateTime? asOfDate,
    double? overrideTotalPaid,
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

    // Compute remaining balance directly from DB records
    final double inMemPaid = payments.fold(0.0, (sum, p) => sum + p.paymentAmount);
    final double totalPaid = (overrideTotalPaid != null && overrideTotalPaid > inMemPaid)
        ? overrideTotalPaid
        : inMemPaid;
    final double totalInterest = payments.fold(0.0, (sum, p) => sum + p.effectiveLateFine + p.postMaturityInterest);
    final double initialLoan = (entry.loanAmount != null && entry.loanAmount! > 0)
        ? entry.loanAmount!
        : ((loaneeLoanAmount != null && loaneeLoanAmount > 0)
            ? loaneeLoanAmount
            : (entry.actualPrincipal ?? 0.0));

    final sortedPayments = List<CollectionPaymentModel>.from(payments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final double calculatedBalance = (initialLoan > 0)
        ? (initialLoan + totalInterest - totalPaid).clamp(0.0, double.infinity)
        : (sortedPayments.isNotEmpty && sortedPayments.first.remainingBalance > 0
            ? sortedPayments.first.remainingBalance
            : 0.0);

    final double remainingBalance = calculatedBalance;

    final effectiveSanctionDate = sanctionDate ?? entry.createdAt;
    final effectiveMaturityDate = maturityDate ?? LoaneeAccount.calculateMaturityDate(effectiveSanctionDate);
    final double effectiveLoanAmount = entry.getCalculatedLoanAmount(loaneeLoanAmount: loaneeLoanAmount);

    final postMaturity = getPostMaturityBreakdown(
      sanctionDate: effectiveSanctionDate,
      maturityDate: effectiveMaturityDate,
      remainingBalance: remainingBalance,
      standardInstallment: baseInstallment,
      asOfDate: asOfDate,
      isDaily: isDaily,
      payments: payments,
      initialLoanAmount: initialLoan > 0 ? initialLoan : remainingBalance,
    );

    final bool isLoanCleared = (initialLoan > 0 && calculatedBalance <= 0) ||
        (sortedPayments.isNotEmpty && sortedPayments.first.remainingBalance <= 0 && totalPaid > 0);

    final int lateUnits;
    final double fineRate = baseInstallment * (_lateFinePercentage / 100.0);
    final double currentIntervalFine;
    final double previousUnpaidFee;
    final double calculatedFine;
    final double overdueMissedAmount;
    final double currentInstallment;
    final double totalPayable;
    final double grandTotal;
    final String explanation;
    final String shortSummary;
    final String? carriedForwardExplanation;

    if (postMaturity.isPastMaturity) {
      // AFTER MATURITY:
      // Total Payable Today must be based on the actual current outstanding loan balance,
      // including only the applicable accrued late/post-maturity amounts already factored
      // into remainingBalance.
      // Do not add active tenure daily late units, previous unpaid fees, or duplicate any components.
      lateUnits = 0;
      currentIntervalFine = 0.0;
      previousUnpaidFee = 0.0;
      calculatedFine = 0.0;
      overdueMissedAmount = 0.0;
      currentInstallment = remainingBalance;
      totalPayable = remainingBalance;
      grandTotal = remainingBalance;
      carriedForwardExplanation = null;
      explanation = '⚠️ PAST MATURITY: ${postMaturity.explanation}';
      shortSummary = '₹${totalPayable.toStringAsFixed(0)} (Matured${postMaturity.overdueMonths > 0 ? " ${postMaturity.overdueMonths}M" : ""})';
    } else {
      // BEFORE MATURITY:
      // Keep existing calculation where today's payable is based on applicable scheduled
      // installment(s), missed installments, and late fee.
      lateUnits = !isLoanCleared
          ? calculateLateUnits(
              entry: entry,
              payments: payments,
              asOfDate: asOfDate,
            )
          : 0;

      currentIntervalFine = (lateUnits > 0 && !isLoanCleared)
          ? (lateUnits * fineRate)
          : 0.0;

      previousUnpaidFee = !isLoanCleared
          ? calculatePreviousUnpaidLateFee(
              entry: entry,
              payments: payments,
              loaneeLoanAmount: loaneeLoanAmount,
              sanctionDate: effectiveSanctionDate,
            )
          : 0.0;

      calculatedFine = currentIntervalFine + previousUnpaidFee;

      final double effectiveBase = baseInstallment;
      overdueMissedAmount = lateUnits * effectiveBase;
      currentInstallment = effectiveBase;
      totalPayable = overdueMissedAmount + currentInstallment;
      grandTotal = totalPayable + calculatedFine;

      final String unitName = isDaily ? (lateUnits == 1 ? 'day' : 'days') : (lateUnits == 1 ? 'week' : 'weeks');

      if (lateUnits > 0) {
        final feeBreakdownNote = 'Late payment fee assessed for $lateUnits missed $unitName: ₹${currentIntervalFine.toStringAsFixed(2)} penalty.';
        final carriedNote = previousUnpaidFee > 0 ? ' Previous unpaid late fee: ₹${previousUnpaidFee.toStringAsFixed(2)} carried forward from missed collection (Total fee: ₹${calculatedFine.toStringAsFixed(2)}).' : '';
        explanation = '$lateUnits $unitName late: $lateUnits missed ${isDaily ? "days" : "weeks"} (₹${overdueMissedAmount.toStringAsFixed(2)}) + ${isDaily ? "Today's" : "This week's"} installment (₹${currentInstallment.toStringAsFixed(2)}) = ₹${totalPayable.toStringAsFixed(2)} Total Due Today. $feeBreakdownNote$carriedNote';
        shortSummary = '₹${totalPayable.toStringAsFixed(0)} ($lateUnits $unitName late + today)';
      } else if (previousUnpaidFee > 0) {
        explanation = 'On Time: Scheduled ${isDaily ? "daily" : "weekly"} installment = ₹${currentInstallment.toStringAsFixed(2)}. ₹${previousUnpaidFee.toStringAsFixed(2)} unpaid late fee carried forward from previous missed collection.';
        shortSummary = '₹${currentInstallment.toStringAsFixed(0)} / $freq (+₹${previousUnpaidFee.toStringAsFixed(0)} fee)';
      } else {
        explanation = 'On Time: Scheduled ${isDaily ? "daily" : "weekly"} installment = ₹${currentInstallment.toStringAsFixed(2)} (Standard rate). Late Payment Fee: ₹0.00.';
        shortSummary = '₹${currentInstallment.toStringAsFixed(0)} / $freq';
      }

      carriedForwardExplanation = previousUnpaidFee > 0
          ? '₹${previousUnpaidFee.toStringAsFixed(2)} unpaid late fee carried forward from previous missed collection.'
          : null;
    }

    final double totalOutstanding = remainingBalance + calculatedFine;

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
      previousUnpaidLateFee: previousUnpaidFee,
      currentIntervalLateFine: currentIntervalFine,
      effectiveLoanAmount: effectiveLoanAmount,
      totalOutstandingDue: totalOutstanding,
      carriedForwardExplanation: carriedForwardExplanation,
      postMaturityBreakdown: postMaturity,
    );
  }

  /// Get comprehensive late fine & overdue status for an individual collection entry
  LoaneeLateFineStatus getLateFineStatusForEntry({
    required RoCollectionEntry entry,
    required List<CollectionPaymentModel> payments,
    double? loaneeLoanAmount,
    double? loaneeDueAmount,
    DateTime? maturityDate,
    DateTime? sanctionDate,
    DateTime? asOfDate,
  }) {
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
      loaneeDueAmount: loaneeDueAmount,
      maturityDate: maturityDate,
      sanctionDate: sanctionDate,
      asOfDate: asOfDate,
    );

    final postMaturity = payableBreakdown.postMaturityBreakdown;

    if (isDaily) {
      final int overdueDays = payableBreakdown.lateUnits;
      final lateFine = payableBreakdown.calculatedLateFine;
      final fineRate = payableBreakdown.lateFineRate;
      final String explanation = hasPayments
          ? 'Payment data found in ro_collection_payments (${payments.length} payments, last on ${formatDate(lastPaymentDate!)}). $overdueDays overdue days: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Today\'s ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee assessed for missed collection: ₹${payableBreakdown.currentIntervalLateFine.toStringAsFixed(2)} penalty.${payableBreakdown.previousUnpaidLateFee > 0 ? " (includes ₹${payableBreakdown.previousUnpaidLateFee.toStringAsFixed(2)} unpaid fee carried forward from previous missed collection)" : ""}${postMaturity != null && postMaturity.isPastMaturity ? " (⚠️ Past maturity: overdue interest applied on balance)" : ""}'
          : 'No payment record found in ro_collection_payments table since account creation on ${formatDate(entry.createdAt)}. $overdueDays overdue days: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Today\'s ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee assessed for missed collection: ₹${payableBreakdown.currentIntervalLateFine.toStringAsFixed(2)} penalty.${payableBreakdown.previousUnpaidLateFee > 0 ? " (includes ₹${payableBreakdown.previousUnpaidLateFee.toStringAsFixed(2)} unpaid fee carried forward from previous missed collection)" : ""}${postMaturity != null && postMaturity.isPastMaturity ? " (⚠️ Past maturity: overdue interest applied on balance)" : ""}';

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
        lateFineRate: fineRate,
        calculatedLateFine: lateFine,
        overdueEmiAmount: 0.0,
        totalOverdueAmount: lateFine,
        calculationExplanation: explanation,
        weeklyBreakdown: null,
        latePayableBreakdown: payableBreakdown,
        postMaturityBreakdown: postMaturity,
      );
    } else {
      // Weekly scheme
      final breakdown = getWeeklyBreakdown(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
      );

      final overdueEmi = breakdown.lateWeeks * breakdown.weeklyInstallment;
      final totalOverdue = overdueEmi + breakdown.totalCalculatedFine;

      final String explanation = hasPayments
          ? 'Payment data found in ro_collection_payments (₹${breakdown.totalPaid.toStringAsFixed(2)} paid across ${payments.length} transactions, covering ${breakdown.weeksPaid}/${breakdown.expectedWeeks} expected weeks). ${breakdown.lateWeeks} overdue weeks: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Current ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee assessed for missed collection: ₹${breakdown.totalCalculatedFine.toStringAsFixed(2)} penalty.${payableBreakdown.previousUnpaidLateFee > 0 ? " (includes ₹${payableBreakdown.previousUnpaidLateFee.toStringAsFixed(2)} unpaid fee carried forward from previous missed collection)" : ""}${postMaturity != null && postMaturity.isPastMaturity ? " (⚠️ Past maturity: overdue interest applied on balance)" : ""}'
          : 'No payment record found in ro_collection_payments table since account creation on ${formatDate(entry.createdAt)}. ${breakdown.lateWeeks} overdue weeks: Missed amount ₹${payableBreakdown.overdueMissedAmount.toStringAsFixed(2)} + Current ₹${payableBreakdown.currentInstallment.toStringAsFixed(2)} = ₹${payableBreakdown.totalPayableAmount.toStringAsFixed(2)} payable. Late fee assessed for missed collection: ₹${breakdown.totalCalculatedFine.toStringAsFixed(2)} penalty.${payableBreakdown.previousUnpaidLateFee > 0 ? " (includes ₹${payableBreakdown.previousUnpaidLateFee.toStringAsFixed(2)} unpaid fee carried forward from previous missed collection)" : ""}${postMaturity != null && postMaturity.isPastMaturity ? " (⚠️ Past maturity: overdue interest applied on balance)" : ""}';

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
        postMaturityBreakdown: postMaturity,
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
    DateTime? fallbackMaturityDate,
    double fallbackLoanAmount = 0.0,
    double fallbackDueAmount = 0.0,
    DateTime? asOfDate,
  }) {
    if (entries.isEmpty) {
      // Fallback if loanee exists in loanee_accounts table but collection entry is not created yet
      final now = asOfDate ?? DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = fallbackStartDate ?? now;
      final baseAmt = baseDailyAmount;
      final double remainingBalance = fallbackDueAmount > 0 ? fallbackDueAmount : fallbackLoanAmount;

      final postMaturity = getPostMaturityBreakdown(
        sanctionDate: startDate,
        maturityDate: fallbackMaturityDate,
        remainingBalance: remainingBalance,
        standardInstallment: baseAmt,
        asOfDate: asOfDate,
        isDaily: true,
      );

      final int daysDiff;
      final double fineRate = baseAmt * (_lateFinePercentage / 100.0);
      final double fine;
      final double overdueMissed;
      final double totalPayable;
      final String explanation;
      final String shortSummary;

      if (postMaturity.isPastMaturity) {
        daysDiff = 0;
        fine = 0.0;
        overdueMissed = 0.0;
        totalPayable = remainingBalance;
        explanation = '⚠️ PAST MATURITY: ${postMaturity.explanation}';
        shortSummary = '₹${totalPayable.toStringAsFixed(0)} (Matured${postMaturity.overdueMonths > 0 ? " ${postMaturity.overdueMonths}M" : ""})';
      } else {
        daysDiff = calculateDailyLateDays(
          baseDate: startDate,
          asOfDate: today,
          hasPreviousPayment: false,
          holidays: holidayDates,
        );
        fine = daysDiff > 0 ? (daysDiff * fineRate) : 0.0;
        overdueMissed = daysDiff * baseAmt;
        totalPayable = overdueMissed + baseAmt;
        explanation = 'Calculated from registration date ${formatDate(startDate)}: $daysDiff days late missed amount ₹${overdueMissed.toStringAsFixed(2)} + Today ₹${baseAmt.toStringAsFixed(2)} = ₹${totalPayable.toStringAsFixed(2)} payable. Late fee assessed for missed collection: ₹${fine.toStringAsFixed(2)}.';
        shortSummary = '₹${totalPayable.toStringAsFixed(0)} ($daysDiff days late + today)';
      }

      final fallbackBreakdown = CollectionLatePayableBreakdown(
        baseInstallment: baseAmt,
        lateUnits: daysDiff,
        isDaily: true,
        frequencyLabel: 'Day',
        overdueMissedAmount: overdueMissed,
        currentInstallment: postMaturity.isPastMaturity ? remainingBalance : baseAmt,
        totalPayableAmount: totalPayable,
        lateFineRate: fineRate,
        calculatedLateFine: fine,
        grandTotalWithPenalty: totalPayable + fine,
        explanation: explanation,
        shortSummary: shortSummary,
        effectiveLoanAmount: fallbackLoanAmount > 0 ? fallbackLoanAmount : (fallbackDueAmount > 0 ? fallbackDueAmount : 10000.0),
        currentIntervalLateFine: fine,
        postMaturityBreakdown: postMaturity,
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
        lateFineRate: fineRate,
        calculatedLateFine: fine,
        overdueEmiAmount: overdueMissed,
        totalOverdueAmount: totalPayable + fine,
        calculationExplanation: fallbackBreakdown.explanation,
        weeklyBreakdown: null,
        latePayableBreakdown: fallbackBreakdown,
        postMaturityBreakdown: postMaturity,
      );
    }

    if (entries.length == 1) {
      final entryPayments = payments.where((p) => p.collectionId == entries.first.id).toList();
      return getLateFineStatusForEntry(
        entry: entries.first,
        payments: entryPayments,
        loaneeLoanAmount: fallbackLoanAmount,
        loaneeDueAmount: fallbackDueAmount,
        sanctionDate: fallbackStartDate,
        maturityDate: fallbackMaturityDate,
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
    PostMaturityInterestBreakdown? aggregatePostMaturity;

    for (final entry in entries) {
      final entryPayments = payments.where((p) => p.collectionId == entry.id).toList();
      final status = getLateFineStatusForEntry(
        entry: entry,
        payments: entryPayments,
        loaneeLoanAmount: fallbackLoanAmount,
        loaneeDueAmount: fallbackDueAmount,
        sanctionDate: fallbackStartDate,
        maturityDate: fallbackMaturityDate,
        asOfDate: asOfDate,
      );
      firstBreakdown ??= status.latePayableBreakdown;
      aggregatePostMaturity ??= status.postMaturityBreakdown;
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
      lateFineRate: types.first.toLowerCase().trim() == 'daily'
          ? (primaryEntry.getCalculatedPayableAmount(loaneeLoanAmount: fallbackLoanAmount, configuredBaseDailyAmount: baseDailyAmount, configuredInterestRate: investmentInterestRate, configuredBasePrincipal: investmentBaseAmount) * (_lateFinePercentage / 100.0))
          : (weeklyInstallmentAmount * (_lateFinePercentage / 100.0)),
      calculatedLateFine: totalFine,
      overdueEmiAmount: totalOverdueEmi,
      totalOverdueAmount: totalOverdueEmi + totalFine,
      calculationExplanation: 'Combined assessment across ${entries.length} loan accounts: ₹${totalFine.toStringAsFixed(2)} late fine penalty total.',
      weeklyBreakdown: null,
      latePayableBreakdown: firstBreakdown,
      postMaturityBreakdown: aggregatePostMaturity,
    );
  }

  /// Save Interest Rate Policy settings (3% Normal vs 7% Post-Maturity) directly to Supabase
  Future<bool> saveInterestPolicySettings({
    double? normalRate,
    double? postMaturityRate,
  }) async {
    try {
      final double newNormal = normalRate ?? _normalInterestRate;
      final double newPost = postMaturityRate ?? _postMaturityInterestRate;

      _normalInterestRate = newNormal;
      _postMaturityInterestRate = newPost;
      _lastUpdated = DateTime.now();
      notifyListeners();

      // 1. Sync to Supabase system_settings table
      try {
        await SupabaseService.instance.setSystemSetting('normal_interest_rate', newNormal);
        await SupabaseService.instance.setSystemSetting('post_maturity_interest_rate', newPost);
      } catch (e) {
        debugPrint('ℹ️ Supabase system_settings update note: $e');
      }

      // 2. Persist locally to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyNormalInterestRate, newNormal);
      await prefs.setDouble(_keyPostMaturityInterestRate, newPost);
      await prefs.setString(_keyLastUpdated, _lastUpdated!.toIso8601String());

      return true;
    } catch (e) {
      debugPrint('⚠️ Error saving interest policy settings: $e');
      return false;
    }
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
