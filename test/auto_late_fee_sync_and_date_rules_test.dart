import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settingsProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsProvider = SettingsProvider();
    await settingsProvider.loadSettings();
  });

  group('Automatic Late Payment Fee Synchronization & Date Rules (Tests A - G)', () {
    test('TEST A: Latest transaction 09/09, asOfDate 12/09 -> 10/09 & 11/09 inserted, 12/09 NOT inserted', () async {
      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-TEST-A',
        customerId: 'CUST-A',
        accountNumber: 'ACC-A',
        loaneeName: 'Test Loanee A',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: DateTime(2026, 2, 1),
        payableAmount: 121.0, // Base daily installment ₹121
        loanAmount: 12100.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Latest transaction was 09-Sep-2026:
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-HIST-09',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 10, 0, 0),
        ),
        saveToRemote: false,
      );

      // Today is 12-Sep-2026
      final asOf12 = DateTime(2026, 9, 12);
      final inserted = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );

      // 1. Exactly 2 records inserted: 10/09 and 11/09
      expect(inserted.length, equals(2));
      expect(inserted.any((p) => p.createdAt.day == 10 && p.createdAt.month == 9), isTrue);
      expect(inserted.any((p) => p.createdAt.day == 11 && p.createdAt.month == 9), isTrue);

      // 2. 12/09 is TODAY and must NOT be inserted
      expect(inserted.any((p) => p.createdAt.day == 12 && p.createdAt.month == 9), isFalse);

      // 3. Daily late fine calculation: ₹121 * 3% = ₹3.63
      for (final rec in inserted) {
        expect(rec.lateFine, equals(3.63));
        expect(rec.paymentType, equals('Late Fee'));
        expect(rec.status, equals('Success'));
      }

      // 4. Breakdown verification
      final cardPayments = collectionProvider.getPaymentsForCollection(entry.id);
      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: cardPayments,
        loaneeLoanAmount: 12100.0,
        loaneeDueAmount: 5000.0,
        maturityDate: DateTime(2026, 7, 1),
        sanctionDate: DateTime(2026, 2, 1),
        asOfDate: asOf12,
      );

      expect(breakdown.lateUnits, equals(2));
      expect(breakdown.calculatedLateFine, equals(7.26));
    });

    test('TEST B: Run sync again on 12/09 -> 0 duplicate records created', () async {
      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-TEST-B',
        customerId: 'CUST-B',
        accountNumber: 'ACC-B',
        loaneeName: 'Test Loanee B',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: DateTime(2026, 2, 1),
        payableAmount: 121.0,
        loanAmount: 12100.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-HIST-09',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 10, 0, 0),
        ),
        saveToRemote: false,
      );

      final asOf12 = DateTime(2026, 9, 12);
      final run1 = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );
      expect(run1.length, equals(2));

      // Run 2 on same day 12/09:
      final run2 = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );

      // No new records inserted
      expect(run2.length, equals(0));

      final allPayments = collectionProvider.getPaymentsForCollection(entry.id);
      // Only initial 1 + 2 auto-assessed = 3 total payment models
      expect(allPayments.length, equals(3));
      final latePayments = allPayments.where((p) => p.lateFine > 0).toList();
      expect(latePayments.length, equals(2));
    });

    test('TEST C: Advance date to 13/09 -> 12/09 inserted automatically, total 3 records = ₹10.89', () async {
      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-TEST-C',
        customerId: 'CUST-C',
        accountNumber: 'ACC-C',
        loaneeName: 'Test Loanee C',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: DateTime(2026, 2, 1),
        payableAmount: 121.0,
        loanAmount: 12100.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-HIST-09',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 10, 0, 0),
        ),
        saveToRemote: false,
      );

      // 1. Sync on 12/09 (creates 10/09 & 11/09)
      final asOf12 = DateTime(2026, 9, 12);
      await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );

      // 2. Midnight passes -> As of 13/09
      final asOf13 = DateTime(2026, 9, 13);
      final runNextDay = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf13,
        saveToRemote: false,
      );

      // 12/09 is now completed, so exactly 1 new record is created
      expect(runNextDay.length, equals(1));
      expect(runNextDay.first.createdAt.day, equals(12));
      expect(runNextDay.first.createdAt.month, equals(9));
      expect(runNextDay.first.lateFine, equals(3.63));

      // Total late fee records in provider is now 3 (10/09, 11/09, 12/09)
      final allPayments = collectionProvider.getPaymentsForCollection(entry.id);
      final autoLatePayments = allPayments.where((p) => p.lateFine > 0).toList();
      expect(autoLatePayments.length, equals(3));

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: allPayments,
        loaneeLoanAmount: 12100.0,
        loaneeDueAmount: 5000.0,
        maturityDate: DateTime(2026, 7, 1),
        sanctionDate: DateTime(2026, 2, 1),
        asOfDate: asOf13,
      );

      expect(breakdown.lateUnits, equals(3));
      expect(breakdown.calculatedLateFine, equals(10.89));
    });

    test('TEST D: Multiple sync calls -> idempotent, no duplicates', () async {
      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-TEST-D',
        customerId: 'CUST-D',
        accountNumber: 'ACC-D',
        loaneeName: 'Test Loanee D',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: DateTime(2026, 2, 1),
        payableAmount: 121.0,
        loanAmount: 12100.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-HIST-09',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 10, 0, 0),
        ),
        saveToRemote: false,
      );

      final asOf12 = DateTime(2026, 9, 12);
      // Run 5 times consecutively
      for (int i = 0; i < 5; i++) {
        await collectionProvider.syncAutoLateFeesForEntry(
          entry: entry,
          settingsProvider: settingsProvider,
          asOfDate: asOf12,
          saveToRemote: false,
        );
      }

      final allPayments = collectionProvider.getPaymentsForCollection(entry.id);
      final autoLateRecords = allPayments.where((p) => p.id.startsWith('PAY-LATE-')).toList();

      // Must have exactly 2 auto records (10-Sep, 11-Sep) and never duplicate
      expect(autoLateRecords.length, equals(2));
      final days = autoLateRecords.map((p) => p.createdAt.day).toSet();
      expect(days, equals({10, 11}));
    });

    test('TEST E: Customer paid on 10-Sep -> 10-Sep has NO late fee record, 11-Sep gets late fee', () async {
      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-TEST-E',
        customerId: 'CUST-E',
        accountNumber: 'ACC-E',
        loaneeName: 'Test Loanee E',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: DateTime(2026, 2, 1),
        payableAmount: 121.0,
        loanAmount: 12100.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Customer payment on 09-Sep:
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-E-09',
          collectionId: entry.id,
          paymentAmount: 121.0,
          remainingBalance: 4879.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 11, 0, 0),
        ),
        saveToRemote: false,
      );

      // Customer made collection payment on 10-Sep:
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-E-10',
          collectionId: entry.id,
          paymentAmount: 121.0,
          remainingBalance: 4758.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 10, 11, 0, 0),
        ),
        saveToRemote: false,
      );

      // Today is 12-Sep
      final asOf12 = DateTime(2026, 9, 12);
      final inserted = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );

      // 10-Sep had a payment -> NOT a missed day!
      // Only 11-Sep was missed -> 1 record inserted
      expect(inserted.length, equals(1));
      expect(inserted.first.createdAt.day, equals(11));
      expect(inserted.any((p) => p.createdAt.day == 10), isFalse);
    });

    test('TEST F: Outstanding balance = ₹0 -> No new late fee records generated', () async {
      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-TEST-F',
        customerId: 'CUST-F',
        accountNumber: 'ACC-F',
        loaneeName: 'Test Loanee F',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: DateTime(2026, 2, 1),
        payableAmount: 121.0,
        loanAmount: 12100.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Fully paid off on 09-Sep:
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-F-09',
          collectionId: entry.id,
          paymentAmount: 12100.0,
          remainingBalance: 0.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 10, 0, 0),
        ),
        saveToRemote: false,
      );

      final asOf12 = DateTime(2026, 9, 12);
      final inserted = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );

      expect(inserted.isEmpty, isTrue, reason: 'Cleared loan balance must not accumulate late fees');
    });

    test('TEST G: Post-Maturity loan -> 7% Post-Maturity Interest and Daily Late Fee continue independently', () async {
      final sanctionDate = DateTime(2026, 2, 1);
      final maturityDate = DateTime(2026, 7, 1);
      final asOf12 = DateTime(2026, 9, 12); // Past maturity (2 months overdue)

      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-TEST-G',
        customerId: 'CUST-G',
        accountNumber: 'ACC-G',
        loaneeName: 'Test Loanee G Post Maturity',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        payableAmount: 121.0,
        loanAmount: 12100.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Payment on 09-Sep leaving balance
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-G-09',
          collectionId: entry.id,
          paymentAmount: 2100.0,
          remainingBalance: 10000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 10, 0, 0),
        ),
        saveToRemote: false,
      );

      // Sync auto late fees
      final inserted = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );

      // 10/09 & 11/09 inserted (2 records * ₹3.63 = ₹7.26)
      expect(inserted.length, equals(2));

      // Verify post-maturity breakdown
      final allPayments = collectionProvider.getPaymentsForCollection(entry.id);
      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: allPayments,
        loaneeLoanAmount: 12100.0,
        loaneeDueAmount: 10000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: asOf12,
      );

      // 1. Post-maturity interest is calculated and independent
      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.postMaturityBreakdown, isNotNull);
      expect(breakdown.postMaturityBreakdown!.overdueMonths, greaterThan(0));
      expect(breakdown.postMaturityBreakdown!.cumulativeInterestAmount, greaterThan(0.0));

      // 2. Daily Late Fee continues independently
      expect(breakdown.lateUnits, equals(2));
      expect(breakdown.calculatedLateFine, equals(7.26));
      expect(breakdown.lateFineRate, equals(3.63));
    });
  });
}
