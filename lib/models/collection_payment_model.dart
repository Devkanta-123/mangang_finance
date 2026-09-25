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

  /// Check if this is a historical Excel imported transaction
  bool get isHistorical => id.startsWith('PAY-HIST') || (remarks != null && remarks!.contains('Historical'));

  /// Effective late fine for this payment:
  /// Uses lateFine if recorded (> 0), otherwise falls back to interest for historical records.
  double get effectiveLateFine => lateFine > 0 ? lateFine : interest;

  /// Total charges recorded on this payment that directly impact loan remaining balance:
  /// - Includes partial payment charges on unpaid base installments (stored in interest)
  /// - For historical payments, falls back to lateFine if interest is 0.
  double get balanceImpactingCharge {
    if (interest > 0) return interest;
    if (isHistorical && lateFine > 0) return lateFine;
    return 0.0;
  }

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

  /// Checks if this payment transaction has hybrid collection modes
  bool get isHybridPayment {
    if (paymentType.contains(',')) return true;
    if (paymentType.contains('-') && RegExp(r'\d').hasMatch(paymentType)) return true;
    if ((paymentType.toLowerCase() == 'other' || paymentType.toLowerCase() == 'hybrid') &&
        remarks != null &&
        remarks!.contains('Hybrid Split:')) {
      return true;
    }
    return false;
  }

  /// Formats the payment mode to display modes with amounts if hybrid (e.g. "Cash-150, Gpay-150")
  String get formattedPaymentMode {
    if (!isHybridPayment) {
      return paymentType;
    }

    // 1. If remarks has "Hybrid Split:", extract and format mode with amounts
    if (remarks != null && remarks!.contains('Hybrid Split:')) {
      final match = RegExp(r'Hybrid Split:\s*([^|]+)', caseSensitive: false).firstMatch(remarks!);
      if (match != null) {
        final splitStr = match.group(1)?.trim() ?? '';
        final formatted = _formatHybridSplitModesString(splitStr);
        if (formatted.isNotEmpty) {
          return formatted;
        }
      }
    }

    // 2. If paymentType contains hyphen/colon/equal with digits
    if (paymentType.contains('-') || paymentType.contains(':') || paymentType.contains('=')) {
      if (RegExp(r'\d').hasMatch(paymentType)) {
        return _formatHybridSplitModesString(paymentType);
      }
    }

    // 3. Fallback to raw paymentType
    return paymentType;
  }

  /// Extracts hybrid split breakdown text from payment remarks or paymentType if available
  String? get hybridSplitBreakdown {
    if (remarks != null && remarks!.contains('Hybrid Split:')) {
      final match = RegExp(r'Hybrid Split:\s*([^|]+)', caseSensitive: false).firstMatch(remarks!);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    if (isHybridPayment) {
      return formattedPaymentMode;
    }
    return null;
  }

  /// Helper to convert a hybrid string with amounts into "Mode-Amount, Mode-Amount"
  static String _formatHybridSplitModesString(String raw) {
    final parts = raw.split(',');
    final formatted = <String>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // Matches "Cash: ₹150.00" or "Cash=150" or "Cash: 150"
      final match = RegExp(r'^([^:=]+)\s*[:=]\s*₹?\s*([\d,]+(?:\.\d+)?)$').firstMatch(trimmed);
      if (match != null) {
        final mode = match.group(1)!.trim();
        final rawAmt = match.group(2)!.replaceAll(',', '');
        final amt = double.tryParse(rawAmt);
        final amtStr = (amt != null && amt % 1 == 0)
            ? amt.toInt().toString()
            : (amt != null ? amt.toStringAsFixed(2) : rawAmt);
        formatted.add('$mode-$amtStr');
        continue;
      }

      // Matches "Cash-150" or "Cash - 150" or "Cash-150.00"
      final dashMatch = RegExp(r'^([A-Za-z\s]+)\s*-\s*₹?\s*([\d,]+(?:\.\d+)?)$').firstMatch(trimmed);
      if (dashMatch != null) {
        final mode = dashMatch.group(1)!.trim();
        final rawAmt = dashMatch.group(2)!.replaceAll(',', '');
        final amt = double.tryParse(rawAmt);
        final amtStr = (amt != null && amt % 1 == 0)
            ? amt.toInt().toString()
            : (amt != null ? amt.toStringAsFixed(2) : rawAmt);
        formatted.add('$mode-$amtStr');
        continue;
      }

      formatted.add(trimmed);
    }
    return formatted.isNotEmpty ? formatted.join(', ') : raw;
  }


  CollectionPaymentModel copyWith({
    String? id,
    String? collectionId,
    double? paymentAmount,
    double? remainingBalance,
    double? lateFine,
    double? interest,
    double? postMaturityInterest,
    String? paymentType,
    String? roPasscode,
    String? roName,
    String? roId,
    String? roRoute,
    DateTime? createdAt,
    String? status,
    String? remarks,
  }) {
    return CollectionPaymentModel(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      lateFine: lateFine ?? this.lateFine,
      interest: interest ?? this.interest,
      postMaturityInterest: postMaturityInterest ?? this.postMaturityInterest,
      paymentType: paymentType ?? this.paymentType,
      roPasscode: roPasscode ?? this.roPasscode,
      roName: roName ?? this.roName,
      roId: roId ?? this.roId,
      roRoute: roRoute ?? this.roRoute,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
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
        if (parsedInterest == 0.0) {
          final partialMatch = RegExp(r'(?:Partial\s*(?:Payment|Base)|unpaid\s*\+\s*₹?\s*[0-9.]+).*?₹?\s*([0-9.]+)\s*fee', caseSensitive: false).firstMatch(rem);
          if (partialMatch != null) {
            parsedInterest = double.tryParse(partialMatch.group(1) ?? '') ?? 0.0;
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
