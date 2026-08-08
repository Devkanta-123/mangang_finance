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
    this.loanamount = 50000.0,
    this.paidamount = 15000.0,
    this.dueamount = 35000.0,
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

  factory LoaneeAccount.fromJson(Map<String, dynamic> json) {
    return LoaneeAccount(
      customerid: json['customerid'] ?? json['customerId'] ?? '',
      accountnumber: json['accountnumber'] ?? json['accountNumber'] ?? '',
      loaneename: json['loaneename'] ?? json['loaneeName'] ?? '',
      guardianname: json['guardianname'] ?? json['guardianName'] ?? '',
      address: json['address'] ?? '',
      businesstype: json['businesstype'] ?? json['businessType'] ?? '',
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
      loanamount: (json['loanamount'] ?? json['loanAmount'] ?? 50000.0).toDouble(),
      paidamount: (json['paidamount'] ?? json['paidAmount'] ?? 15000.0).toDouble(),
      dueamount: (json['dueamount'] ?? json['dueAmount'] ?? 35000.0).toDouble(),
      witnessname: json['witnessname'] ?? json['witnessName'] ?? '',
      witnessguardianname: json['witnessguardianname'] ?? json['witnessGuardianName'] ?? '',
      witnessaddress: json['witnessaddress'] ?? json['witnessAddress'] ?? '',
      witnessbusinesstype: json['witnessbusinesstype'] ?? json['witnessBusinessType'] ?? '',
      witnesspostoffice: json['witnesspostoffice'] ?? json['witnessPostOffice'] ?? '',
      witnesspolicestation: json['witnesspolicestation'] ?? json['witnessPoliceStation'] ?? '',
      witnessdistrict: json['witnessdistrict'] ?? json['witnessDistrict'] ?? '',
      witnesspincode: json['witnesspincode'] ?? json['witnessPinCode'] ?? '',
      witnessmobileno: json['witnessmobileno'] ?? json['witnessMobileNo'] ?? '',
      witnessaadharno: json['witnessaadharno'] ?? json['witnessAadharNo'] ?? '',
      witnessrelationship: json['witnessrelationship'] ?? json['witnessRelationship'] ?? '',
    );
  }
}

