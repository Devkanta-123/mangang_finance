import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Weekly Auto Late Fee Timing and Cleanup', () {
    late SettingsProvider settingsProvider;
    late CollectionSheetProvider collectionProvider;

    setUp(() {
      settingsProvider = SettingsProvider();
      collectionProvider = CollectionSheetProvider();
    });

    test('Weekly auto late fee candidates start strictly AFTER latest real transaction date', () async {
      // Loan created on 2025-02-16, sanctioned 2025-05-09, maturity 2025-10-08
      final entry = RoCollectionEntry(
        id: 'COLL-001',
        customerId: 'CUST-001',
        accountNumber: 'ACC-1001',
        loaneeName: 'John Doe',
        loaneeAddress: 'Address 1',
        collectionType: 'Weekly',
        route: 'Route A',
        mobileNo: '9876543210',
        loanAmount: 10000.0,
        payableAmount: 650.0,
        createdAt: DateTime(2025, 2, 16),
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Excel upload happened with payments up to 2025-08-16
      final realPayment = CollectionPaymentModel(
        id: 'PAY-EXCEL-1',
        collectionId: entry.id,
        paymentAmount: 650.0,
        remainingBalance: 9350.0,
        paymentType: 'Cash',
        roPasscode: '1234',
        roName: 'RO 1',
        roId: 'RO-1',
        roRoute: 'Route A',
        createdAt: DateTime(2025, 8, 16, 10, 0),
        status: 'Success',
      );

      // Pre-existing erroneous auto entry from old bug starting on 2025-02-23
      final buggyAutoPayment = CollectionPaymentModel(
        id: 'PAY-LATE-${entry.id}-20250223',
        collectionId: entry.id,
        paymentAmount: 0.0,
        lateFine: 19.5,
        remainingBalance: 10019.5,
        paymentType: 'Late Fee',
        roPasscode: '',
        roName: 'System (Auto)',
        roId: 'SYS-AUTO',
        roRoute: 'Route A',
        createdAt: DateTime(2025, 2, 23, 12, 0),
        status: 'Success',
        remarks: 'Weekly Late Fee: ₹19.50 (Auto assessed for 23/02/2025)',
      );

      await collectionProvider.addCollectionPayment(realPayment, saveToRemote: false);
      await collectionProvider.addCollectionPayment(buggyAutoPayment, saveToRemote: false);

      // Run sync as of 2025-09-01 (16 days after 2025-08-16, which is 2 full weeks: Aug 23, Aug 30)
      final newRecords = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: DateTime(2025, 9, 1),
        sanctionDate: DateTime(2025, 5, 9),
        saveToRemote: false,
      );

      // 1. The erroneous auto payment from 2025-02-23 MUST be purged!
      final allPayments = collectionProvider.getPaymentsForCollection(entry.id);
      expect(allPayments.any((p) => p.id == buggyAutoPayment.id), isFalse);

      // 2. Newly created records must start strictly after 2025-08-16
      expect(newRecords.length, 2);
      expect(newRecords[0].createdAt.year, 2025);
      expect(newRecords[0].createdAt.month, 8);
      expect(newRecords[0].createdAt.day, 23); // Week 1 after Aug 16

      expect(newRecords[1].createdAt.year, 2025);
      expect(newRecords[1].createdAt.month, 8);
      expect(newRecords[1].createdAt.day, 30); // Week 2 after Aug 16

      // Ensure all candidate dates are strictly after 2025-08-16
      for (final rec in newRecords) {
        expect(rec.createdAt.isAfter(DateTime(2025, 8, 16)), isTrue);
      }
    });

    test('If no real payment exists, no auto late fee is generated', () async {
      final entry = RoCollectionEntry(
        id: 'COLL-002',
        customerId: 'CUST-002',
        accountNumber: 'ACC-1002',
        loaneeName: 'Jane Doe',
        loaneeAddress: 'Address 2',
        collectionType: 'Weekly',
        route: 'Route A',
        mobileNo: '9876543211',
        loanAmount: 10000.0,
        payableAmount: 650.0,
        createdAt: DateTime(2025, 2, 16),
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      final newRecords = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: DateTime(2025, 9, 1),
        sanctionDate: DateTime(2025, 5, 9),
        saveToRemote: false,
      );

      expect(newRecords, isEmpty);
    });
  });
}
