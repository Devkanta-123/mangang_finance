// lib/models/loanee_model.dart

import 'notification_model.dart';

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
  final DateTime? loansanctiondate;
  final DateTime? loanmaturitydate;

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
    DateTime? loansanctiondate,
    DateTime? loanmaturitydate,
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
  })  : createdat = createdat ?? DateTime.now(),
        loansanctiondate = loansanctiondate ?? createdat ?? DateTime.now(),
        loanmaturitydate = loanmaturitydate ?? calculateMaturityDate(loansanctiondate ?? createdat ?? DateTime.now());

  /// Automatically calculates maturity date (5 months after sanction date)
  static DateTime calculateMaturityDate(DateTime sanction) {
    int year = sanction.year;
    int month = sanction.month + 5;
    if (month > 12) {
      year += (month - 1) ~/ 12;
      month = ((month - 1) % 12) + 1;
    }
    int day = sanction.day;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInMonth) {
      day = daysInMonth;
    }
    return DateTime(year, month, day);
  }

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
  bool get isActive => status.toLowerCase() != 'inactive';
  DateTime? get loanSanctionDate => loansanctiondate;
  DateTime? get loanMaturityDate => loanmaturitydate;

  String get formattedSanctionDate {
    final d = loansanctiondate ?? createdat;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  DateTime get effectiveMaturityDate =>
      loanmaturitydate ?? calculateMaturityDate(loansanctiondate ?? createdat);

  String get formattedMaturityDate {
    final d = effectiveMaturityDate;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// Whether loan tenure has exceeded the 5-month maturity date and has unpaid balance
  bool get isPastMaturity {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mat = DateTime(effectiveMaturityDate.year, effectiveMaturityDate.month, effectiveMaturityDate.day);
    final hasBalance = dueamount > 0 || (loanamount > 0 && paidamount < loanamount);
    return today.isAfter(mat) && hasBalance;
  }

  /// Number of overdue days past loan maturity date
  int get daysPastMaturity {
    if (!isPastMaturity) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mat = DateTime(effectiveMaturityDate.year, effectiveMaturityDate.month, effectiveMaturityDate.day);
    return today.difference(mat).inDays;
  }

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

  LoaneeAccount copyWith({
    String? customerid,
    String? accountnumber,
    String? loaneename,
    String? guardianname,
    String? address,
    String? businesstype,
    String? postoffice,
    String? policestation,
    String? district,
    String? pincode,
    String? mobileno,
    String? aadharno,
    DateTime? createdat,
    String? status,
    double? loanamount,
    double? paidamount,
    double? dueamount,
    DateTime? loansanctiondate,
    DateTime? loanmaturitydate,
    String? witnessname,
    String? witnessguardianname,
    String? witnessaddress,
    String? witnessbusinesstype,
    String? witnesspostoffice,
    String? witnesspolicestation,
    String? witnessdistrict,
    String? witnesspincode,
    String? witnessmobileno,
    String? witnessaadharno,
    String? witnessrelationship,
  }) {
    return LoaneeAccount(
      customerid: customerid ?? this.customerid,
      accountnumber: accountnumber ?? this.accountnumber,
      loaneename: loaneename ?? this.loaneename,
      guardianname: guardianname ?? this.guardianname,
      address: address ?? this.address,
      businesstype: businesstype ?? this.businesstype,
      postoffice: postoffice ?? this.postoffice,
      policestation: policestation ?? this.policestation,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      mobileno: mobileno ?? this.mobileno,
      aadharno: aadharno ?? this.aadharno,
      createdat: createdat ?? this.createdat,
      status: status ?? this.status,
      loanamount: loanamount ?? this.loanamount,
      paidamount: paidamount ?? this.paidamount,
      dueamount: dueamount ?? this.dueamount,
      loansanctiondate: loansanctiondate ?? this.loansanctiondate,
      loanmaturitydate: loanmaturitydate ?? this.loanmaturitydate,
      witnessname: witnessname ?? this.witnessname,
      witnessguardianname: witnessguardianname ?? this.witnessguardianname,
      witnessaddress: witnessaddress ?? this.witnessaddress,
      witnessbusinesstype: witnessbusinesstype ?? this.witnessbusinesstype,
      witnesspostoffice: witnesspostoffice ?? this.witnesspostoffice,
      witnesspolicestation: witnesspolicestation ?? this.witnesspolicestation,
      witnessdistrict: witnessdistrict ?? this.witnessdistrict,
      witnesspincode: witnesspincode ?? this.witnesspincode,
      witnessmobileno: witnessmobileno ?? this.witnessmobileno,
      witnessaadharno: witnessaadharno ?? this.witnessaadharno,
      witnessrelationship: witnessrelationship ?? this.witnessrelationship,
    );
  }

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
      'loansanctiondate': loansanctiondate?.toIso8601String(),
      'loanmaturitydate': loanmaturitydate?.toIso8601String(),
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

  /// Robust date parser for all Postgres, ISO-8601, text, and serial formats
  static DateTime? parseDateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is num) {
      if (value > 1000 && value < 100000) {
        return DateTime(1899, 12, 30).add(Duration(days: value.toInt()));
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      return DateTime(dt.year, dt.month, dt.day);
    }

    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;

    // 1. Numeric Excel serial string (e.g. "46204")
    final numVal = double.tryParse(str);
    if (numVal != null &&
        numVal > 1000 &&
        numVal < 100000 &&
        !str.contains('-') &&
        !str.contains('/') &&
        !str.contains('.')) {
      return DateTime(1899, 12, 30).add(Duration(days: numVal.toInt()));
    }

    // 2. Month names mapping (e.g. "24-Aug-2026", "24 August 2026", "Aug 24, 2026")
    const monthNames = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9, 'sept': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };

    final cleanStr =
        str.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts =
        cleanStr.split(RegExp(r'[-/.\s]')).where((p) => p.isNotEmpty).toList();

    if (parts.length == 3) {
      int? monthFromText;
      int? dayFromParts;
      int? yearFromParts;

      for (int i = 0; i < 3; i++) {
        final lower = parts[i].toLowerCase();
        if (monthNames.containsKey(lower)) {
          monthFromText = monthNames[lower];
          if (i == 0) {
            dayFromParts = int.tryParse(parts[1]);
            yearFromParts = int.tryParse(parts[2]);
          } else if (i == 1) {
            dayFromParts = int.tryParse(parts[0]);
            yearFromParts = int.tryParse(parts[2]);
          }
          break;
        }
      }

      if (monthFromText != null &&
          dayFromParts != null &&
          yearFromParts != null) {
        if (yearFromParts < 100) yearFromParts += 2000;
        return DateTime(yearFromParts, monthFromText, dayFromParts);
      }

      final p1 = int.tryParse(parts[0]);
      final p2 = int.tryParse(parts[1]);
      int? p3 = int.tryParse(parts[2]);

      if (p1 != null && p2 != null && p3 != null) {
        if (p3 < 100) p3 += 2000;

        if (p3 > 1900) {
          if (p2 <= 12 && p1 <= 31) {
            return DateTime(p3, p2, p1);
          } else if (p1 <= 12 && p2 <= 31) {
            return DateTime(p3, p1, p2);
          }
        } else if (p1 > 1900) {
          return DateTime(p1, p2, p3);
        }
      }
    }

    // 3. Standard Postgres / ISO formats (e.g. "2026-08-24", "2026-08-24T00:00:00+00:00")
    try {
      final dt = DateTime.parse(str);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {}

    return null;
  }

  factory LoaneeAccount.fromJson(Map<String, dynamic> json) {
    final parsedCreatedAt = parseDateTimeOrNull(
          json['createdat'] ?? json['created_at'] ?? json['createdAt'],
        ) ??
        DateTime.now();

    final rawSanction = json['loansanctiondate'] ??
        json['loan_sanction_date'] ??
        json['loansanction_date'] ??
        json['loanSanctionDate'] ??
        json['sanction_date'] ??
        json['sanctiondate'] ??
        json['sanctionDate'];
    final parsedSanctionDate = parseDateTimeOrNull(rawSanction);

    final rawMaturity = json['loanmaturitydate'] ??
        json['loan_maturity_date'] ??
        json['loanmaturity_date'] ??
        json['loanMaturityDate'] ??
        json['maturity_date'] ??
        json['maturitydate'] ??
        json['maturityDate'];
    final parsedMaturityDate = parseDateTimeOrNull(rawMaturity);

    final finalSanction = parsedSanctionDate ?? parsedCreatedAt;
    final finalMaturity =
        parsedMaturityDate ?? calculateMaturityDate(finalSanction);

    return LoaneeAccount(
      customerid: json['customerid']?.toString() ??
          json['customerId']?.toString() ??
          json['customer_id']?.toString() ??
          '',
      accountnumber: json['accountnumber']?.toString() ??
          json['accountNumber']?.toString() ??
          json['account_number']?.toString() ??
          '',
      loaneename: json['loaneename']?.toString() ??
          json['loaneeName']?.toString() ??
          json['loanee_name']?.toString() ??
          '',
      guardianname: json['guardianname']?.toString() ??
          json['guardianName']?.toString() ??
          json['guardian_name']?.toString() ??
          '',
      address: json['address']?.toString() ?? '',
      businesstype: json['businesstype']?.toString() ??
          json['businessType']?.toString() ??
          json['business_type']?.toString() ??
          '',
      postoffice: json['postoffice']?.toString() ??
          json['postOffice']?.toString() ??
          json['post_office']?.toString() ??
          '',
      policestation: json['policestation']?.toString() ??
          json['policeStation']?.toString() ??
          json['police_station']?.toString() ??
          '',
      district: json['district']?.toString() ?? '',
      pincode: json['pincode']?.toString() ??
          json['pinCode']?.toString() ??
          json['pin_code']?.toString() ??
          '',
      mobileno: json['mobileno']?.toString() ??
          json['mobileNo']?.toString() ??
          json['mobile_no']?.toString() ??
          '',
      aadharno: json['aadharno']?.toString() ??
          json['aadharNo']?.toString() ??
          json['aadhar_no']?.toString() ??
          '',
      createdat: parsedCreatedAt,
      status: json['status']?.toString() ?? 'Active',
      loanamount: _parseDouble(
          json['loanamount'] ?? json['loanAmount'] ?? json['loan_amount']),
      paidamount: _parseDouble(
          json['paidamount'] ?? json['paidAmount'] ?? json['paid_amount']),
      dueamount: _parseDouble(
          json['dueamount'] ?? json['dueAmount'] ?? json['due_amount']),
      loansanctiondate: finalSanction,
      loanmaturitydate: finalMaturity,
      witnessname: json['witnessname']?.toString() ??
          json['witnessName']?.toString() ??
          json['witness_name']?.toString() ??
          '',
      witnessguardianname: json['witnessguardianname']?.toString() ??
          json['witnessGuardianName']?.toString() ??
          json['witness_guardian_name']?.toString() ??
          '',
      witnessaddress: json['witnessaddress']?.toString() ??
          json['witnessAddress']?.toString() ??
          json['witness_address']?.toString() ??
          '',
      witnessbusinesstype: json['witnessbusinesstype']?.toString() ??
          json['witnessBusinessType']?.toString() ??
          json['witness_business_type']?.toString() ??
          '',
      witnesspostoffice: json['witnesspostoffice']?.toString() ??
          json['witnessPostOffice']?.toString() ??
          json['witness_post_office']?.toString() ??
          '',
      witnesspolicestation: json['witnesspolicestation']?.toString() ??
          json['witnessPoliceStation']?.toString() ??
          json['witness_police_station']?.toString() ??
          '',
      witnessdistrict: json['witnessdistrict']?.toString() ??
          json['witnessDistrict']?.toString() ??
          json['witness_district']?.toString() ??
          '',
      witnesspincode: json['witnesspincode']?.toString() ??
          json['witnessPinCode']?.toString() ??
          json['witness_pin_code']?.toString() ??
          '',
      witnessmobileno: json['witnessmobileno']?.toString() ??
          json['witnessMobileNo']?.toString() ??
          json['witness_mobile_no']?.toString() ??
          '',
      witnessaadharno: json['witnessaadharno']?.toString() ??
          json['witnessAadharNo']?.toString() ??
          json['witness_aadhar_no']?.toString() ??
          '',
      witnessrelationship: json['witnessrelationship']?.toString() ??
          json['witnessRelationship']?.toString() ??
          json['witness_relationship']?.toString() ??
          '',
    );
  }
}
