// lib/models/loanee_model.dart

class LoaneeAccount {
  final String customerid;
  final String accountnumber;
  final String loaneename;
  final String guardianname; // W/O, S/O, D/O
  final String address;
  final String businesstype;
  final String postoffice; // P/O
  final String policestation; // P/S
  final String district;
  final String pincode; // PIN
  final String mobileno;
  final String aadharno;
  final DateTime createdat;
  final String status;
  final double loanamount;
  final double paidamount;
  final double dueamount;

  // Witness Details
  final String witnessname;
  final String witnessguardianname; // W/O, S/O, D/O
  final String witnessaddress;
  final String witnessbusinesstype;
  final String witnesspostoffice; // P/O
  final String witnesspolicestation; // P/S
  final String witnessdistrict;
  final String witnesspincode; // PIN
  final String witnessmobileno;
  final String witnessaadharno;
  final String witnessrelationship;

  LoaneeAccount({
    required this.customerid,
    required this.accountnumber,
    required this.loaneename,
    required this.guardianname,
    required this.address,
    required this.businesstype,
    required this.postoffice,
    required this.policestation,
    required this.district,
    required this.pincode,
    required this.mobileno,
    required this.aadharno,
    DateTime? createdat,
    this.status = 'Active',
    this.loanamount = 0.0,
    this.paidamount = 0.0,
    this.dueamount = 0.0,
    this.witnessname = '',
    this.witnessguardianname = '',
    this.witnessaddress = '',
    this.witnessbusinesstype = '',
    this.witnesspostoffice = '',
    this.witnesspolicestation = '',
    this.witnessdistrict = '',
    this.witnesspincode = '',
    this.witnessmobileno = '',
    this.witnessaadharno = '',
    this.witnessrelationship = '',
  }) : createdat = createdat ?? DateTime.now();

  // Backward compatibility & camelCase getters for Loanee
  String get customerId => customerid;
  String get accountNumber => accountnumber;
  String get loaneeName => loaneename;
  String get guardianName => guardianname;
  String get businessType => businesstype;
  String get postOffice => postoffice;
  String get policeStation => policestation;
  String get pinCode => pincode;
  String get mobileNo => mobileno;
  String get aadharNo => aadharno;
  DateTime get createdAt => createdat;
  double get loanAmount => loanamount;
  double get paidAmount => paidamount;
  double get dueAmount => dueamount;

  // Witness getters
  String get witnessName => witnessname;
  String get witnessGuardianName => witnessguardianname;
  String get witnessAddress => witnessaddress;
  String get witnessBusinessType => witnessbusinesstype;
  String get witnessPostOffice => witnesspostoffice;
  String get witnessPoliceStation => witnesspolicestation;
  String get witnessDistrict => witnessdistrict;
  String get witnessPinCode => witnesspincode;
  String get witnessMobileNo => witnessmobileno;
  String get witnessAadharNo => witnessaadharno;
  String get witnessRelationship => witnessrelationship;

  Map<String, dynamic> toJson() {
    return {
      'customerid': customerid,
      'accountnumber': accountnumber,
      'loaneename': loaneename,
      'guardianname': guardianname,
      'address': address,
      'businesstype': businesstype,
      'postoffice': postoffice,
      'policestation': policestation,
      'district': district,
      'pincode': pincode,
      'mobileno': mobileno,
      'aadharno': aadharno,
      'createdat': createdat.toIso8601String(),
      'status': status,
      'loanamount': loanamount,
      'paidamount': paidamount,
      'dueamount': dueamount,
      'witnessname': witnessname,
      'witnessguardianname': witnessguardianname,
      'witnessaddress': witnessaddress,
      'witnessbusinesstype': witnessbusinesstype,
      'witnesspostoffice': witnesspostoffice,
      'witnesspolicestation': witnesspolicestation,
      'witnessdistrict': witnessdistrict,
      'witnesspincode': witnesspincode,
      'witnessmobileno': witnessmobileno,
      'witnessaadharno': witnessaadharno,
      'witnessrelationship': witnessrelationship,
    };
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  factory LoaneeAccount.fromJson(Map<String, dynamic> json) {
    return LoaneeAccount(
      customerid: json['customerid']?.toString() ?? json['customerId']?.toString() ?? '',
      accountnumber: json['accountnumber']?.toString() ?? json['accountNumber']?.toString() ?? '',
      loaneename: json['loaneename']?.toString() ?? json['loaneeName']?.toString() ?? '',
      guardianname: json['guardianname']?.toString() ?? json['guardianName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      businesstype: json['businesstype']?.toString() ?? json['businessType']?.toString() ?? '',
      postoffice: json['postoffice']?.toString() ?? json['postOffice']?.toString() ?? '',
      policestation: json['policestation']?.toString() ?? json['policeStation']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? json['pinCode']?.toString() ?? '',
      mobileno: json['mobileno']?.toString() ?? json['mobileNo']?.toString() ?? '',
      aadharno: json['aadharno']?.toString() ?? json['aadharNo']?.toString() ?? '',
      createdat: json['createdat'] != null
          ? (DateTime.tryParse(json['createdat'].toString()) ?? DateTime.now())
          : (json['createdAt'] != null
              ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
              : DateTime.now()),
      status: json['status']?.toString() ?? 'Active',
      loanamount: _parseDouble(json['loanamount'] ?? json['loanAmount'] ?? json['loan_amount']),
      paidamount: _parseDouble(json['paidamount'] ?? json['paidAmount'] ?? json['paid_amount']),
      dueamount: _parseDouble(json['dueamount'] ?? json['dueAmount'] ?? json['due_amount']),
      witnessname: json['witnessname']?.toString() ?? json['witnessName']?.toString() ?? '',
      witnessguardianname: json['witnessguardianname']?.toString() ?? json['witnessGuardianName']?.toString() ?? '',
      witnessaddress: json['witnessaddress']?.toString() ?? json['witnessAddress']?.toString() ?? '',
      witnessbusinesstype: json['witnessbusinesstype']?.toString() ?? json['witnessBusinessType']?.toString() ?? '',
      witnesspostoffice: json['witnesspostoffice']?.toString() ?? json['witnessPostOffice']?.toString() ?? '',
      witnesspolicestation: json['witnesspolicestation']?.toString() ?? json['witnessPoliceStation']?.toString() ?? '',
      witnessdistrict: json['witnessdistrict']?.toString() ?? json['witnessDistrict']?.toString() ?? '',
      witnesspincode: json['witnesspincode']?.toString() ?? json['witnessPinCode']?.toString() ?? '',
      witnessmobileno: json['witnessmobileno']?.toString() ?? json['witnessMobileNo']?.toString() ?? '',
      witnessaadharno: json['witnessaadharno']?.toString() ?? json['witnessAadharNo']?.toString() ?? '',
      witnessrelationship: json['witnessrelationship']?.toString() ?? json['witnessRelationship']?.toString() ?? '',
    );
  }
}

