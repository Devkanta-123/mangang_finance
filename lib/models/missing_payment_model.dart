// lib/models/missing_payment_model.dart

/// Dedicated data model for Missing Payment Records stored in 'missing_payment_records' table.
/// Architecture Principle: MISSING != PAYMENT.
/// Missing records represent assessed missed payment logs and must not appear in ro_collection_payments.
class MissingPaymentRecord {
  final String id;
  final String? accountId;
  final String collectionId;
  final String? loaneeId;
  final String? customerId;
  final String? accountNo;
  final String loaneeName;
  final String? mobileNo;
  final String? route;
  final String collectionType; // 'daily' or 'weekly'
  final DateTime missedDate;
  final double dayPayment;
  final double missingPay;
  final double missingFine;
  final int missingWeek;
  final double missingBalance;
  final String status; // 'missing', 'partially_resolved', 'resolved'
  final String source; // 'system'
  final String? remarks;
  final DateTime? paidDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MissingPaymentRecord({
    required this.id,
    this.accountId,
    required this.collectionId,
    this.loaneeId,
    this.customerId,
    this.accountNo,
    required this.loaneeName,
    this.mobileNo,
    this.route,
    required this.collectionType,
    required this.missedDate,
    this.dayPayment = 0.0,
    this.missingPay = 0.0,
    this.missingFine = 0.0,
    this.missingWeek = 0,
    this.missingBalance = 0.0,
    this.status = 'missing',
    this.source = 'system',
    this.remarks,
    this.paidDate,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDaily => collectionType.toLowerCase().trim() == 'daily';
  bool get isWeekly => !isDaily;
  bool get isResolved =>
      status.toLowerCase().trim() == 'resolved' ||
      status.toLowerCase().trim() == 'cleared' ||
      status.toLowerCase().trim() == 'paid' ||
      paidDate != null;
  bool get isPaidOrLocked => isResolved || paidDate != null;
  bool get isPartial =>
      !isResolved &&
      (status.toLowerCase().trim() == 'partially_resolved' ||
          status.toLowerCase().trim() == 'partial' ||
          status.toLowerCase().trim() == 'partial paid' ||
          status.toLowerCase().trim() == 'partially paid' ||
          (dayPayment > 0 && missingPay > 0));
  bool get isPaused => status.toLowerCase().trim() == 'paused';

  /// Calculates the number of missing weeks elapsed from missedDate to asOfDate.
  /// Rule:
  /// - Days 1 to 7: 1 week (e.g. 7 days = 1 week)
  /// - Days 8 to 14: 2 weeks (e.g. 10 days = 2 weeks)
  /// - Days 15 to 21: 3 weeks
  /// - Formula: (daysPast / 7.0).ceil().clamp(1, 52)
  static int calculateWeeks({
    required DateTime missedDate,
    DateTime? asOfDate,
  }) {
    final cleanMissed = DateTime(missedDate.year, missedDate.month, missedDate.day);
    final targetDate = asOfDate ?? DateTime.now();
    final cleanTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final int daysPast = cleanTarget.difference(cleanMissed).inDays;
    if (daysPast <= 0) return 1;
    return (daysPast / 7.0).ceil().clamp(1, 52);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'collection_id': collectionId,
      'loanee_id': loaneeId,
      'customer_id': customerId,
      'account_no': accountNo,
      'loanee_name': loaneeName,
      'mobile_no': mobileNo,
      'route': route,
      'collection_type': collectionType,
      'missed_date': '${missedDate.year}-${missedDate.month.toString().padLeft(2, '0')}-${missedDate.day.toString().padLeft(2, '0')}',
      'day_payment': dayPayment,
      'missing_pay': missingPay,
      'missing_fine': missingFine,
      'missing_week': missingWeek,
      'missing_balance': missingBalance,
      'status': status,
      'source': source,
      'remarks': remarks,
      'paid_date': paidDate != null
          ? '${paidDate!.year}-${paidDate!.month.toString().padLeft(2, '0')}-${paidDate!.day.toString().padLeft(2, '0')}'
          : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Robust calendar date parser capable of handling ISO strings, Postgres dates,
  /// timestamps, and delimited dates without corrupting the calendar day via .toLocal().
  /// Rule: A calendar day (e.g. 2026-09-28) must evaluate identically across all Android models and timezones.
  static DateTime parseCalendarDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return DateTime(val.year, val.month, val.day);
    if (val is num) {
      if (val > 1000 && val < 100000) {
        final base = DateTime(1899, 12, 30);
        return base.add(Duration(days: val.toInt()));
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(val.toInt());
      return DateTime(dt.year, dt.month, dt.day);
    }
    final str = val.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return DateTime.now();

    // 1. Standard ISO-8601 YYYY-MM-DD (e.g. "2026-09-28", "2026-09-28T00:00:00+00:00", "2026-09-28 12:00:00")
    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(str);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // 2. Delimited formats (DD/MM/YYYY, DD-MM-YYYY, YYYY/MM/DD)
    final parts = str.split(RegExp(r'[-/.\s]')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3) {
      final p0 = int.tryParse(parts[0]);
      final p1 = int.tryParse(parts[1]);
      final p2 = int.tryParse(parts[2]);
      if (p0 != null && p1 != null && p2 != null) {
        if (p0 > 1000) {
          return DateTime(p0, p1, p2);
        } else if (p2 > 1000) {
          return DateTime(p2, p1, p0);
        }
      }
    }

    final dt = DateTime.tryParse(str);
    if (dt != null) {
      return DateTime(dt.year, dt.month, dt.day);
    }
    return DateTime.now();
  }

  static DateTime? parseNullableCalendarDate(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;
    return parseCalendarDate(val);
  }

  factory MissingPaymentRecord.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 0;
    }

    final rawRemarks = json['remarks']?.toString();
    DateTime? resolvedPaidDate = parseNullableCalendarDate(json['paid_date'] ?? json['paidDate']);
    if (resolvedPaidDate == null && rawRemarks != null && rawRemarks.contains('PAID_DATE:')) {
      final match = RegExp(r'PAID_DATE:([^\s\]]+)').firstMatch(rawRemarks);
      if (match != null) {
        resolvedPaidDate = parseCalendarDate(match.group(1)!);
      }
    }

    final double dayPaymentVal = parseNum(json['day_payment'] ?? json['dayPayment']);
    double missingPayVal = parseNum(json['missing_pay'] ?? json['missingPay']);
    final statusStr = json['status']?.toString() ?? 'missing';
    final isPaidOrResolved = statusStr.toLowerCase().trim() == 'resolved' ||
        statusStr.toLowerCase().trim() == 'cleared' ||
        statusStr.toLowerCase().trim() == 'paid' ||
        resolvedPaidDate != null;

    // Requirement: Basic pay must NOT become zero when paid.
    // If it was stored as 0 in older records, restore the old amount from dayPayment or remarks.
    if (missingPayVal <= 0.0 && isPaidOrResolved) {
      if (dayPaymentVal > 0.0) {
        missingPayVal = dayPaymentVal;
      } else if (rawRemarks != null) {
        final payMatch = RegExp(r'(?:Missing Pay|Paid)\s*₹?\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(rawRemarks);
        if (payMatch != null) {
          missingPayVal = double.tryParse(payMatch.group(1)!) ?? 0.0;
        }
      }
    }

    return MissingPaymentRecord(
      id: json['id']?.toString() ?? '',
      accountId: json['account_id']?.toString() ?? json['accountId']?.toString(),
      collectionId: json['collection_id']?.toString() ?? json['collectionId']?.toString() ?? '',
      loaneeId: json['loanee_id']?.toString() ?? json['loaneeId']?.toString(),
      customerId: json['customer_id']?.toString() ?? json['customerId']?.toString(),
      accountNo: json['account_no']?.toString() ?? json['accountNo']?.toString(),
      loaneeName: json['loanee_name']?.toString() ?? json['loaneeName']?.toString() ?? 'Loanee',
      mobileNo: json['mobile_no']?.toString() ?? json['mobileNo']?.toString(),
      route: json['route']?.toString(),
      collectionType: json['collection_type']?.toString() ?? json['collectionType']?.toString() ?? 'daily',
      missedDate: parseCalendarDate(json['missed_date'] ?? json['missedDate']),
      dayPayment: dayPaymentVal,
      missingPay: missingPayVal,
      missingFine: parseNum(json['missing_fine'] ?? json['missingFine']),
      missingWeek: parseInt(json['missing_week'] ?? json['missingWeek']),
      missingBalance: parseNum(json['missing_balance'] ?? json['missingBalance']),
      status: json['status']?.toString() ?? 'missing',
      source: json['source']?.toString() ?? 'system',
      remarks: rawRemarks,
      paidDate: resolvedPaidDate,
      createdAt: parseCalendarDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseCalendarDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  MissingPaymentRecord copyWith({
    String? id,
    String? accountId,
    String? collectionId,
    String? loaneeId,
    String? customerId,
    String? accountNo,
    String? loaneeName,
    String? mobileNo,
    String? route,
    String? collectionType,
    DateTime? missedDate,
    double? dayPayment,
    double? missingPay,
    double? missingFine,
    int? missingWeek,
    double? missingBalance,
    String? status,
    String? source,
    String? remarks,
    DateTime? paidDate,
    bool clearPaidDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MissingPaymentRecord(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      collectionId: collectionId ?? this.collectionId,
      loaneeId: loaneeId ?? this.loaneeId,
      customerId: customerId ?? this.customerId,
      accountNo: accountNo ?? this.accountNo,
      loaneeName: loaneeName ?? this.loaneeName,
      mobileNo: mobileNo ?? this.mobileNo,
      route: route ?? this.route,
      collectionType: collectionType ?? this.collectionType,
      missedDate: missedDate ?? this.missedDate,
      dayPayment: dayPayment ?? this.dayPayment,
      missingPay: missingPay ?? this.missingPay,
      missingFine: missingFine ?? this.missingFine,
      missingWeek: missingWeek ?? this.missingWeek,
      missingBalance: missingBalance ?? this.missingBalance,
      status: status ?? this.status,
      source: source ?? this.source,
      remarks: remarks ?? this.remarks,
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
