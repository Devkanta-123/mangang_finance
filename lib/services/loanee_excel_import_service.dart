// lib/services/loanee_excel_import_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/loanee_model.dart';
import '../providers/loanee_provider.dart';
import '../services/customer_id_service.dart';
import '../services/supabase_service.dart';

/// Single parsed row record representing one Loanee from the Excel file
class LoaneeImportRowRecord {
  final int rowIndex; // 1-indexed row number from Excel
  final String rawCustomerId;
  final String rawAccountNumber;
  final String rawLoaneeName;
  final String rawGuardianName;
  final String rawAddress;
  final String rawBusinessType;
  final String rawPostOffice;
  final String rawPoliceStation;
  final String rawDistrict;
  final String rawPinCode;
  final String rawMobileNo;
  final String rawAadhaarNo;
  final String rawCreatedAt;
  final String rawStatus;
  final String rawLoanAmount;
  final String rawPaidAmount;
  final String rawDueAmount;
  final String rawSanctionDate;
  final String rawMaturityDate;

  final LoaneeAccount? loaneeModel;
  final bool isValid;
  final bool isDuplicate;
  final String? errorMessage;
  final List<String> warnings;

  LoaneeImportRowRecord({
    required this.rowIndex,
    required this.rawCustomerId,
    required this.rawAccountNumber,
    required this.rawLoaneeName,
    this.rawGuardianName = '',
    this.rawAddress = '',
    this.rawBusinessType = '',
    this.rawPostOffice = '',
    this.rawPoliceStation = '',
    this.rawDistrict = '',
    this.rawPinCode = '',
    this.rawMobileNo = '',
    this.rawAadhaarNo = '',
    this.rawCreatedAt = '',
    this.rawStatus = '',
    this.rawLoanAmount = '',
    this.rawPaidAmount = '',
    this.rawDueAmount = '',
    this.rawSanctionDate = '',
    this.rawMaturityDate = '',
    this.loaneeModel,
    required this.isValid,
    this.isDuplicate = false,
    this.errorMessage,
    this.warnings = const [],
  });
}

/// Full aggregate preview result before committing to DB
class LoaneeImportPreviewResult {
  final int totalRows;
  final int validRowsCount;
  final int invalidRowsCount;
  final int duplicateRowsCount;
  final double totalLoanAmount;
  final double totalPaidAmount;
  final double totalDueAmount;
  final List<LoaneeImportRowRecord> rowRecords;
  final List<String> fileValidationErrors;

  LoaneeImportPreviewResult({
    required this.totalRows,
    required this.validRowsCount,
    required this.invalidRowsCount,
    required this.duplicateRowsCount,
    required this.totalLoanAmount,
    required this.totalPaidAmount,
    required this.totalDueAmount,
    required this.rowRecords,
    this.fileValidationErrors = const [],
  });

  bool get hasFileErrors => fileValidationErrors.isNotEmpty;
  bool get canImport => validRowsCount > 0 && !hasFileErrors;

  /// Summary string formatted as: Total: X | Imported: Y | Failed: Z
  String get summaryString =>
      'Total: $totalRows | Valid: $validRowsCount | Failed: $invalidRowsCount';
}

/// Outcome of executing the database import
class LoaneeImportExecutionResult {
  final bool success;
  final int total;
  final int imported;
  final int failed;
  final String? errorMessage;
  final List<String> failureDetails;

  LoaneeImportExecutionResult({
    required this.success,
    required this.total,
    required this.imported,
    required this.failed,
    this.errorMessage,
    this.failureDetails = const [],
  });

  /// Standard format: Total: 100 | Imported: 95 | Failed: 5
  String get summaryText =>
      'Total: $total | Imported: $imported | Failed: $failed';
}

class LoaneeExcelImportService {
  static const String templateAssetPath = 'assets/template/loanee_basic.xlsx';
  static const String templateSheetName = 'Loanee Basic Details';

  /// Standard Headers matching assets/template/loanee_basic.xlsx
  static const List<String> headers = [
    'Customer ID',
    'Account Number',
    'Loanee Name',
    'Guardian Name',
    'Address',
    'Business Type',
    'Post Office',
    'Police Station',
    'District',
    'PIN Code',
    'Mobile No',
    'Aadhaar No',
    'Created At',
    'Status',
    'Loan Amount',
    'Paid Amount',
    'Due Amount',
    'Loan Sanction Date',
    'Loan Maturity Date',
  ];

