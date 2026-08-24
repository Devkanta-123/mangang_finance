// test/late_fine_calculation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Late Fine & Sunday Exclusion Calculations', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    test('Example 1: Due date Saturday, Collection date Sunday -> 0 late days', () {
      final saturday = DateTime(2026, 8, 22);
      final sunday = DateTime(2026, 8, 23);

      final lateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: saturday,
        asOfDate: sunday,
        hasPreviousPayment: false,
      );

      expect(lateDays, equals(0), reason: 'Sunday is a non-working day, expected 0 late days');

      final lateDaysBetween = SettingsProvider.calculateLateDaysBetween(
        dueDate: saturday,
        collectionDate: sunday,
      );
      expect(lateDaysBetween, equals(0));
    });

    test('Example 2: Due date Saturday, Collection date Monday -> 1 late day (Sunday skipped)', () {
      final saturday = DateTime(2026, 8, 22);
      final monday = DateTime(2026, 8, 24);

      final lateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: saturday,
        asOfDate: monday,
        hasPreviousPayment: false,
      );

      expect(lateDays, equals(1), reason: 'Saturday missed, Sunday skipped -> 1 late day');

      final lateDaysBetween = SettingsProvider.calculateLateDaysBetween(
        dueDate: saturday,
        collectionDate: monday,
      );
      expect(lateDaysBetween, equals(1));
    });

    test('Example 3: Due date Friday (last paid Friday), Collection date Monday -> 1 late day (Saturday counted, Sunday skipped)', () {
      final friday = DateTime(2026, 8, 21);
      final monday = DateTime(2026, 8, 24);

      // When last payment was Friday, next due was Saturday. Missed Saturday, Sunday skipped, collected Monday:
      final lateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: friday,
        asOfDate: monday,
        hasPreviousPayment: true,
      );

      expect(lateDays, equals(1), reason: 'Saturday counted, Sunday skipped -> 1 late day');
    });

    test('Example 4: Due date Monday, Collection date Tuesday -> 1 late day', () {
      final monday = DateTime(2026, 8, 17);
      final tuesday = DateTime(2026, 8, 18);

      final lateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: monday,
        asOfDate: tuesday,
        hasPreviousPayment: false,
      );

      expect(lateDays, equals(1), reason: 'Monday missed -> 1 late day on Tuesday');

      final lateDaysBetween = SettingsProvider.calculateLateDaysBetween(
        dueDate: monday,
        collectionDate: tuesday,
      );
      expect(lateDaysBetween, equals(1));
    });

    test('Example 5: Due date Monday, Collection date Wednesday -> 2 late days', () {
      final monday = DateTime(2026, 8, 17);
      final wednesday = DateTime(2026, 8, 19);

      final lateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: monday,
        asOfDate: wednesday,
        hasPreviousPayment: false,
      );

      expect(lateDays, equals(2), reason: 'Monday and Tuesday missed -> 2 late days on Wednesday');

      final lateDaysBetween = SettingsProvider.calculateLateDaysBetween(
        dueDate: monday,
        collectionDate: wednesday,
      );
      expect(lateDaysBetween, equals(2));
    });

    test('Multi-week date range: Multiple Sundays are properly excluded', () {
      // Monday Aug 3 to Monday Aug 24: 21 calendar days, contains 3 Sundays (Aug 9, Aug 16, Aug 23)
      final startMonday = DateTime(2026, 8, 3);
      final endMonday = DateTime(2026, 8, 24);

      final lateDaysNoPayment = SettingsProvider.calculateDailyLateDays(
        baseDate: startMonday,
        asOfDate: endMonday,
        hasPreviousPayment: false,
      );
      // 21 days - 3 Sundays = 18 late days
      expect(lateDaysNoPayment, equals(18));

      final lateDaysWithPayment = SettingsProvider.calculateDailyLateDays(
        baseDate: startMonday,
        asOfDate: endMonday,
        hasPreviousPayment: true,
      );
      // 21 days - startDay(Mon Aug 3) - 3 Sundays = 17 late days
      expect(lateDaysWithPayment, equals(17));
    });

    test('Multi-month boundary: Spans month end with Sunday exclusion intact', () {
      // Friday Jul 31, 2026 to Tuesday Aug 4, 2026 (5 calendar days):
      // Jul 31 (Fri), Aug 1 (Sat), Aug 2 (Sun - skipped), Aug 3 (Mon), Aug 4 (Tue)
      final jul31 = DateTime(2026, 7, 31);
      final aug4 = DateTime(2026, 8, 4);

      final lateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: jul31,
        asOfDate: aug4,
        hasPreviousPayment: false,
      );
      // Days in [Jul 31, Aug 4): Jul 31, Aug 1, Aug 2 (Sun skipped), Aug 3 -> 3 late days
      expect(lateDays, equals(3));
    });

    test('Sunday due date rule: Due on Sunday does not count Sunday itself as late day', () {
      final sunday = DateTime(2026, 8, 23);
      final monday = DateTime(2026, 8, 24);
      final tuesday = DateTime(2026, 8, 25);

      final mondayLate = SettingsProvider.calculateDailyLateDays(
        baseDate: sunday,
        asOfDate: monday,
        hasPreviousPayment: false,
      );
      expect(mondayLate, equals(0), reason: 'Sunday skipped, paying on Monday is 0 late days');

      final tuesdayLate = SettingsProvider.calculateDailyLateDays(
        baseDate: sunday,
        asOfDate: tuesday,
        hasPreviousPayment: false,
      );
      expect(tuesdayLate, equals(1), reason: 'Sunday skipped, Monday missed -> 1 late day on Tuesday');
    });

    test('Case 1: Daily loan with NO data in ro_collection_payments table (Sunday excluded)', () {
      final now = DateTime(2026, 8, 17); // Monday
      final startDate = now.subtract(const Duration(days: 10)); // Friday Aug 7

      final entry = RoCollectionEntry(
        id: 'COL-1001',
        customerId: 'CUST-1001',
        accountNumber: 'ACC-88239101',
        loaneeName: 'Devkanta Singh',
        loaneeAddress: 'Imphal East',
        collectionType: 'Daily',
        route: 'Mangang',
        mobileNo: '9876543210',
        createdAt: startDate,
      );

      final List<CollectionPaymentModel> payments = []; // Empty: no data in ro_collection_payments

      final status = settingsProvider.getLateFineStatusForEntry(
        entry: entry,
        payments: payments,
        asOfDate: now,
      );

      expect(status.isDaily, isTrue);
      expect(status.hasPaymentsInTable, isFalse);
      expect(status.paymentRecordsCount, equals(0));
      // 10 calendar days with 2 Sundays (Aug 9, Aug 16) excluded = 8 overdue days
      expect(status.overdueUnits, equals(8));
      expect(status.lateFineRate, equals(3.0)); // Default ₹3/day
      expect(status.calculatedLateFine, equals(24.0)); // 8 * 3 = ₹24
      expect(status.totalOverdueAmount, equals(24.0));
      expect(status.calculationExplanation, contains('No payment record found in ro_collection_payments'));
    });

    test('Case 2: Daily loan WITH payments existing in ro_collection_payments table (Sunday excluded)', () {
      final now = DateTime(2026, 8, 17); // Monday
      final startDate = now.subtract(const Duration(days: 20));
      final lastPaymentDate = now.subtract(const Duration(days: 4)); // Thursday Aug 13

      final entry = RoCollectionEntry(
        id: 'COL-1002',
        customerId: 'CUST-1002',
        accountNumber: 'ACC-88239102',
        loaneeName: 'Tomba Meitei',
        loaneeAddress: 'Imphal West',
        collectionType: 'Daily',
        route: 'Luwang',
        mobileNo: '9876543211',
        createdAt: startDate,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-01',
          collectionId: entry.id,
          paymentAmount: 500.0,
          createdAt: lastPaymentDate,
        ),
      ];

      final status = settingsProvider.getLateFineStatusForEntry(
        entry: entry,
        payments: payments,
        asOfDate: now,
      );

      expect(status.isDaily, isTrue);
      expect(status.hasPaymentsInTable, isTrue);
      expect(status.paymentRecordsCount, equals(1));
      // Between Thu Aug 13 and Mon Aug 17: Fri Aug 14 (1), Sat Aug 15 (1), Sun Aug 16 (skipped) = 2 overdue days
      expect(status.overdueUnits, equals(2));
      expect(status.calculatedLateFine, equals(6.0)); // 2 * 3 = ₹6
      expect(status.calculationExplanation, contains('Payment data found in ro_collection_payments'));
    });

    test('Case 3: Weekly loan with NO data in ro_collection_payments table', () {
      final now = DateTime(2026, 8, 17);
      final startDate = now.subtract(const Duration(days: 21)); // 3 weeks ago

      final entry = RoCollectionEntry(
        id: 'COL-1003',
        customerId: 'CUST-1003',
        accountNumber: 'ACC-88239103',
        loaneeName: 'Chaoba Devi',
        loaneeAddress: 'Thoubal',
        collectionType: 'Mon', // Weekly collection on Monday
        route: 'Khuman',
        mobileNo: '9876543212',
        createdAt: startDate,
      );

      final List<CollectionPaymentModel> payments = []; // No payment in table

      final status = settingsProvider.getLateFineStatusForEntry(
        entry: entry,
        payments: payments,
        asOfDate: now,
      );

      expect(status.isDaily, isFalse);
      expect(status.hasPaymentsInTable, isFalse);
      expect(status.paymentRecordsCount, equals(0));
      expect(status.overdueUnits, equals(3)); // 3 weeks overdue
      expect(status.lateFineRate, equals(25.0)); // Default ₹25/week
      expect(status.calculatedLateFine, equals(75.0)); // 3 * 25 = ₹75 fine
      expect(status.overdueEmiAmount, equals(1950.0)); // 3 * 650 = ₹1950 principal
      expect(status.totalOverdueAmount, equals(2025.0)); // 1950 + 75 = ₹2025
    });

    test('Case 4: Weekly loan WITH partial payments in ro_collection_payments table', () {
      final now = DateTime(2026, 8, 17);
      final startDate = now.subtract(const Duration(days: 28)); // 4 weeks elapsed

      final entry = RoCollectionEntry(
        id: 'COL-1004',
        customerId: 'CUST-1004',
        accountNumber: 'ACC-88239104',
        loaneeName: 'Bembem Devi',
        loaneeAddress: 'Bishnupur',
        collectionType: 'Weekly',
        route: 'Moirang',
        mobileNo: '9876543213',
        createdAt: startDate,
      );

      final payments = [
        CollectionPaymentModel(
          id: 'PAY-01',
          collectionId: entry.id,
          paymentAmount: 1300.0, // 2 weeks paid (650 * 2)
          createdAt: now.subtract(const Duration(days: 14)),
        ),
      ];

      final status = settingsProvider.getLateFineStatusForEntry(
        entry: entry,
        payments: payments,
        asOfDate: now,
      );

      expect(status.isDaily, isFalse);
      expect(status.hasPaymentsInTable, isTrue);
      expect(status.overdueUnits, equals(2)); // 4 expected - 2 paid = 2 weeks overdue
      expect(status.calculatedLateFine, equals(50.0)); // 2 * 25 = ₹50
      expect(status.overdueEmiAmount, equals(1300.0)); // 2 * 650 = ₹1300
      expect(status.totalOverdueAmount, equals(1350.0)); // 1300 + 50 = ₹1350
    });

    test('Case 5: Dynamic Admin Settings Rate changes apply to calculations with Sunday exclusion', () async {
      await settingsProvider.saveLatePaymentSettings(
        dailyFine: 5.0, // ₹5/day
        weeklyFine: 40.0, // ₹40/week
        weeklyInstallment: 700.0,
        weeklyTenure: 15.0,
      );

      final now = DateTime(2026, 8, 17); // Monday
      final startDate = now.subtract(const Duration(days: 5)); // Wednesday Aug 12

      final dailyEntry = RoCollectionEntry(
        id: 'COL-1005',
        customerId: 'CUST-1005',
        accountNumber: 'ACC-88239105',
        loaneeName: 'Ramesh Singh',
        loaneeAddress: 'Kakching',
        collectionType: 'Daily',
        route: 'Angom',
        mobileNo: '9876543214',
        createdAt: startDate,
      );

      final dailyStatus = settingsProvider.getLateFineStatusForEntry(
        entry: dailyEntry,
        payments: [],
        asOfDate: now,
      );

      expect(dailyStatus.lateFineRate, equals(5.0));
      // Wed 12, Thu 13, Fri 14, Sat 15, Sun 16 (skipped) = 4 days * ₹5 = ₹20
      expect(dailyStatus.overdueUnits, equals(4));
      expect(dailyStatus.calculatedLateFine, equals(20.0));

      final weeklyStartDate = now.subtract(const Duration(days: 14)); // 2 weeks
      final weeklyEntry = RoCollectionEntry(
        id: 'COL-1006',
        customerId: 'CUST-1006',
        accountNumber: 'ACC-88239106',
        loaneeName: 'Suresh Kumar',
        loaneeAddress: 'Churachandpur',
        collectionType: 'Weekly',
        route: 'Mangang',
        mobileNo: '9876543215',
        createdAt: weeklyStartDate,
      );

      final weeklyStatus = settingsProvider.getLateFineStatusForEntry(
        entry: weeklyEntry,
        payments: [],
        asOfDate: now,
      );

      expect(weeklyStatus.lateFineRate, equals(40.0));
      expect(weeklyStatus.calculatedLateFine, equals(80.0)); // 2 weeks * ₹40 = ₹80
    });

    test('Case 6: Loanee Fine Acknowledgment persistence', () async {
      const customerId = 'CUST-1001';

      expect(await settingsProvider.isFineAcknowledgedToday(customerId), isFalse);

      await settingsProvider.acknowledgeFineForToday(customerId);

      expect(await settingsProvider.isFineAcknowledgedToday(customerId), isTrue);
      final timestamp = await settingsProvider.getAcknowledgmentTimestamp(customerId);
      expect(timestamp, isNotNull);
    });
  });
}

