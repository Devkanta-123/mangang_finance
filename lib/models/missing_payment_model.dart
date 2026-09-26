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
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDaily => collectionType.toLowerCase().trim() == 'daily';
  bool get isWeekly => !isDaily;
  bool get isResolved => status.toLowerCase().trim() == 'resolved';
  bool get isPartial => status.toLowerCase().trim() == 'partially_resolved' || (dayPayment > 0 && missingPay > 0);

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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MissingPaymentRecord.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      final str = val.toString().trim();
      return DateTime.tryParse(str) ?? DateTime.now();
    }

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
      missedDate: parseDate(json['missed_date'] ?? json['missedDate']),
      dayPayment: parseNum(json['day_payment'] ?? json['dayPayment']),
      missingPay: parseNum(json['missing_pay'] ?? json['missingPay']),
      missingFine: parseNum(json['missing_fine'] ?? json['missingFine']),
      missingWeek: parseInt(json['missing_week'] ?? json['missingWeek']),
      missingBalance: parseNum(json['missing_balance'] ?? json['missingBalance']),
      status: json['status']?.toString() ?? 'missing',
      source: json['source']?.toString() ?? 'system',
      remarks: json['remarks']?.toString(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