  /// Excel epoch date: December 30, 1899 (for Windows Excel 1900 date system)
  static final DateTime excelEpoch = DateTime(1899, 12, 30);

  /// Parse an Excel serial date number (e.g. 46204.0 -> 2026-07-01) or date string
  static DateTime? parseDateValue(dynamic rawValue) {
    if (rawValue == null) return null;

    // 1. Direct DateTime instance
    if (rawValue is DateTime) {
      return DateTime(rawValue.year, rawValue.month, rawValue.day);
    }

    // 2. Excel package DateCellValue or DateTimeCellValue
    if (rawValue is DateCellValue) {
      return DateTime(rawValue.year, rawValue.month, rawValue.day);
    }
    if (rawValue is DateTimeCellValue) {
      return DateTime(rawValue.year, rawValue.month, rawValue.day);
    }

    // 3. Numeric Excel Serial Date (e.g. 46204 or 46204.0)
    if (rawValue is num) {
      final double serial = rawValue.toDouble();
      if (serial > 1000 && serial < 100000) {
        final days = serial.floor();
        return excelEpoch.add(Duration(days: days));
      }
    }

    final str = rawValue.toString().trim();
    if (str.isEmpty) return null;

    // 4. Numeric string representing Excel serial date (e.g. "46204" or "46204.0")
    final numVal = double.tryParse(str);
    if (numVal != null &&
        numVal > 1000 &&
        numVal < 100000 &&
        !str.contains('-') &&
        !str.contains('/')) {
      final days = numVal.floor();
      return excelEpoch.add(Duration(days: days));
    }

    // 5. Standard formats: DD/MM/YYYY, DD-MM-YYYY, YYYY/MM/DD, MM/DD/YYYY
    final partsSlash = str.split('/');
    if (partsSlash.length == 3) {
      final p1 = int.tryParse(partsSlash[0]);
      final p2 = int.tryParse(partsSlash[1]);
      final p3 = int.tryParse(partsSlash[2]);
      if (p1 != null && p2 != null && p3 != null) {
        if (p3 > 1900) {
          // DD/MM/YYYY or MM/DD/YYYY
          if (p2 <= 12 && p1 <= 31) {
            return DateTime(p3, p2, p1);
          } else if (p1 <= 12 && p2 <= 31) {
            return DateTime(p3, p1, p2);
          }
        } else if (p1 > 1900) {
          // YYYY/MM/DD
          return DateTime(p1, p2, p3);
        }
      }
    }

    final partsHyphen = str.split('-');
    if (partsHyphen.length == 3) {
      final p1 = int.tryParse(partsHyphen[0]);
      final p2 = int.tryParse(partsHyphen[1]);
      final p3 = int.tryParse(partsHyphen[2]);
      if (p1 != null && p2 != null && p3 != null) {
        if (p3 > 1900) {
          // DD-MM-YYYY
          if (p2 <= 12 && p1 <= 31) {
            return DateTime(p3, p2, p1);
          }
        } else if (p1 > 1900) {
          // YYYY-MM-DD
          return DateTime(p1, p2, p3);
        }
      }
    }

    // 6. ISO Format (e.g. "2026-08-24", "2026-08-24T00:00:00")
    try {
      final dt = DateTime.parse(str);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {}

    return null;
  }

  /// Parse numeric amount safely from dynamic cell value (e.g. 57500, 57500.0, "₹ 57,500", "57500.00")
  static double? parseNumericAmount(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is num) return rawValue.toDouble();

    if (rawValue is IntCellValue) return rawValue.value.toDouble();
    if (rawValue is DoubleCellValue) return rawValue.value;
    if (rawValue is TextCellValue) {
      final clean = rawValue.value.text
              ?.replaceAll('₹', '')
              .replaceAll(',', '')
              .trim() ??
          rawValue.value
              .toString()
              .replaceAll('₹', '')
              .replaceAll(',', '')
              .trim();
      return double.tryParse(clean);
    }

    final str =
        rawValue.toString().replaceAll('₹', '').replaceAll(',', '').trim();
    if (str.isEmpty) return null;
    return double.tryParse(str);
  }

