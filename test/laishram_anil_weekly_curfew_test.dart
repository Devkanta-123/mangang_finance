import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/holiday_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Laishram Anil Weekly Curfew Holiday Test', () {
    test('Curfew holiday on Tuesday 18 August is excluded from expected weeks', () {
      final settings = SettingsProvider();

      // Register the official curfew holiday on 18 August 2026
      final curfewHoliday = Holiday(
        id: 'HOL-20260818',
        date: DateTime(2026, 8, 18),
        description: 'caurfew',
      );
      settings.setHolidaysForTesting([curfewHoliday]);

      final entry = RoCollectionEntry(
        id: 'COL-HIST-1790838596773-1',
        customerId: '26LA000374',
        accountNumber: 'MF26A000374',
        loaneeName: 'Laishram Anil',
        loaneeAddress: 'Langthabal lep makha leikai',
        collectionType: 'Tue',
        route: 'Khuman',
        mobileNo: '8754345610.0',
        loanAmount: 11500.0,
        payableAmount: 650.0,
        createdAt: DateTime(2026, 10, 1),
      );

      final sanctionDate = DateTime(2026, 7, 15);
      final asOfDate = DateTime(2026, 10, 1);

      // 10 payments recorded (18 August was skipped due to curfew)
      final payments = [
        DateTime(2026, 7, 21),
        DateTime(2026, 7, 28),
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 11),
        // 18 Aug skipped
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 8),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 29),
      ].map((date) => CollectionPaymentModel(
        id: 'PAY-${date.year}${date.month}${date.day}',
        collectionId: entry.id,
        paymentAmount: 650.0,
        remainingBalance: 5000.0,
        paymentType: 'Cash',
        roPasscode: '',
        roName: 'Office Entry',
        roId: null,
        status: 'Success',
        remarks: 'Historical Excel Import',
        createdAt: date,
      )).toList();

      final breakdown = settings.getWeeklyBreakdown(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
        sanctionDate: sanctionDate,
      );

      expect(breakdown.weeksPaid, equals(10));
      // 11 Tuesdays total - 1 curfew Tuesday = 10 active expected collection weeks
      expect(breakdown.expectedWeeks, equals(10));
      // 10 expected - 10 paid = 0 overdue weeks!
      expect(breakdown.lateWeeks, equals(0));
      expect(breakdown.totalCalculatedFine, equals(0.0));
      expect(breakdown.unpaidAmount, equals(0.0));
    });

    test('Without holiday, 11 Tuesdays elapsed with 10 payments correctly yields 1 late week', () {
      final settings = SettingsProvider();
      // No holidays registered
      settings.setHolidaysForTesting([]);

      final entry = RoCollectionEntry(
        id: 'COL-HIST-1790838596773-1',
        customerId: '26LA000374',
        accountNumber: 'MF26A000374',
        loaneeName: 'Laishram Anil',
        loaneeAddress: 'Langthabal lep makha leikai',
        collectionType: 'Tue',
        route: 'Khuman',
        mobileNo: '8754345610.0',
        loanAmount: 11500.0,
        payableAmount: 650.0,
        createdAt: DateTime(2026, 10, 1),
      );

      final sanctionDate = DateTime(2026, 7, 15);
      final asOfDate = DateTime(2026, 10, 1);

      final payments = [
        DateTime(2026, 7, 21),
        DateTime(2026, 7, 28),
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 11),
        // 18 Aug skipped
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 8),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 29),
      ].map((date) => CollectionPaymentModel(
        id: 'PAY-${date.year}${date.month}${date.day}',
        collectionId: entry.id,
        paymentAmount: 650.0,
        remainingBalance: 5000.0,
        paymentType: 'Cash',
        roPasscode: '',
        roName: 'Office Entry',
        roId: null,
        status: 'Success',
        remarks: 'Historical Excel Import',
        createdAt: date,
      )).toList();

      final breakdown = settings.getWeeklyBreakdown(
        entry: entry,
        payments: payments,
        asOfDate: asOfDate,
        sanctionDate: sanctionDate,
      );

      expect(breakdown.weeksPaid, equals(10));
      expect(breakdown.expectedWeeks, equals(11));
      expect(breakdown.lateWeeks, equals(1));
      expect(breakdown.totalCalculatedFine, equals(19.50));
      expect(breakdown.unpaidAmount, equals(650.0));
    });
  });
}
