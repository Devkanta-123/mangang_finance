// lib/models/ro_collection_entry_model.dart

class RoCollectionEntry {
  final String id;
  final String customerId;
  final String accountNumber;
  final String loaneeName;
  final String loaneeAddress;
  final String collectionType; // Daily, Mon, Tue, Wed, Thur, Fri, Sat
  final double collectedAmount;
  final double remainingBalance;
  final double paymentAmount;
  final double lateFine;
  final String paymentType; // Cash, Paytm, Gpay, Phonepay, Other
  final String route; // Mangang, Luwang, Khuman, Angom, Moirang, etc.
  final String mobileNo;
  final DateTime createdAt;
  final String status; // 'Active', 'Collected', etc.

  RoCollectionEntry({
    required this.id,
    required this.customerId,
    required this.accountNumber,
    required this.loaneeName,
    required this.loaneeAddress,
    required this.collectionType,
    required this.collectedAmount,
    this.remainingBalance = 5000.0,
    this.paymentAmount = 0.0,
    this.lateFine = 0.0,
    this.paymentType = 'Cash',
    required this.route,
    required this.mobileNo,
    DateTime? createdAt,
    this.status = 'Active',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'account_number': accountNumber,
      'loanee_name': loaneeName,
      'loanee_address': loaneeAddress,
      'collection_type': collectionType,
      'collected_amount': collectedAmount,
      'remaining_balance': remainingBalance,
      'payment_amount': paymentAmount,
      'late_fine': lateFine,
      'payment_type': paymentType,
      'route': route,
      'mobile_no': mobileNo,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory RoCollectionEntry.fromJson(Map<String, dynamic> json) {
    return RoCollectionEntry(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? json['customerId'] ?? '',
      accountNumber: json['account_number'] ?? json['accountNumber'] ?? '',
      loaneeName: json['loanee_name'] ?? json['loaneeName'] ?? '',
      loaneeAddress: json['loanee_address'] ?? json['loaneeAddress'] ?? '',
      collectionType: json['collection_type'] ?? json['collectionType'] ?? 'Daily',
      collectedAmount: (json['collected_amount'] ?? json['collectedAmount'] ?? 0.0).toDouble(),
      remainingBalance: (json['remaining_balance'] ?? json['remainingBalance'] ?? 5000.0).toDouble(),
      paymentAmount: (json['payment_amount'] ?? json['paymentAmount'] ?? 0.0).toDouble(),
      lateFine: (json['late_fine'] ?? json['lateFine'] ?? 0.0).toDouble(),
      paymentType: json['payment_type'] ?? json['paymentType'] ?? 'Cash',
      route: json['route'] ?? 'Mangang',
      mobileNo: json['mobile_no'] ?? json['mobileNo'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
      status: json['status'] ?? 'Active',
    );
  }
}
