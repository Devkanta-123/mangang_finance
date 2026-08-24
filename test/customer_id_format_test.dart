// test/customer_id_format_test.dart

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/create_loanee_page.dart';
import 'package:mangang_finance/screens/create_ro_page.dart';
import 'package:mangang_finance/services/customer_id_service.dart';
import 'package:mangang_finance/services/loanee_excel_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerIdService Auto-Generated ID Formats & Sequences', () {
    // -------------------------------------------------------------
    // 1. LOANEE CUSTOMER ID: YYLA + 6 digits (e.g. 26LA000001)
    // -------------------------------------------------------------
    test('1. Loanee Customer ID generation follows YYLA + 6-digit sequence', () {
      final now2026 = DateTime(2026, 8, 24);

      // First Loanee -> 26LA000001
      final id1 = CustomerIdService.generateLoaneeCustomerId(
        existingLoanees: [],
        now: now2026,
      );
      expect(id1, equals('26LA000001'));

      // Second Loanee -> 26LA000002
      final id2 = CustomerIdService.generateLoaneeCustomerId(
        existingIds: [id1],
        now: now2026,
      );
      expect(id2, equals('26LA000002'));

      // Third Loanee -> 26LA000003
      final id3 = CustomerIdService.generateLoaneeCustomerId(
        existingIds: [id1, id2],
        now: now2026,
      );
      expect(id3, equals('26LA000003'));
    });

    // -------------------------------------------------------------
    // 2. RO CUSTOMER ID: YYR + 3 digits (e.g. 26R001)
    // -------------------------------------------------------------
    test('2. RO Customer ID generation follows YYR + 3-digit sequence', () {
      final now2026 = DateTime(2026, 8, 24);

      // First RO -> 26R001
      final id1 = CustomerIdService.generateRoCustomerId(
        existingRos: [],
        now: now2026,
      );
      expect(id1, equals('26R001'));

      // Second RO -> 26R002
      final id2 = CustomerIdService.generateRoCustomerId(
        existingIds: [id1],
        now: now2026,
      );
      expect(id2, equals('26R002'));

      // Third RO -> 26R003
      final id3 = CustomerIdService.generateRoCustomerId(
        existingIds: [id1, id2],
        now: now2026,
      );
      expect(id3, equals('26R003'));
    });

    // -------------------------------------------------------------
    // 3. LOANEE ACCOUNT NUMBER: MF + YY + A + 6 digits (e.g. MF26A000001)
    // -------------------------------------------------------------
    test('3. Loanee Account Number generation follows MF + YY + A + 6-digit sequence', () {
      final now2026 = DateTime(2026, 8, 24);

      // First Loanee Account -> MF26A000001
      final acc1 = CustomerIdService.generateLoaneeAccountNumber(
        existingLoanees: [],
        now: now2026,
      );
      expect(acc1, equals('MF26A000001'));

      // Second Loanee Account -> MF26A000002
      final acc2 = CustomerIdService.generateLoaneeAccountNumber(
        existingAccNos: [acc1],
        now: now2026,
      );
      expect(acc2, equals('MF26A000002'));

      // Third Loanee Account -> MF26A000003
      final acc3 = CustomerIdService.generateLoaneeAccountNumber(
        existingAccNos: [acc1, acc2],
        now: now2026,
      );
      expect(acc3, equals('MF26A000003'));
    });

    // -------------------------------------------------------------
    // 4. RO ACCOUNT NUMBER: AC + YY + RS + 4 digits (e.g. AC26RS0001)
    // -------------------------------------------------------------
    test('4. RO Account Number generation follows AC + YY + RS + 4-digit sequence', () {
      final now2026 = DateTime(2026, 8, 24);

      // First RO Account -> AC26RS0001
      final acc1 = CustomerIdService.generateRoAccountNumber(
        existingRos: [],
        now: now2026,
      );
      expect(acc1, equals('AC26RS0001'));

      // Second RO Account -> AC26RS0002
      final acc2 = CustomerIdService.generateRoAccountNumber(
        existingAccNos: [acc1],
        now: now2026,
      );
      expect(acc2, equals('AC26RS0002'));

      // Third RO Account -> AC26RS0003
      final acc3 = CustomerIdService.generateRoAccountNumber(
        existingAccNos: [acc1, acc2],
        now: now2026,
      );
      expect(acc3, equals('AC26RS0003'));
    });

    // -------------------------------------------------------------
    // 5. ZERO-PADDING VERIFICATION
    // -------------------------------------------------------------
    test('5. Exact zero-padding rules for all 4 generators', () {
      final now2026 = DateTime(2026, 8, 24);

      // Loanee Customer ID: 6 digits
      expect(CustomerIdService.formatLoaneeCustomerId(1, now: now2026), equals('26LA000001'));
      expect(CustomerIdService.formatLoaneeCustomerId(999, now: now2026), equals('26LA000999'));
      expect(CustomerIdService.formatLoaneeCustomerId(999999, now: now2026), equals('26LA999999'));

      // RO Customer ID: 3 digits
      expect(CustomerIdService.formatRoCustomerId(1, now: now2026), equals('26R001'));
      expect(CustomerIdService.formatRoCustomerId(99, now: now2026), equals('26R099'));
      expect(CustomerIdService.formatRoCustomerId(999, now: now2026), equals('26R999'));

      // Loanee Account Number: 6 digits
      expect(CustomerIdService.formatLoaneeAccountNumber(1, now: now2026), equals('MF26A000001'));
      expect(CustomerIdService.formatLoaneeAccountNumber(50, now: now2026), equals('MF26A000050'));
      expect(CustomerIdService.formatLoaneeAccountNumber(999999, now: now2026), equals('MF26A999999'));

      // RO Account Number: 4 digits
      expect(CustomerIdService.formatRoAccountNumber(1, now: now2026), equals('AC26RS0001'));
      expect(CustomerIdService.formatRoAccountNumber(100, now: now2026), equals('AC26RS0100'));
      expect(CustomerIdService.formatRoAccountNumber(9999, now: now2026), equals('AC26RS9999'));
    });

    // -------------------------------------------------------------
    // 6. DYNAMIC YEAR HANDLING
    // -------------------------------------------------------------
    test('6. Dynamic Year handling across year changes (never hardcoded)', () {
      final now2027 = DateTime(2027, 1, 1);
      expect(CustomerIdService.generateLoaneeCustomerId(existingLoanees: [], now: now2027), equals('27LA000001'));
      expect(CustomerIdService.generateRoCustomerId(existingRos: [], now: now2027), equals('27R001'));
      expect(CustomerIdService.generateLoaneeAccountNumber(existingLoanees: [], now: now2027), equals('MF27A000001'));
      expect(CustomerIdService.generateRoAccountNumber(existingRos: [], now: now2027), equals('AC27RS0001'));

      final now2030 = DateTime(2030, 12, 31);
      expect(CustomerIdService.generateLoaneeCustomerId(existingLoanees: [], now: now2030), equals('30LA000001'));
      expect(CustomerIdService.generateRoCustomerId(existingRos: [], now: now2030), equals('30R001'));
      expect(CustomerIdService.generateLoaneeAccountNumber(existingLoanees: [], now: now2030), equals('MF30A000001'));
      expect(CustomerIdService.generateRoAccountNumber(existingRos: [], now: now2030), equals('AC30RS0001'));
    });

    // -------------------------------------------------------------
    // 7. SEPARATE SEQUENCES
    // -------------------------------------------------------------
    test('7. Customer IDs and Account Numbers for Loanee and RO have separate sequences', () {
      final now2026 = DateTime(2026, 8, 24);

      final existingLoanees = [
        LoaneeAccount(
          customerid: '26LA000001',
          accountnumber: 'MF26A000001',
          loaneename: 'Loanee 1',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Retail',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000001',
          aadharno: '111122223333',
        ),
        LoaneeAccount(
          customerid: '26LA000002',
          accountnumber: 'MF26A000002',
          loaneename: 'Loanee 2',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Retail',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000002',
          aadharno: '111122223334',
        ),
      ];

      final existingRos = [
        RoAccount(
          customerid: '26R001',
          accountnumber: 'AC26RS0001',
          roname: 'RO 1',
          guardianname: 'N/A',
          address: 'Imphal',
          designation: 'Recovery Officer',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000010',
          aadharno: '222233334444',
        ),
      ];

      // Next Loanee ID & Account
      expect(CustomerIdService.generateLoaneeCustomerId(existingLoanees: existingLoanees, now: now2026), equals('26LA000003'));
      expect(CustomerIdService.generateLoaneeAccountNumber(existingLoanees: existingLoanees, now: now2026), equals('MF26A000003'));

      // Next RO ID & Account
      expect(CustomerIdService.generateRoCustomerId(existingRos: existingRos, now: now2026), equals('26R002'));
      expect(CustomerIdService.generateRoAccountNumber(existingRos: existingRos, now: now2026), equals('AC26RS0002'));
    });

    // -------------------------------------------------------------
    // 8. PRESERVATION OF EXISTING RECORDS
    // -------------------------------------------------------------
    test('8. Existing legacy Customer IDs and Account Numbers are preserved unchanged', () {
      final now2026 = DateTime(2026, 8, 24);

      final legacyLoanees = [
        LoaneeAccount(
          customerid: 'CUST-1001',
          accountnumber: 'ACC-88239101',
          loaneename: 'Legacy Loanee 1',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Retail',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000001',
          aadharno: '111122223333',
        ),
      ];

      final legacyRos = [
        RoAccount(
          customerid: 'RO-CUST-5001',
          accountnumber: 'RO-ACC-991001',
          roname: 'Legacy RO',
          guardianname: 'N/A',
          address: 'Imphal',
          designation: 'Recovery Officer',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000010',
          aadharno: '222233334444',
        ),
      ];

      // Existing records stay intact
      expect(legacyLoanees[0].customerId, equals('CUST-1001'));
      expect(legacyLoanees[0].accountNumber, equals('ACC-88239101'));
      expect(legacyRos[0].customerId, equals('RO-CUST-5001'));
      expect(legacyRos[0].accountNumber, equals('RO-ACC-991001'));

      // New generated records adopt new formats starting at 1
      expect(CustomerIdService.generateLoaneeCustomerId(existingLoanees: legacyLoanees, now: now2026), equals('26LA000001'));
      expect(CustomerIdService.generateLoaneeAccountNumber(existingLoanees: legacyLoanees, now: now2026), equals('MF26A000001'));
      expect(CustomerIdService.generateRoCustomerId(existingRos: legacyRos, now: now2026), equals('26R001'));
      expect(CustomerIdService.generateRoAccountNumber(existingRos: legacyRos, now: now2026), equals('AC26RS0001'));
    });

    // -------------------------------------------------------------
    // 9. BATCH & CONCURRENT GENERATION WITH ZERO COLLISIONS
    // -------------------------------------------------------------
    test('9. Batch and concurrent generation with reserved IDs guarantees zero collisions', () {
      final now2026 = DateTime(2026, 8, 24);

      final custBatch = CustomerIdService.generateLoaneeCustomerIdsBatch(3, now: now2026);
      expect(custBatch, equals(['26LA000001', '26LA000002', '26LA000003']));

      final accBatch = CustomerIdService.generateLoaneeAccountNumbersBatch(3, now: now2026);
      expect(accBatch, equals(['MF26A000001', 'MF26A000002', 'MF26A000003']));

      // In-flight reserved ID collision avoidance
      final nextWithReserved = CustomerIdService.generateLoaneeCustomerId(
        existingIds: custBatch,
        reservedIds: {'26LA000004'},
        now: now2026,
      );
      expect(nextWithReserved, equals('26LA000005'));
    });

    // -------------------------------------------------------------
    // 10. FORMAT VALIDATIONS
    // -------------------------------------------------------------
    test('10. Validation functions recognize new and legacy formats', () {
      expect(CustomerIdService.isValidLoaneeCustomerId('26LA000001'), isTrue);
      expect(CustomerIdService.isValidLoaneeCustomerId('2026LA000001'), isTrue);
      expect(CustomerIdService.isValidLoaneeCustomerId('CUST-1001'), isTrue);

      expect(CustomerIdService.isValidRoCustomerId('26R001'), isTrue);
      expect(CustomerIdService.isValidRoCustomerId('2026R001'), isTrue);
      expect(CustomerIdService.isValidRoCustomerId('RO-CUST-5001'), isTrue);

      expect(CustomerIdService.isValidLoaneeAccountNumber('MF26A000001'), isTrue);
      expect(CustomerIdService.isValidLoaneeAccountNumber('MF2026A000001'), isTrue);
      expect(CustomerIdService.isValidLoaneeAccountNumber('ACC-88239101'), isTrue);

      expect(CustomerIdService.isValidRoAccountNumber('AC26RS0001'), isTrue);
      expect(CustomerIdService.isValidRoAccountNumber('AC2026RS0001'), isTrue);
      expect(CustomerIdService.isValidRoAccountNumber('RO-ACC-991001'), isTrue);
    });

    // -------------------------------------------------------------
    // 11. BULK EXCEL LOANEE IMPORT INTEGRATION
    // -------------------------------------------------------------
    test('11. Bulk Excel Loanee Import assigns new ID formats for rows missing Customer ID/Account No', () {
      final excel = Excel.createExcel();
      final sheet = excel['Loanee Basic Details'];

      const headers = LoaneeExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      // Row 1: Has Customer ID, missing Account Number
      final row1 = [
        '26LA000001', '', 'Robert Sanasam', 'S. Tomba', 'Keishamthong', 'Handicrafts',
        'Keishamthong PO', 'Imphal PS', 'Imphal West', '795001', '9862990001', '123456789012',
        '2026-08-24', 'Active', '50000', '0', '50000', '2026-08-24', '2027-01-24'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      // Row 2: Missing Customer ID, has Account Number
      final row2 = [
        '', 'MF26A000002', 'Bembem Devi', 'W/O Sanatomba', 'Singjamei', 'Handloom',
        'Singjamei PO', 'Singjamei PS', 'Imphal West', '795008', '9862990002', '987654321098',
        '2026-08-24', 'Active', '30000', '0', '30000', '2026-08-24', '2027-01-24'
      ];
      for (int c = 0; c < row2.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2))
          .value = TextCellValue(row2[c]);
      }

      final bytes = excel.save()!;
      final preview = LoaneeExcelImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: [],
      );

      expect(preview.validRowsCount, equals(2));

      final shortYear = CustomerIdService.getShortYear();
      final imported1 = preview.rowRecords[0].loaneeModel;
      expect(imported1, isNotNull);
      expect(imported1!.customerId, equals('26LA000001'));
      expect(imported1.accountNumber, startsWith('MF${shortYear}A'));

      final imported2 = preview.rowRecords[1].loaneeModel;
      expect(imported2, isNotNull);
      expect(imported2!.customerId, startsWith('${shortYear}LA'));
      expect(imported2.accountNumber, equals('MF26A000002'));
    });
  });

  group('Provider & UI Integration Tests for New ID Formats', () {
    test('12. LoaneeProvider and RoProvider generate new Customer IDs and Account Numbers', () {
      final loaneeProvider = LoaneeProvider();
      final roProvider = RoProvider();

      final shortYear = CustomerIdService.getShortYear();

      final loaneeId = loaneeProvider.generateNextCustomerId();
      final loaneeAcc = loaneeProvider.generateNextAccountNumber();
      expect(loaneeId, startsWith('${shortYear}LA'));
      expect(loaneeId.length, equals(10)); // 26 (2) + LA (2) + 000001 (6) = 10
      expect(loaneeAcc, startsWith('MF${shortYear}A'));
      expect(loaneeAcc.length, equals(11)); // MF (2) + 26 (2) + A (1) + 000001 (6) = 11

      final roId = roProvider.generateNextCustomerId();
      final roAcc = roProvider.generateNextAccountNumber();
      expect(roId, startsWith('${shortYear}R'));
      expect(roId.length, equals(6)); // 26 (2) + R (1) + 001 (3) = 6
      expect(roAcc, startsWith('AC${shortYear}RS'));
      expect(roAcc.length, equals(10)); // AC (2) + 26 (2) + RS (2) + 0001 (4) = 10
    });

    testWidgets('13. CreateLoaneePage initializes with new format YYLA000001 and MFYYA000001', (tester) async {
      final shortYear = CustomerIdService.getShortYear();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(
            home: CreateLoaneePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Customer ID field has generated ID matching {shortYear}LA000001
      final customerIdFinder = find.byWidgetPredicate((widget) {
        return widget is TextFormField &&
            widget.controller?.text.startsWith('${shortYear}LA') == true;
      });
      expect(customerIdFinder, findsOneWidget);

      // Check Account Number field has generated Account No matching MF{shortYear}A000001
      final accountNoFinder = find.byWidgetPredicate((widget) {
        return widget is TextFormField &&
            widget.controller?.text.startsWith('MF${shortYear}A') == true;
      });
      expect(accountNoFinder, findsOneWidget);
    });

    testWidgets('14. CreateRoPage initializes with new format YYR001 and ACYYRS0001', (tester) async {
      final shortYear = CustomerIdService.getShortYear();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => RoProvider()),
            ChangeNotifierProvider(create: (_) => CollectionSheetProvider()),
          ],
          child: const MaterialApp(
            home: CreateRoPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Customer ID field has generated ID matching {shortYear}R001
      final customerIdFinder = find.byWidgetPredicate((widget) {
        return widget is TextFormField &&
            widget.controller?.text.startsWith('${shortYear}R') == true;
      });
      expect(customerIdFinder, findsOneWidget);

      // Check Account Number field has generated Account No matching AC{shortYear}RS0001
      final accountNoFinder = find.byWidgetPredicate((widget) {
        return widget is TextFormField &&
            widget.controller?.text.startsWith('AC${shortYear}RS') == true;
      });
      expect(accountNoFinder, findsOneWidget);
    });
  });
}
