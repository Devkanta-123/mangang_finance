// test/late_fine_calculation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Late Fine & Overdue Calculations', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();
    });

    test('Case 1: Daily loan with NO data in ro_collection_payments table', () {
      final now = DateTime(2026, 8, 17);
      final startDate = now.subtract(const Duration(days: 10)); // 10 days ago

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
      expect(status.overdueUnits, equals(10)); // 10 days overdue
      expect(status.lateFineRate, equals(3.0)); // Default ₹3/day
      expect(status.calculatedLateFine, equals(30.0)); // 10 * 3 = ₹30
      expect(status.totalOverdueAmount, equals(30.0));
      expect(status.calculationExplanation, contains('No payment record found in ro_collection_payments'));
    });

    test('Case 2: Daily loan WITH payments existing in ro_collection_payments table', () {
      final now = DateTime(2026, 8, 17);
      final startDate = now.subtract(const Duration(days: 20));
      final lastPaymentDate = now.subtract(const Duration(days: 4)); // 4 days ago

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
      expect(status.overdueUnits, equals(3)); // (4 - 1) = 3 overdue days
      expect(status.calculatedLateFine, equals(9.0)); // 3 * 3 = ₹9
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

    test('Case 5: Dynamic Admin Settings Rate changes apply to calculations', () async {
      await settingsProvider.saveLatePaymentSettings(
        dailyFine: 5.0, // ₹5/day
        weeklyFine: 40.0, // ₹40/week
        weeklyInstallment: 700.0,
        weeklyTenure: 15.0,
      );

      final now = DateTime(2026, 8, 17);
      final startDate = now.subtract(const Duration(days: 5));

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
      expect(dailyStatus.calculatedLateFine, equals(25.0)); // 5 days * ₹5 = ₹25

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
