// test/bulk_collection_import_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
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
  });
}
