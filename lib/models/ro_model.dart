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
  bool get isActive => status.toLowerCase() != 'inactive';

  RoAccount copyWith({
    String? customerid,
    String? accountnumber,
    String? roname,
    String? guardianname,
    String? address,
    String? designation,
    String? route,
    String? postoffice,
    String? policestation,
    String? district,
    String? pincode,
    String? mobileno,
    String? aadharno,
    DateTime? createdat,
    String? status,
  }) {
    return RoAccount(
      customerid: customerid ?? this.customerid,
      accountnumber: accountnumber ?? this.accountnumber,
      roname: roname ?? this.roname,
      guardianname: guardianname ?? this.guardianname,
      address: address ?? this.address,
      designation: designation ?? this.designation,
      route: route ?? this.route,
      postoffice: postoffice ?? this.postoffice,
      policestation: policestation ?? this.policestation,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      mobileno: mobileno ?? this.mobileno,
      aadharno: aadharno ?? this.aadharno,
      createdat: createdat ?? this.createdat,
      status: status ?? this.status,
    );
  }

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

  static String _parseString(dynamic val, [String defaultVal = '']) {
    if (val == null) return defaultVal;
    return val.toString();
  }

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString()) ?? DateTime.now();
  }

  static String _parseStatus(dynamic val) {
    if (val == null) return 'Active';
    if (val is bool) return val ? 'Active' : 'Inactive';
    final s = val.toString().trim();
    if (s.isEmpty) return 'Active';
    return s;
  }

  factory RoAccount.fromJson(Map<String, dynamic> json) {
    return RoAccount(
      customerid: _parseString(
        json['customerid'] ?? json['customerId'] ?? json['customer_id'] ?? json['id'],
      ),
      accountnumber: _parseString(
        json['accountnumber'] ?? json['accountNumber'] ?? json['account_number'] ?? json['account_no'] ?? json['acc_no'],
      ),
      roname: _parseString(
        json['roname'] ?? json['roName'] ?? json['ro_name'] ?? json['name'] ?? json['officer_name'],
      ),
      guardianname: _parseString(
        json['guardianname'] ?? json['guardianName'] ?? json['guardian_name'] ?? json['father_name'] ?? json['fathername'],
      ),
      address: _parseString(
        json['address'] ?? json['addr'] ?? json['ro_address'],
      ),
      designation: _parseString(
        json['designation'] ?? json['role'] ?? json['desig'],
        'RO Officer',
      ),
      route: _parseString(
        json['route'] ?? json['routename'] ?? json['routeName'] ?? json['route_name'] ?? json['assigned_route'],
      ),
      postoffice: _parseString(
        json['postoffice'] ?? json['postOffice'] ?? json['post_office'] ?? json['po'],
      ),
      policestation: _parseString(
        json['policestation'] ?? json['policeStation'] ?? json['police_station'] ?? json['ps'],
      ),
      district: _parseString(
        json['district'] ?? json['dist'],
        'Imphal West',
      ),
      pincode: _parseString(
        json['pincode'] ?? json['pinCode'] ?? json['pin_code'] ?? json['pin'] ?? json['zip'],
      ),
      mobileno: _parseString(
        json['mobileno'] ?? json['mobileNo'] ?? json['mobile_no'] ?? json['mobile'] ?? json['phone'],
      ),
      aadharno: _parseString(
        json['aadharno'] ?? json['aadharNo'] ?? json['aadhar_no'] ?? json['aadhar'] ?? json['aadhaar'],
      ),
      createdat: _parseDate(
        json['createdat'] ?? json['createdAt'] ?? json['created_at'] ?? json['creation_date'],
      ),
      status: _parseStatus(
        json['status'] ?? json['is_active'] ?? json['isActive'],
      ),
    );
  }
}
