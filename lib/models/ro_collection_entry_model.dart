// lib/models/ro_collection_entry_model.dart

class RoCollectionEntry {
  final String id;
  final String customerId;
  final String accountNumber;
  final String loaneeName;
  final String loaneeAddress;
  final String collectionType; // Daily, Mon, Tue, Wed, Thur, Fri, Sat
  final String route; // Mangang, Luwang, Khuman, Angom, Moirang, etc.
  final String mobileNo;
  final DateTime createdAt;
  final String status; // 'Active', etc.

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
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
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
  }

  factory RoCollectionEntry.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