  /// Extract cell string content cleanly
  static String getCellString(dynamic cell) {
    if (cell == null) return '';
    if (cell is TextCellValue) {
      return cell.value.text?.trim() ?? cell.value.toString().trim();
    }
    if (cell is IntCellValue) return cell.value.toString().trim();
    if (cell is DoubleCellValue) return cell.value.toString().trim();
    if (cell is DateCellValue) return '${cell.day}/${cell.month}/${cell.year}';
    if (cell is DateTimeCellValue) {
      return '${cell.day}/${cell.month}/${cell.year}';
    }
    if (cell is Data) {
      final val = cell.value;
      if (val == null) return '';
      if (val is TextCellValue) {
        return val.value.text?.trim() ?? val.value.toString().trim();
      }
      if (val is IntCellValue) return val.value.toString().trim();
      if (val is DoubleCellValue) return val.value.toString().trim();
      if (val is DateCellValue) return '${val.day}/${val.month}/${val.year}';
      if (val is DateTimeCellValue) {
        return '${val.day}/${val.month}/${val.year}';
      }
      return val.toString().trim();
    }
    return cell.toString().trim();
  }

  /// Generate fallback template Excel bytes matching assets/template/loanee_basic.xlsx
  static List<int> generateTemplateExcelBytes() {
    final excelDoc = Excel.createExcel();
    final defaultSheet = excelDoc.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != templateSheetName) {
      excelDoc.rename(defaultSheet, templateSheetName);
    }

