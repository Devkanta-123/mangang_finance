import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/missing_payment_model.dart';
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

    test('Missing week calculation strictly matches user rule (Sep 18 = 2 weeks, Sep 21 = 1 week on Sep 28)', () {
      final asOfDate = DateTime(2026, 9, 28);

      // September 21, 2026 is 7 days ago -> 1 week
      final weeksForSep21 = MissingPaymentRecord.calculateWeeks(
        missedDate: DateTime(2026, 9, 21),
        asOfDate: asOfDate,
      );
      expect(weeksForSep21, 1);

      // September 18, 2026 is 10 days ago -> 2 weeks
      final weeksForSep18 = MissingPaymentRecord.calculateWeeks(
        missedDate: DateTime(2026, 9, 18),
        asOfDate: asOfDate,
      );
      expect(weeksForSep18, 2);

      // Boundary tests
      // 1 day ago -> 1 week
      expect(
        MissingPaymentRecord.calculateWeeks(missedDate: DateTime(2026, 9, 27), asOfDate: asOfDate),
        1,
      );
      // 14 days ago -> 2 weeks
      expect(
        MissingPaymentRecord.calculateWeeks(missedDate: DateTime(2026, 9, 14), asOfDate: asOfDate),
        2,
      );
      // 15 days ago -> 3 weeks
      expect(
        MissingPaymentRecord.calculateWeeks(missedDate: DateTime(2026, 9, 13), asOfDate: asOfDate),
        3,
      );
    });

    test('Sync auto late fees calculates missingWeek and missingBalance = missingWeek * fine', () async {
      final asOfDate = DateTime(2026, 9, 28);
      final entry = RoCollectionEntry(
        id: 'COLL-003',
        customerId: 'CUST-003',
        accountNumber: 'ACC-1003',
        loaneeName: 'User Test Loanee',
        loaneeAddress: 'Address 3',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543212',
        loanAmount: 10000.0,
        payableAmount: 100.0,
        createdAt: DateTime(2026, 9, 1),
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Real payment on 2026-09-17 so candidate dates start from 2026-09-18
      final payment = CollectionPaymentModel(
        id: 'PAY-START-1',
        collectionId: entry.id,
        paymentAmount: 100.0,
        remainingBalance: 9900.0,
        paymentType: 'Cash',
        roPasscode: '1234',
        roName: 'RO 1',
        roId: 'RO-1',
        roRoute: 'Route A',
        createdAt: DateTime(2026, 9, 17, 10, 0),
        status: 'Success',
      );
      await collectionProvider.addCollectionPayment(payment, saveToRemote: false);

      // Run sync as of 2026-09-28
      final newRecords = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOfDate,
        saveToRemote: false,
      );

      // Check candidate date 2026-09-18 (10 days past -> 2 weeks)
      final sep18Rec = newRecords.firstWhere(
        (r) => r.missedDate.year == 2026 && r.missedDate.month == 9 && r.missedDate.day == 18,
      );
      expect(sep18Rec.missingWeek, 2);
      expect(sep18Rec.missingFine, 3.0); // 3% of 100
      expect(sep18Rec.missingBalance, 6.0); // 2 * 3.0

      // Check candidate date 2026-09-21 (7 days past -> 1 week)
      final sep21Rec = newRecords.firstWhere(
        (r) => r.missedDate.year == 2026 && r.missedDate.month == 9 && r.missedDate.day == 21,
      );
      expect(sep21Rec.missingWeek, 1);
      expect(sep21Rec.missingFine, 3.0);
      expect(sep21Rec.missingBalance, 3.0); // 1 * 3.0
    });

    test('Clearing past missing record preserves missingBalance and locks in resolvedWeek', () async {
      final missedDate = DateTime(2026, 9, 18);
      final paidDate = DateTime(2026, 9, 28);
      final entry = RoCollectionEntry(
        id: 'COLL-004',
        customerId: 'CUST-004',
        accountNumber: 'ACC-1004',
        loaneeName: 'Loanee Clear Test',
        loaneeAddress: 'Address 4',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543213',
        loanAmount: 10000.0,
        payableAmount: 100.0,
        createdAt: DateTime(2026, 9, 1),
      );
      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      final initialRecord = MissingPaymentRecord(
        id: 'MISS-COLL-004-20260918',
        collectionId: entry.id,
        loaneeName: entry.loaneeName,
        collectionType: 'daily',
        missedDate: missedDate,
        dayPayment: 0.0,
        missingPay: 100.0,
        missingFine: 3.0,
        missingWeek: 1,
        missingBalance: 3.0,
        status: 'missing',
        createdAt: missedDate,
        updatedAt: missedDate,
      );
      collectionProvider.setMissingRecordsForTest([initialRecord]);

      // Loanee clears the missing record on Sep 28
      final cleared = await collectionProvider.clearPastMissingRecord(
        missingRecord: initialRecord,
        paidDate: paidDate,
        amountPaidForMissing: 100.0,
      );

      expect(cleared, isNotNull);
      expect(cleared!.isResolved, isTrue);
      expect(cleared.paidDate, DateTime(2026, 9, 28));
      // 10 days past -> locked in at 2 weeks
      expect(cleared.missingWeek, 2);
      // missingBalance = 2 * 3.0 = 6.0 preserved!
      expect(cleared.missingBalance, 6.0);
      expect(cleared.missingPay, 0.0);

      // Verify total missing balance includes the resolved record
      final totalMissingBal = collectionProvider.getTotalMissingBalanceForCollection(entry.id);
      expect(totalMissingBal, 6.0);
    });

    test('Late Payment Fee balance matches Total Missing Balance, not just single late payment fee', () async {
      final entry = RoCollectionEntry(
        id: 'COLL-005',
        customerId: 'CUST-005',
        accountNumber: 'ACC-1005',
        loaneeName: 'Late Fee Match Test',
        loaneeAddress: 'Address 5',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543214',
        loanAmount: 10000.0,
        payableAmount: 100.0,
        createdAt: DateTime(2026, 9, 1),
      );
      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      final payment = CollectionPaymentModel(
        id: 'PAY-START-5',
        collectionId: entry.id,
        paymentAmount: 100.0,
        remainingBalance: 9900.0,
        paymentType: 'Cash',
        roPasscode: '1234',
        roName: 'RO 1',
        roId: 'RO-1',
        roRoute: 'Route A',
        createdAt: DateTime(2026, 9, 17, 10, 0),
        status: 'Success',
      );
      await collectionProvider.addCollectionPayment(payment, saveToRemote: false);

      // Missed on 2026-09-18. As of 2026-09-28 (10 days past -> 2 weeks)
      await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: DateTime(2026, 9, 28),
        saveToRemote: false,
      );

      final totalMissingBal = collectionProvider.getTotalMissingBalanceForCollection(entry.id);
      // Sum of missing balances across all candidate dates (Sep 18 & 19 @ 2 wks + Sep 21-26 @ 1 wk = 30.00)
      expect(totalMissingBal, 30.0);

      final payments = collectionProvider.getPaymentsForCollection(entry.id);
      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        overrideLateFine: totalMissingBal,
      );

      // Late Payment Fee balance under Payment matches total missing balance (₹30.00), not just single fee (₹3.00)
      expect(breakdown.calculatedLateFine, 30.0);
    });
  });
}

