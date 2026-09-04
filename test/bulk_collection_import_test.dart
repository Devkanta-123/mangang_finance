// test/bulk_collection_import_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/services/bulk_collection_import_service.dart';

void main() {
  group('Bulk Collection Card Import & Template Generation Tests for RoCollectionEntry', () {
    test('generateTemplateExcelBytes creates a valid Excel file with RoCollectionEntry headers and 1 dummy record', () {
      final sampleEntry = RoCollectionEntry(
        id: 'COL-101',
        customerId: 'CUST-2001',
        accountNumber: 'ACC-88239201',
        loaneeName: 'Ibomcha Sharma',
        loaneeAddress: 'Imphal West Market',
        collectionType: 'Daily',
        route: 'Office',
        mobileNo: '9862123456',
        status: 'Active',
      );

      final bytes = BulkCollectionImportService.generateTemplateExcelBytes(sampleEntry: sampleEntry);
      expect(bytes, isNotEmpty);

      // Decode and verify structure
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.isNotEmpty, isTrue);

      final sheet = excel.tables.values.first;
      expect(sheet.maxRows, greaterThanOrEqualTo(2)); // Row 0: Headers, Row 1: Dummy data

      // Verify Header row (Row 0)
      final headerRow = sheet.rows[0];
      expect(headerRow.length, greaterThanOrEqualTo(BulkCollectionImportService.headers.length));
      expect(headerRow[0]?.value.toString(), equals('Customer_ID'));
      expect(headerRow[1]?.value.toString(), equals('Account_Number'));
      expect(headerRow[2]?.value.toString(), equals('Loanee_Name'));
      expect(headerRow[3]?.value.toString(), equals('Loanee_Address'));
      expect(headerRow[4]?.value.toString(), equals('Mobile_No'));
      expect(headerRow[5]?.value.toString(), equals('Collection_Type'));
      expect(headerRow[6]?.value.toString(), equals('Route'));
      expect(headerRow[7]?.value.toString(), equals('Status'));

      // Verify Dummy Data row (Row 1)
      final dataRow = sheet.rows[1];
      expect(dataRow[0]?.value.toString(), equals('CUST-2001'));
      expect(dataRow[1]?.value.toString(), equals('ACC-88239201'));
      expect(dataRow[2]?.value.toString(), equals('Ibomcha Sharma'));
      expect(dataRow[3]?.value.toString(), equals('Imphal West Market'));
      expect(dataRow[4]?.value.toString(), equals('9862123456'));
      expect(dataRow[5]?.value.toString(), equals('Daily'));
      expect(dataRow[6]?.value.toString(), equals('Office'));
      expect(dataRow[7]?.value.toString(), equals('Active'));
    });

    test('generateTemplateCsvString generates standard CSV format for RoCollectionEntry with 1 dummy record', () {
      final csvString = BulkCollectionImportService.generateTemplateCsvString();
      expect(csvString, isNotEmpty);
      expect(csvString, contains('Customer_ID,Account_Number,Loanee_Name,Loanee_Address,Mobile_No,Collection_Type,Route,Status'));
      expect(csvString, contains('CUST-1001'));
      expect(csvString, contains('ACC-88239101'));
      expect(csvString, contains('Thoiba Singh'));
      expect(csvString, contains('Daily'));
      expect(csvString, contains('Office'));
    });

    test('parseRows accepts existing loanee in loanee_accounts and creates valid entryModel', () {
      final loanee = LoaneeAccount(
        customerid: '26LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'R. Sharma',
        address: 'Angom Leikai',
        businesstype: 'Retail Shop',
        postoffice: 'Imphal',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795005',
        mobileno: '9862112233',
        aadharno: '123456789012',
        loanamount: 11500.0,
      );

      final rawRows = [
        ['Customer_ID', 'Account_Number', 'Loanee_Name', 'Loanee_Address', 'Mobile_No', 'Collection_Type', 'Route', 'Status'],
        ['26LA000001', 'MF2026A000001', 'Ramesh Kumar', 'Angom Leikai', '9862112233', 'Daily', 'Office', 'Active'],
      ];

      final results = BulkCollectionImportService.parseRows(
        rawRows: rawRows,
        existingLoanees: [loanee],
        existingEntries: [],
        availableRoutes: ['Office'],
      );

      expect(results.length, equals(1));
      final r = results.first;
      expect(r.isValid, isTrue);
      expect(r.errorMessage, isNull);
      expect(r.entryModel, isNotNull);
      expect(r.entryModel!.customerId, equals('26LA000001'));
      expect(r.entryModel!.accountNumber, equals('MF2026A000001'));
      expect(r.entryModel!.loaneeName, equals('Ramesh Kumar'));
    });

    test('parseRows skips non-existing loanee and provides informative error message', () {
      final rawRows = [
        ['Customer_ID', 'Account_Number', 'Loanee_Name', 'Loanee_Address', 'Mobile_No', 'Collection_Type', 'Route', 'Status'],
        ['CUST-UNKNOWN', 'ACC-UNKNOWN', 'Unknown Person', 'Market', '9876543210', 'Daily', 'Office', 'Active'],
      ];

      final results = BulkCollectionImportService.parseRows(
        rawRows: rawRows,
        existingLoanees: [], // Empty loanees database
        existingEntries: [],
      );

      expect(results.length, equals(1));
      final r = results.first;
      expect(r.isValid, isFalse);
      expect(r.entryModel, isNull);
      expect(r.errorMessage, contains('Loanee does not exist in loanee_accounts database'));
      expect(r.errorMessage, contains('Skipped'));
    });

    test('parseRows flags mismatched Customer ID and Account Number belonging to different loanees', () {
      final loanee1 = LoaneeAccount(
        customerid: '26LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Loanee One',
        guardianname: 'G1',
        address: 'Addr 1',
        businesstype: 'Shop',
        postoffice: 'Imphal',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795005',
        mobileno: '9862111111',
        aadharno: '111111111111',
      );
      final loanee2 = LoaneeAccount(
        customerid: '26LA000002',
        accountnumber: 'MF2026A000002',
        loaneename: 'Loanee Two',
        guardianname: 'G2',
        address: 'Addr 2',
        businesstype: 'Shop',
        postoffice: 'Imphal',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795005',
        mobileno: '9862222222',
        aadharno: '222222222222',
      );

      // Mix Customer ID of loanee 1 with Account Number of loanee 2
      final rawRows = [
        ['Customer_ID', 'Account_Number', 'Loanee_Name', 'Loanee_Address', 'Mobile_No', 'Collection_Type', 'Route', 'Status'],
        ['26LA000001', 'MF2026A000002', 'Loanee', 'Addr', '9862111111', 'Daily', 'Office', 'Active'],
      ];

      final results = BulkCollectionImportService.parseRows(
        rawRows: rawRows,
        existingLoanees: [loanee1, loanee2],
        existingEntries: [],
      );

      expect(results.length, equals(1));
      final r = results.first;
      expect(r.isValid, isFalse);
      expect(r.errorMessage, contains('belong to different loanee accounts in database'));
    });

    test('parseRows flags duplicate active collection card for already registered loanee', () {
      final loanee = LoaneeAccount(
        customerid: '26LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'G',
        address: 'Addr',
        businesstype: 'Shop',
        postoffice: 'Imphal',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795005',
        mobileno: '9862112233',
        aadharno: '123456789012',
      );

      final existingCard = RoCollectionEntry(
        id: 'COL-1',
        customerId: '26LA000001',
        accountNumber: 'MF2026A000001',
        loaneeName: 'Ramesh Kumar',
        loaneeAddress: 'Addr',
        collectionType: 'Daily',
        route: 'Office',
        mobileNo: '9862112233',
      );

      final rawRows = [
        ['Customer_ID', 'Account_Number', 'Loanee_Name', 'Loanee_Address', 'Mobile_No', 'Collection_Type', 'Route', 'Status'],
        ['26LA000001', 'MF2026A000001', 'Ramesh Kumar', 'Addr', '9862112233', 'Daily', 'Office', 'Active'],
      ];

      final results = BulkCollectionImportService.parseRows(
        rawRows: rawRows,
        existingLoanees: [loanee],
        existingEntries: [existingCard],
      );

      expect(results.length, equals(1));
      final r = results.first;
      expect(r.isValid, isFalse);
      expect(r.isDuplicate, isTrue);
      expect(r.errorMessage, contains('already registered'));
      expect(r.errorMessage, contains('Duplicate entry blocked'));
    });

    test('parseRows detects and blocks duplicate Customer_ID within the uploaded Excel file (in-file duplicate)', () {
      final loanee = LoaneeAccount(
        customerid: '26LA000001',
        accountnumber: 'MF2026A000001',
        loaneename: 'Ramesh Kumar',
        guardianname: 'G',
        address: 'Addr',
        businesstype: 'Shop',
        postoffice: 'Imphal',
        policestation: 'Porompat',
        district: 'Imphal East',
        pincode: '795005',
        mobileno: '9862112233',
        aadharno: '123456789012',
      );

      final rawRows = [
        ['Customer_ID', 'Account_Number', 'Loanee_Name', 'Loanee_Address', 'Mobile_No', 'Collection_Type', 'Route', 'Status'],
        ['26LA000001', 'MF2026A000001', 'Ramesh Kumar', 'Addr', '9862112233', 'Daily', 'Office', 'Active'],
        ['26LA000001', 'MF2026A000001', 'Ramesh Kumar', 'Addr', '9862112233', 'Daily', 'Office', 'Active'],
      ];

      final results = BulkCollectionImportService.parseRows(
        rawRows: rawRows,
        existingLoanees: [loanee],
        existingEntries: [],
      );

      expect(results.length, equals(2));
      // First row should be valid
      expect(results[0].isValid, isTrue);
      expect(results[0].isDuplicate, isFalse);

      // Second row should be flagged as duplicate in Excel and blocked
      expect(results[1].isValid, isFalse);
      expect(results[1].isDuplicate, isTrue);
      expect(results[1].errorMessage, contains('Duplicate Customer ID "26LA000001" in Excel'));
      expect(results[1].errorMessage, contains('row #2'));
      expect(results[1].errorMessage, contains('Duplicate entry blocked'));
    });

    test('parseRows checks first from loanee_accounts and blocks entry if loanee does not exist', () {
      final rawRows = [
        ['Customer_ID', 'Account_Number', 'Loanee_Name', 'Loanee_Address', 'Mobile_No', 'Collection_Type', 'Route', 'Status'],
        ['NONEXISTENT-CUST', 'NONEXISTENT-ACC', 'Ghost User', 'Unknown', '9862000000', 'Daily', 'Office', 'Active'],
      ];

      final results = BulkCollectionImportService.parseRows(
        rawRows: rawRows,
        existingLoanees: [], // Empty loanees database
        existingEntries: [],
      );

      expect(results.length, equals(1));
      expect(results[0].isValid, isFalse);
      expect(results[0].isDuplicate, isFalse);
      expect(results[0].errorMessage, contains('Loanee does not exist in loanee_accounts database'));
    });

    test('processBulkEntryUpload blocks rows marked isDuplicate from being inserted', () async {
      final row1 = BulkCollectionEntryRowResult(
        rowIndex: 2,
        customerId: '26LA000001',
        accountNumber: 'MF2026A000001',
        loaneeName: 'Loanee One',
        loaneeAddress: 'Address',
        mobileNo: '9862112233',
        collectionType: 'Daily',
        route: 'Office',
        isValid: true,
        isDuplicate: true, // Marked as duplicate
        errorMessage: 'Duplicate entry blocked',
        entryModel: RoCollectionEntry(
          id: 'COL-DUP-1',
          customerId: '26LA000001',
          accountNumber: 'MF2026A000001',
          loaneeName: 'Loanee One',
          loaneeAddress: 'Address',
          collectionType: 'Daily',
          route: 'Office',
          mobileNo: '9862112233',
        ),
      );

      // Even if isValid was true, isDuplicate: true must block insertion
      final res = await BulkCollectionImportService.processBulkEntryUpload(
        validRows: [row1],
        collectionProvider: FakeCollectionSheetProviderForTest(),
      );

      expect(res['addedCount'], equals(0));
      expect(res['failedCount'], equals(1));
      expect(res['failedMessages'], isNotEmpty);
    });
  });
}

class FakeCollectionSheetProviderForTest extends Fake implements CollectionSheetProvider {
  @override
  final List<RoCollectionEntry> collectionEntries = [];

  @override
  Future<bool> addCollectionEntry(RoCollectionEntry entry) async {
    return true;
  }
}
