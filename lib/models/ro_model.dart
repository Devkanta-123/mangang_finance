// lib/models/ro_model.dart

class RoAccount {
  final String customerid;
  final String accountnumber;
  final String roname;
  final String guardianname; // W/O, S/O, D/O
  final String address;
  final String designation; // Text input, NOT dropdown
  final String route; // Mapped Route from Master Table
  final String postoffice; // P/O
  final String policestation; // P/S
  final String district;
  final String pincode; // PIN
  final String mobileno;
  final String aadharno;
  final DateTime createdat;
  final String status;

  RoAccount({
    required this.customerid,
    required this.accountnumber,
    required this.roname,
    required this.guardianname,
    required this.address,
    required this.designation,
    this.route = '',
    required this.postoffice,
    required this.policestation,
    required this.district,
    required this.pincode,
    required this.mobileno,
    required this.aadharno,
    DateTime? createdat,
    this.status = 'Active',
  }) : createdat = createdat ?? DateTime.now();

  // Getters for camelCase & alias compatibility
  String get customerId => customerid;
  String get accountNumber => accountnumber;
  String get roName => roname;
  String get guardianName => guardianname;
  String get postOffice => postoffice;
  String get policeStation => policestation;
  String get pinCode => pincode;
  String get mobileNo => mobileno;
  String get aadharNo => aadharno;
  DateTime get createdAt => createdat;

  Map<String, dynamic> toJson() {
    return {
      'customerid': customerid,
      'accountnumber': accountnumber,
      'roname': roname,
      'guardianname': guardianname,
      'address': address,
      'designation': designation,
      'route': route,
      'postoffice': postoffice,
      'policestation': policestation,
      'district': district,
      'pincode': pincode,
      'mobileno': mobileno,
      'aadharno': aadharno,
      'createdat': createdat.toIso8601String(),
      'status': status,
    };
  }

  factory RoAccount.fromJson(Map<String, dynamic> json) {
    return RoAccount(
      customerid: json['customerid'] ?? json['customerId'] ?? '',
      accountnumber: json['accountnumber'] ?? json['accountNumber'] ?? '',
      roname: json['roname'] ?? json['roName'] ?? json['name'] ?? '',
      guardianname: json['guardianname'] ?? json['guardianName'] ?? '',
      address: json['address'] ?? '',
      designation: json['designation'] ?? '',
      route: json['route'] ?? json['routename'] ?? json['routeName'] ?? '',
      postoffice: json['postoffice'] ?? json['postOffice'] ?? '',
      policestation: json['policestation'] ?? json['policeStation'] ?? '',
      district: json['district'] ?? '',
      pincode: json['pincode'] ?? json['pinCode'] ?? '',
      mobileno: json['mobileno'] ?? json['mobileNo'] ?? '',
      aadharno: json['aadharno'] ?? json['aadharNo'] ?? '',
      createdat: json['createdat'] != null
          ? DateTime.parse(json['createdat'])
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
      status: json['status'] ?? 'Active',
    );
  }
}
