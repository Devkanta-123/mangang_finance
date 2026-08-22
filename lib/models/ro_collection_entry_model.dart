// lib/models/ro_collection_entry_model.dart

/// Comprehensive breakdown of Loan Amount (including interest) vs Actual Principal, Interest, and Payables
class LoanPrincipalBreakdown {
  final double loanAmount; // Total amount entered / sanctioned including interest (e.g. ₹57,500)
  final double actualPrincipal; // Actual principal = loanAmount / (1 + rate / 100) (e.g. ₹50,000)
  final double interestRate; // e.g. 15.0%
  final double interestAmount; // loanAmount - actualPrincipal (e.g. ₹7,500)
  final double basePrincipal; // e.g. ₹10,000
  final double baseDailyAmount; // e.g. ₹100
  final double baseWeeklyAmount; // e.g. ₹650
  final double dailyPayable; // (actualPrincipal / basePrincipal) * baseDailyAmount (e.g. ₹500/day)
  final double weeklyPayable; // (actualPrincipal / basePrincipal) * baseWeeklyAmount (e.g. ₹3,250/week)

  LoanPrincipalBreakdown({
    required this.loanAmount,
    required this.actualPrincipal,
    required this.interestRate,
    required this.interestAmount,
    required this.basePrincipal,
    required this.baseDailyAmount,
    required this.baseWeeklyAmount,
    required this.dailyPayable,
    required this.weeklyPayable,
  });

  factory LoanPrincipalBreakdown.calculate({
    required double loanAmount,
    double interestRate = 15.0,
    double basePrincipal = 10000.0,
    double baseDailyAmount = 100.0,
    double baseWeeklyAmount = 650.0,
  }) {
    final rate = interestRate > 0 ? interestRate : 15.0;
    final basePrinc = basePrincipal > 0 ? basePrincipal : 10000.0;
    final baseDaily = baseDailyAmount > 0 ? baseDailyAmount : (basePrinc / 100.0);
    final baseWeekly = baseWeeklyAmount > 0 ? baseWeeklyAmount : 650.0;

    // Formula: principal = loan_amount / (1 + interest_rate / 100)
    final double rawPrincipal = loanAmount > 0
        ? (loanAmount / (1.0 + (rate / 100.0)))
        : basePrinc;
    final double principal = double.parse(rawPrincipal.toStringAsFixed(2));

    final double rawInterest = (loanAmount > principal) ? (loanAmount - principal) : 0.0;
    final double interest = double.parse(rawInterest.toStringAsFixed(2));

    // Formula: daily_payable = principal / base_principal * base_daily_amount
    final double rawDaily = (principal / basePrinc) * baseDaily;
    final double daily = double.parse(rawDaily.toStringAsFixed(2));

    // Formula: weekly_payable = principal / base_principal * base_weekly_amount
    final double rawWeekly = (principal / basePrinc) * baseWeekly;
    final double weekly = double.parse(rawWeekly.toStringAsFixed(2));

    return LoanPrincipalBreakdown(
      loanAmount: loanAmount,
      actualPrincipal: principal,
      interestRate: rate,
      interestAmount: interest,
      basePrincipal: basePrinc,
      baseDailyAmount: baseDaily,
      baseWeeklyAmount: baseWeekly,
      dailyPayable: daily,
      weeklyPayable: weekly,
    );
  }
}

class RoCollectionEntry {
  final String id;
  final String customerId;
  final String accountNumber;
  final String loaneeName;
  final String loaneeAddress;
  final String collectionType; // Daily, Mon, Tue, Wed, Thur, Fri, Sat, Weekly
  final String route; // Mangang, Luwang, Khuman, Angom, Moirang, etc.
  final String mobileNo;
  final DateTime createdAt;
  final String status; // 'Active', etc.
  final double? payableAmount;
  final double? loanAmount; // Total loan amount (including interest)
  final double? actualPrincipal; // Actual loan principal (excluding interest)
  final double? interestAmount; // Interest component
  final double? interestRate; // Configured rate (e.g. 15%)
  final String? frequency; // 'Day', 'Week', 'Daily', 'Weekly'

  RoCollectionEntry({
    required this.id,
    required this.customerId,
    required this.accountNumber,
    required this.loaneeName,
    required this.loaneeAddress,
    required this.collectionType,
    required this.route,
    required this.mobileNo,
    DateTime? createdAt,
    this.status = 'Active',
    this.payableAmount,
    this.loanAmount,
    this.actualPrincipal,
    this.interestAmount,
    this.interestRate,
    this.frequency,
  }) : createdAt = createdAt ?? DateTime.now();

