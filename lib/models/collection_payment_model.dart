// lib/models/collection_payment_model.dart

import 'notification_model.dart';

class CollectionPaymentModel {
  final String id;
  final String collectionId; // Foreign key linking to ro_collection_entries.id
  final double paymentAmount;
  final double remainingBalance;
  final double lateFine;
  final double interest; // Total Interest amount added in this transaction / historical import
  final double postMaturityInterest; // Post maturity fine / interest amount
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
    this.postMaturityInterest = 0.0,
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

  /// Effective late fine for this payment:
  /// Uses lateFine if recorded (> 0), otherwise falls back to interest for historical records.
  double get effectiveLateFine => lateFine > 0 ? lateFine : interest;

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
      'interest': interest,
      'post_maturity_interest': postMaturityInterest,
      'payment_type': paymentType,
      'ro_passcode': roPasscode,
      'ro_name': roName,
      'ro_id': roId,
      'ro_route': roRoute,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'remarks': remarks,
    };
  }

  factory CollectionPaymentModel.fromJson(Map<String, dynamic> json) {
    double parsedInterest = (json['interest'] ?? json['interest_amount'] ?? json['interestAmount'] ?? 0.0).toDouble();
    double parsedLateFine = (json['late_fine'] ?? json['lateFine'] ?? json['late_payment_fee'] ?? json['latePaymentFee'] ?? 0.0).toDouble();
    double parsedPostMat = (json['post_maturity_interest'] ?? json['postMaturityInterest'] ?? 0.0).toDouble();

    final pId = json['id']?.toString() ?? '';
    final remStr = json['remarks']?.toString() ?? '';
    final isHistorical = pId.startsWith('PAY-HIST') || remStr.contains('Historical');

    if (json['remarks'] != null) {
      final rem = json['remarks'].toString();
      if (parsedPostMat == 0.0) {
        final pmMatch = RegExp(r'Post\s*Maturity(?:\s*(?:Fine|Interest))?:\s*₹?\s*([0-9.]+)').firstMatch(rem);
        if (pmMatch != null) {
          parsedPostMat = double.tryParse(pmMatch.group(1) ?? '') ?? 0.0;
        }
      }
      if (parsedLateFine == 0.0) {
        // Check for partial/cleared late fee note first: e.g. "Late Fee: ₹7.26 assessed..., ₹5.00 cleared, ₹2.26 carried forward"
        final clearedMatch = RegExp(r'₹?\s*([0-9.]+)\s*cleared', caseSensitive: false).firstMatch(rem);
        if (clearedMatch != null) {
          parsedLateFine = double.tryParse(clearedMatch.group(1) ?? '') ?? 0.0;
        } else if (!rem.toLowerCase().contains('assessed')) {
          // Standard late fee format: e.g. "Daily Late Fee: ₹3.63" or "Late Fee: ₹3.00"
          final lfMatch = RegExp(r'(?:Daily/Weekly\s*)?Late\s*(?:Payment\s*)?(?:Fee|Fine):\s*₹?\s*([0-9.]+)').firstMatch(rem);
          if (lfMatch != null) {
            parsedLateFine = double.tryParse(lfMatch.group(1) ?? '') ?? 0.0;
          }
        }
      }
      if (parsedInterest == 0.0) {
        // Only historical imports map late fee remarks to the interest column
        if (isHistorical) {
          final lfMatch = RegExp(r'(?:Daily/Weekly\s*)?Late\s*(?:Payment\s*)?(?:Fee|Fine|Interest):\s*₹?\s*([0-9.]+)').firstMatch(rem);
          if (lfMatch != null) {
            parsedInterest = double.tryParse(lfMatch.group(1) ?? '') ?? 0.0;
          }
        }
        if (parsedInterest == 0.0) {
          final match = RegExp(r'(?:^|[(,\s])(?:Total\s*)?Interest:\s*₹?\s*([0-9.]+)').firstMatch(rem);
          if (match != null) {
            final val = double.tryParse(match.group(1) ?? '') ?? 0.0;
            final isDuplicatedBug = parsedPostMat > 0 &&
                val == parsedPostMat &&
                rem.contains('Post Maturity: ₹${parsedPostMat.toStringAsFixed(2)}, Interest: ₹${parsedPostMat.toStringAsFixed(2)}');
            if (!isDuplicatedBug) {
              parsedInterest = val;
            }
          }
        }
      }
    }

    if (isHistorical && parsedInterest == 0.0 && parsedLateFine > 0.0) {
      parsedInterest = parsedLateFine;
      parsedLateFine = 0.0;
    }

    return CollectionPaymentModel(
      id: json['id']?.toString() ?? '',
      collectionId: json['collection_id']?.toString() ?? json['collectionId']?.toString() ?? '',
      paymentAmount: (json['payment_amount'] ?? json['amount'] ?? json['collected_amount'] ?? json['collectedAmount'] ?? 0.0).toDouble(),
      remainingBalance: (json['remaining_balance'] ?? json['remainingBalance'] ?? 0.0).toDouble(),
      lateFine: parsedLateFine,
      interest: parsedInterest,
      postMaturityInterest: parsedPostMat,
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
