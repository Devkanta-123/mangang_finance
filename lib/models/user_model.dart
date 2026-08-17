enum UserType { admin, ro, loanee }

class User {
  final String name;
  final String mobileNo;
  final UserType userType;
  final String? customerId;
  final String? roName;
  final String? accountName;

  User({
    required this.name,
    required this.mobileNo,
    required this.userType,
    this.customerId,
    this.roName,
    this.accountName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    UserType parseUserType(String? val) {
      if (val == null) return UserType.loanee;
      final clean = val.toLowerCase().replaceAll('usertype.', '');
      if (clean == 'admin') return UserType.admin;
      if (clean == 'ro') return UserType.ro;
      return UserType.loanee;
    }

    return User(
      name: json['name']?.toString() ?? 'User',
      mobileNo: json['mobileNo']?.toString() ?? json['mobile_no']?.toString() ?? '',
      userType: parseUserType(json['userType']?.toString() ?? json['user_type']?.toString()),
      customerId: json['customerId']?.toString() ?? json['customer_id']?.toString(),
      roName: json['roName']?.toString() ?? json['ro_name']?.toString(),
      accountName: json['accountName']?.toString() ?? json['account_name']?.toString(),
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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory UserAuthRecord.fromJson(Map<String, dynamic> json) {
    UserType parseUserType(String? val) {
      if (val == null) return UserType.loanee;
      final clean = val.toLowerCase().replaceAll('usertype.', '');
      if (clean == 'admin') return UserType.admin;
      if (clean == 'ro') return UserType.ro;
      return UserType.loanee;
    }

    return UserAuthRecord(
      id: json['id']?.toString() ?? json['mobile_no']?.toString() ?? '',
      mobileNo: json['mobile_no']?.toString() ?? json['mobileNo']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? json['customerId']?.toString(),
      userType: parseUserType(json['user_type']?.toString() ?? json['userType']?.toString()),
      pin: json['pin']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      roName: json['ro_name']?.toString() ?? json['roName']?.toString(),
      accountName: json['account_name']?.toString() ?? json['accountName']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'mobile_no': mobileNo,
      'customer_id': customerId,
      'user_type': userType.name,
      'pin': pin,
      'name': name,
      'ro_name': roName,
      'account_name': accountName,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  User toUser() {
    return User(
      name: name,
      mobileNo: mobileNo,
      userType: userType,
      customerId: customerId,
      roName: roName,
      accountName: accountName,
    );
  }
}