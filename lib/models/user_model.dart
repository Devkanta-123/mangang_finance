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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobileNo': mobileNo,
      'userType': userType.toString(),
      'customerId': customerId,
      'roName': roName,
      'accountName': accountName,
    };
  }
}