  double get initialBalance => loanAmount ?? actualPrincipal ?? 11500.0;

  bool get isDaily => collectionType.toLowerCase().trim() == 'daily';

  RoCollectionEntry copyWith({
    String? id,
    String? customerId,
    String? accountNumber,
    String? loaneeName,
    String? loaneeAddress,
    String? collectionType,
    String? route,
    String? mobileNo,
    DateTime? createdAt,
    String? status,
    double? payableAmount,
    double? loanAmount,
    double? actualPrincipal,
    double? interestAmount,
    double? interestRate,
    String? frequency,
    double? initialBalance,
  }) {
    return RoCollectionEntry(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      accountNumber: accountNumber ?? this.accountNumber,
      loaneeName: loaneeName ?? this.loaneeName,
      loaneeAddress: loaneeAddress ?? this.loaneeAddress,
      collectionType: collectionType ?? this.collectionType,
      route: route ?? this.route,
      mobileNo: mobileNo ?? this.mobileNo,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      payableAmount: payableAmount ?? this.payableAmount,
      loanAmount: initialBalance ?? loanAmount ?? this.loanAmount,
      actualPrincipal: actualPrincipal ?? this.actualPrincipal,
      interestAmount: interestAmount ?? this.interestAmount,
      interestRate: interestRate ?? this.interestRate,
      frequency: frequency ?? this.frequency,
    );
  }

  /// Frequency label ('Day' for Daily, 'Week' for Weekly schemes)
  String get frequencyLabel {
    if (frequency != null && frequency!.trim().isNotEmpty) {
      final f = frequency!.trim().toLowerCase();
      if (f == 'day' || f == 'daily') return 'Day';
      if (f == 'week' || f == 'weekly') return 'Week';
      return frequency!.trim();
    }
    return isDaily ? 'Day' : 'Week';
  }

  /// Calculates the full principal, interest, and payable breakdown
  LoanPrincipalBreakdown getLoanBreakdown({
    double? loaneeLoanAmount,
    double? configuredInterestRate,
    double? configuredBasePrincipal,
    double? configuredBaseDailyAmount,
    double? configuredWeeklyInstallment,
  }) {
    final double rawLoan = (loanAmount != null && loanAmount! > 0)
        ? loanAmount!
        : ((loaneeLoanAmount != null && loaneeLoanAmount > 0)
            ? loaneeLoanAmount
            : 11500.0); // Default ₹11,500 (₹10,000 principal + 15% interest)

    final double rate = configuredInterestRate ?? interestRate ?? 15.0;
    final double basePrinc = configuredBasePrincipal ?? 10000.0;
    final double baseDaily = configuredBaseDailyAmount ?? (basePrinc / 100.0);
    final double baseWeekly = configuredWeeklyInstallment ?? 650.0;

    return LoanPrincipalBreakdown.calculate(
      loanAmount: rawLoan,
      interestRate: rate,
      basePrincipal: basePrinc,
      baseDailyAmount: baseDaily,
      baseWeeklyAmount: baseWeekly,
    );
  }

  /// Calculates dynamic payable amount using the actual principal
  /// (e.g. ₹57,500 total -> ₹50,000 principal -> ₹500/day)
  double getCalculatedPayableAmount({
    double? loaneeLoanAmount,
    double? configuredInterestRate,
    double? configuredBasePrincipal,
    double? configuredBaseDailyAmount,
    double? configuredWeeklyInstallment,
  }) {
    if (payableAmount != null && payableAmount! > 0) {
      return payableAmount!;
    }
    final breakdown = getLoanBreakdown(
      loaneeLoanAmount: loaneeLoanAmount,
      configuredInterestRate: configuredInterestRate,
      configuredBasePrincipal: configuredBasePrincipal,
      configuredBaseDailyAmount: configuredBaseDailyAmount,
      configuredWeeklyInstallment: configuredWeeklyInstallment,
    );

    return isDaily ? breakdown.dailyPayable : breakdown.weeklyPayable;
  }

  /// Calculates actual principal (excluding interest)
  double getCalculatedActualPrincipal({
    double? loaneeLoanAmount,
    double? configuredInterestRate,
    double? configuredBasePrincipal,
  }) {
    if (actualPrincipal != null && actualPrincipal! > 0) {
      return actualPrincipal!;
    }
    final breakdown = getLoanBreakdown(
      loaneeLoanAmount: loaneeLoanAmount,
      configuredInterestRate: configuredInterestRate,
      configuredBasePrincipal: configuredBasePrincipal,
    );
    return breakdown.actualPrincipal;
  }

