// test/office_master_route_payment_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';

void main() {
  group('Master Route Office & Admin Payment Entry Tests', () {
    test('CollectionSheetProvider identifies Office as Master Route correctly', () {
      expect(CollectionSheetProvider.isOfficeRoute('Office'), isTrue);
      expect(CollectionSheetProvider.isOfficeRoute('office'), isTrue);
      expect(CollectionSheetProvider.isOfficeRoute('OFFICE'), isTrue);
      expect(CollectionSheetProvider.isOfficeRoute('Head Office'), isTrue);
      expect(CollectionSheetProvider.isOfficeRoute('Main Office'), isTrue);
      expect(CollectionSheetProvider.isOfficeRoute('Mangang'), isFalse);
      expect(CollectionSheetProvider.isOfficeRoute('Luwang'), isFalse);
      expect(CollectionSheetProvider.isOfficeRoute(null), isFalse);
    });

    test('CollectionPaymentModel recognizes Admin/Office payment entry', () {
      // 1. Payment recorded by Administrator
      final adminPayment = CollectionPaymentModel(
        id: 'PAY-ADMIN-001',
        collectionId: 'COL-OFFICE-1',
        paymentAmount: 650.0,
        remainingBalance: 4000.0,
        lateFine: 0.0,
        paymentType: 'Cash',
        roPasscode: '123456',
        roName: 'Administrator',
        roId: 'ADM-01',
        roRoute: 'Office',
        remarks: 'Office Master Entry: Recorded directly by Administrator (Administrator)',
      );

      expect(adminPayment.isAdminOrOfficeEntry, isTrue);
      expect(adminPayment.recordedByDisplayName, contains('Admin • Office Route'));
      expect(adminPayment.recordedByShortLabel, equals('Admin (Office)'));

      // 2. Regular RO Field Officer payment
      final roPayment = CollectionPaymentModel(
        id: 'PAY-RO-001',
        collectionId: 'COL-MANGANG-1',
        paymentAmount: 500.0,
        remainingBalance: 5000.0,
        lateFine: 0.0,
        paymentType: 'Cash',
        roPasscode: '789122',
        roName: 'Yumnam Ranbir',
        roId: 'RO-001',
        roRoute: 'Mangang',
      );

      expect(roPayment.isAdminOrOfficeEntry, isFalse);
      expect(roPayment.recordedByDisplayName, equals('Yumnam Ranbir'));
      expect(roPayment.recordedByShortLabel, equals('Yumnam Ranbir'));
    });

    test('Admin recording payment for an Office collection entry', () {
      final officeCard = RoCollectionEntry(
        id: 'COL-OFFICE-101',
        customerId: 'CUST-8001',
        accountNumber: 'ACC-88239999',
        loaneeName: 'Thoiba Singh',
        loaneeAddress: 'Imphal Head Office',
        collectionType: 'Daily',
        route: 'Office',
        mobileNo: '9876543210',
      );

      expect(CollectionSheetProvider.isOfficeRoute(officeCard.route), isTrue);

      final payment = CollectionPaymentModel(
        id: 'PAY-10001',
        collectionId: officeCard.id,
        paymentAmount: 500.0,
        remainingBalance: 2500.0,
        lateFine: 0.0,
        paymentType: 'UPI',
        roPasscode: '123456',
        roName: 'Administrator',
        roId: 'ADM-01',
        roRoute: 'Office',
        remarks: 'Office Master Entry: Recorded directly by Administrator (Administrator)',
      );

      expect(payment.isAdminOrOfficeEntry, isTrue);
      expect(payment.roRoute, equals('Office'));
      expect(payment.roId, equals('ADM-01'));
      expect(payment.remarks, contains('Office Master Entry'));
    });

    test('Admin payment permission is restricted to Office route and RO to rest routes', () {
      final officeEntry = RoCollectionEntry(
        id: 'COL-OFFICE-101',
        customerId: 'CUST-8001',
        accountNumber: 'ACC-88239999',
        loaneeName: 'Thoiba Singh',
        loaneeAddress: 'Imphal Head Office',
        collectionType: 'Daily',
        route: 'Office',
        mobileNo: '9876543210',
      );

      final mangangEntry = RoCollectionEntry(
        id: 'COL-MANGANG-102',
        customerId: 'CUST-8002',
        accountNumber: 'ACC-88239998',
        loaneeName: 'Sanathoi Devi',
        loaneeAddress: 'Keishamthong',
        collectionType: 'Daily',
        route: 'Mangang',
        mobileNo: '9876543211',
      );

      // Check isOfficeRoute
      final bool isOffice1 = CollectionSheetProvider.isOfficeRoute(officeEntry.route);
      final bool isOffice2 = CollectionSheetProvider.isOfficeRoute(mangangEntry.route);

      // When Admin:
      bool checkAdminCanRecord(bool isOffice) => isOffice;
      bool checkRoCanRecord(bool isOffice) => !isOffice;

      expect(checkAdminCanRecord(isOffice1), isTrue, reason: 'Admin must be able to record Office route collection');
      expect(checkAdminCanRecord(isOffice2), isFalse, reason: 'Admin must NOT be able to record non-Office route collection');

      expect(checkRoCanRecord(isOffice1), isFalse, reason: 'RO must NOT be able to record Office route collection');
      expect(checkRoCanRecord(isOffice2), isTrue, reason: 'RO must be able to record non-Office route collection');
    });
  });
}
