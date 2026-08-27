// test/overdue_compound_interest_calculation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Overdue Compound Interest Calculation - DB-Driven Tests', () {
    late SettingsProvider settingsProvider;

    setUp(() {
      settingsProvider = SettingsProvider();
    });

    test('1. Overdue interest rate comes from configured setting (default 7.0% per month)', () {
      expect(settingsProvider.postMaturityInterestRate, 7.0);
    });

    test('2. Loan not past maturity date has 0 overdue months and ₹0.00 overdue interest', () {
      final sanctionDate = DateTime(2026, 1, 1);
      final maturityDate = LoaneeAccount.calculateMaturityDate(sanctionDate); // 2026-06-01 (5 months)
      final asOfDate = DateTime(2026, 5, 15); // Before maturity

      final entry = RoCollectionEntry(
        id: 'ENTRY-1',
        customerId: 'CUST-001',
        accountNumber: 'ACC-001',
        loaneeName: 'Test Loanee',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Mangang',
        mobileNo: '9876543210',
        loanAmount: 50000.0,
        createdAt: sanctionDate,
      );

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: const [],
        loaneeLoanAmount: 50000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: asOfDate,
      );

      expect(breakdown.isPastMaturity, isFalse);
      expect(breakdown.postMaturityBreakdown?.overdueMonths ?? 0, 0);
      expect(breakdown.postMaturityBreakdown?.postMaturityInterestAmount ?? 0.0, 0.0);
      expect(breakdown.postMaturityBreakdown?.cumulativeInterestAmount ?? 0.0, 0.0);
    });

    test('3. Compound overdue interest chains month-by-month without hardcoding', () {
      final sanctionDate = DateTime(2025, 1, 1);
      final maturityDate = LoaneeAccount.calculateMaturityDate(sanctionDate); // 2025-06-01 (5 months)
      // Exactly 3 overdue months: maturity is 2025-06-01 -> month 1 (06-02 to 07-01), month 2 (07-02 to 08-01), month 3 (08-02 to 09-01)
      final asOfDate = DateTime(2025, 8, 15); // Month 3 overdue

      const double initialUnpaidBalance = 39000.0;

      final entry = RoCollectionEntry(
        id: 'ENTRY-2',
        customerId: 'CUST-002',
        accountNumber: 'ACC-002',
        loaneeName: 'Compounding Loanee',
        loaneeAddress: 'Imphal West',
        collectionType: 'Daily',
        route: 'Luwang',
        mobileNo: '9876543211',
        loanAmount: initialUnpaidBalance,
        createdAt: sanctionDate,
      );

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: const [],
        loaneeLoanAmount: initialUnpaidBalance,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: asOfDate,
      );

      final postMaturity = breakdown.postMaturityBreakdown;
      expect(postMaturity, isNotNull);
      expect(postMaturity!.isPastMaturity, isTrue);
      expect(postMaturity.overdueMonths, 3);
      expect(postMaturity.monthlySteps.length, 3);

      // Month 1: 39,000 * 7% = 2,730 -> Ending = 41,730
      final step1 = postMaturity.monthlySteps[0];
      expect(step1.monthNumber, 1);
      expect(step1.startingBalance, 39000.0);
      expect(step1.interestAmount, 2730.0);
      expect(step1.endingBalance, 41730.0);

      // Month 2: Starting = 41,730 (previous ending balance), 41,730 * 7% = 2,921.10 -> Ending = 44,651.10
      final step2 = postMaturity.monthlySteps[1];
      expect(step2.monthNumber, 2);
      expect(step2.startingBalance, 41730.0);
      expect(step2.interestAmount, 2921.10);
      expect(step2.endingBalance, 44651.10);

      // Month 3: Starting = 44,651.10, 44,651.10 * 7% = 3,125.58 -> Ending = 47,776.68
      final step3 = postMaturity.monthlySteps[2];
      expect(step3.monthNumber, 3);
      expect(step3.startingBalance, 44651.10);
      expect(step3.interestAmount, 3125.58);
      expect(step3.endingBalance, 47776.68);

      // UI Fields verification:
      // Unpaid Remaining Balance (starting balance of current month)
      expect(postMaturity.remainingBalance, 44651.10);
      // Accrued Overdue Interest (current month interest)
      expect(postMaturity.postMaturityInterestAmount, 3125.58);
      // Total Payable Today = Unpaid Remaining Balance + Accrued Overdue Interest
      expect(postMaturity.postMaturityPayableAmount, 47776.68);
      expect(
        (postMaturity.remainingBalance + postMaturity.postMaturityInterestAmount).toStringAsFixed(2),
        postMaturity.postMaturityPayableAmount.toStringAsFixed(2),
      );
      expect(breakdown.totalPayableAmount, 47776.68);
    });

    test('4. Partial payments before maturity reduce starting balance before compounding begins', () {
      final sanctionDate = DateTime(2025, 1, 1);
      final maturityDate = LoaneeAccount.calculateMaturityDate(sanctionDate); // 2025-06-01
      final asOfDate = DateTime(2025, 6, 15); // Month 1 overdue

      // Pre-maturity payment of ₹11,000 against a ₹50,000 loan -> Balance at maturity = ₹39,000
      final payment1 = CollectionPaymentModel(
        id: 'PAY-1',
        collectionId: 'ENTRY-3',
        paymentAmount: 11000.0,
        createdAt: DateTime(2025, 3, 1),
      );

      final entry = RoCollectionEntry(
        id: 'ENTRY-3',
        customerId: 'CUST-003',
        accountNumber: 'ACC-003',
        loaneeName: 'Partial Paid Loanee',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Mangang',
        mobileNo: '9876543212',
        loanAmount: 50000.0,
        createdAt: sanctionDate,
      );

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [payment1],
        loaneeLoanAmount: 50000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: asOfDate,
      );

      final postMaturity = breakdown.postMaturityBreakdown;
      expect(postMaturity, isNotNull);
      expect(postMaturity!.isPastMaturity, isTrue);
      expect(postMaturity.overdueMonths, 1);
      expect(postMaturity.remainingBalance, 39000.0);
      expect(postMaturity.postMaturityInterestAmount, 2730.0); // 39,000 * 7%
      expect(postMaturity.postMaturityPayableAmount, 41730.0); // 39,000 + 2,730
    });

    test('5. Partial payments made during overdue months reduce subsequent compounding base', () {
      final sanctionDate = DateTime(2025, 1, 1);
      final maturityDate = LoaneeAccount.calculateMaturityDate(sanctionDate); // 2025-06-01
      final asOfDate = DateTime(2025, 7, 15); // Month 2 overdue

      // Payment made in Month 1 of overdue period (e.g. 2025-06-15)
      final overduePayment = CollectionPaymentModel(
        id: 'PAY-2',
        collectionId: 'ENTRY-4',
        paymentAmount: 10000.0,
        createdAt: DateTime(2025, 6, 15),
      );

      final entry = RoCollectionEntry(
        id: 'ENTRY-4',
        customerId: 'CUST-004',
        accountNumber: 'ACC-004',
        loaneeName: 'Mid-Overdue Paid Loanee',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Mangang',
        mobileNo: '9876543213',
        loanAmount: 39000.0,
        createdAt: sanctionDate,
      );

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: [overduePayment],
        loaneeLoanAmount: 39000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: asOfDate,
      );

      final postMaturity = breakdown.postMaturityBreakdown;
      expect(postMaturity, isNotNull);
      expect(postMaturity!.isPastMaturity, isTrue);
      expect(postMaturity.overdueMonths, 2);

      // Month 1: 39,000 * 7% = 2,730 -> Ending before payment = 41,730 -> After 10,000 payment = 31,730
      // Month 2: Starting = 31,730 -> 31,730 * 7% = 2,221.10 -> Ending = 33,951.10
      expect(postMaturity.monthlySteps[0].startingBalance, 39000.0);
      expect(postMaturity.monthlySteps[0].interestAmount, 2730.0);

      expect(postMaturity.monthlySteps[1].startingBalance, 31730.0);
      expect(postMaturity.monthlySteps[1].interestAmount, 2221.10);
      expect(postMaturity.monthlySteps[1].endingBalance, 33951.10);

      expect(postMaturity.remainingBalance, 31730.0);
      expect(postMaturity.postMaturityInterestAmount, 2221.10);
      expect(postMaturity.postMaturityPayableAmount, 33951.10);
    });

    test('6. LoaneeAccount model accurately calculates maturity date and overdue status', () {
      final sanction = DateTime(2025, 3, 15);
      final loanee = LoaneeAccount(
        customerid: 'CUST-005',
        accountnumber: 'ACC-005',
        loaneename: 'Model Test Loanee',
        guardianname: 'Guardian',
        address: 'Imphal',
        businesstype: 'Retail',
        postoffice: 'PO',
        policestation: 'PS',
        district: 'District',
        pincode: '795001',
        mobileno: '9876543214',
        aadharno: '123456789012',
        loanamount: 50000.0,
        paidamount: 10000.0,
        dueamount: 40000.0,
        loansanctiondate: sanction,
      );

      expect(loanee.effectiveMaturityDate, DateTime(2025, 8, 15));
      expect(loanee.formattedSanctionDate, '15/03/2025');
      expect(loanee.formattedMaturityDate, '15/08/2025');
    });
  });
}