    final Sheet sheet = excelDoc[templateSheetName];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E1E1E'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // 1. Add Header row
    for (int col = 0; col < headers.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // 2. Add sample record matching template
    final sampleValues = [
      'CUST001',
      'LN000001',
      'Ramesh Kumar',
      'S/O Mahesh Kumar',
      'Main Road, Guwahati',
      'Small Business',
      'Dispur',
      'Dispur',
      'Kamrup Metro',
      '781006',
      '9876543210',
      'XXXX XXXX 1234',
      '24/08/2026',
      'Active',
      '57500',
      '0',
      '57500',
      '24/08/2026',
      '24/01/2027',
    ];

    for (int col = 0; col < sampleValues.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1));
      cell.value = TextCellValue(sampleValues[col]);
    }

    return excelDoc.save() ?? [];
  }

  /// Download or share the existing `assets/template/loanee_basic.xlsx`
  static Future<bool> downloadTemplate(BuildContext context) async {
    try {
      List<int> bytes = [];

      try {
        final byteData = await rootBundle.load(templateAssetPath);
        bytes = byteData.buffer.asUint8List();
      } catch (assetErr) {
        debugPrint(
            'ℹ️ Asset load note: $assetErr, generating exact template bytes dynamically');
        bytes = generateTemplateExcelBytes();
      }

      if (bytes.isEmpty) {
        bytes = generateTemplateExcelBytes();
      }

      if (kIsWeb) {
        final xfile = XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: 'loanee_basic.xlsx',
        );
        await Share.shareXFiles([xfile],
            text: 'Mangang Finance - Loanee Basic Excel Template');
        return true;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/loanee_basic.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Loanee Basic Excel Template',
        text:
            'Download and fill loanee details in this Excel template to bulk import into Mangang Finance.',
      );

      if (!context.mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Template ready! (${result.status.name}) File: loanee_basic.xlsx'),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error downloading Loanee template: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download template: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
  }

  /// Parse CSV string as fallback
  static List<List<String>> parseCsvString(String csvText) {
    final List<List<String>> rows = [];
    final lines = const LineSplitter().convert(csvText);

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final List<String> cells = [];
      final StringBuffer current = StringBuffer();
      bool inQuotes = false;

      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (char == ',' && !inQuotes) {
          cells.add(current.toString().trim());
          current.clear();
        } else {
          current.write(char);
        }
      }
      cells.add(current.toString().trim());
      rows.add(cells);
    }
    return rows;
  }

  /// Parse workbook bytes and generate full validation preview with duplicate checks
  static LoaneeImportPreviewResult parseWorkbookBytes({
    required List<int> bytes,
    required List<LoaneeAccount> existingLoanees,
  }) {
    if (bytes.isEmpty) {
      return LoaneeImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        totalLoanAmount: 0.0,
        totalPaidAmount: 0.0,
        totalDueAmount: 0.0,
        rowRecords: [],
        fileValidationErrors: ['The selected file is empty.'],
      );
    }

    Excel? excelDoc;
    try {
      excelDoc = Excel.decodeBytes(bytes);
    } catch (e) {
      // Check if it's CSV
      try {
        final csvStr = utf8.decode(bytes, allowMalformed: true);
        final parsed = parseCsvString(csvStr);
        if (parsed.isNotEmpty) {
          return _parseCsvRows(parsed, existingLoanees);
        }
      } catch (_) {}

      return LoaneeImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        totalLoanAmount: 0.0,
        totalPaidAmount: 0.0,
        totalDueAmount: 0.0,
        rowRecords: [],
        fileValidationErrors: ['Failed to decode Excel workbook: $e'],
      );
    }

    if (excelDoc.tables.isEmpty) {
      return LoaneeImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        totalLoanAmount: 0.0,
        totalPaidAmount: 0.0,
        totalDueAmount: 0.0,
        rowRecords: [],
        fileValidationErrors: ['Excel workbook contains no sheets.'],
      );
    }

    // Select target sheet
    Sheet? targetSheet;
    if (excelDoc.tables.containsKey(templateSheetName)) {
      targetSheet = excelDoc.tables[templateSheetName];
    } else {
      for (final sheet in excelDoc.tables.values) {
        if (sheet.maxRows > 0 &&
            sheet.rows.any((r) => r.any((c) => c?.value != null))) {
          targetSheet = sheet;
          break;
        }
      }
    }

    if (targetSheet == null || targetSheet.rows.isEmpty) {
      return LoaneeImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        totalLoanAmount: 0.0,
        totalPaidAmount: 0.0,
        totalDueAmount: 0.0,
        rowRecords: [],
        fileValidationErrors: ['The Excel worksheet is empty.'],
      );
    }

    final rawRows = targetSheet.rows;

    // Identify Header Row dynamically
    int headerRowIndex = -1;
    for (int r = 0; r < rawRows.length && r < 10; r++) {
      final rowText =
          rawRows[r].map((c) => getCellString(c).toLowerCase()).join(' ');
      if (rowText.contains('customer') ||
          rowText.contains('account') ||
          rowText.contains('loanee') ||
          rowText.contains('name') ||
          rowText.contains('loan amount')) {
        headerRowIndex = r;
        break;
      }
    }

    if (headerRowIndex == -1) {
      return LoaneeImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        totalLoanAmount: 0.0,
        totalPaidAmount: 0.0,
        totalDueAmount: 0.0,
        rowRecords: [],
        fileValidationErrors: [
          'Required header row not found in Excel sheet. Ensure columns match the template (Customer ID, Account Number, Loanee Name, Loan Amount, etc.).'
        ],
      );
    }

    final headerRow = rawRows[headerRowIndex];

    // Identify column indices
    int custCol = -1;
    int accCol = -1;
    int nameCol = -1;
    int guardianCol = -1;
    int addressCol = -1;
    int businessCol = -1;
    int poCol = -1;
    int psCol = -1;
    int distCol = -1;
    int pinCol = -1;
    int mobileCol = -1;
    int aadharCol = -1;
    int createdCol = -1;
    int statusCol = -1;
    int loanCol = -1;
    int paidCol = -1;
    int dueCol = -1;
    int sanctionCol = -1;
    int maturityCol = -1;

    for (int c = 0; c < headerRow.length; c++) {
      final headerStr =
          getCellString(headerRow[c]).toLowerCase().replaceAll('_', ' ').trim();

      if (custCol == -1 &&
          (headerStr.contains('customer') ||
              headerStr == 'cust id' ||
              headerStr == 'cust')) {
        custCol = c;
      } else if (accCol == -1 &&
          (headerStr.contains('account') ||
              headerStr == 'acc no' ||
              headerStr == 'acc')) {
        accCol = c;
      } else if (nameCol == -1 &&
          (headerStr.contains('loanee name') ||
              headerStr == 'name' ||
              headerStr == 'loanee')) {
        nameCol = c;
      } else if (guardianCol == -1 &&
          (headerStr.contains('guardian') ||
              headerStr.contains('w/o') ||
              headerStr.contains('s/o') ||
              headerStr.contains('d/o') ||
              headerStr.contains('father'))) {
        guardianCol = c;
      } else if (addressCol == -1 &&
          (headerStr.contains('address') || headerStr == 'addr')) {
        addressCol = c;
      } else if (businessCol == -1 &&
          (headerStr.contains('business') || headerStr.contains('occupation'))) {
        businessCol = c;
      } else if (poCol == -1 &&
          (headerStr.contains('post office') ||
              headerStr == 'p/o' ||
              headerStr == 'po')) {
        poCol = c;
      } else if (psCol == -1 &&
          (headerStr.contains('police station') ||
              headerStr == 'p/s' ||
              headerStr == 'ps')) {
        psCol = c;
      } else if (distCol == -1 &&
          (headerStr.contains('district') || headerStr == 'dist')) {
        distCol = c;
      } else if (pinCol == -1 &&
          (headerStr.contains('pin') || headerStr.contains('postal'))) {
        pinCol = c;
      } else if (mobileCol == -1 &&
          (headerStr.contains('mobile') ||
              headerStr.contains('phone') ||
              headerStr == 'contact')) {
        mobileCol = c;
      } else if (aadharCol == -1 &&
          (headerStr.contains('aadhar') || headerStr.contains('aadhaar'))) {
        aadharCol = c;
      } else if (createdCol == -1 &&
          (headerStr.contains('created') || headerStr == 'reg date')) {
        createdCol = c;
      } else if (statusCol == -1 && headerStr.contains('status')) {
        statusCol = c;
      } else if (loanCol == -1 &&
          (headerStr.contains('loan amount') ||
              headerStr == 'loan' ||
              headerStr == 'principal' ||
              headerStr == 'sanctioned amount')) {
        loanCol = c;
      } else if (paidCol == -1 &&
          (headerStr.contains('paid amount') || headerStr == 'paid')) {
        paidCol = c;
      } else if (dueCol == -1 &&
          (headerStr.contains('due amount') ||
              headerStr == 'due' ||
              headerStr == 'balance')) {
        dueCol = c;
      } else if (sanctionCol == -1 &&
          (headerStr.contains('sanction') || headerStr.contains('sanction date'))) {
        sanctionCol = c;
      } else if (maturityCol == -1 &&
          (headerStr.contains('maturity') || headerStr.contains('maturity date'))) {
        maturityCol = c;
      }
    }

    // Default Fallback Indices if position-based
    if (custCol == -1 && headerRow.isNotEmpty) custCol = 0;
    if (accCol == -1 && headerRow.length > 1) accCol = 1;
    if (nameCol == -1 && headerRow.length > 2) nameCol = 2;
    if (guardianCol == -1 && headerRow.length > 3) guardianCol = 3;
    if (addressCol == -1 && headerRow.length > 4) addressCol = 4;
    if (businessCol == -1 && headerRow.length > 5) businessCol = 5;
    if (poCol == -1 && headerRow.length > 6) poCol = 6;
    if (psCol == -1 && headerRow.length > 7) psCol = 7;
    if (distCol == -1 && headerRow.length > 8) distCol = 8;
    if (pinCol == -1 && headerRow.length > 9) pinCol = 9;
    if (mobileCol == -1 && headerRow.length > 10) mobileCol = 10;
    if (aadharCol == -1 && headerRow.length > 11) aadharCol = 11;
    if (createdCol == -1 && headerRow.length > 12) createdCol = 12;
    if (statusCol == -1 && headerRow.length > 13) statusCol = 13;
    if (loanCol == -1 && headerRow.length > 14) loanCol = 14;
    if (paidCol == -1 && headerRow.length > 15) paidCol = 15;
    if (dueCol == -1 && headerRow.length > 16) dueCol = 16;
    if (sanctionCol == -1 && headerRow.length > 17) sanctionCol = 17;
    if (maturityCol == -1 && headerRow.length > 18) maturityCol = 18;

    // Database duplicate trackers
    final dbCustIds = <String>{};
    final dbAccNos = <String>{};
    final dbMobiles = <String>{};
    for (final l in existingLoanees) {
      if (l.customerId.trim().isNotEmpty) {
        dbCustIds.add(l.customerId.trim().toLowerCase());
      }
      if (l.accountNumber.trim().isNotEmpty) {
        dbAccNos.add(l.accountNumber.trim().toLowerCase());
      }
      if (l.mobileNo.trim().isNotEmpty) {
        dbMobiles.add(l.mobileNo.trim());
      }
    }

    // In-file duplicate trackers (mapping identifier -> first row index where seen)
    final fileCustIds = <String, int>{};
    final fileAccNos = <String, int>{};
    final fileMobiles = <String, int>{};

    final List<LoaneeImportRowRecord> parsedRecords = [];
    int validCount = 0;
    int invalidCount = 0;
    int duplicateCount = 0;
    double totalLoan = 0.0;
    double totalPaid = 0.0;
    double totalDue = 0.0;

    for (int r = headerRowIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty ||
          row.every((c) =>
              c == null ||
              c.value == null ||
              c.value.toString().trim().isEmpty)) {
        continue; // Skip empty rows
      }

      String getCol(int colIdx) {
        if (colIdx >= 0 && colIdx < row.length) {
          return getCellString(row[colIdx]);
        }
        return '';
      }

      dynamic getRawCol(int colIdx) {
        if (colIdx >= 0 && colIdx < row.length) {
          return row[colIdx]?.value;
        }
        return null;
      }

      final rawCust = getCol(custCol);
      final rawAcc = getCol(accCol);
      final rawName = getCol(nameCol);
      final rawGuardian = getCol(guardianCol);
      final rawAddress = getCol(addressCol);
      final rawBusiness = getCol(businessCol);
      final rawPo = getCol(poCol);
      final rawPs = getCol(psCol);
      final rawDist = getCol(distCol);
      final rawPin = getCol(pinCol);
      final rawMobile = getCol(mobileCol);
      final rawAadhar = getCol(aadharCol);
      final rawCreated = getCol(createdCol);
      final rawStatus = getCol(statusCol);
      final rawLoan = getCol(loanCol);
      final rawPaid = getCol(paidCol);
      final rawDue = getCol(dueCol);
      final rawSanction = getCol(sanctionCol);
      final rawMaturity = getCol(maturityCol);

      final List<String> warnings = [];
      String? rowError;
      bool isRowValid = true;
      bool isRowDuplicate = false;

      // 1. Mandatory Field Validation
      if (rawName.isEmpty) {
        isRowValid = false;
        rowError = 'Loanee Name is required.';
      } else if (rawCust.isEmpty && rawAcc.isEmpty) {
        isRowValid = false;
        rowError = 'Customer ID or Account Number is required.';
      }

      // 2. Duplicate Validation (In-file & Database)
      final normCust = rawCust.toLowerCase().trim();
      final normAcc = rawAcc.toLowerCase().trim();
      final cleanMobile = rawMobile.replaceAll(RegExp(r'\D'), '').trim();

      if (isRowValid) {
        // Check in-file duplicates
        if (normCust.isNotEmpty && fileCustIds.containsKey(normCust)) {
          isRowValid = false;
          isRowDuplicate = true;
          rowError =
              'Duplicate Customer ID "$rawCust" in Excel (already in row #${fileCustIds[normCust]}).';
        } else if (normAcc.isNotEmpty && fileAccNos.containsKey(normAcc)) {
          isRowValid = false;
          isRowDuplicate = true;
          rowError =
              'Duplicate Account Number "$rawAcc" in Excel (already in row #${fileAccNos[normAcc]}).';
        } else if (cleanMobile.isNotEmpty &&
            cleanMobile.length == 10 &&
            fileMobiles.containsKey(cleanMobile)) {
          isRowValid = false;
          isRowDuplicate = true;
          rowError =
              'Duplicate Mobile Number "$rawMobile" in Excel (already in row #${fileMobiles[cleanMobile]}).';
        }

        // Check database duplicates
        if (isRowValid) {
          if (normCust.isNotEmpty && dbCustIds.contains(normCust)) {
            isRowValid = false;
            isRowDuplicate = true;
            rowError =
                'Loanee already exists in database with Customer ID "$rawCust".';
          } else if (normAcc.isNotEmpty && dbAccNos.contains(normAcc)) {
            isRowValid = false;
            isRowDuplicate = true;
            rowError =
                'Loanee already exists in database with Account Number "$rawAcc".';
          } else if (cleanMobile.isNotEmpty &&
              cleanMobile.length == 10 &&
              dbMobiles.contains(cleanMobile)) {
            isRowValid = false;
            isRowDuplicate = true;
            rowError =
                'Loanee already exists in database with Mobile Number "$rawMobile".';
          }
        }
      }

      // Track in file for subsequent rows
      if (normCust.isNotEmpty && !fileCustIds.containsKey(normCust)) {
        fileCustIds[normCust] = r + 1;
      }
      if (normAcc.isNotEmpty && !fileAccNos.containsKey(normAcc)) {
        fileAccNos[normAcc] = r + 1;
      }
      if (cleanMobile.isNotEmpty && !fileMobiles.containsKey(cleanMobile)) {
        fileMobiles[cleanMobile] = r + 1;
      }

      // 3. Numeric & Date parsing
      final parsedLoan = parseNumericAmount(getRawCol(loanCol)) ??
          double.tryParse(rawLoan.replaceAll(RegExp(r'[^\d.]'), '')) ??
          0.0;
      final parsedPaid = parseNumericAmount(getRawCol(paidCol)) ??
          double.tryParse(rawPaid.replaceAll(RegExp(r'[^\d.]'), '')) ??
          0.0;
      double parsedDue = parseNumericAmount(getRawCol(dueCol)) ??
          double.tryParse(rawDue.replaceAll(RegExp(r'[^\d.]'), '')) ??
          0.0;

      if (parsedDue == 0.0 && parsedLoan > 0 && parsedPaid == 0.0) {
        parsedDue = parsedLoan;
      } else if (parsedDue == 0.0 && parsedLoan > parsedPaid) {
        parsedDue = parsedLoan - parsedPaid;
      }

      final parsedCreated =
          parseDateValue(getRawCol(createdCol)) ?? DateTime.now();
      final parsedSanction = parseDateValue(getRawCol(sanctionCol)) ??
          parsedCreated;
      final parsedMaturity = parseDateValue(getRawCol(maturityCol)) ??
          LoaneeAccount.calculateMaturityDate(parsedSanction);

      final statusVal = rawStatus.isNotEmpty ? rawStatus : 'Active';
      final businessVal =
          rawBusiness.isNotEmpty ? rawBusiness : 'Retail Grocery';
      final distVal = rawDist.isNotEmpty ? rawDist : 'Imphal West';

      // 4. Construct LoaneeAccount model if valid (WITHOUT ANY WITNESS DATA)
      LoaneeAccount? model;
      if (isRowValid) {
        final resolvedCustId = rawCust.isNotEmpty
            ? rawCust
            : CustomerIdService.generateLoaneeCustomerId(
                existingLoanees: existingLoanees,
                reservedIds: fileCustIds.keys.toSet(),
              );
        final resolvedAccNo = rawAcc.isNotEmpty
            ? rawAcc
            : CustomerIdService.generateLoaneeAccountNumber(
                existingLoanees: existingLoanees,
                reservedAccNos: fileAccNos.keys.toSet(),
              );

        model = LoaneeAccount(
          customerid: resolvedCustId,
          accountnumber: resolvedAccNo,
          loaneename: rawName,
          guardianname: rawGuardian.isNotEmpty ? rawGuardian : 'N/A',
          address: rawAddress.isNotEmpty ? rawAddress : 'Main Road',
          businesstype: businessVal,
          postoffice: rawPo.isNotEmpty ? rawPo : 'N/A',
          policestation: rawPs.isNotEmpty ? rawPs : 'N/A',
          district: distVal,
          pincode: rawPin.isNotEmpty ? rawPin : '795001',
          mobileno: rawMobile,
          aadharno: rawAadhar,
          createdat: parsedCreated,
          status: statusVal,
          loanamount: parsedLoan,
          paidamount: parsedPaid,
          dueamount: parsedDue,
          loansanctiondate: parsedSanction,
          loanmaturitydate: parsedMaturity,
          // Requirement 7: Import ONLY basic loanee details. Do NOT import or require witness data.
          witnessname: '',
          witnessguardianname: '',
          witnessaddress: '',
          witnessbusinesstype: '',
          witnesspostoffice: '',
          witnesspolicestation: '',
          witnessdistrict: '',
          witnesspincode: '',
          witnessmobileno: '',
          witnessaadharno: '',
          witnessrelationship: '',
        );

        validCount++;
        totalLoan += parsedLoan;
        totalPaid += parsedPaid;
        totalDue += parsedDue;
      } else {
        invalidCount++;
        if (isRowDuplicate) {
          duplicateCount++;
        }
      }

      parsedRecords.add(
        LoaneeImportRowRecord(
          rowIndex: r + 1,
          rawCustomerId: rawCust,
          rawAccountNumber: rawAcc,
          rawLoaneeName: rawName,
          rawGuardianName: rawGuardian,
          rawAddress: rawAddress,
          rawBusinessType: rawBusiness,
          rawPostOffice: rawPo,
          rawPoliceStation: rawPs,
          rawDistrict: rawDist,
          rawPinCode: rawPin,
          rawMobileNo: rawMobile,
          rawAadhaarNo: rawAadhar,
          rawCreatedAt: rawCreated,
          rawStatus: rawStatus,
          rawLoanAmount: rawLoan,
          rawPaidAmount: rawPaid,
          rawDueAmount: rawDue,
          rawSanctionDate: rawSanction,
          rawMaturityDate: rawMaturity,
          loaneeModel: model,
          isValid: isRowValid,
          isDuplicate: isRowDuplicate,
          errorMessage: rowError,
          warnings: warnings,
        ),
      );
    }

    return LoaneeImportPreviewResult(
      totalRows: parsedRecords.length,
      validRowsCount: validCount,
      invalidRowsCount: invalidCount,
      duplicateRowsCount: duplicateCount,
      totalLoanAmount: totalLoan,
      totalPaidAmount: totalPaid,
      totalDueAmount: totalDue,
      rowRecords: parsedRecords,
      fileValidationErrors: [],
    );
  }

  /// Helper to parse CSV rows
  static LoaneeImportPreviewResult _parseCsvRows(
    List<List<String>> rows,
    List<LoaneeAccount> existingLoanees,
  ) {
    if (rows.isEmpty) {
      return LoaneeImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        totalLoanAmount: 0.0,
        totalPaidAmount: 0.0,
        totalDueAmount: 0.0,
        rowRecords: [],
        fileValidationErrors: ['CSV file is empty.'],
      );
    }

    // Convert string rows to pseudo Excel cells
    final excelDoc = Excel.createExcel();
    final sheet = excelDoc[templateSheetName];
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = TextCellValue(rows[r][c]);
      }
    }
    return parseWorkbookBytes(
      bytes: excelDoc.save() ?? [],
      existingLoanees: existingLoanees,
    );
  }

  /// Pick an Excel (.xlsx/.xls) or CSV file and parse rows into LoaneeImportPreviewResult
  static Future<LoaneeImportPreviewResult?> pickAndParseLoaneeExcel({
    required BuildContext context,
    required List<LoaneeAccount> existingLoanees,
  }) async {
    try {
      final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (pickedFiles.isEmpty) {
        return null;
      }

      final file = pickedFiles.first;
      Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty && file.path != null) {
        final localFile = File(file.path!);
        if (await localFile.exists()) {
          bytes = await localFile.readAsBytes();
        }
      }

      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Could not read file content. Please select a valid file.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return null;
      }

      return parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: existingLoanees,
      );
    } catch (e) {
      debugPrint('❌ Error picking/parsing Loanee Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to parse Excel file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return null;
    }
  }

  /// Execute batch import with notification suppression and transaction support
  static Future<LoaneeImportExecutionResult> executeImport({
    required List<LoaneeImportRowRecord> validRows,
    required LoaneeProvider loaneeProvider,
    SupabaseService? supabaseService,
  }) async {
    final supa = supabaseService ?? SupabaseService.instance;
    final totalRows = validRows.length;

    final loaneesToImport = validRows
        .where((r) => r.isValid && r.loaneeModel != null)
        .map((r) => r.loaneeModel!)
        .toList();

    if (loaneesToImport.isEmpty) {
      return LoaneeImportExecutionResult(
        success: false,
        total: totalRows,
        imported: 0,
        failed: totalRows,
        errorMessage: 'No valid loanee records to import.',
      );
    }

    try {
      // Requirement 11: During bulk import, suppress per-loanee notifications.
      final result = await supa.runWithNotificationSuppression(() async {
        return await loaneeProvider
            .addLoaneesBatchWithConnectionCheck(loaneesToImport);
      });

      final bool isSuccess = result['success'] == true;
      final int importedCount = isSuccess ? loaneesToImport.length : 0;
      final int failedCount = totalRows - importedCount;

      return LoaneeImportExecutionResult(
        success: isSuccess,
        total: totalRows,
        imported: importedCount,
        failed: failedCount,
        errorMessage: isSuccess ? null : (result['message'] as String?),
      );
    } catch (e) {
      debugPrint('❌ Error executing loanee import: $e');
      return LoaneeImportExecutionResult(
        success: false,
        total: totalRows,
        imported: 0,
        failed: totalRows,
        errorMessage: 'Import failed due to error: $e',
      );
    }
  }
}
