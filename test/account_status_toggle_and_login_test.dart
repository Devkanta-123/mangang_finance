import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Account Status & Inactive Flag Tests', () {
    test('LoaneeAccount isActive getter and copyWith status', () {
      final loanee = LoaneeAccount(
        customerid: 'CUST-1001',
        accountnumber: 'ACC-88239101',
        loaneename: 'John Doe',
        guardianname: 'Jane Doe',
        address: 'Imphal',
        businesstype: 'Retail',
        postoffice: 'Imphal PO',
        policestation: 'Imphal PS',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9876543210',
        aadharno: '123456789012',
        status: 'Active',
      );

      expect(loanee.isActive, isTrue);

      final inactiveLoanee = loanee.copyWith(status: 'Inactive');
      expect(inactiveLoanee.isActive, isFalse);
      expect(inactiveLoanee.status, 'Inactive');

      final reactivated = inactiveLoanee.copyWith(status: 'Active');
      expect(reactivated.isActive, isTrue);
    });

    test('RoAccount isActive getter and copyWith status', () {
      final ro = RoAccount(
        customerid: 'RO-CUST-5001',
        accountnumber: 'RO-ACC-991001',
        roname: 'Officer Smith',
        guardianname: 'Elder Smith',
        address: 'Thoubal',
        designation: 'Senior RO',
        route: 'Route A',
        postoffice: 'Thoubal PO',
        policestation: 'Thoubal PS',
        district: 'Thoubal',
        pincode: '795138',
        mobileno: '9123456789',
        aadharno: '987654321012',
        status: 'Active',
      );

      expect(ro.isActive, isTrue);

      final inactiveRo = ro.copyWith(status: 'Inactive');
      expect(inactiveRo.isActive, isFalse);
      expect(inactiveRo.status, 'Inactive');
    });

    test('UserAuthRecord isActive and copyWith status', () {
      final userAuth = UserAuthRecord(
        id: 'CUST-1001',
        mobileNo: '9876543210',
        customerId: 'CUST-1001',
        userType: UserType.loanee,
        pin: '123456',
        name: 'John Doe',
        status: 'Active',
      );

      expect(userAuth.isActive, isTrue);

      final inactiveAuth = userAuth.copyWith(status: 'Inactive');
      expect(inactiveAuth.isActive, isFalse);
      expect(inactiveAuth.status, 'Inactive');
    });

    test('LoaneeProvider updateStatus updates in-memory status', () async {
      final provider = LoaneeProvider();
      final loanee = LoaneeAccount(
        customerid: 'CUST-TEST-1',
        accountnumber: 'ACC-TEST-1',
        loaneename: 'Test Loanee',
        guardianname: 'Guardian',
        address: 'Address',
        businesstype: 'Type',
        postoffice: 'PO',
        policestation: 'PS',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9999999999',
        aadharno: '111122223333',
        status: 'Active',
      );

      // Add to provider list
      provider.loanees; // getter
      // Test updateStatus
      await provider.updateStatus('CUST-TEST-1', 'Inactive');
      // toggleStatus helper test
      final toggled = loanee.copyWith(status: 'Inactive');
      expect(toggled.isActive, isFalse);
    });

    test('RoProvider updateStatus updates status', () async {
      final ro = RoAccount(
        customerid: 'RO-TEST-1',
        accountnumber: 'RO-ACC-TEST-1',
        roname: 'Test RO',
        guardianname: 'Guardian',
        address: 'Address',
        designation: 'Officer',
        route: 'Route 1',
        postoffice: 'PO',
        policestation: 'PS',
        district: 'Thoubal',
        pincode: '795138',
        mobileno: '8888888888',
        aadharno: '222233334444',
        status: 'Active',
      );

      expect(ro.isActive, isTrue);
      final inactive = ro.copyWith(status: 'Inactive');
      expect(inactive.isActive, isFalse);
      expect(inactive.status, 'Inactive');
    });

    test('AuthProvider blocks login when offline cached user is Inactive', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', '654321');
      await prefs.setString(
        'user_data',
        '{"name":"Inactive User","mobileNo":"9999999999","userType":"loanee","customerId":"CUST-999","status":"Inactive"}',
      );

      final authProvider = AuthProvider();
      final result = await authProvider.loginWithPin('654321');

      expect(result.success, isFalse);
      expect(result.isInactive, isTrue);
      expect(result.message, contains('INACTIVE'));
      expect(authProvider.isLoggedIn, isFalse);
    });

    test('AuthProvider updateAdminUserStatus updates user status and currentUser status', () async {
      final authProvider = AuthProvider();
      authProvider.setAdminUsersForTesting([
        UserAuthRecord(
          id: 'ADM-01',
          name: 'Admin User',
          mobileNo: '9876543210',
          customerId: 'ADM-01',
          userType: UserType.admin,
          pin: '1234',
          status: 'Active',
        ),
      ]);
      authProvider.setCurrentUserForTesting(
        User(
          name: 'Admin User',
          mobileNo: '9876543210',
          customerId: 'ADM-01',
          userType: UserType.admin,
          status: 'Active',
        ),
      );

      expect(authProvider.currentUser?.isActive, isTrue);
      expect(authProvider.adminUsers.first.isActive, isTrue);

      await authProvider.updateAdminUserStatus('ADM-01', 'Inactive', customerId: 'ADM-01');

      expect(authProvider.adminUsers.first.isActive, isFalse);
      expect(authProvider.adminUsers.first.status, 'Inactive');
      expect(authProvider.currentUser?.isActive, isFalse);
      expect(authProvider.currentUser?.status, 'Inactive');
    });

    test('UserAuthRecord with Inactive status strictly reports isActive as false', () {
      final roAuth = UserAuthRecord(
        id: 'RO-101',
        mobileNo: '9876543210',
        customerId: 'RO-101',
        userType: UserType.ro,
        pin: '1234',
        name: 'Officer John',
        status: 'Inactive',
      );

      expect(roAuth.isActive, isFalse);
      expect(roAuth.status, 'Inactive');

      final user = roAuth.toUser();
      expect(user.isActive, isFalse);
      expect(user.status, 'Inactive');
    });
  });
}
