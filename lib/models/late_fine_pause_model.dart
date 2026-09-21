// lib/models/late_fine_pause_model.dart

class LateFinePauseModel {
  final String id;
  final String collectionId;
  final String? customerId;
  final String? accountNumber;
  final String loaneeName;
  final DateTime fromDate;
  final DateTime toDate;
  final String? reason;
  final String? pausedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  LateFinePauseModel({
    required this.id,
    required this.collectionId,
    this.customerId,
    this.accountNumber,
    required this.loaneeName,
    required this.fromDate,
    required this.toDate,
    this.reason,
    this.pausedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Normalized from date (00:00:00)
  DateTime get cleanFromDate => DateTime(fromDate.year, fromDate.month, fromDate.day);

  /// Normalized to date (00:00:00)
  DateTime get cleanToDate => DateTime(toDate.year, toDate.month, toDate.day);

  /// Total days included in this pause period (inclusive)
  int get totalDays => cleanToDate.difference(cleanFromDate).inDays + 1;

  /// Check if a specific date falls within this pause range (inclusive of from and to dates)
  bool isDatePaused(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return !clean.isBefore(cleanFromDate) && !clean.isAfter(cleanToDate);
  }

  /// Check if the pause is active today
  bool isCurrentlyActive([DateTime? now]) {
    final today = now ?? DateTime.now();
    return isDatePaused(today);
  }

  /// Check if the pause date range has expired (today is past toDate)
  bool isExpired([DateTime? now]) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    return cleanToday.isAfter(cleanToDate);
  }

  /// Check if the pause is scheduled for the future
  bool isUpcoming([DateTime? now]) {
    final today = now ?? DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    return cleanToday.isBefore(cleanFromDate);
  }

  /// Human-readable status label
  String get statusLabel {
    if (isCurrentlyActive()) return 'Active';
    if (isExpired()) return 'Expired';
    return 'Upcoming';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection_id': collectionId,
      'customer_id': customerId,
      'account_number': accountNumber,
      'loanee_name': loaneeName,
      'from_date': '${cleanFromDate.year.toString().padLeft(4, '0')}-${cleanFromDate.month.toString().padLeft(2, '0')}-${cleanFromDate.day.toString().padLeft(2, '0')}',
      'to_date': '${cleanToDate.year.toString().padLeft(4, '0')}-${cleanToDate.month.toString().padLeft(2, '0')}-${cleanToDate.day.toString().padLeft(2, '0')}',
      'reason': reason,
      'paused_by': pausedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LateFinePauseModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null) {
        final str = val.toString().trim();
        final parsed = DateTime.tryParse(str);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final rawFrom = json['from_date'] ?? json['fromDate'];
    final rawTo = json['to_date'] ?? json['toDate'];

    return LateFinePauseModel(
      id: json['id']?.toString() ?? '',
      collectionId: json['collection_id']?.toString() ?? json['collectionId']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? json['customerId']?.toString(),
      accountNumber: json['account_number']?.toString() ?? json['accountNumber']?.toString(),
      loaneeName: json['loanee_name']?.toString() ?? json['loaneeName']?.toString() ?? '',
      fromDate: parseDate(rawFrom),
      toDate: parseDate(rawTo),
      reason: json['reason']?.toString(),
      pausedBy: json['paused_by']?.toString() ?? json['pausedBy']?.toString(),
      createdAt: json['created_at'] != null ? parseDate(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : DateTime.now(),
    );
  }

  LateFinePauseModel copyWith({
    String? id,
    String? collectionId,
    String? customerId,
    String? accountNumber,
    String? loaneeName,
    DateTime? fromDate,
    DateTime? toDate,
    String? reason,
    String? pausedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LateFinePauseModel(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      customerId: customerId ?? this.customerId,
      accountNumber: accountNumber ?? this.accountNumber,
      loaneeName: loaneeName ?? this.loaneeName,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      reason: reason ?? this.reason,
      pausedBy: pausedBy ?? this.pausedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
