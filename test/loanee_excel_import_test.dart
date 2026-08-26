// test/loanee_excel_import_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/create_loanee_page.dart';
import 'package:mangang_finance/services/loanee_excel_import_service.dart';
import 'package:mangang_finance/widgets/loanee_excel_upload_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final bytes = LoaneeExcelImportService.generateTemplateExcelBytes();
    Directory('assets/template').createSync(recursive: true);
    File('assets/template/loanee_basic.xlsx').writeAsBytesSync(bytes);
    Directory('assets/templates').createSync(recursive: true);
    File('assets/templates/loanee_basic.xlsx').writeAsBytesSync(bytes);
  });

  group('Loanee Basic Excel Import Service & Template Tests', () {
    test('1. Inspect actual template file assets/template/loanee_basic.xlsx and verify columns & mapping (18 columns, no Created At)', () {
      final file = File('assets/template/loanee_basic.xlsx');
      expect(file.existsSync(), isTrue, reason: 'Template file assets/template/loanee_basic.xlsx must exist');

      final bytes = file.readAsBytesSync();
      expect(bytes, isNotEmpty);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.containsKey('Loanee Basic Details'), isTrue,
          reason: 'Sheet name should be "Loanee Basic Details"');

      final sheet = excel.tables['Loanee Basic Details']!;
      expect(sheet.maxRows, greaterThanOrEqualTo(2));

      // Verify Column Headers in Row 1 (Index 0) - Exactly 18 columns without Created At
      final headerRow = sheet.rows[0];
      final headerStrings = headerRow.map((c) => LoaneeExcelImportService.getCellString(c)).toList();

      expect(headerStrings.length, equals(18));
      expect(headerStrings[0], equals('Customer ID'));
      expect(headerStrings[1], equals('Account Number'));
      expect(headerStrings[2], equals('Loanee Name'));
      expect(headerStrings[3], equals('Guardian Name'));
      expect(headerStrings[4], equals('Address'));
      expect(headerStrings[5], equals('Business Type'));
      expect(headerStrings[6], equals('Post Office'));
      expect(headerStrings[7], equals('Police Station'));
      expect(headerStrings[8], equals('District'));
      expect(headerStrings[9], equals('PIN Code'));
      expect(headerStrings[10], equals('Mobile No'));
      expect(headerStrings[11], equals('Aadhaar No'));
      expect(headerStrings[12], equals('Status'));
      expect(headerStrings[13], equals('Loan Amount'));
      expect(headerStrings[14], equals('Paid Amount'));
      expect(headerStrings[15], equals('Due Amount'));
      expect(headerStrings[16], equals('Loan Sanction Date'));
      expect(headerStrings[17], equals('Loan Maturity Date'));

      // Parse Workbook using Service
      final preview = LoaneeExcelImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: [],
      );

      expect(preview.totalRows, equals(1));
      expect(preview.validRowsCount, equals(1));
      expect(preview.invalidRowsCount, equals(0));
      expect(preview.totalLoanAmount, equals(57500.0));
      expect(preview.totalPaidAmount, equals(0.0));
      expect(preview.totalDueAmount, equals(57500.0));

      final record = preview.rowRecords.first;
      expect(record.isValid, isTrue);
      expect(record.rawCustomerId, isNotEmpty);
      expect(record.rawAccountNumber, isNotEmpty);
      expect(record.rawLoaneeName, equals('Ramesh Kumar'));
      expect(record.rawGuardianName, equals('S/O Mahesh Kumar'));
      expect(record.rawAddress, equals('Main Road, Guwahati'));
      expect(record.rawBusinessType, equals('Small Business'));
      expect(record.rawPostOffice, equals('Dispur'));
      expect(record.rawPoliceStation, equals('Dispur'));
      expect(record.rawDistrict, equals('Kamrup Metro'));
      expect(record.rawPinCode, equals('781006'));
      expect(record.rawMobileNo, equals('9876543210'));
      expect(record.rawAadhaarNo, equals('XXXX XXXX 1234'));
      expect(record.rawStatus, equals('Active'));

      final loanee = record.loaneeModel!;
      // Created At takes system current date:
      final now = DateTime.now();
      expect(loanee.createdAt.year, equals(now.year));
      expect(loanee.createdAt.month, equals(now.month));
      expect(loanee.createdAt.day, equals(now.day));

      // Sanction Date & Maturity Date take the values from Excel itself (24/08/2026 and 24/01/2027):
      expect(loanee.loanSanctionDate, equals(DateTime(2026, 8, 24)));
      expect(loanee.loanMaturityDate, equals(DateTime(2027, 1, 24)));

      // Requirement 7: Check that NO witness data is imported or populated
      expect(loanee.witnessName, isEmpty);
      expect(loanee.witnessGuardianName, isEmpty);
      expect(loanee.witnessAddress, isEmpty);
      expect(loanee.witnessBusinessType, isEmpty);
      expect(loanee.witnessPostOffice, isEmpty);
      expect(loanee.witnessPoliceStation, isEmpty);
      expect(loanee.witnessDistrict, isEmpty);
      expect(loanee.witnessPinCode, isEmpty);
      expect(loanee.witnessMobileNo, isEmpty);
      expect(loanee.witnessAadharNo, isEmpty);
      expect(loanee.witnessRelationship, isEmpty);
    });

    test('2. Multiple valid rows parse all loanee details accurately without witness data (18 columns)', () {
      final excel = Excel.createExcel();
      final sheet = excel['Loanee Basic Details'];

      // Add Header (18 columns)
      const headers = LoaneeExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      // Add Row 1
      final row1 = [
        'CUST101', 'LN100001', 'Anand Sharma', 'S/O Birendra Sharma', 'Paona Bazar', 'Retail',
        'Imphal PO', 'City PS', 'Imphal West', '795001', '9862000001', '123456789012',
        'Active', '20000', '0', '20000', '2026-07-01', '2026-12-01'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      // Add Row 2
      final row2 = [
        'CUST102', 'LN100002', 'Bina Devi', 'W/O Tomba Singh', 'Thangal Bazar', 'Handloom',
        'Lamphel PO', 'Lamphel PS', 'Imphal West', '795004', '9862000002', '987654321098',
        'Active', '30000', '5000', '25000', '05/06/2026', '05/11/2026'
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

      expect(preview.totalRows, equals(2));
      expect(preview.validRowsCount, equals(2));
      expect(preview.invalidRowsCount, equals(0));
      expect(preview.totalLoanAmount, equals(50000.0));
      expect(preview.totalPaidAmount, equals(5000.0));
      expect(preview.totalDueAmount, equals(45000.0));

      final l1 = preview.rowRecords[0].loaneeModel!;
      expect(l1.customerId, equals('CUST101'));
      expect(l1.accountNumber, equals('LN100001'));
      expect(l1.loaneeName, equals('Anand Sharma'));
      expect(l1.guardianName, equals('S/O Birendra Sharma'));
      expect(l1.loanAmount, equals(20000.0));
      expect(l1.paidAmount, equals(0.0));
      expect(l1.dueAmount, equals(20000.0));
      expect(l1.loanSanctionDate, equals(DateTime(2026, 7, 1)));
      expect(l1.loanMaturityDate, equals(DateTime(2026, 12, 1)));
      expect(l1.witnessName, isEmpty);

      final l2 = preview.rowRecords[1].loaneeModel!;
      expect(l2.customerId, equals('CUST102'));
      expect(l2.accountNumber, equals('LN100002'));
      expect(l2.loaneeName, equals('Bina Devi'));
      expect(l2.loanAmount, equals(30000.0));
      expect(l2.paidAmount, equals(5000.0));
      expect(l2.dueAmount, equals(25000.0));
      expect(l2.loanSanctionDate, equals(DateTime(2026, 6, 5)));
      expect(l2.loanMaturityDate, equals(DateTime(2026, 11, 5)));
      expect(l2.witnessName, isEmpty);
    });

    test('3. In-file duplicate checking detects duplicate Customer ID, Account Number, and Mobile Number', () {
      final excel = Excel.createExcel();
      final sheet = excel['Loanee Basic Details'];

      for (int c = 0; c < LoaneeExcelImportService.headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(LoaneeExcelImportService.headers[c]);
      }

      // Row 1: Original
      final row1 = [
        'CUST201', 'LN200001', 'Chao Singh', 'S/O Tomba', 'Kakching', 'Farming',
        'PO', 'PS', 'Kakching', '795103', '9862111111', '111122223333',
        'Active', '10000', '0', '10000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      // Row 2: Duplicate Customer ID
      final row2 = [
        'CUST201', 'LN200002', 'Deben Roy', 'S/O Ram', 'Thoubal', 'Farming',
        'PO', 'PS', 'Thoubal', '795138', '9862222222', '222233334444',
        'Active', '10000', '0', '10000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row2.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2))
          .value = TextCellValue(row2[c]);
      }

      // Row 3: Duplicate Account Number
      final row3 = [
        'CUST203', 'LN200001', 'Elangbam Devi', 'D/O Mani', 'Bishnupur', 'Handicraft',
        'PO', 'PS', 'Bishnupur', '795126', '9862333333', '333344445555',
        'Active', '15000', '0', '15000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row3.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3))
          .value = TextCellValue(row3[c]);
      }

      // Row 4: Duplicate Mobile Number
      final row4 = [
        'CUST204', 'LN200004', 'Firoz Khan', 'S/O Ali', 'Yairipok', 'Shop',
        'PO', 'PS', 'Thoubal', '795149', '9862111111', '444455556666',
        'Active', '20000', '0', '20000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row4.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4))
          .value = TextCellValue(row4[c]);
      }

      final bytes = excel.save()!;
      final preview = LoaneeExcelImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: [],
      );

      expect(preview.totalRows, equals(4));
      expect(preview.validRowsCount, equals(1)); // Only Row 1 is valid
      expect(preview.invalidRowsCount, equals(3));
      expect(preview.duplicateRowsCount, equals(3));

      expect(preview.rowRecords[0].isValid, isTrue);
      expect(preview.rowRecords[1].isValid, isFalse);
      expect(preview.rowRecords[1].errorMessage, contains('Duplicate Customer ID'));
      expect(preview.rowRecords[2].isValid, isFalse);
      expect(preview.rowRecords[2].errorMessage, contains('Duplicate Account Number'));
      expect(preview.rowRecords[3].isValid, isFalse);
      expect(preview.rowRecords[3].errorMessage, contains('Duplicate Mobile Number'));
    });

    test('4. Database duplicate checking detects loanees already existing in DB', () {
      final existingDbLoanees = [
        LoaneeAccount(
          customerid: 'CUST-DB-01',
          accountnumber: 'ACC-DB-01',
          loaneename: 'Existing Master Loanee',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Grocery',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862999999',
          aadharno: '999988887777',
        ),
      ];

      final excel = Excel.createExcel();
      final sheet = excel['Loanee Basic Details'];
      for (int c = 0; c < LoaneeExcelImportService.headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(LoaneeExcelImportService.headers[c]);
      }

      // Row 1: Clashing with DB Customer ID
      final row1 = [
        'CUST-DB-01', 'LN300001', 'New Loanee 1', 'S/O A', 'Add 1', 'Biz',
        'PO', 'PS', 'Dist', '795001', '9862000011', '123412341234',
        'Active', '10000', '0', '10000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row1[c]);
      }

      // Row 2: Clashing with DB Account Number
      final row2 = [
        'CUST302', 'ACC-DB-01', 'New Loanee 2', 'S/O B', 'Add 2', 'Biz',
        'PO', 'PS', 'Dist', '795001', '9862000012', '567856785678',
        'Active', '10000', '0', '10000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row2.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2))
          .value = TextCellValue(row2[c]);
      }

      // Row 3: Clashing with DB Mobile Number
      final row3 = [
        'CUST303', 'LN300003', 'New Loanee 3', 'S/O C', 'Add 3', 'Biz',
        'PO', 'PS', 'Dist', '795001', '9862999999', '901290129012',
        'Active', '10000', '0', '10000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row3.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3))
          .value = TextCellValue(row3[c]);
      }

      // Row 4: Completely Fresh Loanee
      final row4 = [
        'CUST304', 'LN300004', 'Fresh Loanee', 'S/O D', 'Add 4', 'Biz',
        'PO', 'PS', 'Dist', '795001', '9862000014', '345634563456',
        'Active', '10000', '0', '10000', '2026-08-01', '2027-01-01'
      ];
      for (int c = 0; c < row4.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4))
          .value = TextCellValue(row4[c]);
      }

      final bytes = excel.save()!;
      final preview = LoaneeExcelImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: existingDbLoanees,
      );

      expect(preview.totalRows, equals(4));
      expect(preview.validRowsCount, equals(1)); // Only Row 4 is valid
      expect(preview.invalidRowsCount, equals(3));
      expect(preview.duplicateRowsCount, equals(3));

      expect(preview.rowRecords[0].errorMessage, contains('already exists in database with Customer ID'));
      expect(preview.rowRecords[1].errorMessage, contains('already exists in database with Account Number'));
      expect(preview.rowRecords[2].errorMessage, contains('already exists in database with Mobile Number'));
      expect(preview.rowRecords[3].isValid, isTrue);
    });

    test('5. Missing required fields and empty rows are handled gracefully', () {
      final excel = Excel.createExcel();
      final sheet = excel['Loanee Basic Details'];
      for (int c = 0; c < LoaneeExcelImportService.headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(LoaneeExcelImportService.headers[c]);
      }

      // Row 1: Empty row (should be skipped)
      // Row 2: Missing Loanee Name
      final row2 = ['CUST401', 'LN400001', '', 'S/O Tomba', 'Add', 'Biz'];
      for (int c = 0; c < row2.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2))
          .value = TextCellValue(row2[c]);
      }

      // Row 3: Missing Customer ID and Account Number
      final row3 = ['', '', 'Gourachandra', 'S/O Mani', 'Add', 'Biz'];
      for (int c = 0; c < row3.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3))
          .value = TextCellValue(row3[c]);
      }

      final bytes = excel.save()!;
      final preview = LoaneeExcelImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: [],
      );

      expect(preview.totalRows, equals(2)); // Empty row 1 skipped
      expect(preview.validRowsCount, equals(0));
      expect(preview.invalidRowsCount, equals(2));

      expect(preview.rowRecords[0].errorMessage, equals('Loanee Name is required.'));
      expect(preview.rowRecords[1].errorMessage, equals('Customer ID or Account Number is required.'));
    });

    test('6. Date formats parsing handles serial dates, standard dates, text month names, 2-digit years, and ISO dates', () {
      expect(LoaneeExcelImportService.parseDateValue(46204.0), equals(DateTime(2026, 7, 1)));
      expect(LoaneeExcelImportService.parseDateValue('24/08/2026'), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue('2026-08-24'), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue('24-08-2026'), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue('24-Aug-2026'), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue('24 August 2026'), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue('Aug 24, 2026'), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue('01-Mar-2026'), equals(DateTime(2026, 3, 1)));
      expect(LoaneeExcelImportService.parseDateValue('24/08/26'), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue(DateTime(2026, 8, 24)), equals(DateTime(2026, 8, 24)));
      expect(LoaneeExcelImportService.parseDateValue(IntCellValue(46204)), equals(DateTime(2026, 7, 1)));
      expect(LoaneeExcelImportService.parseDateValue(TextCellValue('24/08/2026')), equals(DateTime(2026, 8, 24)));
    });

    test('7. Numeric parsing handles currency symbols and formats correctly', () {
      expect(LoaneeExcelImportService.parseNumericAmount(57500), equals(57500.0));
      expect(LoaneeExcelImportService.parseNumericAmount('57500.50'), equals(57500.50));
      expect(LoaneeExcelImportService.parseNumericAmount('₹ 57,500.00'), equals(57500.0));
      expect(LoaneeExcelImportService.parseNumericAmount(''), isNull);
    });

    test('8. Template Excel byte generation creates a valid workbook with exact 18 columns and 1 sample row', () {
      final bytes = LoaneeExcelImportService.generateTemplateExcelBytes();
      expect(bytes, isNotEmpty);

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Loanee Basic Details'];
      expect(sheet.maxRows, greaterThanOrEqualTo(2));

      final headerRow = sheet.rows[0];
      expect(headerRow.length, equals(18));
      expect(headerRow[0]?.value.toString(), equals('Customer ID'));
      expect(headerRow[2]?.value.toString(), equals('Loanee Name'));
      expect(headerRow[13]?.value.toString(), equals('Loan Amount'));
      expect(headerRow[16]?.value.toString(), equals('Loan Sanction Date'));
      expect(headerRow[17]?.value.toString(), equals('Loan Maturity Date'));
    });

    test('9. Execution summary produces the exact format Total: X | Imported: Y | Failed: Z', () {
      final executionResult = LoaneeImportExecutionResult(
        success: true,
        total: 100,
        imported: 95,
        failed: 5,
      );

      expect(executionResult.summaryText, equals('Total: 100 | Imported: 95 | Failed: 5'));
    });

    test('13. Distinct Loan Sanction Date and Loan Maturity Date from Excel are preserved without overriding', () {
      final excel = Excel.createExcel();
      final sheet = excel['Loanee Basic Details'];

      // Header without Created At
      const headers = LoaneeExcelImportService.headers;
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
      }

      // Loanee with specific historical Sanction Date (01-01-2026) and Maturity Date (01-06-2026)
      final row = [
        'CUST999', 'LN999001', 'Historical Loanee', 'S/O Tomba', 'Imphal', 'Retail',
        'Imphal PO', 'City PS', 'Imphal West', '795001', '9862999123', '123456789999',
        'Active', '50000', '10000', '40000', '01/01/2026', '01/06/2026'
      ];
      for (int c = 0; c < row.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value = TextCellValue(row[c]);
      }

      final bytes = excel.save()!;
      final preview = LoaneeExcelImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: [],
      );

      expect(preview.validRowsCount, equals(1));
      final record = preview.rowRecords.first;
      final loanee = record.loaneeModel!;

      // createdAt must take current date (e.g. today in 2026)
      final now = DateTime.now();
      expect(loanee.createdAt.year, equals(now.year));
      expect(loanee.createdAt.month, equals(now.month));
      expect(loanee.createdAt.day, equals(now.day));

      // Sanction Date & Maturity Date must NOT be equal to createdAt; they must be 01/01/2026 and 01/06/2026 from Excel
      expect(loanee.loanSanctionDate, equals(DateTime(2026, 1, 1)));
      expect(loanee.loanMaturityDate, equals(DateTime(2026, 6, 1)));
      expect(loanee.loanSanctionDate, isNot(equals(loanee.createdAt)));
    });
  });

  group('CreateLoaneePage UI & Dialog Widget Tests', () {
    testWidgets('10. CreateLoaneePage renders "Download Template" and "Upload Excel" buttons without any layout errors on standard screen', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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

      // Verify page title
      expect(find.text('Create Loanee & Witness Account'), findsOneWidget);

      // Verify presence of "Download Template" and "Upload Excel" buttons
      expect(find.text('Download Template'), findsWidgets);
      expect(find.text('Upload Excel'), findsWidgets);

      // Verify manual form is completely intact
      expect(find.text('1. Account & System Identifiers'), findsOneWidget);
      expect(find.text('2. Loanee Personal Details'), findsOneWidget);
      expect(find.text('3. Loanee Address & Area Details'), findsOneWidget);
      expect(find.text('4. Loanee Business & Financial Details'), findsOneWidget);
      expect(find.text('5. Witness Details'), findsOneWidget);
      expect(find.text('Clear Form'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('11. CreateLoaneePage renders and scrolls smoothly on narrow mobile screen (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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

      // Verify buttons exist on mobile layout
      expect(find.text('Download Template'), findsOneWidget);
      expect(find.text('Upload Excel'), findsOneWidget);

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('12. LoaneeExcelUploadDialog displays preview stats, rows, and Confirm Import button', (tester) async {
      final previewResult = LoaneeImportPreviewResult(
        totalRows: 2,
        validRowsCount: 2,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        totalLoanAmount: 50000.0,
        totalPaidAmount: 0.0,
        totalDueAmount: 50000.0,
        rowRecords: [
          LoaneeImportRowRecord(
            rowIndex: 2,
            rawCustomerId: 'CUST501',
            rawAccountNumber: 'LN500001',
            rawLoaneeName: 'Tomba Singh',
            rawLoanAmount: '25000',
            isValid: true,
          ),
          LoaneeImportRowRecord(
            rowIndex: 3,
            rawCustomerId: 'CUST502',
            rawAccountNumber: 'LN500002',
            rawLoaneeName: 'Chaoba Singh',
            rawLoanAmount: '25000',
            isValid: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LoaneeExcelUploadDialog(previewResult: previewResult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Excel Loanee Bulk Import Preview'), findsOneWidget);
      expect(find.text('Total Rows'), findsOneWidget);
      expect(find.text('Valid Loanees'), findsOneWidget);
      expect(find.text('Total Loan'), findsOneWidget);
      expect(find.text('Tomba Singh'), findsOneWidget);
      expect(find.text('Chaoba Singh'), findsOneWidget);
      expect(find.text('Confirm Import (2 Loanees)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    test('14. LoaneeAccount.fromJson correctly maps loansanctiondate and loanmaturitydate from loanee_accounts table', () {
      final dbJson = {
        'customerid': '2026LA000055',
        'accountnumber': 'MF2026A000055',
        'loaneename': 'Sanctioned Test User',
        'guardianname': 'S/O Guardian',
        'address': 'Imphal West',
        'businesstype': 'Handloom',
        'postoffice': 'Imphal',
        'policestation': 'Imphal',
        'district': 'Imphal West',
        'pincode': '795001',
        'mobileno': '9862123456',
        'aadharno': '123456789012',
        'createdat': '2026-08-01T12:00:00Z',
        'status': 'Active',
        'loanamount': 50000,
        'paidamount': 10000,
        'dueamount': 40000,
        'loansanctiondate': '2026-03-15T00:00:00+00:00',
        'loanmaturitydate': '2026-08-15T00:00:00+00:00',
      };

      final loanee = LoaneeAccount.fromJson(dbJson);
      expect(loanee.loansanctiondate, equals(DateTime(2026, 3, 15)));
      expect(loanee.loanmaturitydate, equals(DateTime(2026, 8, 15)));
      expect(loanee.formattedSanctionDate, equals('15/03/2026'));
      expect(loanee.formattedMaturityDate, equals('15/08/2026'));

      // Also verify string dates like DD/MM/YYYY
      final textDateJson = {
        'customerid': '2026LA000056',
        'accountnumber': 'MF2026A000056',
        'loaneename': 'Text Date User',
        'guardianname': 'N/A',
        'address': 'Imphal',
        'businesstype': 'Grocery',
        'postoffice': 'PO',
        'policestation': 'PS',
        'district': 'Imphal West',
        'pincode': '795001',
        'mobileno': '9862123457',
        'aadharno': '123456789013',
        'loansanctiondate': '24/08/2026',
        'loanmaturitydate': '24/01/2027',
      };

      final loanee2 = LoaneeAccount.fromJson(textDateJson);
      expect(loanee2.formattedSanctionDate, equals('24/08/2026'));
      expect(loanee2.formattedMaturityDate, equals('24/01/2027'));
    });
  });
}
