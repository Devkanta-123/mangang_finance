import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Late Payment Fee Auto-Calculation Tests When Maturity Date Passed', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    test('User Test 1: Maturity passed, latest payment 09-Sep-2026, current 12-Sep-2026 -> 3 late days, ₹18 fine', () {
      final sanctionDate = DateTime(2026, 2, 1);
      final maturityDate = DateTime(2026, 7, 1); // Maturity passed before Sep 2026
      final latestPaymentDate = DateTime(2026, 9, 9);
      final currentDate = DateTime(2026, 9, 12); // Saturday

      final entry = RoCollectionEntry(
        id: 'COL-TEST-01',
        customerId: 'CUST-01',
        accountNumber: 'ACC-01',
        loaneeName: 'User Test 1',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        payableAmount: 200.0, // Base daily installment = ₹200
        loanAmount: 20000.0,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-01',
          collectionId: entry.id,
          paymentAmount: 5000.0,
          remainingBalance: 15000.0,
          status: 'Success',
          createdAt: latestPaymentDate,
        ),
      ];

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 20000.0,
        loaneeDueAmount: 15000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: currentDate,
      );

      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.lateUnits, equals(3), reason: '10-Sep(1), 11-Sep(2), 12-Sep(3) = 3 late days');
      expect(breakdown.baseInstallment, equals(200.0));
      expect(breakdown.lateFineRate, equals(6.0)); // 200 * 3% = ₹6/day
      expect(breakdown.calculatedLateFine, equals(18.0), reason: '3 days * ₹6 = ₹18.00');

      // Verify 7% post-maturity interest is preserved independently
      expect(breakdown.postMaturityBreakdown, isNotNull);
      expect(breakdown.postMaturityBreakdown!.isPastMaturity, isTrue);
      expect(breakdown.postMaturityBreakdown!.postMaturityInterestRate, equals(7.0));
    });

    test('User Test 2: Maturity passed, latest payment 10-Sep-2026, current 12-Sep-2026 -> 2 late days, ₹12 fine', () {
      final sanctionDate = DateTime(2026, 2, 1);
      final maturityDate = DateTime(2026, 7, 1);
      final latestPaymentDate = DateTime(2026, 9, 10); // Thursday
      final currentDate = DateTime(2026, 9, 12); // Saturday

      final entry = RoCollectionEntry(
        id: 'COL-TEST-02',
        customerId: 'CUST-02',
        accountNumber: 'ACC-02',
        loaneeName: 'User Test 2',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        payableAmount: 200.0, // Base daily installment = ₹200
        loanAmount: 20000.0,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-02',
          collectionId: entry.id,
          paymentAmount: 5000.0,
          remainingBalance: 15000.0,
          status: 'Success',
          createdAt: latestPaymentDate,
        ),
      ];

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 20000.0,
        loaneeDueAmount: 15000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: currentDate,
      );

      expect(breakdown.isPastMaturity, isTrue);
      expect(breakdown.lateUnits, equals(2), reason: '11-Sep(1), 12-Sep(2) = 2 late days');
      expect(breakdown.baseInstallment, equals(200.0));
      expect(breakdown.lateFineRate, equals(6.0));
      expect(breakdown.calculatedLateFine, equals(12.0), reason: '2 days * ₹6 = ₹12.00');
    });

    test('User Test 3: Outstanding balance is ₹0 -> Late Payment Fee does not continue increasing', () {
      final sanctionDate = DateTime(2026, 2, 1);
      final maturityDate = DateTime(2026, 7, 1);
      final latestPaymentDate = DateTime(2026, 7, 1);
      final currentDate = DateTime(2026, 9, 12); // Months passed

      final entry = RoCollectionEntry(
        id: 'COL-TEST-03',
        customerId: 'CUST-03',
        accountNumber: 'ACC-03',
        loaneeName: 'User Test 3 Cleared',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        payableAmount: 200.0,
        loanAmount: 20000.0,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-03',
          collectionId: entry.id,
          paymentAmount: 20000.0,
          remainingBalance: 0.0, // Fully cleared
          status: 'Success',
          createdAt: latestPaymentDate,
        ),
      ];

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 20000.0,
        loaneeDueAmount: 0.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: currentDate,
      );

      expect(breakdown.lateUnits, equals(0));
      expect(breakdown.calculatedLateFine, equals(0.0), reason: 'Cleared loan must not accumulate fine');
    });

    test('User Test 4: Payment made today (12-Sep) resets late days to 0 today; advances next day', () {
      final sanctionDate = DateTime(2026, 2, 1);
      final maturityDate = DateTime(2026, 7, 1);
      final todayPaymentDate = DateTime(2026, 9, 12);
      final currentDate = DateTime(2026, 9, 12);

      final entry = RoCollectionEntry(
        id: 'COL-TEST-04',
        customerId: 'CUST-04',
        accountNumber: 'ACC-04',
        loaneeName: 'User Test 4 Today',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        payableAmount: 200.0, // Base daily installment = ₹200
        loanAmount: 20000.0,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-04',
          collectionId: entry.id,
          paymentAmount: 1000.0,
          remainingBalance: 14000.0,
          status: 'Success',
          createdAt: todayPaymentDate,
        ),
      ];

      // Calculation on the same day as payment:
      final breakdownToday = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 20000.0,
        loaneeDueAmount: 14000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: currentDate,
      );

      expect(breakdownToday.lateUnits, equals(0), reason: 'Paid today -> 0 late days');
      expect(breakdownToday.calculatedLateFine, equals(0.0));

      // Sunday 13-Sep is skipped:
      final breakdownSunday = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 20000.0,
        loaneeDueAmount: 14000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: DateTime(2026, 9, 13),
      );
      expect(breakdownSunday.lateUnits, equals(0), reason: 'Sunday skipped -> 0 late days');

      // Monday 14-Sep has 1 late day:
      final breakdownMonday = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 20000.0,
        loaneeDueAmount: 14000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: DateTime(2026, 9, 14),
      );
      expect(breakdownMonday.lateUnits, equals(1), reason: 'Monday is 1 late day');
      expect(breakdownMonday.calculatedLateFine, equals(6.0));
    });

    test('No double counting: Cleared late fees are not added again', () {
      final sanctionDate = DateTime(2026, 2, 1);
      final maturityDate = DateTime(2026, 7, 1);
      final paymentDate = DateTime(2026, 9, 9);
      final currentDate = DateTime(2026, 9, 12);

      final entry = RoCollectionEntry(
        id: 'COL-TEST-05',
        customerId: 'CUST-05',
        accountNumber: 'ACC-05',
        loaneeName: 'User Test 5 No Duplicate',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        payableAmount: 200.0, // Base daily installment = ₹200
        loanAmount: 20000.0,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-05',
          collectionId: entry.id,
          paymentAmount: 5000.0,
          remainingBalance: 15000.0,
          lateFine: 12.0, // ₹12 was assessed and paid/cleared on 09-Sep
          status: 'Success',
          remarks: 'Late Fee: ₹12.00 cleared',
          createdAt: paymentDate,
        ),
      ];

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 20000.0,
        loaneeDueAmount: 15000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: currentDate,
      );

      // Only the 3 new days (10th, 11th, 12th) are assessed: 3 * ₹6 = ₹18.00.
      // The previous ₹12 is NOT added again.
      expect(breakdown.lateUnits, equals(3));
      expect(breakdown.previousUnpaidLateFee, equals(0.0));
      expect(breakdown.currentIntervalLateFine, equals(18.0));
      expect(breakdown.calculatedLateFine, equals(18.0));
    });

    test('Exact User Scenario: Base ₹121, Late Fee ₹3 history (stored under interest), As-Of 12-Sep-2026 -> exactly 3 late days and ₹10.89 fine (NOT 7 days / ₹25.41)', () {
      final sanctionDate = DateTime(2026, 2, 1);
      final maturityDate = DateTime(2026, 7, 1);
      final asOfDate = DateTime(2026, 9, 12); // Saturday

      final entry = RoCollectionEntry(
        id: 'COL-USER-SCREEN',
        customerId: 'CUST-SCREEN',
        accountNumber: 'ACC-SCREEN',
        loaneeName: 'User Exact Screen Test',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: sanctionDate,
        payableAmount: 121.0, // Base daily installment = ₹121
        loanAmount: 12100.0,
      );

      // User screen payment history:
      // 09/09/2026 -> Late Fee ₹3.00 (in interest column for historical/ledger)
      // 08/09/2026 -> Late Fee ₹3.00
      // 07/09/2026 -> Late Fee ₹3.00
      // 05/09/2026 -> Late Fee ₹3.00
      // 04/09/2026 -> Payment ₹120.00, no late fee
      final payments = [
        CollectionPaymentModel(
          id: 'PAY-HIST-01',
          collectionId: entry.id,
          paymentAmount: 120.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 4),
        ),
        CollectionPaymentModel(
          id: 'PAY-HIST-02',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 5),
        ),
        CollectionPaymentModel(
          id: 'PAY-HIST-03',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 7),
        ),
        CollectionPaymentModel(
          id: 'PAY-HIST-04',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 8),
        ),
        CollectionPaymentModel(
          id: 'PAY-HIST-05',
          collectionId: entry.id,
          paymentAmount: 0.0,
          interest: 3.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9),
        ),
      ];

      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 12100.0,
        loaneeDueAmount: 5000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: asOfDate,
      );

      // Verify the number of late days is 3 (10-Sep, 11-Sep, 12-Sep), NOT 7
      expect(breakdown.lateUnits, equals(3), reason: 'Missed days since 09-Sep are 10-Sep, 11-Sep, 12-Sep (3 days)');
      expect(breakdown.baseInstallment, equals(121.0));
      expect(breakdown.lateFineRate, equals(3.63)); // 121 * 3% = 3.63/day
      expect(breakdown.calculatedLateFine, equals(10.89), reason: '3 days * ₹3.63 = ₹10.89 (NOT ₹25.41)');

      // Also verify LoaneeLateFineStatus calculationExplanation and overdueUnits
      final status = settingsProvider.getLateFineStatusForEntry(
        entry: entry,
        payments: payments,
        loaneeLoanAmount: 12100.0,
        loaneeDueAmount: 5000.0,
        maturityDate: maturityDate,
        sanctionDate: sanctionDate,
        asOfDate: asOfDate,
      );

      expect(status.overdueUnits, equals(3));
      expect(status.calculatedLateFine, equals(10.89));
      expect(status.lastPaymentDate, equals(DateTime(2026, 9, 9)));
    });
  });
}
