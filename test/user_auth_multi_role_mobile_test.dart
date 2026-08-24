import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_model.dart';

/// In-memory mock representing the Supabase 'user_auth' table with composite UNIQUE(mobile_no, user_type)
class MockUserAuthDatabase {
  final Map<String, UserAuthRecord> _records = {};

  /// Check if a user with (mobile_no, user_type) already exists
  bool checkExists({required String mobileNo, required UserType userType}) {
    return _records.values.any(
      (r) => r.mobileNo.trim() == mobileNo.trim() && r.userType == userType,
    );
  }

  /// Register or insert record. Rejects if duplicate (mobile_no, user_type) exists.
  Map<String, dynamic> registerUser({
    required String mobileNo,
    required UserType userType,
    required String pin,
    required String name,
    String? customerId,
    String? accountName,
    String? roName,
  }) {
    final cleanMobile = mobileNo.trim();
    if (checkExists(mobileNo: cleanMobile, userType: userType)) {
      return {
        'success': false,
        'code': 23505,
        'message': 'Duplicate registration rejected: An account with mobile number $cleanMobile is already registered as ${userType.name.toUpperCase()}.',
      };
    }

    final id = customerId?.isNotEmpty == true ? customerId! : '${userType.name}_$cleanMobile';
    final record = UserAuthRecord(
      id: id,
      mobileNo: cleanMobile,
      customerId: customerId,
      userType: userType,
      pin: pin,
      name: name,
      accountName: accountName,
      roName: roName,
      status: 'Active',
    );
    _records[id] = record;
    return {
      'success': true,
      'record': record,
      'message': 'User registered successfully',
    };
  }

