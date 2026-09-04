enum UserType { admin, manager, ro, loanee }

class User {
  final String name;
  final String mobileNo;
  final UserType userType;
  final String? customerId;
  final String? roName;
  final String? accountName;
  final String status;

  User({
    required this.name,
    required this.mobileNo,
    required this.userType,
    this.customerId,
    this.roName,
    this.accountName,
    this.status = 'Active',
  });

  bool get isActive {
    final s = status.trim().toLowerCase();
    return s != 'inactive' && s != 'false' && s != 'disabled' && s != 'deactivated';
  }

  User copyWith({
    String? name,
    String? mobileNo,
    UserType? userType,
    String? customerId,
    String? roName,
    String? accountName,
    String? status,
  }) {
    return User(
      name: name ?? this.name,
      mobileNo: mobileNo ?? this.mobileNo,
      userType: userType ?? this.userType,
      customerId: customerId ?? this.customerId,
      roName: roName ?? this.roName,
      accountName: accountName ?? this.accountName,
      status: status ?? this.status,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    UserType parseUserType(String? val) {
      if (val == null) return UserType.loanee;
      final clean = val.toLowerCase().replaceAll('usertype.', '');
      if (clean == 'admin') return UserType.admin;
      if (clean == 'manager') return UserType.manager;
      if (clean == 'ro') return UserType.ro;
      return UserType.loanee;
    }

    final rawStatus = json['status']?.toString();
    final bool isInactiveBool = json['is_active'] == false || json['isActive'] == false;
    String statusVal = 'Active';
    if (rawStatus != null && rawStatus.isNotEmpty) {
      statusVal = rawStatus;
    }
    if (isInactiveBool || statusVal.toLowerCase() == 'inactive' || statusVal.toLowerCase() == 'false') {
      statusVal = 'Inactive';
    }

    return User(
      name: json['name']?.toString() ?? 'User',
      mobileNo: json['mobileNo']?.toString() ?? json['mobile_no']?.toString() ?? '',
      userType: parseUserType(json['userType']?.toString() ?? json['user_type']?.toString()),
      customerId: json['customerId']?.toString() ?? json['customer_id']?.toString(),
      roName: json['roName']?.toString() ?? json['ro_name']?.toString(),
      accountName: json['accountName']?.toString() ?? json['account_name']?.toString(),
      status: statusVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobileNo': mobileNo,
      'userType': userType.name,
      'customerId': customerId,
      'roName': roName,
      'accountName': accountName,
      'status': status,
    };
  }
}

class UserAuthRecord {
  final String id;
  final String mobileNo;
  final String? customerId;
  final UserType userType;
  final String pin;
  final String name;
  final String? roName;
  final String? accountName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAuthRecord({
    required this.id,
    required this.mobileNo,
    this.customerId,
    required this.userType,
    required this.pin,
    required this.name,
    this.roName,
    this.accountName,
    this.status = 'Active',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive {
    final s = status.trim().toLowerCase();
    return s != 'inactive' && s != 'false' && s != 'disabled' && s != 'deactivated';
  }

  static UserType parseUserType(String? val) {
    if (val == null) return UserType.loanee;
    final clean = val.toLowerCase().replaceAll('usertype.', '');
    if (clean == 'admin') return UserType.admin;
    if (clean == 'manager') return UserType.manager;
    if (clean == 'ro') return UserType.ro;
    return UserType.loanee;
  }

  UserAuthRecord copyWith({
    String? id,
    String? mobileNo,
    String? customerId,
    UserType? userType,
    String? pin,
    String? name,
    String? roName,
    String? accountName,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAuthRecord(
      id: id ?? this.id,
      mobileNo: mobileNo ?? this.mobileNo,
      customerId: customerId ?? this.customerId,
      userType: userType ?? this.userType,
      pin: pin ?? this.pin,
      name: name ?? this.name,
      roName: roName ?? this.roName,
      accountName: accountName ?? this.accountName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserAuthRecord.fromJson(Map<String, dynamic> json) {
    final custId = json['customer_id']?.toString() ?? json['customerId']?.toString();
    final rawId = json['id']?.toString();
    final effectiveId = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : (custId != null && custId.isNotEmpty ? custId : (json['mobile_no']?.toString() ?? json['mobileNo']?.toString() ?? ''));

    final rawStatus = json['status']?.toString();
    final bool isInactiveBool = json['is_active'] == false || json['isActive'] == false;
    String statusVal = 'Active';
    if (rawStatus != null && rawStatus.isNotEmpty) {
      statusVal = rawStatus;
    }
    if (isInactiveBool || statusVal.toLowerCase() == 'inactive' || statusVal.toLowerCase() == 'false') {
      statusVal = 'Inactive';
    }

    return UserAuthRecord(
      id: effectiveId,
      mobileNo: json['mobile_no']?.toString() ?? json['mobileNo']?.toString() ?? '',
      customerId: custId,
      userType: parseUserType(json['user_type']?.toString() ?? json['userType']?.toString()),
      pin: json['pin']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      roName: json['ro_name']?.toString() ?? json['roName']?.toString(),
      accountName: json['account_name']?.toString() ?? json['accountName']?.toString(),
      status: statusVal,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseJson({bool includeId = false}) {
    final map = <String, dynamic>{
      'mobile_no': mobileNo.trim(),
      'user_type': userType.name,
      'pin': pin.trim(),
      'name': name.trim(),
      'ro_name': roName,
      'account_name': accountName,
      'status': status,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (customerId != null && customerId!.trim().isNotEmpty) {
      map['customer_id'] = customerId!.trim();
    }

    final numericId = int.tryParse(id.trim());
    if (numericId != null) {
      map['id'] = numericId;
    } else if (includeId && id.trim().isNotEmpty) {
      map['id'] = id.trim();
    }

    return map;
  }

  User toUser() {
    return User(
      name: name,
      mobileNo: mobileNo,
      userType: userType,
      customerId: customerId,
      roName: roName,
      accountName: accountName,
      status: status,
    );
  }
}