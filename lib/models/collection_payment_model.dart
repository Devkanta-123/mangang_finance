// lib/models/collection_payment_model.dart

import 'notification_model.dart';

class CollectionPaymentModel {
  final String id;
  final String collectionId; // Foreign key linking to ro_collection_entries.id
  final double paymentAmount;
  final double remainingBalance;
  final double lateFine;
  final double interest; // Interest amount added in this transaction / historical import
  final String paymentType; // Cash, Paytm, Gpay, Phonepay, Other
  final String roPasscode; // 6 digits RO passcode
  final String? roName; // Name of RO who recorded the payment entry
  final String? roId; // Customer ID / mobile of RO
  final String? roRoute; // Assigned route of RO who collected the payment
  final DateTime createdAt;
  final String status;
  final String? remarks;

  CollectionPaymentModel({
    required this.id,
    required this.collectionId,
    required this.paymentAmount,
    this.remainingBalance = 0.0,
    this.lateFine = 0.0,
    this.interest = 0.0,
    this.paymentType = 'Cash',
    this.roPasscode = '',
    this.roName,
    this.roId,
    this.roRoute,
    DateTime? createdAt,
    this.status = 'Success',
    this.remarks,
  }) : createdAt = createdAt ?? DateTime.now();

  // Alias getter for backward compatibility
  double get amount => paymentAmount;

  /// Check if the payment entry was recorded directly by Administrator or for Office Master Route
  bool get isAdminOrOfficeEntry {
    final cleanId = roId?.toUpperCase().trim() ?? '';
    final cleanName = roName?.toLowerCase().trim() ?? '';
    final cleanRoute = roRoute?.toLowerCase().trim() ?? '';
    final cleanRemarks = remarks?.toLowerCase().trim() ?? '';
    return cleanId.startsWith('ADM') ||
        cleanName.contains('admin') ||
        cleanRoute == 'office' ||
        cleanRemarks.contains('admin') ||
        cleanRemarks.contains('office master');
  }

  /// Full descriptive attribution name
  String get recordedByDisplayName {
    if (isAdminOrOfficeEntry) {
      final name = (roName != null && roName!.isNotEmpty) ? roName! : 'Administrator';
      return '$name (Admin • Office Route)';
    }
    return (roName != null && roName!.isNotEmpty) ? roName! : 'RO Officer';
  }

  /// Short badge label for tables and lists
  String get recordedByShortLabel {
    if (isAdminOrOfficeEntry) {
      return 'Admin (Office)';
    }
    return (roName != null && roName!.isNotEmpty) ? roName! : 'RO Officer';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection_id': collectionId,
      'payment_amount': paymentAmount,
      'remaining_balance': remainingBalance,
      'late_fine': lateFine,
      'payment_type': paymentType,
      'ro_passcode': roPasscode,
      if (roName != null) 'ro_name': roName,
      if (roId != null) 'ro_id': roId,
      if (roRoute != null) 'ro_route': roRoute,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'remarks': remarks,
    };
  }

  factory CollectionPaymentModel.fromJson(Map<String, dynamic> json) {
    double parsedInterest = (json['interest'] ?? json['interest_amount'] ?? json['interestAmount'] ?? 0.0).toDouble();
    if (parsedInterest == 0.0 && json['remarks'] != null) {
      final rem = json['remarks'].toString();
      final match = RegExp(r'Interest:\s*₹?\s*([0-9.]+)').firstMatch(rem);
      if (match != null) {
        parsedInterest = double.tryParse(match.group(1) ?? '') ?? 0.0;
      }
    }

    return CollectionPaymentModel(
      id: json['id']?.toString() ?? '',
      collectionId: json['collection_id']?.toString() ?? json['collectionId']?.toString() ?? '',
      paymentAmount: (json['payment_amount'] ?? json['amount'] ?? json['collected_amount'] ?? json['collectedAmount'] ?? 0.0).toDouble(),
      remainingBalance: (json['remaining_balance'] ?? json['remainingBalance'] ?? 0.0).toDouble(),
      lateFine: (json['late_fine'] ?? json['lateFine'] ?? 0.0).toDouble(),
      interest: parsedInterest,
      paymentType: json['payment_type']?.toString() ?? json['paymentType']?.toString() ?? 'Cash',
      roPasscode: json['ro_passcode']?.toString() ?? json['roPasscode']?.toString() ?? '',
      roName: json['ro_name']?.toString() ?? json['roName']?.toString() ?? json['recorded_by']?.toString() ?? json['recordedBy']?.toString(),
      roId: json['ro_id']?.toString() ?? json['roId']?.toString(),
      roRoute: json['ro_route']?.toString() ?? json['roRoute']?.toString(),
      createdAt: AppNotification.parseDateTime(json['created_at'] ?? json['createdAt']),
      status: json['status']?.toString() ?? 'Success',
      remarks: json['remarks']?.toString(),
    );
  }
}

/// Encapsulates paginated collection payment history results from query
class PaginatedPaymentsResult {
  final List<CollectionPaymentModel> payments;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedPaymentsResult({
    required this.payments,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  }) : totalPages = totalCount > 0 ? (totalCount / pageSize).ceil() : 1;

  bool get hasPreviousPage => page > 1;
  bool get hasNextPage => page < totalPages;
}