  /// Calculates interest amount
  double getCalculatedInterestAmount({
    double? loaneeLoanAmount,
    double? configuredInterestRate,
    double? configuredBasePrincipal,
  }) {
    if (interestAmount != null && interestAmount! > 0) {
      return interestAmount!;
    }
    final breakdown = getLoanBreakdown(
      loaneeLoanAmount: loaneeLoanAmount,
      configuredInterestRate: configuredInterestRate,
      configuredBasePrincipal: configuredBasePrincipal,
    );
    return breakdown.interestAmount;
  }

  /// Calculates total loan amount (including interest)
  double getCalculatedLoanAmount({
    double? loaneeLoanAmount,
    double? defaultBaseAmount,
  }) {
    if (loanAmount != null && loanAmount! > 0) {
      return loanAmount!;
    }
    if (loaneeLoanAmount != null && loaneeLoanAmount > 0) {
      return loaneeLoanAmount;
    }
    return defaultBaseAmount ?? 11500.0;
  }

  /// Formatted payable amount string e.g. "₹100 / Day", "₹500 / Day", "₹650 / Week"
  String getFormattedPayableAmount({
    double? loaneeLoanAmount,
    double? configuredInterestRate,
    double? configuredBasePrincipal,
    double? configuredBaseDailyAmount,
    double? configuredWeeklyInstallment,
  }) {
    final amt = getCalculatedPayableAmount(
      loaneeLoanAmount: loaneeLoanAmount,
      configuredInterestRate: configuredInterestRate,
      configuredBasePrincipal: configuredBasePrincipal,
      configuredBaseDailyAmount: configuredBaseDailyAmount,
      configuredWeeklyInstallment: configuredWeeklyInstallment,
    );
    final roundedAmt = double.parse(amt.toStringAsFixed(2));
    final freq = frequencyLabel;
    final formattedAmt = (roundedAmt % 1 == 0)
        ? roundedAmt.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')
        : roundedAmt.toStringAsFixed(2);
    return '₹$formattedAmt / $freq';
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'customer_id': customerId,
      'account_number': accountNumber,
      'loanee_name': loaneeName,
      'loanee_address': loaneeAddress,
      'collection_type': collectionType,
      'route': route,
      'mobile_no': mobileNo,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
    if (payableAmount != null) map['payable_amount'] = payableAmount;
    if (loanAmount != null) map['loan_amount'] = loanAmount;
    if (actualPrincipal != null) map['actual_principal'] = actualPrincipal;
    if (interestAmount != null) map['interest_amount'] = interestAmount;
    if (interestRate != null) map['interest_rate'] = interestRate;
    if (frequency != null) map['frequency'] = frequency;
    return map;
  }

  factory RoCollectionEntry.fromJson(Map<String, dynamic> json) {
    final double? pAmt = json['payable_amount'] != null
        ? (json['payable_amount'] as num).toDouble()
        : (json['payableAmount'] != null ? (json['payableAmount'] as num).toDouble() : null);
    final double? lAmt = json['loan_amount'] != null
        ? (json['loan_amount'] as num).toDouble()
        : (json['loanAmount'] != null ? (json['loanAmount'] as num).toDouble() : null);
    final double? aPrinc = json['actual_principal'] != null
        ? (json['actual_principal'] as num).toDouble()
        : (json['actualPrincipal'] != null ? (json['actualPrincipal'] as num).toDouble() : null);
    final double? iAmt = json['interest_amount'] != null
        ? (json['interest_amount'] as num).toDouble()
        : (json['interestAmount'] != null ? (json['interestAmount'] as num).toDouble() : null);
    final double? iRate = json['interest_rate'] != null
        ? (json['interest_rate'] as num).toDouble()
        : (json['interestRate'] != null ? (json['interestRate'] as num).toDouble() : null);
    final String? freq = json['frequency']?.toString();

    return RoCollectionEntry(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? json['customerId']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? json['accountNumber']?.toString() ?? '',
      loaneeName: json['loanee_name']?.toString() ?? json['loaneeName']?.toString() ?? '',
      loaneeAddress: json['loanee_address']?.toString() ?? json['loaneeAddress']?.toString() ?? '',
      collectionType: json['collection_type']?.toString() ?? json['collectionType']?.toString() ?? 'Daily',
      route: json['route']?.toString() ?? 'Mangang',
      mobileNo: json['mobile_no']?.toString() ?? json['mobileNo']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      status: json['status']?.toString() ?? 'Active',
      payableAmount: pAmt,
      loanAmount: lAmt,
      actualPrincipal: aPrinc,
      interestAmount: iAmt,
      interestRate: iRate,
      frequency: freq,
    );
  }
}