  /// Authenticate by (mobile_no, user_type) then validate PIN
  UserAuthRecord? authenticate({
    required String mobileNo,
    UserType? userType,
    required String pin,
  }) {
    final cleanMobile = mobileNo.trim();
    final cleanPin = pin.trim();

    if (userType != null) {
      // Strictly look up by (mobile_no, user_type)
      try {
        final record = _records.values.firstWhere(
          (r) => r.mobileNo == cleanMobile && r.userType == userType,
        );
        if (record.pin == cleanPin && record.isActive) {
          return record;
        }
      } catch (_) {
        return null;
      }
    } else {
      // Auto-detect by (mobile_no, pin)
      try {
        final record = _records.values.firstWhere(
          (r) => r.mobileNo == cleanMobile && r.pin == cleanPin,
        );
        if (record.isActive) {
          return record;
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Reset PIN strictly for a specific role (mobile_no, user_type)
  bool resetPin({
    required String mobileNo,
    required UserType userType,
    required String newPin,
  }) {
    final cleanMobile = mobileNo.trim();
    for (final entry in _records.entries) {
      if (entry.value.mobileNo == cleanMobile && entry.value.userType == userType) {
        _records[entry.key] = entry.value.copyWith(pin: newPin.trim());
        return true;
      }
    }
    return false;
  }

  UserAuthRecord? getRecord(String id) => _records[id];
  int get count => _records.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Auth Multi-Role & Composite Unique Constraint Verification', () {
    const sharedMobile = '9876543210';
    late MockUserAuthDatabase db;

    setUp(() {
      db = MockUserAuthDatabase();
    });

    test('1. Register: Mobile=9876543210, UserType=Admin, PIN=1234 -> SUCCESS', () {
      final res = db.registerUser(
        mobileNo: sharedMobile,
        userType: UserType.admin,
        pin: '1234',
        name: 'Administrator',
      );

      expect(res['success'], isTrue);
      expect(db.count, equals(1));

      final adminRecord = db.getRecord('admin_$sharedMobile');
      expect(adminRecord, isNotNull);
      expect(adminRecord!.mobileNo, equals(sharedMobile));
      expect(adminRecord.userType, equals(UserType.admin));
      expect(adminRecord.pin, equals('1234'));
    });

    test('2. Register: Mobile=9876543210, UserType=Manager, PIN=5678 -> SUCCESS (Same Mobile, Different Role)', () {
      // First register Admin
      db.registerUser(
        mobileNo: sharedMobile,
        userType: UserType.admin,
        pin: '1234',
        name: 'Administrator',
      );

      // Now register Manager with the SAME mobile number
      final res = db.registerUser(
        mobileNo: sharedMobile,
        userType: UserType.manager,
        pin: '5678',
        name: 'Branch Manager',
      );

      expect(res['success'], isTrue);
      expect(db.count, equals(2));

      final managerRecord = db.getRecord('manager_$sharedMobile');
      expect(managerRecord, isNotNull);
      expect(managerRecord!.mobileNo, equals(sharedMobile));
      expect(managerRecord.userType, equals(UserType.manager));
      expect(managerRecord.pin, equals('5678'));
    });

    test('3. Register again: Mobile=9876543210, UserType=Admin, PIN=9999 -> REJECT as duplicate user', () {
      // 1. Initial Admin registration
      db.registerUser(
        mobileNo: sharedMobile,
        userType: UserType.admin,
        pin: '1234',
        name: 'Administrator',
      );

      // 2. Attempt duplicate registration for Admin with same mobile
      final duplicateRes = db.registerUser(
        mobileNo: sharedMobile,
        userType: UserType.admin,
        pin: '9999',
        name: 'Another Admin',
      );

      expect(duplicateRes['success'], isFalse);
      expect(duplicateRes['code'], equals(23505));
      expect(duplicateRes['message'], contains('Duplicate registration rejected'));

      // Total count remains 1 and original PIN remains 1234
      expect(db.count, equals(1));
      final adminRecord = db.getRecord('admin_$sharedMobile');
      expect(adminRecord!.pin, equals('1234'));
    });

    test('4. Login: 9876543210 + Admin + 1234 -> Login as Admin', () {
      db.registerUser(mobileNo: sharedMobile, userType: UserType.admin, pin: '1234', name: 'Admin User');
      db.registerUser(mobileNo: sharedMobile, userType: UserType.manager, pin: '5678', name: 'Manager User');

      // Login strictly providing role
      final authAdmin = db.authenticate(mobileNo: sharedMobile, userType: UserType.admin, pin: '1234');
      expect(authAdmin, isNotNull);
      expect(authAdmin!.userType, equals(UserType.admin));
      expect(authAdmin.name, equals('Admin User'));

      // Auto-detect login with PIN 1234 resolves to Admin
      final autoAdmin = db.authenticate(mobileNo: sharedMobile, pin: '1234');
      expect(autoAdmin, isNotNull);
      expect(autoAdmin!.userType, equals(UserType.admin));

      // Wrong PIN for Admin fails
      final failedAdmin = db.authenticate(mobileNo: sharedMobile, userType: UserType.admin, pin: '5678');
      expect(failedAdmin, isNull);
    });

    test('5. Login: 9876543210 + Manager + 5678 -> Login as Manager', () {
      db.registerUser(mobileNo: sharedMobile, userType: UserType.admin, pin: '1234', name: 'Admin User');
      db.registerUser(mobileNo: sharedMobile, userType: UserType.manager, pin: '5678', name: 'Manager User');

      // Login strictly providing role
      final authManager = db.authenticate(mobileNo: sharedMobile, userType: UserType.manager, pin: '5678');
      expect(authManager, isNotNull);
      expect(authManager!.userType, equals(UserType.manager));
      expect(authManager.name, equals('Manager User'));

      // Auto-detect login with PIN 5678 resolves to Manager
      final autoManager = db.authenticate(mobileNo: sharedMobile, pin: '5678');
      expect(autoManager, isNotNull);
      expect(autoManager!.userType, equals(UserType.manager));

      // Wrong PIN for Manager fails
      final failedManager = db.authenticate(mobileNo: sharedMobile, userType: UserType.manager, pin: '1234');
      expect(failedManager, isNull);
    });

    test('6. Manager PIN change -> Must NOT change Admin PIN', () {
      db.registerUser(mobileNo: sharedMobile, userType: UserType.admin, pin: '1234', name: 'Admin User');
      db.registerUser(mobileNo: sharedMobile, userType: UserType.manager, pin: '5678', name: 'Manager User');

      // Reset Manager PIN to 9999
      final resetSuccess = db.resetPin(mobileNo: sharedMobile, userType: UserType.manager, newPin: '9999');
      expect(resetSuccess, isTrue);

      // Verify Manager PIN changed
      final managerRecord = db.getRecord('manager_$sharedMobile');
      expect(managerRecord!.pin, equals('9999'));

      // Verify Admin PIN is completely UNCHANGED
      final adminRecord = db.getRecord('admin_$sharedMobile');
      expect(adminRecord!.pin, equals('1234'));

      // Manager logs in with new PIN
      expect(db.authenticate(mobileNo: sharedMobile, userType: UserType.manager, pin: '9999'), isNotNull);
      // Admin still logs in with original PIN
      expect(db.authenticate(mobileNo: sharedMobile, userType: UserType.admin, pin: '1234'), isNotNull);
    });

    test('7. Admin PIN change -> Must NOT change Manager PIN', () {
      db.registerUser(mobileNo: sharedMobile, userType: UserType.admin, pin: '1234', name: 'Admin User');
      db.registerUser(mobileNo: sharedMobile, userType: UserType.manager, pin: '5678', name: 'Manager User');

      // Reset Admin PIN to 7777
      final resetSuccess = db.resetPin(mobileNo: sharedMobile, userType: UserType.admin, newPin: '7777');
      expect(resetSuccess, isTrue);

      // Verify Admin PIN changed
      final adminRecord = db.getRecord('admin_$sharedMobile');
      expect(adminRecord!.pin, equals('7777'));

      // Verify Manager PIN is completely UNCHANGED
      final managerRecord = db.getRecord('manager_$sharedMobile');
      expect(managerRecord!.pin, equals('5678'));

      // Admin logs in with new PIN
      expect(db.authenticate(mobileNo: sharedMobile, userType: UserType.admin, pin: '7777'), isNotNull);
      // Manager still logs in with original PIN
      expect(db.authenticate(mobileNo: sharedMobile, userType: UserType.manager, pin: '5678'), isNotNull);
    });

    test('8. Existing users must continue to work after migration', () {
      // Existing records created before migration with single mobile or customer ID
      final existingLegacyLoanee = UserAuthRecord(
        id: '2026LA000001',
        mobileNo: '9862000001',
        customerId: '2026LA000001',
        userType: UserType.loanee,
        pin: '1234',
        name: 'Legacy Loanee',
        status: 'Active',
      );

      final existingLegacyRo = UserAuthRecord(
        id: '2026R001',
        mobileNo: '9862000002',
        customerId: '2026R001',
        userType: UserType.ro,
        pin: '4321',
        name: 'Legacy RO',
        status: 'Active',
      );

      // Insert directly as existing rows in the migrated database
      db._records[existingLegacyLoanee.id] = existingLegacyLoanee;
      db._records[existingLegacyRo.id] = existingLegacyRo;

      // Existing loanee logs in successfully
      final loaneeLogin = db.authenticate(
        mobileNo: '9862000001',
        userType: UserType.loanee,
        pin: '1234',
      );
      expect(loaneeLogin, isNotNull);
      expect(loaneeLogin!.id, equals('2026LA000001'));
      expect(loaneeLogin.name, equals('Legacy Loanee'));

      // Existing RO logs in successfully
      final roLogin = db.authenticate(
        mobileNo: '9862000002',
        userType: UserType.ro,
        pin: '4321',
      );
      expect(roLogin, isNotNull);
      expect(roLogin!.id, equals('2026R001'));
      expect(roLogin.name, equals('Legacy RO'));
    });

    test('9. Loanee and RO Model deserialization & JSON persistence verification', () {
      final ro = RoAccount(
        customerid: '2026R001',
        accountnumber: 'AC2026RS0001',
        roname: 'RO Officer',
        guardianname: 'Guardian',
        address: 'Imphal West',
        designation: 'Field Officer',
        postoffice: 'Imphal',
        policestation: 'Imphal',
        district: 'Imphal West',
        mobileno: sharedMobile,
        pincode: '795001',
        aadharno: '999988887777',
      );

      final loanee = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Loanee Bembem',
        guardianname: 'Father',
        address: 'Imphal East',
        businesstype: 'Handloom',
        postoffice: 'Porompat',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795005',
        mobileno: sharedMobile,
        aadharno: '111122223333',
      );

      final roAuth = UserAuthRecord(
        id: ro.customerId,
        mobileNo: ro.mobileNo,
        customerId: ro.customerId,
        userType: UserType.ro,
        pin: '222222',
        name: ro.roName,
        roName: ro.roName,
        status: ro.status,
      );

      final loaneeAuth = UserAuthRecord(
        id: loanee.customerId,
        mobileNo: loanee.mobileNo,
        customerId: loanee.customerId,
        userType: UserType.loanee,
        pin: '333333',
        name: loanee.loaneeName,
        accountName: loanee.accountNumber,
        status: loanee.status,
      );

      expect(roAuth.mobileNo, equals(loaneeAuth.mobileNo));
      expect(roAuth.id, isNot(equals(loaneeAuth.id)));

      final roJson = roAuth.toSupabaseJson();
      final parsedRo = UserAuthRecord.fromJson(roJson);
      expect(parsedRo.id, equals('2026R001'));
      expect(parsedRo.userType, equals(UserType.ro));
      expect(parsedRo.pin, equals('222222'));

      final loaneeJson = loaneeAuth.toSupabaseJson();
      final parsedLoanee = UserAuthRecord.fromJson(loaneeJson);
      expect(parsedLoanee.id, equals('2026LA000001'));
      expect(parsedLoanee.userType, equals(UserType.loanee));
      expect(parsedLoanee.pin, equals('333333'));
    });
  });
}
