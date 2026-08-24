// test/loanee_witness_excel_import_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/create_loanee_page.dart';
import 'package:mangang_finance/services/supabase_service.dart';
import 'package:mangang_finance/services/witness_excel_import_service.dart';
import 'package:mangang_finance/widgets/witness_excel_upload_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loanee Witness Excel Import Service & Template Tests', () {
    // -------------------------------------------------------------
    // 1. Template file inspection & verification
    // -------------------------------------------------------------
    test('1. Inspect actual template file assets/template/loanee_witness.xlsx and verify columns & mapping', () {
      final file = File('assets/template/loanee_witness.xlsx');
      expect(file.existsSync(), isTrue, reason: 'Template file assets/template/loanee_witness.xlsx must exist');

      final bytes = file.readAsBytesSync();
      expect(bytes, isNotEmpty);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.containsKey('Loanee Witness'), isTrue,
          reason: 'Sheet name should be "Loanee Witness"');

      final sheet = excel.tables['Loanee Witness']!;
      expect(sheet.maxRows, greaterThanOrEqualTo(2));

      // Verify Column Headers in Row 1 (Index 0)
      final headerRow = sheet.rows[0];
      final headerStrings = headerRow.map((c) => WitnessExcelImportService.getCellString(c)).toList();

      expect(headerStrings[0], equals('Customer ID'));
      expect(headerStrings[1], equals('Account Number'));
      expect(headerStrings[2], equals('Witness Name'));
      expect(headerStrings[3], equals('Witness Guardian Name'));
      expect(headerStrings[4], equals('Witness Address'));
      expect(headerStrings[5], equals('Witness Business Type'));
      expect(headerStrings[6], equals('Witness Post Office'));
      expect(headerStrings[7], equals('Witness Police Station'));
      expect(headerStrings[8], equals('Witness District'));
      expect(headerStrings[9], equals('Witness PIN Code'));
      expect(headerStrings[10], equals('Witness Mobile No'));
      expect(headerStrings[11], equals('Witness Aadhaar No'));
      expect(headerStrings[12], equals('Witness Relationship'));
    });

    // -------------------------------------------------------------
    // 2. Valid Witness Import mapped by Customer ID + Account Number
    // -------------------------------------------------------------
    test('2. Valid witness row mapped by Customer ID + Account ID successfully attaches to Loanee', () {
      final existingLoanee = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'S/O Mahesh Kumar',
        address: 'Main Road, Guwahati',
        businesstype: 'Retail',
        postoffice: 'Dispur',
        policestation: 'Dispur',
        district: 'Kamrup Metro',
        pincode: '781006',
        mobileno: '9876543210',
        aadharno: '123456789012',
      );

      final excel = Excel.createExcel();
      final sheet = excel['Loanee Witness'];

      const headers = WitnessExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      final row1 = [
        '2026LA000001', 'MF2026A000001', 'Suresh Kumar', 'S/O Ram Kumar', 'Main Road, Guwahati',
        'Small Business', 'Dispur', 'Dispur', 'Kamrup Metro', '781006', '9876501234',
        '987654321098', 'Friend'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      final preview = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel.save()!,
        existingLoanees: [existingLoanee],
      );

      expect(preview.totalRows, equals(1));
      expect(preview.validRowsCount, equals(1));
      expect(preview.invalidRowsCount, equals(0));

      final record = preview.rowRecords.first;
      expect(record.isValid, isTrue);
      expect(record.matchedLoanee, isNotNull);
      expect(record.matchedLoanee!.loaneeName, equals('Ramesh Kumar'));

      final updated = record.updatedLoanee!;
      expect(updated.customerId, equals('2026LA000001'));
      expect(updated.accountNumber, equals('MF2026A000001'));
      expect(updated.witnessName, equals('Suresh Kumar'));
      expect(updated.witnessGuardianName, equals('S/O Ram Kumar'));
      expect(updated.witnessAddress, equals('Main Road, Guwahati'));
      expect(updated.witnessRelationship, equals('Friend'));
      expect(updated.witnessMobileNo, equals('9876501234'));
      expect(updated.witnessPinCode, equals('781006'));
    });

    // -------------------------------------------------------------
    // 3. Customer ID not found
    // -------------------------------------------------------------
    test('3. Non-existent Customer ID marks row as invalid with descriptive reason', () {
      final existingLoanee = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'S/O Mahesh',
        address: 'Guwahati',
        businesstype: 'Retail',
        postoffice: 'Dispur',
        policestation: 'Dispur',
        district: 'Kamrup',
        pincode: '781006',
        mobileno: '9876543210',
        aadharno: '123456789012',
      );

      final excel = Excel.createExcel();
      final sheet = excel['Loanee Witness'];

      const headers = WitnessExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      // Customer ID is unknown: 2026LA999999
      final row1 = [
        '2026LA999999', 'MF2026A000001', 'Suresh Kumar', 'S/O Ram Kumar', 'Main Road',
        'Business', 'Dispur', 'Dispur', 'Kamrup', '781006', '9876501234',
        '987654321098', 'Friend'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      final preview = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel.save()!,
        existingLoanees: [existingLoanee],
      );

      expect(preview.validRowsCount, equals(0));
      expect(preview.invalidRowsCount, equals(1));
      expect(preview.rowRecords.first.errorMessage, contains('Customer ID "2026LA999999" not found'));
    });

    // -------------------------------------------------------------
    // 4. Account ID not found
    // -------------------------------------------------------------
    test('4. Non-existent Account Number marks row as invalid with descriptive reason', () {
      final existingLoanee = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'S/O Mahesh',
        address: 'Guwahati',
        businesstype: 'Retail',
        postoffice: 'Dispur',
        policestation: 'Dispur',
        district: 'Kamrup',
        pincode: '781006',
        mobileno: '9876543210',
        aadharno: '123456789012',
      );

      final excel = Excel.createExcel();
      final sheet = excel['Loanee Witness'];

      const headers = WitnessExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      // Account Number is unknown: MF2026A999999
      final row1 = [
        '2026LA000001', 'MF2026A999999', 'Suresh Kumar', 'S/O Ram Kumar', 'Main Road',
        'Business', 'Dispur', 'Dispur', 'Kamrup', '781006', '9876501234',
        '987654321098', 'Friend'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      final preview = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel.save()!,
        existingLoanees: [existingLoanee],
      );

      expect(preview.validRowsCount, equals(0));
      expect(preview.invalidRowsCount, equals(1));
      expect(preview.rowRecords.first.errorMessage, contains('Account Number "MF2026A999999" not found'));
    });

    // -------------------------------------------------------------
    // 5. Customer ID + Account ID mismatch (Belong to different loanees)
    // -------------------------------------------------------------
    test('5. Customer ID and Account ID belonging to different Loanees is rejected as mismatch', () {
      final loanee1 = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Loanee One',
        guardianname: 'S/O Guardian 1',
        address: 'Imphal',
        businesstype: 'Retail',
        postoffice: 'Imphal',
        policestation: 'Imphal',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9862000001',
        aadharno: '111122223333',
      );

      final loanee2 = LoaneeAccount(
        customerid: '2026LA000002',
        accountnumber: 'MF2026A000002',
        loaneename: 'Loanee Two',
        guardianname: 'S/O Guardian 2',
        address: 'Imphal',
        businesstype: 'Retail',
        postoffice: 'Imphal',
        policestation: 'Imphal',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9862000002',
        aadharno: '111122223334',
      );

      final excel = Excel.createExcel();
      final sheet = excel['Loanee Witness'];

      const headers = WitnessExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      // Mix Customer ID of Loanee 1 with Account Number of Loanee 2
      final row1 = [
        '2026LA000001', 'MF2026A000002', 'Witness Person', 'S/O Ram', 'Imphal',
        'Retail', 'Imphal', 'Imphal', 'Imphal West', '795001', '9862990001',
        '123456789012', 'Friend'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      final preview = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel.save()!,
        existingLoanees: [loanee1, loanee2],
      );

      expect(preview.validRowsCount, equals(0));
      expect(preview.invalidRowsCount, equals(1));
      expect(preview.rowRecords.first.errorMessage,
          contains('Customer ID "2026LA000001" and Account Number "MF2026A000002" do not belong to the same Loanee'));
    });

    // -------------------------------------------------------------
    // 6. In-File Duplicate Witness Rows
    // -------------------------------------------------------------
    test('6. Duplicate in-file witness rows for the same loanee are detected and marked', () {
      final loanee = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'S/O Mahesh',
        address: 'Guwahati',
        businesstype: 'Retail',
        postoffice: 'Dispur',
        policestation: 'Dispur',
        district: 'Kamrup',
        pincode: '781006',
        mobileno: '9876543210',
        aadharno: '123456789012',
      );

      final excel = Excel.createExcel();
      final sheet = excel['Loanee Witness'];

      const headers = WitnessExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      final row1 = [
        '2026LA000001', 'MF2026A000001', 'Witness One', 'S/O Ram', 'Guwahati',
        'Retail', 'Dispur', 'Dispur', 'Kamrup', '781006', '9876501234',
        '123456789012', 'Friend'
      ];
      final row2 = [
        '2026LA000001', 'MF2026A000001', 'Witness Two', 'S/O Shyam', 'Guwahati',
        'Retail', 'Dispur', 'Dispur', 'Kamrup', '781006', '9876501235',
        '123456789013', 'Brother'
      ];

      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1)).value = TextCellValue(row1[c]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2)).value = TextCellValue(row2[c]);
      }

      final preview = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel.save()!,
        existingLoanees: [loanee],
      );

      expect(preview.totalRows, equals(2));
      expect(preview.validRowsCount, equals(1));
      expect(preview.invalidRowsCount, equals(1));
      expect(preview.duplicateRowsCount, equals(1));
      expect(preview.rowRecords[1].isDuplicate, isTrue);
      expect(preview.rowRecords[1].errorMessage, contains('Duplicate witness row for Loanee'));
    });

    // -------------------------------------------------------------
    // 7. Multiple Witnesses for Different Loanees
    // -------------------------------------------------------------
    test('7. Multiple valid witness rows for distinct Loanees parse accurately', () {
      final loanee1 = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Loanee 1',
        guardianname: 'S/O G1',
        address: 'Imphal',
        businesstype: 'Retail',
        postoffice: 'Imphal',
        policestation: 'Imphal',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9862000001',
        aadharno: '111122223333',
      );
      final loanee2 = LoaneeAccount(
        customerid: '2026LA000002',
        accountnumber: 'MF2026A000002',
        loaneename: 'Loanee 2',
        guardianname: 'S/O G2',
        address: 'Imphal',
        businesstype: 'Retail',
        postoffice: 'Imphal',
        policestation: 'Imphal',
        district: 'Imphal West',
        pincode: '795001',
        mobileno: '9862000002',
        aadharno: '111122223334',
      );

      final excel = Excel.createExcel();
      final sheet = excel['Loanee Witness'];

      const headers = WitnessExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      final row1 = [
        '2026LA000001', 'MF2026A000001', 'Witness Alpha', 'S/O Ram', 'Imphal',
        'Retail', 'Imphal', 'Imphal', 'Imphal West', '795001', '9862990001',
        '123456789012', 'Friend'
      ];
      final row2 = [
        '2026LA000002', 'MF2026A000002', 'Witness Beta', 'S/O Shyam', 'Imphal',
        'Retail', 'Imphal', 'Imphal', 'Imphal West', '795001', '9862990002',
        '123456789013', 'Brother'
      ];

      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1)).value = TextCellValue(row1[c]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2)).value = TextCellValue(row2[c]);
      }

      final preview = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel.save()!,
        existingLoanees: [loanee1, loanee2],
      );

      expect(preview.totalRows, equals(2));
      expect(preview.validRowsCount, equals(2));
      expect(preview.invalidRowsCount, equals(0));
      expect(preview.rowRecords[0].updatedLoanee!.witnessName, equals('Witness Alpha'));
      expect(preview.rowRecords[1].updatedLoanee!.witnessName, equals('Witness Beta'));
    });

    // -------------------------------------------------------------
    // 8. Missing and Invalid Fields Validation
    // -------------------------------------------------------------
    test('8. Missing witness name or invalid mobile/PIN are rejected', () {
      final loanee = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'S/O Mahesh',
        address: 'Guwahati',
        businesstype: 'Retail',
        postoffice: 'Dispur',
        policestation: 'Dispur',
        district: 'Kamrup',
        pincode: '781006',
        mobileno: '9876543210',
        aadharno: '123456789012',
      );

      // Missing Witness Name
      final rowMissingName = [
        '2026LA000001', 'MF2026A000001', '', 'S/O Ram', 'Guwahati',
        'Retail', 'Dispur', 'Dispur', 'Kamrup', '781006', '9876501234',
        '123456789012', 'Friend'
      ];
      final excel1 = Excel.createExcel();
      final sheet1 = excel1['Loanee Witness'];
      for (int c = 0; c < WitnessExcelImportService.headers.length; c++) {
        sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value = TextCellValue(WitnessExcelImportService.headers[c]);
        sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1)).value = TextCellValue(rowMissingName[c]);
      }
      final preview1 = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel1.save()!,
        existingLoanees: [loanee],
      );
      expect(preview1.rowRecords.first.errorMessage, contains('Witness Name is required'));

      // Invalid Mobile (8 digits)
      final rowInvalidMobile = [
        '2026LA000001', 'MF2026A000001', 'Suresh Kumar', 'S/O Ram', 'Guwahati',
        'Retail', 'Dispur', 'Dispur', 'Kamrup', '781006', '98765012',
        '123456789012', 'Friend'
      ];
      final excel2 = Excel.createExcel();
      final sheet2 = excel2['Loanee Witness'];
      for (int c = 0; c < WitnessExcelImportService.headers.length; c++) {
        sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value = TextCellValue(WitnessExcelImportService.headers[c]);
        sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1)).value = TextCellValue(rowInvalidMobile[c]);
      }
      final preview2 = WitnessExcelImportService.parseWorkbookBytes(
        bytes: excel2.save()!,
        existingLoanees: [loanee],
      );
      expect(preview2.rowRecords.first.errorMessage, contains('Witness Mobile Number must be 10 digits'));
    });

    // -------------------------------------------------------------
    // 9. Notification Suppression during Bulk Import
    // -------------------------------------------------------------
    test('9. Notification suppression is properly active during bulk witness execution', () async {
      final supa = SupabaseService.instance;
      expect(supa.arePaymentNotificationsSuppressed, isFalse);

      bool suppressedInside = false;
      await supa.runWithNotificationSuppression(() async {
        suppressedInside = supa.arePaymentNotificationsSuppressed;
      });

      expect(suppressedInside, isTrue);
      expect(supa.arePaymentNotificationsSuppressed, isFalse, reason: 'Must return to normal after block');
    });
  });

  group('Loanee Witness UI Integration Tests', () {
    testWidgets('10. CreateLoaneePage renders both Basic Loanee and Witness Excel Action Banners', (tester) async {
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

      // Basic Loanee Action Buttons
      expect(find.text('Bulk Loanee Excel Import / Export'), findsOneWidget);
      expect(find.text('Download Template'), findsOneWidget);
      expect(find.text('Upload Excel'), findsOneWidget);

      // Witness Excel Action Buttons
      expect(find.text('Bulk Loanee Witness Excel Import / Export'), findsOneWidget);
      expect(find.text('Download Witness Template'), findsOneWidget);
      expect(find.text('Upload Witness Excel'), findsOneWidget);
    });

    testWidgets('11. WitnessExcelUploadDialog renders summary chips and rows', (tester) async {
      final loanee = LoaneeAccount(
        customerid: '2026LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'S/O Mahesh',
        address: 'Guwahati',
        businesstype: 'Retail',
        postoffice: 'Dispur',
        policestation: 'Dispur',
        district: 'Kamrup',
        pincode: '781006',
        mobileno: '9876543210',
        aadharno: '123456789012',
      );

      final record = WitnessImportRowRecord(
        rowIndex: 2,
        rawCustomerId: '2026LA000001',
        rawAccountNumber: 'MF2026A000001',
        rawWitnessName: 'Suresh Kumar',
        rawWitnessGuardianName: 'S/O Ram',
        rawWitnessAddress: 'Guwahati',
        rawWitnessRelationship: 'Friend',
        rawWitnessMobileNo: '9876501234',
        matchedLoanee: loanee,
        updatedLoanee: loanee.copyWith(witnessname: 'Suresh Kumar'),
        isValid: true,
      );

      final preview = WitnessImportPreviewResult(
        totalRows: 1,
        validRowsCount: 1,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        rowRecords: [record],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WitnessExcelUploadDialog(previewResult: preview),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Witness Excel Preview'), findsOneWidget);
      expect(find.text('Total Rows'), findsOneWidget);
      expect(find.text('Valid Loanees'), findsOneWidget);
      expect(find.text('Confirm & Import (1)'), findsOneWidget);
      expect(find.textContaining('Ramesh Kumar'), findsOneWidget);
      expect(find.textContaining('Suresh Kumar'), findsOneWidget);
    });
  });
}
