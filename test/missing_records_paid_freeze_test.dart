// test/missing_records_paid_freeze_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/missing_payment_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/services/missing_records_excel_import_service.dart';
import 'package:mangang_finance/widgets/missing_records_excel_upload_dialog.dart';

void main() {
  group('Missing Records Paid Freeze and Basic Pay Preservation Tests', () {
    late CollectionSheetProvider collectionProvider;

    setUp(() {
      collectionProvider = CollectionSheetProvider();
    });

    test('MissingPaymentRecord preserves old basic pay when cleared', () async {
      final missedDate = DateTime(2026, 9, 15);
      final paidDate = DateTime(2026, 9, 28);

      final initialRecord = MissingPaymentRecord(
        id: 'MISS-TEST-001',
        collectionId: 'COLL-001',
        loaneeName: 'Test Borrower',
        collectionType: 'weekly',
        missedDate: missedDate,
        dayPayment: 0.0,
        missingPay: 1500.0, // Old Basic Pay
        missingFine: 45.0,
        missingWeek: 1,
        missingBalance: 45.0,
        status: 'missing',
        createdAt: missedDate,
        updatedAt: missedDate,
      );

      collectionProvider.setMissingRecordsForTest([initialRecord]);

      // Loanee pays for the missing record
      final cleared = await collectionProvider.clearPastMissingRecord(
        missingRecord: initialRecord,
        paidDate: paidDate,
        amountPaidForMissing: 1500.0,
      );

      expect(cleared, isNotNull);
      expect(cleared!.isResolved, isTrue);
      expect(cleared.isPaidOrLocked, isTrue);
      expect(cleared.paidDate, DateTime(2026, 9, 28));

      // REQUIREMENT: Basic pay must NOT become zero. It must remain the old amount!
      expect(cleared.missingPay, 1500.0);
      expect(cleared.dayPayment, 1500.0);
      expect(cleared.status, 'resolved');
    });

    test('MissingPaymentRecord.fromJson restores old basic pay for legacy records saved as 0', () {
      final json = {
        'id': 'MISS-LEGACY-001',
        'collection_id': 'COLL-001',
        'loanee_name': 'Legacy Borrower',
        'collection_type': 'daily',
        'missed_date': '2026-09-10',
        'day_payment': 200.0,
        'missing_pay': 0.0, // Was previously saved as 0
        'missing_fine': 6.0,
        'missing_week': 1,
        'missing_balance': 6.0,
        'status': 'resolved',
        'paid_date': '2026-09-20',
        'created_at': '2026-09-10T00:00:00.000',
        'updated_at': '2026-09-20T00:00:00.000',
        'remarks': 'Paid ₹200.00 on 20-09-2026',
      };

      final record = MissingPaymentRecord.fromJson(json);

      expect(record.isResolved, isTrue);
      expect(record.isPaidOrLocked, isTrue);
      // Restored from day_payment since it was zeroed in older versions
      expect(record.missingPay, 200.0);
    });

    test('isPaidOrLocked is true when record has paidDate or resolved status', () {
      final recWithPaidDate = MissingPaymentRecord(
        id: 'MISS-PAID-01',
        collectionId: 'COLL-001',
        loaneeName: 'Loanee',
        collectionType: 'daily',
        missedDate: DateTime(2026, 9, 1),
        missingPay: 100.0,
        paidDate: DateTime(2026, 9, 10),
        status: 'missing',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 10),
      );

      expect(recWithPaidDate.isPaidOrLocked, isTrue);
      expect(recWithPaidDate.isResolved, isTrue);
    });

    testWidgets('MissingRecordsExcelUploadDialog preview renders with no overflow exception', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final parseResult = MissingExcelParseResult(
        fileName: 'missing_payments_test.xlsx',
        fileErrors: [],
        sheets: [
          MissingExcelCustomerSheetResult(
            sheetName: 'Loanee1',
            rawCustomerId: 'CUST-001',
            rawAccountNumber: 'ACC-001',
            rawMobileNo: '9876543210',
            matchedEntry: RoCollectionEntry(
              id: 'COLL-001',
              customerId: 'CUST-001',
              accountNumber: 'ACC-001',
              loaneeName: 'Test Borrower Name',
              loaneeAddress: 'Test Address',
              mobileNo: '9876543210',
              route: 'Route A',
              collectionType: 'daily',
              loanAmount: 10000,
            ),
            missingRows: [
              ParsedMissingExcelRecord(
                rowIndex: 2,
                missedDate: DateTime(2026, 9, 20),
                dayPayment: 0,
                missingPay: 200,
                missingFine: 6,
                missingWeek: 1,
                missingBalance: 6,
                status: 'missing',
              ),
            ],
            generatedModelRecords: [
              MissingPaymentRecord(
                id: 'MISS-001',
                collectionId: 'COLL-001',
                loaneeName: 'Test Borrower Name',
                collectionType: 'daily',
                missedDate: DateTime(2026, 9, 20),
                missingPay: 200,
                status: 'missing',
                createdAt: DateTime(2026, 9, 20),
                updatedAt: DateTime(2026, 9, 20),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MissingRecordsExcelUploadDialog(parseResult: parseResult),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Missing Records Excel Preview'), findsOneWidget);
      expect(find.text('1 Missing Records'), findsOneWidget);
      expect(find.text('Basic Pay'), findsOneWidget);
      expect(find.text('₹200'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
