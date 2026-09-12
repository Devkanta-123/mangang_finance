import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';

void main() {
  group('Partial Late Fee Cleared & Insertion Tests (User Exact Scenario: 5 paid out of 7.26 assessed)', () {
    const double assessedFee = 7.26;
    const double paidLateFine = 5.00;
    const double carriedForward = 2.26;
    const String remarks =
        'Admin Entry: Direct Office Collection by Administrator (Roshan Singh) for Moirang | Late Fee: ₹7.26 assessed for missed collection, ₹5.00 cleared, ₹2.26 carried forward';

    test('1. Direct CollectionPaymentModel instantiation preserves lateFine = 5.00 and interest = 0.00', () {
      final payment = CollectionPaymentModel(
        id: 'PAY-TEST-001',
        collectionId: 'COL-MOIRANG-001',
        paymentAmount: 121.0,
        remainingBalance: 8000.0,
        lateFine: paidLateFine,
        interest: 0.0,
        paymentType: 'Cash',
        roName: 'Roshan Singh',
        remarks: remarks,
      );

      expect(payment.lateFine, equals(5.00));
      expect(payment.interest, equals(0.00));
      expect(payment.effectiveLateFine, equals(5.00));
      expect(assessedFee - paidLateFine, closeTo(carriedForward, 0.001));

      final json = payment.toJson();
      expect(json['late_fine'], equals(5.00));
      expect(json['interest'], equals(0.00));
      expect(json['remarks'], equals(remarks));
    });

    test('2. CollectionPaymentModel.fromJson does not overwrite interest with assessed fee 7.26 from remarks', () {
      final json = {
        'id': 'PAY-1789029823142',
        'collection_id': 'COL-MOIRANG-001',
        'payment_amount': 121.0,
        'remaining_balance': 8000.0,
        'late_fine': 5.00,
        'interest': 0.00,
        'payment_type': 'Cash',
        'ro_name': 'Roshan Singh',
        'remarks': remarks,
        'created_at': DateTime(2026, 9, 12, 11, 0, 0).toIso8601String(),
        'status': 'Success',
      };

      final payment = CollectionPaymentModel.fromJson(json);

      expect(payment.lateFine, equals(5.00), reason: 'lateFine must be strictly the ₹5.00 cleared/paid');
      expect(payment.interest, equals(0.00), reason: 'interest must stay 0.00 and NOT be corrupted by assessed ₹7.26 in remarks');
      expect(payment.effectiveLateFine, equals(5.00), reason: 'effectiveLateFine must strictly evaluate to ₹5.00');
    });

    test('3. CollectionPaymentModel.fromJson falls back to cleared amount 5.00 if late_fine column was 0.00 in DB', () {
      final jsonWithZeroLateFine = {
        'id': 'PAY-1789029823142',
        'collection_id': 'COL-MOIRANG-001',
        'payment_amount': 121.0,
        'remaining_balance': 8000.0,
        'late_fine': 0.00,
        'interest': 0.00,
        'payment_type': 'Cash',
        'ro_name': 'Roshan Singh',
        'remarks': remarks,
        'created_at': DateTime(2026, 9, 12, 11, 0, 0).toIso8601String(),
        'status': 'Success',
      };

      final payment = CollectionPaymentModel.fromJson(jsonWithZeroLateFine);

      expect(payment.lateFine, equals(5.00), reason: 'Should parse ₹5.00 cleared from remarks, NOT ₹7.26 assessed');
      expect(payment.interest, equals(0.00));
      expect(payment.effectiveLateFine, equals(5.00));
    });

    test('4. CollectionSheetProvider totals calculate ₹5.00 late fee, NOT ₹7.26', () {
      final provider = CollectionSheetProvider();
      final entry = RoCollectionEntry(
        id: 'COL-MOIRANG-001',
        customerId: '26LA000083',
        accountNumber: 'MF26A000083',
        loaneeName: 'Naosekpam Malabati',
        loaneeAddress: 'Moirang',
        route: 'Moirang',
        collectionType: 'Daily',
        loanAmount: 13915.0,
        mobileNo: '9862112233',
      );
      provider.handleRealtimeEntryInsert(entry);

      final payment = CollectionPaymentModel(
        id: 'PAY-1789029823142',
        collectionId: entry.id,
        paymentAmount: 121.0,
        remainingBalance: 8000.0,
        lateFine: paidLateFine,
        interest: 0.0,
        paymentType: 'Cash',
        roName: 'Roshan Singh',
        remarks: remarks,
        createdAt: DateTime(2026, 9, 12, 11, 0, 0),
      );
      provider.handleRealtimePaymentInsert(payment);

      final totalLateFees = provider.getTotalLatePaymentFeesForCollection(entry.id);
      expect(totalLateFees, equals(5.00), reason: 'Total late fees must be ₹5.00 (the amount paid), not ₹7.26');

      final todayLateFees = provider.getTodayLateFineForCollection(entry.id, DateTime(2026, 9, 12));
      expect(todayLateFees, equals(5.00), reason: "Today's late fine must be ₹5.00, not ₹7.26");
    });

    test('5. Unpaid late fee carried forward is correctly identified as ₹2.26', () {
      final entry = RoCollectionEntry(
        id: 'COL-MOIRANG-001',
        customerId: '26LA000083',
        accountNumber: 'MF26A000083',
        loaneeName: 'Naosekpam Malabati',
        loaneeAddress: 'Moirang',
        route: 'Moirang',
        collectionType: 'Daily',
        loanAmount: 13915.0,
        mobileNo: '9862112233',
      );

      final payment = CollectionPaymentModel(
        id: 'PAY-1789029823142',
        collectionId: entry.id,
        paymentAmount: 121.0,
        remainingBalance: 8000.0,
        lateFine: paidLateFine,
        interest: 0.0,
        paymentType: 'Cash',
        roName: 'Roshan Singh',
        remarks: remarks,
        createdAt: DateTime(2026, 9, 12, 11, 0, 0),
      );

      final unpaid = SettingsProvider.calculatePreviousUnpaidLateFee(
        entry: entry,
        payments: [payment],
      );

      expect(unpaid, equals(carriedForward), reason: 'Unpaid carried forward must strictly be ₹2.26');
    });
  });
}
