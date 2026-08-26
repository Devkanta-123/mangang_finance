import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Post-Maturity Overdue Interest Tests (Immediate Trigger & Latest Period Interest)', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    test('Test 1: Maturity Date = 01-08-2026, Current Date = 01-08-2026 (Not overdue)', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);
      final asOfDate = DateTime(2026, 8, 1);

      final breakdown = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isFalse);
      expect(breakdown.overdueMonths, equals(0));
      expect(breakdown.postMaturityInterestAmount, equals(0.0));
      expect(breakdown.postMaturityPayableAmount, equals(34200.0));
      expect(breakdown.monthlySteps, isEmpty);
    });

    test('Test 2: Maturity Date = 01-08-2026, Current Date = 02-08-2026 (Immediate 1st day overdue)', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);
      final asOfDate = DateTime(2026, 8, 2);

      final breakdown = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.overdueMonths, equals(1));
      // First overdue interest = 34,200 * 7% = ₹2,394
      expect(breakdown.postMaturityInterestAmount, equals(2394.0));
      // Total Payable = 34,200 + 2,394 = ₹36,594
      expect(breakdown.postMaturityPayableAmount, equals(36594.0));
      expect(breakdown.monthlySteps.length, equals(1));
      expect(breakdown.monthlySteps[0].monthNumber, equals(1));
      expect(breakdown.monthlySteps[0].startingBalance, equals(34200.0));
      expect(breakdown.monthlySteps[0].interestAmount, equals(2394.0));
      expect(breakdown.monthlySteps[0].endingBalance, equals(36594.0));
    });

    test('Test 3: Maturity Date = 01-08-2026, Current Date = 15-08-2026 (Still 1st overdue period, no daily prorating)', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);
      final asOfDate = DateTime(2026, 8, 15);

      final breakdown = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.overdueMonths, equals(1));
      // Applicable overdue interest remains ₹2,394 (NO daily/partial addition)
      expect(breakdown.postMaturityInterestAmount, equals(2394.0));
      expect(breakdown.postMaturityPayableAmount, equals(36594.0));
      expect(breakdown.monthlySteps.length, equals(1));
    });

    test('Test 4: Maturity Date = 01-08-2026, Current Date = after second boundary (15-09-2026)', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);
      final asOfDate = DateTime(2026, 9, 15);

      final breakdown = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.overdueMonths, equals(2));

      // Steps verification:
      // Month 1: 34,200 * 7% = 2,394 -> 36,594
      // Month 2: 36,594 * 7% = 2,561.58 -> 39,155.58
      expect(breakdown.monthlySteps.length, equals(2));
      expect(breakdown.monthlySteps[0].interestAmount, equals(2394.0));
      expect(breakdown.monthlySteps[0].endingBalance, equals(36594.0));
      expect(breakdown.monthlySteps[1].interestAmount, equals(2561.58));
      expect(breakdown.monthlySteps[1].endingBalance, equals(39155.58));

      // CRITICAL: Overdue Interest field must show ONLY the latest month's interest (₹2,561.58), NOT cumulative (₹4,955.58)
      expect(breakdown.postMaturityInterestAmount, equals(2561.58));
      expect(breakdown.postMaturityInterestAmount, isNot(equals(4955.58)));

      // Total Payable = ₹39,155.58
      expect(breakdown.postMaturityPayableAmount, equals(39155.58));
    });

    test('Test 5: Idempotency - Calling calculation repeatedly on the same date produces exact same result', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);
      final asOfDate = DateTime(2026, 9, 15);

      final run1 = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      final run2 = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      expect(run1.postMaturityInterestAmount, equals(2561.58));
      expect(run2.postMaturityInterestAmount, equals(2561.58));
      expect(run1.postMaturityPayableAmount, equals(39155.58));
      expect(run2.postMaturityPayableAmount, equals(39155.58));
    });

    test('Test 6: Loan with maturity date in the future', () {
      final sanctionDate = DateTime(2026, 7, 1);
      final maturityDate = DateTime(2026, 12, 1); // 5 months in future
      final asOfDate = DateTime(2026, 8, 22);

      final breakdown = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isFalse);
      expect(breakdown.overdueMonths, equals(0));
      expect(breakdown.postMaturityInterestAmount, equals(0.0));
      expect(breakdown.postMaturityPayableAmount, equals(34200.0));
    });

    test('Test 7: Period 3 compounding (15-10-2026)', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);
      final asOfDate = DateTime(2026, 10, 15);

      final breakdown = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 34200.0,
        standardInstallment: 100.0,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.overdueMonths, equals(3));
      // Month 3 interest = 39,155.58 * 7% = 2,740.89
      expect(breakdown.postMaturityInterestAmount, equals(2740.89));
      // Total Payable = 39,155.58 + 2,740.89 = 41,896.47
      expect(breakdown.postMaturityPayableAmount, equals(41896.47));
    });

    test('Test 8: Collection Late Payable Breakdown Integration for Past-Maturity Loan', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);
      final asOfDate = DateTime(2026, 9, 15); // Period 2

      final entry = RoCollectionEntry(
        id: 'COL-MATURED-01',
        customerId: 'CUST-MATURED-01',
        accountNumber: 'ACC-880011',
        loaneeName: 'Matured Loanee',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Master Route',
        mobileNo: '9876500000',
        createdAt: sanctionDate,
        loanAmount: 57500.0,
        actualPrincipal: 50000.0,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-01',
          collectionId: entry.id,
          paymentAmount: 23300.0,
          remainingBalance: 34200.0,
          createdAt: DateTime(2026, 7, 10),
        ),
      ];

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 57500.0,
        maturityDate: maturityDate,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isTrue);
      // Total payable is ₹39,155.58
      expect(breakdown.totalPayableAmount, equals(39155.58));
      // Overdue interest field is ONLY the latest month's interest: ₹2,561.58
      expect(breakdown.postMaturityBreakdown!.postMaturityInterestAmount, equals(2561.58));
      expect(breakdown.postMaturityBreakdown!.postMaturityPayableAmount, equals(39155.58));
    });

    test('Test 9: Prompt Specification Case - ₹39,000 loan, ₹2,300 paid -> ₹36,700 outstanding across 1, 2, and 3 overdue months', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);

      // Month 1: 15-08-2026
      final m1 = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 36700.0,
        standardInstallment: 100.0,
        asOfDate: DateTime(2026, 8, 15),
      );
      expect(m1.isPastMaturity, isTrue);
      expect(m1.overdueMonths, equals(1));
      expect(m1.remainingBalance, equals(36700.0));
      expect(m1.postMaturityInterestAmount, equals(2569.0));
      expect(m1.postMaturityPayableAmount, equals(39269.0));

      // Month 2 (no payment): 15-09-2026
      final m2 = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 36700.0,
        standardInstallment: 100.0,
        asOfDate: DateTime(2026, 9, 15),
      );
      expect(m2.isPastMaturity, isTrue);
      expect(m2.overdueMonths, equals(2));
      expect(m2.remainingBalance, equals(39269.0));
      expect(m2.postMaturityInterestAmount, equals(2748.83));
      expect(m2.postMaturityPayableAmount, equals(42017.83));

      // Month 3 (no payment): 15-10-2026
      final m3 = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 36700.0,
        standardInstallment: 100.0,
        asOfDate: DateTime(2026, 10, 15),
      );
      expect(m3.isPastMaturity, isTrue);
      expect(m3.overdueMonths, equals(3));
      expect(m3.remainingBalance, equals(42017.83));
      expect(m3.postMaturityInterestAmount, equals(2941.25));
      expect(m3.postMaturityPayableAmount, equals(44959.08));
    });

    test('Test 10: Partial payment handling after overdue interest is added (₹500 payment in month 1)', () {
      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);

      final entry = RoCollectionEntry(
        id: 'COL-PARTIAL-01',
        customerId: 'CUST-P01',
        accountNumber: 'ACC-P01',
        loaneeName: 'Partial Payment Loanee',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Master Route',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        loanAmount: 39000.0,
      );

      final payments = [
        // Pre-maturity payment of ₹2,300
        CollectionPaymentModel(
          id: 'PAY-PRE-01',
          collectionId: entry.id,
          paymentAmount: 2300.0,
          remainingBalance: 36700.0,
          createdAt: DateTime(2026, 5, 15),
        ),
        // Post-maturity partial payment of ₹500 during Month 1
        CollectionPaymentModel(
          id: 'PAY-POST-01',
          collectionId: entry.id,
          paymentAmount: 500.0,
          remainingBalance: 38769.0, // 39,269 - 500 = 38,769
          createdAt: DateTime(2026, 8, 20),
        ),
      ];

      // Verify Month 2 breakdown on 15-09-2026:
      // Starting balance = ₹38,769
      // Interest = 38,769 * 7% = ₹2,713.83
      // Total Payable = 38,769 + 2,713.83 = ₹41,482.83
      final breakdownMonth2 = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 39000.0,
        maturityDate: maturityDate,
        asOfDate: DateTime(2026, 9, 15),
      );

      expect(breakdownMonth2.isPastMaturity, isTrue);
      expect(breakdownMonth2.postMaturityBreakdown!.overdueMonths, equals(2));
      expect(breakdownMonth2.postMaturityBreakdown!.remainingBalance, equals(38769.0));
      expect(breakdownMonth2.postMaturityBreakdown!.postMaturityInterestAmount, equals(2713.83));
      expect(breakdownMonth2.postMaturityBreakdown!.postMaturityPayableAmount, equals(41482.83));
      expect(breakdownMonth2.totalPayableAmount, equals(41482.83));
    });

    test('Test 11: Dynamic Overdue Rate from Settings Provider (e.g. 10% instead of 7%)', () async {
      await settingsProvider.saveInterestPolicySettings(
        normalRate: 3.0,
        postMaturityRate: 10.0,
      );

      final sanctionDate = DateTime(2026, 3, 1);
      final maturityDate = DateTime(2026, 8, 1);

      final breakdown = settingsProvider.getPostMaturityBreakdown(
        sanctionDate: sanctionDate,
        maturityDate: maturityDate,
        remainingBalance: 36700.0,
        standardInstallment: 100.0,
        asOfDate: DateTime(2026, 8, 15),
      );

      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.postMaturityInterestRate, equals(10.0));
      // 36,700 * 10% = 3,670
      expect(breakdown.postMaturityInterestAmount, equals(3670.0));
      expect(breakdown.postMaturityPayableAmount, equals(40370.0));
    });
  });
}
