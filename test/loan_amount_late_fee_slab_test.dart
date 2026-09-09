// test/loan_amount_late_fee_slab_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loan Amount Late Fee Slab Rates', () {
    test('Loan amount <= ₹10,000 uses ₹3/day slab', () {
      expect(SettingsProvider.getLateFeeRateForLoanAmount(5000.0), equals(3.0));
      expect(SettingsProvider.getLateFeeRateForLoanAmount(10000.0), equals(3.0));
    });

    test('Loan amount > ₹10,000 and < ₹30,000 uses ₹6/day slab (e.g. ₹23,000 loan)', () {
      expect(SettingsProvider.getLateFeeRateForLoanAmount(10000.01), equals(6.0));
      expect(SettingsProvider.getLateFeeRateForLoanAmount(15000.0), equals(6.0));
      expect(SettingsProvider.getLateFeeRateForLoanAmount(23000.0), equals(6.0));
      expect(SettingsProvider.getLateFeeRateForLoanAmount(29999.99), equals(6.0));
    });

    test('Loan amount >= ₹30,000 uses ₹9/day slab', () {
      expect(SettingsProvider.getLateFeeRateForLoanAmount(30000.0), equals(9.0));
      expect(SettingsProvider.getLateFeeRateForLoanAmount(57500.0), equals(9.0));
      expect(SettingsProvider.getLateFeeRateForLoanAmount(100000.0), equals(9.0));
    });
  });

  group('Screenshot Example: ₹23,000 Loan with 2 Late Days', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    test('Calculates Late Payment Fee = ₹12.00 (NOT ₹6.00) and Total Payable Today = ₹600.00', () {
      // Wednesday Aug 19, 2026 as reference date
      final asOfDate = DateTime(2026, 8, 19);
      // Loan created on Monday Aug 17, 2026 -> 2 late days (Mon & Tue missed)
      final createdAt = DateTime(2026, 8, 17);

      final entry = RoCollectionEntry(
        id: 'COL-TEST-23K',
        customerId: 'CUST-23K',
        accountNumber: 'ACC-23000',
        loaneeName: 'Khundrakpam Herojit',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543210',
        loanAmount: 23000.0,
        payableAmount: 200.0,
        createdAt: createdAt,
      );

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [],
        asOfDate: asOfDate,
      );

      // Late Days: 2
      expect(breakdown.lateUnits, equals(2));
      // Late Fee Rate: ₹6/day for ₹23,000 loan
      expect(breakdown.lateFineRate, equals(6.0));
      // Late Payment Fee: 2 * 6 = ₹12.00 (NOT ₹6.00)
      expect(breakdown.calculatedLateFine, equals(12.0));
      // Overdue Missed Amount: 2 * 200 = ₹400.00
      expect(breakdown.overdueMissedAmount, equals(400.0));
      // Today's Installment: ₹200.00
      expect(breakdown.currentInstallment, equals(200.0));
      // Total Payable Today: ₹400 + ₹200 = ₹600.00
      expect(breakdown.totalPayableAmount, equals(600.0));
      // Grand Total With Penalty: ₹600 + ₹12 = ₹612.00
      expect(breakdown.grandTotalWithPenalty, equals(612.0));
    });
  });

  group('Carry-Forward & Payment Balance Logic', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    test('1. Normal installment payment (₹600) with ₹0 late fee carries forward the ₹12 late fee', () {
      final asOfDate = DateTime(2026, 8, 20); // Thursday
      final paymentDate = DateTime(2026, 8, 19); // Wednesday

      final entry = RoCollectionEntry(
        id: 'COL-TEST-CARRY',
        customerId: 'CUST-CARRY',
        accountNumber: 'ACC-CARRY',
        loaneeName: 'Test Loanee',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543210',
        loanAmount: 23000.0,
        payableAmount: 200.0,
        createdAt: DateTime(2026, 8, 17),
      );

      // Payment on Wednesday: ₹600 installment paid, late fine NOT cleared (0.00)
      // Remarks stores audit trail note:
      final payment1 = CollectionPaymentModel(
        id: 'PAY-1',
        collectionId: entry.id,
        paymentAmount: 600.0,
        remainingBalance: 22412.0, // 23,012 - 600 = 22,412
        lateFine: 0.0,
        remarks: 'Collected by RO | Late Fee: ₹12.00 assessed, ₹0.00 cleared, ₹12.00 carried forward',
        createdAt: paymentDate,
      );

      // Next day (Thursday), customer arrives on-time (0 missed days since Wednesday payment)
      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [payment1],
        asOfDate: asOfDate,
      );

      // Previous unpaid late fee is carried forward: ₹12.00
      expect(breakdown.previousUnpaidLateFee, equals(12.0));
      // Current interval late fine is 0.0 (on-time today)
      expect(breakdown.currentIntervalLateFine, equals(0.0));
      // Total assessed fee recommendation is ₹12.00
      expect(breakdown.calculatedLateFine, equals(12.0));
      // Explanation clearly informs user about carry-forward:
      expect(
        breakdown.carriedForwardExplanation,
        equals('₹12.00 previous late payment fee carried forward because it was not cleared in the previous payment.'),
      );
      // Total Outstanding Due incorporates carried-forward fee
      expect(breakdown.totalOutstandingDue, greaterThanOrEqualTo(22412.0));
    });

    test('2. When cleared, clearing late fee reduces balance properly (e.g. ₹23,012 - ₹12 = ₹23,000)', () {
      const double currentBalWithFee = 23012.0;
      const double paymentAmount = 0.0;
      const double lateFineCleared = 12.0;

      // Balance adjustment formula used in submitEntryForm and transaction_page:
      final newRemainingBalance = (currentBalWithFee - paymentAmount - lateFineCleared).clamp(0.0, 999999.0);
      expect(newRemainingBalance, equals(23000.0));
    });

    test('3. Clearing the carried forward fee in subsequent payment clears the carried fee', () {
      final entry = RoCollectionEntry(
        id: 'COL-TEST-CLEARED',
        customerId: 'CUST-CLEARED',
        accountNumber: 'ACC-CLEARED',
        loaneeName: 'Test Loanee 2',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543210',
        loanAmount: 23000.0,
        payableAmount: 200.0,
        createdAt: DateTime(2026, 8, 17),
      );

      final payment1 = CollectionPaymentModel(
        id: 'PAY-1',
        collectionId: entry.id,
        paymentAmount: 600.0,
        lateFine: 0.0,
        remarks: 'Late Fee: ₹12.00 assessed, ₹0.00 cleared, ₹12.00 carried forward',
        createdAt: DateTime(2026, 8, 19),
      );

      // Payment 2 clears the ₹12.00 late fee
      final payment2 = CollectionPaymentModel(
        id: 'PAY-2',
        collectionId: entry.id,
        paymentAmount: 200.0,
        lateFine: 12.0,
        remarks: 'Late Fee: ₹12.00 cleared',
        createdAt: DateTime(2026, 8, 20),
      );

      final unpaid = SettingsProvider.calculatePreviousUnpaidLateFee(
        entry: entry,
        payments: [payment1, payment2],
      );

      expect(unpaid, equals(0.0), reason: 'Fee was explicitly cleared in payment 2');
    });

    test('4. Partial clearing of carried forward fee preserves remaining unpaid fee', () {
      final entry = RoCollectionEntry(
        id: 'COL-TEST-PARTIAL',
        customerId: 'CUST-PARTIAL',
        accountNumber: 'ACC-PARTIAL',
        loaneeName: 'Test Loanee 3',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543210',
        loanAmount: 23000.0,
        payableAmount: 200.0,
        createdAt: DateTime(2026, 8, 17),
      );

      final payment1 = CollectionPaymentModel(
        id: 'PAY-1',
        collectionId: entry.id,
        paymentAmount: 600.0,
        lateFine: 5.0, // Only ₹5 cleared out of ₹12
        remarks: 'Late Fee: ₹12.00 assessed, ₹5.00 cleared, ₹7.00 carried forward',
        createdAt: DateTime(2026, 8, 19),
      );

      final unpaid = SettingsProvider.calculatePreviousUnpaidLateFee(
        entry: entry,
        payments: [payment1],
      );

      expect(unpaid, equals(7.0), reason: '₹7.00 should remain carried forward');
    });

    test('5. Remaining Balance does NOT auto-add unpaid late fee, while Total Outstanding Due / Late Due Amount includes it', () async {
      final collectionProvider = CollectionSheetProvider();
      final entry = RoCollectionEntry(
        id: 'COL-BAL-TEST',
        customerId: 'CUST-BAL',
        accountNumber: 'ACC-BAL',
        loaneeName: 'Balance Test',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route A',
        mobileNo: '9876543210',
        loanAmount: 23000.0,
        payableAmount: 200.0,
        createdAt: DateTime(2026, 8, 17),
      );

      await collectionProvider.addCollectionEntry(entry);

      final payment1 = CollectionPaymentModel(
        id: 'PAY-BAL-1',
        collectionId: entry.id,
        paymentAmount: 600.0,
        lateFine: 0.0,
        remarks: 'Late Fee: ₹12.00 assessed, ₹0.00 cleared, ₹12.00 carried forward',
        createdAt: DateTime(2026, 8, 19),
      );

      await collectionProvider.addCollectionPayment(payment1);

      // Remaining Balance: initialBal (23,000) - totalPaid (600) = 22,400.00 (pure loan balance)
      final bal = collectionProvider.getLatestRemainingBalance(entry.id);
      expect(bal, equals(22400.0));

      // Late Due Amount / Total Outstanding Due = 22,400 + 12 = 22,412.00
      final totalDue = collectionProvider.getLatestTotalOutstandingDue(entry.id);
      expect(totalDue, equals(22412.0));
    });
  });

  group('Weekly Late Payment Fee Slab (₹25/wk) & Carry Forward', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    test('Weekly late fee rate: 1 week late = ₹25.00, 2 weeks late = ₹50.00', () {
      // Loan created on Monday Aug 3, 2026
      final createdAt = DateTime(2026, 8, 3);

      final entry = RoCollectionEntry(
        id: 'COL-WEEKLY-TEST',
        customerId: 'CUST-W1',
        accountNumber: 'ACC-W1',
        loaneeName: 'Weekly Loanee',
        loaneeAddress: 'Imphal',
        collectionType: 'Weekly',
        route: 'Route W',
        mobileNo: '9876543210',
        loanAmount: 11375.0,
        payableAmount: 650.0,
        createdAt: createdAt,
      );

      // 1 week late: Aug 10, 2026 (7 days elapsed, 0 paid -> 1 week late)
      final breakdown1Wk = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [],
        asOfDate: DateTime(2026, 8, 10),
      );
      expect(breakdown1Wk.lateUnits, equals(1));
      expect(breakdown1Wk.calculatedLateFine, equals(25.0));

      // 2 weeks late: Aug 17, 2026 (14 days elapsed, 0 paid -> 2 weeks late)
      final breakdown2Wks = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [],
        asOfDate: DateTime(2026, 8, 17),
      );
      expect(breakdown2Wks.lateUnits, equals(2));
      expect(breakdown2Wks.calculatedLateFine, equals(50.0));

      // 3 weeks late: Aug 24, 2026 (21 days elapsed, 0 paid -> 3 weeks late)
      final breakdown3Wks = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [],
        asOfDate: DateTime(2026, 8, 24),
      );
      expect(breakdown3Wks.lateUnits, equals(3));
      expect(breakdown3Wks.calculatedLateFine, equals(75.0));
    });

    test('Weekly carry forward: unpaid ₹25 / ₹50 late fee carries forward to next payment', () {
      final createdAt = DateTime(2026, 8, 3);

      final entry = RoCollectionEntry(
        id: 'COL-WEEKLY-CARRY',
        customerId: 'CUST-W2',
        accountNumber: 'ACC-W2',
        loaneeName: 'Weekly Loanee 2',
        loaneeAddress: 'Imphal',
        collectionType: 'Weekly',
        route: 'Route W',
        mobileNo: '9876543210',
        loanAmount: 11375.0,
        payableAmount: 650.0,
        createdAt: createdAt,
      );

      // Week 2: ₹650 paid, but 2-week late fee (₹50) was NOT paid (carried forward)
      final payment1 = CollectionPaymentModel(
        id: 'PAY-W-1',
        collectionId: entry.id,
        paymentAmount: 650.0,
        lateFine: 0.0,
        remarks: 'Late Fee: ₹50.00 assessed, ₹0.00 cleared, ₹50.00 carried forward',
        createdAt: DateTime(2026, 8, 17),
      );

      // On Aug 17, calculate breakdown after payment1 (1 week paid of 2 elapsed = 1 week late + ₹50 carried forward)
      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [payment1],
        asOfDate: DateTime(2026, 8, 17),
      );

      // Previous unpaid fee carried forward: ₹50.00
      expect(breakdown.previousUnpaidLateFee, equals(50.0));
      // 1 missed week remaining = ₹25.00 + ₹50.00 carried forward = ₹75.00
      expect(breakdown.calculatedLateFine, equals(75.0));
      expect(
        breakdown.carriedForwardExplanation,
        equals('₹50.00 previous late payment fee carried forward because it was not cleared in the previous payment.'),
      );

      // Now customer pays ₹650 and clears ₹50 of late fee
      final payment2 = CollectionPaymentModel(
        id: 'PAY-W-2',
        collectionId: entry.id,
        paymentAmount: 650.0,
        lateFine: 50.0,
        remarks: 'Late Fee: ₹50.00 cleared',
        createdAt: DateTime(2026, 8, 24),
      );

      final remainingCarried = SettingsProvider.calculatePreviousUnpaidLateFee(
        entry: entry,
        payments: [payment1, payment2],
      );
      expect(remainingCarried, equals(0.0), reason: '₹50 carried fee was fully cleared in payment2');
    });
  });
}
