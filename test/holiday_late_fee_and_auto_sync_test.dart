// test/holiday_late_fee_and_auto_sync_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/holiday_model.dart';
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

  group('Holiday Implementation & Exclusion Tests', () {
    test('1. calculateDailyLateDays excludes registered holidays just like Sundays', () {
      // Date range: Monday 10-Aug to Friday 14-Aug (4 calendar elapsed days)
      final monday = DateTime(2026, 8, 10);
      final friday = DateTime(2026, 8, 14);

      // Without holidays: 4 days (Mon 10, Tue 11, Wed 12, Thu 13)
      final normalLateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: monday,
        asOfDate: friday,
        hasPreviousPayment: false,
      );
      expect(normalLateDays, equals(4));

      // With holiday on Wednesday 12-Aug:
      final wednesdayHoliday = DateTime(2026, 8, 12);
      final lateDaysWithHoliday = SettingsProvider.calculateDailyLateDays(
        baseDate: monday,
        asOfDate: friday,
        hasPreviousPayment: false,
        holidays: [wednesdayHoliday],
      );

      // 4 days - 1 holiday = 3 late days
      expect(lateDaysWithHoliday, equals(3), reason: 'Wednesday holiday must be excluded');
    });

    test('2. Multiple holidays and Sundays in date range are all excluded properly', () {
      // Range: Monday 10-Aug to Monday 17-Aug (7 calendar days)
      // Contains: Sunday 16-Aug
      // Add holidays: Tuesday 11-Aug and Friday 14-Aug
      final start = DateTime(2026, 8, 10);
      final end = DateTime(2026, 8, 17);

      final holidays = [
        DateTime(2026, 8, 11), // Tuesday
        DateTime(2026, 8, 14), // Friday
      ];

      final lateDays = SettingsProvider.calculateDailyLateDays(
        baseDate: start,
        asOfDate: end,
        hasPreviousPayment: false,
        holidays: holidays,
      );

      // Total days before end: 7 (Mon 10, Tue 11, Wed 12, Thu 13, Fri 14, Sat 15, Sun 16)
      // Excluded: Sun 16 (Sunday), Tue 11 (Holiday), Fri 14 (Holiday) = 3 excluded
      // Net late days = 4 (Mon 10, Wed 12, Thu 13, Sat 15)
      expect(lateDays, equals(4));
    });

    test('3. syncAutoLateFeesForEntry skips holiday date and does NOT insert PAY-LATE record', () async {
      final collectionProvider = CollectionSheetProvider();

      final entry = RoCollectionEntry(
        id: 'COL-HOL-TEST',
        customerId: 'CUST-HOL',
        accountNumber: 'ACC-HOL',
        loaneeName: 'Tomba Singh',
        loaneeAddress: 'Imphal',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9876543210',
        createdAt: DateTime(2026, 9, 1),
        payableAmount: 100.0,
        loanAmount: 10000.0,
      );

      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Last payment was on 09-Sep-2026:
      await collectionProvider.addCollectionPayment(
        CollectionPaymentModel(
          id: 'PAY-HIST-09',
          collectionId: entry.id,
          paymentAmount: 100.0,
          remainingBalance: 5000.0,
          status: 'Success',
          createdAt: DateTime(2026, 9, 9, 10, 0, 0),
        ),
        saveToRemote: false,
      );

      // Register 10-Sep-2026 as an official holiday
      final holiday = Holiday(
        id: 'HOL-20260910',
        date: DateTime(2026, 9, 10),
        description: 'Kang (Rath Yatra)',
        createdBy: 'Admin',
      );
      // Inject holiday into settingsProvider
      await settingsProvider.addHoliday(
        date: holiday.date,
        description: holiday.description,
      );

      expect(settingsProvider.isHoliday(DateTime(2026, 9, 10)), isTrue);

      // Today is 12-Sep-2026
      final asOf12 = DateTime(2026, 9, 12);
      final inserted = await collectionProvider.syncAutoLateFeesForEntry(
        entry: entry,
        settingsProvider: settingsProvider,
        asOfDate: asOf12,
        saveToRemote: false,
      );

      // Candidate dates between 09-Sep and 12-Sep were: 10-Sep and 11-Sep.
      // 10-Sep is HOLIDAY -> SKIPPED!
      // 11-Sep is regular missed day -> INSERTED!
      // 12-Sep is TODAY -> EXCLUDED!
      expect(inserted.length, equals(1));
      expect(inserted.first.createdAt.day, equals(11));
      expect(inserted.any((p) => p.createdAt.day == 10), isFalse, reason: 'Holiday date must NOT have an auto late fee inserted');

      // Verify breakdown
      final allPayments = collectionProvider.getPaymentsForCollection(entry.id);
      final breakdown = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: allPayments,
        loaneeLoanAmount: 10000.0,
        loaneeDueAmount: 5000.0,
        asOfDate: asOf12,
      );

      // Only 1 late day assessed (11-Sep), not 2
      expect(breakdown.lateUnits, equals(1));
      expect(breakdown.calculatedLateFine, equals(3.0)); // 100 * 3% = ₹3.00
    });

    test('4. Holiday helper methods correctly report isToday, isUpcoming, isPast', () {
      final now = DateTime.now();
      final todayHoliday = Holiday(
        id: 'HOL-TODAY',
        date: DateTime(now.year, now.month, now.day),
        description: 'Today Festival',
      );
      expect(todayHoliday.isToday, isTrue);
      expect(todayHoliday.isUpcoming, isFalse);
      expect(todayHoliday.isPast, isFalse);
      expect(todayHoliday.relativeLabel, equals('Today'));

      final tomorrowHoliday = Holiday(
        id: 'HOL-TOMORROW',
        date: DateTime(now.year, now.month, now.day + 1),
        description: 'Tomorrow Festival',
      );
      expect(tomorrowHoliday.isToday, isFalse);
      expect(tomorrowHoliday.isUpcoming, isTrue);
      expect(tomorrowHoliday.relativeLabel, equals('Tomorrow'));

      final pastHoliday = Holiday(
        id: 'HOL-PAST',
        date: DateTime(now.year, now.month, now.day - 2),
        description: 'Past Holiday',
      );
      expect(pastHoliday.isPast, isTrue);
      expect(pastHoliday.daysFromToday, equals(-2));
      expect(pastHoliday.relativeLabel, equals('2 days ago'));
    });
  });
}
