// lib/services/missing_records_excel_import_service.dart

import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/missing_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/settings_provider.dart';
import 'supabase_service.dart';

/// Single parsed row representing a historical missing day/week from Excel
class ParsedMissingExcelRecord {
  final int rowIndex; // 1-indexed row number
  final DateTime missedDate;
  final double dayPayment;
  final double missingPay;
  final double missingFine;
  final int missingWeek;
  final double missingBalance;
  final String status; // 'missing', 'partially_resolved'
  final String? remarks;

  ParsedMissingExcelRecord({
    required this.rowIndex,
    required this.missedDate,
    required this.dayPayment,
    required this.missingPay,
    required this.missingFine,
    required this.missingWeek,
    required this.missingBalance,
    required this.status,
    this.remarks,
  });

  String get formattedDate =>
      '${missedDate.day.toString().padLeft(2, '0')}/${missedDate.month.toString().padLeft(2, '0')}/${missedDate.year}';
}

/// Parsed result for one customer/sheet in the missing details Excel
class MissingExcelCustomerSheetResult {
  final String sheetName;
  final String rawCustomerId;
  final String rawAccountNumber;
  final String rawMobileNo;
  final double? expectedTotalPayment;
  final int? expectedTotalMissing;
  final double? expectedTotalMissingAmount;
  final double? expectedTotalMissingBalance;

  final RoCollectionEntry? matchedEntry;
  final DateTime? latestDateInSheet;
  final DateTime? latestPaidDateInSheet;

  final List<ParsedMissingExcelRecord> missingRows;
  final List<MissingPaymentRecord> generatedModelRecords;
  final List<DateTime> duplicateDates;
  final List<String> warnings;
  final List<String> errors;

  MissingExcelCustomerSheetResult({
    required this.sheetName,
    required this.rawCustomerId,
    required this.rawAccountNumber,
    required this.rawMobileNo,
    this.expectedTotalPayment,
    this.expectedTotalMissing,
    this.expectedTotalMissingAmount,
    this.expectedTotalMissingBalance,
    this.matchedEntry,
    this.latestDateInSheet,
    this.latestPaidDateInSheet,
    required this.missingRows,
    required this.generatedModelRecords,
    this.duplicateDates = const [],
    this.warnings = const [],
    this.errors = const [],
  });

  bool get isValid => matchedEntry != null && errors.isEmpty && (missingRows.isNotEmpty || duplicateDates.isNotEmpty);
  double get totalMissingAmount => missingRows.fold(0.0, (sum, r) => sum + r.missingPay);
  double get totalMissingBalance => missingRows.fold(0.0, (sum, r) => sum + r.missingBalance);
}

/// Overall result of parsing the entire Excel file
class MissingExcelParseResult {
  final String fileName;
  final List<MissingExcelCustomerSheetResult> sheets;
  final List<String> fileErrors;

  MissingExcelParseResult({
    required this.fileName,
    required this.sheets,
    this.fileErrors = const [],
  });

  bool get hasValidRecords => sheets.any((s) => s.isValid);
  int get totalRecordsToInsert =>
      sheets.fold(0, (sum, s) => sum + s.generatedModelRecords.length);
  double get grandTotalMissingAmount =>
      sheets.fold(0.0, (sum, s) => sum + s.totalMissingAmount);
  double get grandTotalMissingBalance =>
      sheets.fold(0.0, (sum, s) => sum + s.totalMissingBalance);
}

/// Result after executing the import and triggering the automated missing date scan
class MissingImportExecutionResult {
  final int totalImportedRecords;
  final int automatedNewRecords;
  final List<String> importedCollectionIds;
  final List<String> messages;
  final bool success;

  MissingImportExecutionResult({
    required this.totalImportedRecords,
    required this.automatedNewRecords,
    required this.importedCollectionIds,
    required this.messages,
    required this.success,
  });
}

/// Service to parse, validate, and import historical missing logs from Excel
/// Strictly references 'assets/template/Missing Pament Details.xlsx'
class MissingRecordsExcelImportService {
  static final DateTime excelEpoch = DateTime(1899, 12, 30);

  /// Helper to pick an Excel file
  static Future<List<PlatformFile>> pickExcelFile() async {
    return await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
  }

  /// Top-level pick and parse method avoiding UI thread mouse tracker collisions
  static Future<MissingExcelParseResult?> pickAndParseMissingExcel({
    required BuildContext context,
    required CollectionSheetProvider collectionProvider,
    RoCollectionEntry? preselectedEntry,
    LoaneeProvider? loaneeProvider,
  }) async {
    try {
      final pickedFiles = await pickExcelFile();
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
            const SnackBar(
              content: Text('Selected Excel file is empty or could not be read.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      // Allow native window manager focus and pointer events to settle completely
      await Future.delayed(const Duration(milliseconds: 150));

      final result = await parseExcelBytes(
        bytes: bytes,
        fileName: file.name,
        existingEntries: collectionProvider.collectionEntries,
        preselectedEntry: preselectedEntry,
        loaneeProvider: loaneeProvider,
        collectionProvider: collectionProvider,
      );

      return result;
    } catch (e) {
      debugPrint('Error picking missing excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Helper to share/download sample template
  static Future<void> downloadSampleTemplate() async {
    try {
      final ByteData data = await rootBundle.load('assets/template/Missing Pament Details.xlsx');
      final Uint8List bytes = data.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/Missing_Payment_Details_Template.xlsx');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Mangang Finance - Missing Payment Details Template',
      );
    } catch (e) {
      debugPrint('Error sharing template: $e');
    }
  }

  /// Parses date from dynamic cell value (Excel serial number or date string)
  static DateTime? parseDateValue(dynamic rawValue) {
    if (rawValue == null) return null;

    if (rawValue is DateTime) {
      return DateTime(rawValue.year, rawValue.month, rawValue.day);
    }
    if (rawValue is xl.DateCellValue) {
      return DateTime(rawValue.year, rawValue.month, rawValue.day);
    }
    if (rawValue is xl.DateTimeCellValue) {
      return DateTime(rawValue.year, rawValue.month, rawValue.day);
    }
    if (rawValue is xl.Data) {
      return parseDateValue(rawValue.value);
    }

    if (rawValue is num) {
      final double serial = rawValue.toDouble();
      if (serial > 1000 && serial < 100000) {
        final days = serial.floor();
        return excelEpoch.add(Duration(days: days));
      }
    }

    if (rawValue is xl.IntCellValue) {
      final int serial = rawValue.value;
      if (serial > 1000 && serial < 100000) {
        return excelEpoch.add(Duration(days: serial));
      }
    }
    if (rawValue is xl.DoubleCellValue) {
      final double serial = rawValue.value;
      if (serial > 1000 && serial < 100000) {
        return excelEpoch.add(Duration(days: serial.floor()));
      }
    }

    String str;
    if (rawValue is xl.TextCellValue) {
      str = rawValue.value.toString().trim();
    } else {
      str = rawValue.toString().trim();
    }
    if (str.isEmpty) return null;

    // Check if numeric string representing Excel serial
    final numVal = double.tryParse(str);
    if (numVal != null && numVal > 1000 && numVal < 100000 && !str.contains('-') && !str.contains('/')) {
      final days = numVal.floor();
      return excelEpoch.add(Duration(days: days));
    }

    // Try ISO format
    try {
      final dt = DateTime.parse(str);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {}

    // Formats: DD/MM/YYYY or MM/DD/YYYY or YYYY/MM/DD
    final partsSlash = str.split('/');
    if (partsSlash.length == 3) {
      final p1 = int.tryParse(partsSlash[0]);
      final p2 = int.tryParse(partsSlash[1]);
      final p3 = int.tryParse(partsSlash[2]);
      if (p1 != null && p2 != null && p3 != null) {
        if (p3 > 1900) {
          if (p2 <= 12 && p1 <= 31) {
            return DateTime(p3, p2, p1);
          } else if (p1 <= 12 && p2 <= 31) {
            return DateTime(p3, p1, p2);
          }
        } else if (p1 > 1900) {
          return DateTime(p1, p2, p3);
        }
      }
    }

    // Formats: DD-MM-YYYY or YYYY-MM-DD
    final partsHyphen = str.split('-');
    if (partsHyphen.length == 3) {
      final p1 = int.tryParse(partsHyphen[0]);
      final p2 = int.tryParse(partsHyphen[1]);
      final p3 = int.tryParse(partsHyphen[2]);
      if (p1 != null && p2 != null && p3 != null) {
        if (p3 > 1900) {
          if (p2 <= 12 && p1 <= 31) {
            return DateTime(p3, p2, p1);
          }
        } else if (p1 > 1900) {
          return DateTime(p1, p2, p3);
        }
      }
    }

    return null;
  }

  /// Parses numeric amount safely
  static double? parseNumericAmount(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is num) return rawValue.toDouble();
    if (rawValue is xl.IntCellValue) return rawValue.value.toDouble();
    if (rawValue is xl.DoubleCellValue) return rawValue.value;
    if (rawValue is xl.Data) return parseNumericAmount(rawValue.value);

    String str;
    if (rawValue is xl.TextCellValue) {
      str = rawValue.value.toString();
    } else {
      str = rawValue.toString();
    }

    str = str
        .replaceAll('₹', '')
        .replaceAll('Rs', '')
        .replaceAll('INR', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(str);
  }

  /// Extracts text representation from a cell
  static String extractCellText(dynamic rawValue) {
    if (rawValue == null) return '';
    if (rawValue is xl.Data) return extractCellText(rawValue.value);
    if (rawValue is xl.TextCellValue) return rawValue.value.toString().trim();
    if (rawValue is xl.IntCellValue) return rawValue.value.toString().trim();
    if (rawValue is xl.DoubleCellValue) return rawValue.value.toString().trim();
    return rawValue.toString().trim();
  }

  /// Parses the entire Excel file bytes
  static Future<MissingExcelParseResult> parseExcelBytes({
    required Uint8List bytes,
    required String fileName,
    required List<RoCollectionEntry> existingEntries,
    RoCollectionEntry? preselectedEntry,
    LoaneeProvider? loaneeProvider,
    CollectionSheetProvider? collectionProvider,
  }) async {
    final List<MissingExcelCustomerSheetResult> parsedSheets = [];
    final List<String> fileErrors = [];

    xl.Excel excelDoc;
    try {
      excelDoc = xl.Excel.decodeBytes(bytes);
    } catch (e) {
      return MissingExcelParseResult(
        fileName: fileName,
        sheets: [],
        fileErrors: ['Failed to decode Excel file: $e'],
      );
    }

    for (final tableKey in excelDoc.tables.keys) {
      final sheet = excelDoc.tables[tableKey];
      if (sheet == null || sheet.maxRows == 0) continue;

      final sheetResult = _parseSingleSheet(
        sheet: sheet,
        sheetName: tableKey,
        existingEntries: existingEntries,
        preselectedEntry: preselectedEntry,
        loaneeProvider: loaneeProvider,
        collectionProvider: collectionProvider,
      );

      if (sheetResult != null) {
        parsedSheets.add(sheetResult);
      }
    }

    if (parsedSheets.isEmpty) {
      fileErrors.add('No valid missing payment sheet found in the uploaded Excel.');
    }

    return MissingExcelParseResult(
      fileName: fileName,
      sheets: parsedSheets,
      fileErrors: fileErrors,
    );
  }

  /// Parses a single sheet adhering to 'Missing Pament Details.xlsx' structure
  static MissingExcelCustomerSheetResult? _parseSingleSheet({
    required xl.Sheet sheet,
    required String sheetName,
    required List<RoCollectionEntry> existingEntries,
    RoCollectionEntry? preselectedEntry,
    LoaneeProvider? loaneeProvider,
    CollectionSheetProvider? collectionProvider,
  }) {
    final List<String> warnings = [];
    final List<String> errors = [];

    String rawCustomerId = '';
    String rawAccountNo = '';
    String rawMobileNo = '';

    double? totalPaymentInHeader;
    int? totalMissingInHeader;
    double? totalMissingAmountInHeader;
    double? totalMissingBalanceInHeader;

    int headerRowIndex = -1;
    int dateCol = -1;
    int dayPaymentCol = -1;
    int missingPayCol = -1;
    int missingFineCol = -1;
    int missingWeekCol = -1;
    int missingBalanceCol = -1;

    // 1. Scan metadata rows 0 to 6
    final int scanLimit = sheet.maxRows > 15 ? 15 : sheet.maxRows;
    for (int r = 0; r < scanLimit; r++) {
      final row = sheet.rows[r];
      for (int c = 0; c < row.length; c++) {
        final cellText = extractCellText(row[c]).toLowerCase();
        final nextCellText = (c + 1 < row.length) ? extractCellText(row[c + 1]) : '';

        // Customer ID
        if (cellText.contains('customer') || cellText.contains('coustomer')) {
          if (nextCellText.isNotEmpty && rawCustomerId.isEmpty) {
            rawCustomerId = nextCellText;
          } else if (cellText.contains(':')) {
            final parts = cellText.split(':');
            if (parts.length > 1 && rawCustomerId.isEmpty) rawCustomerId = parts[1].trim();
          }
        }

        // Account Number
        if (cellText.contains('account no') || cellText.contains('account number') || cellText == 'account') {
          if (nextCellText.isNotEmpty && rawAccountNo.isEmpty) {
            rawAccountNo = nextCellText;
          } else if (cellText.contains(':')) {
            final parts = cellText.split(':');
            if (parts.length > 1 && rawAccountNo.isEmpty) rawAccountNo = parts[1].trim();
          }
        }

        // Mobile Number
        if (cellText.contains('mobile') || cellText.contains('phone')) {
          if (nextCellText.isNotEmpty && rawMobileNo.isEmpty) {
            rawMobileNo = nextCellText;
          } else if (cellText.contains(':')) {
            final parts = cellText.split(':');
            if (parts.length > 1 && rawMobileNo.isEmpty) rawMobileNo = parts[1].trim();
          }
        }

        // Summary Card Headers (e.g. Row 4 & 5)
        if (cellText.contains('total pament') || cellText.contains('total payment')) {
          if (r + 1 < sheet.maxRows) {
            totalPaymentInHeader = parseNumericAmount(sheet.rows[r + 1][c]);
          }
        }
        if (cellText.contains('total missing') && !cellText.contains('amount') && !cellText.contains('balance')) {
          if (r + 1 < sheet.maxRows) {
            totalMissingInHeader = parseNumericAmount(sheet.rows[r + 1][c])?.toInt();
          }
        }
        if (cellText.contains('total missing amount')) {
          if (r + 1 < sheet.maxRows) {
            totalMissingAmountInHeader = parseNumericAmount(sheet.rows[r + 1][c]);
          }
        }
        if (cellText.contains('total missing balance')) {
          if (r + 1 < sheet.maxRows) {
            totalMissingBalanceInHeader = parseNumericAmount(sheet.rows[r + 1][c]);
          }
        }

        // Header Row Identification (e.g. Row 7 with Date, Day Payment, Missing Pay...)
        if (cellText == 'date' || cellText.startsWith('date')) {
          headerRowIndex = r;
        }
      }
    }

    if (headerRowIndex == -1) {
      // Could not find detail table header
      return null;
    }

    // 2. Identify column mappings in header row
    final headerRow = sheet.rows[headerRowIndex];
    for (int c = 0; c < headerRow.length; c++) {
      final hText = extractCellText(headerRow[c]).toLowerCase().trim();
      if (hText.isEmpty) continue;
      if (hText.contains('date') && !hText.contains('paid date') && !hText.contains('pay date')) {
        dateCol = c;
      } else if (hText.contains('day payment') || hText.contains('day pay') || (hText.contains('day') && hText.contains('payment'))) {
        dayPaymentCol = c;
      } else if (hText.contains('missing pay') || hText.contains('missing amount') || hText == 'pay') {
        missingPayCol = c;
      } else if (hText.contains('missing fine') || hText.contains('fine') || hText.contains('find')) {
        missingFineCol = c;
      } else if (hText.contains('missing week') || hText.contains('week')) {
        missingWeekCol = c;
      } else if (hText.contains('missing balance') || (hText.contains('missing') && hText.contains('balance'))) {
        missingBalanceCol = c;
      }
    }

    if (dateCol == -1) {
      errors.add('Header row in sheet "$sheetName" missing Date column.');
      return null;
    }

    // Default missing columns by position ONLY if NO specific data columns were identified at all
    // (legacy unlabelled format fallback where all columns were unlabeled)
    final bool hasExplicitColumns = dayPaymentCol != -1 ||
        missingPayCol != -1 ||
        missingFineCol != -1 ||
        missingWeekCol != -1 ||
        missingBalanceCol != -1;

    if (!hasExplicitColumns && headerRow.length >= 6) {
      if (dayPaymentCol == -1 && dateCol + 1 < headerRow.length) dayPaymentCol = dateCol + 1;
      if (missingPayCol == -1 && dateCol + 2 < headerRow.length) missingPayCol = dateCol + 2;
      if (missingFineCol == -1 && dateCol + 3 < headerRow.length) missingFineCol = dateCol + 3;
      if (missingWeekCol == -1 && dateCol + 4 < headerRow.length) missingWeekCol = dateCol + 4;
      if (missingBalanceCol == -1 && dateCol + 5 < headerRow.length) missingBalanceCol = dateCol + 5;
    }

    // 3. Resolve matching collection entry
    RoCollectionEntry? matchedEntry = preselectedEntry;
    if (matchedEntry == null) {
      final cleanAccount = rawAccountNo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      final cleanCust = rawCustomerId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      final cleanMobile = rawMobileNo.replaceAll(RegExp(r'[^0-9]'), '');

      for (final entry in existingEntries) {
        final entryAcc = entry.accountNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        final entryCust = entry.customerId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        final entryMob = entry.mobileNo.replaceAll(RegExp(r'[^0-9]'), '');

        if (cleanAccount.isNotEmpty && entryAcc == cleanAccount) {
          matchedEntry = entry;
          break;
        }
        if (cleanCust.isNotEmpty && entryCust == cleanCust) {
          matchedEntry = entry;
          break;
        }
        if (cleanMobile.isNotEmpty && cleanMobile.length >= 10 && entryMob.endsWith(cleanMobile)) {
          matchedEntry = entry;
          break;
        }
      }

      // Fallback: If template file has blank header cells and exactly one entry is provided:
      if (matchedEntry == null && cleanAccount.isEmpty && cleanCust.isEmpty && cleanMobile.isEmpty && existingEntries.length == 1) {
        matchedEntry = existingEntries.first;
      }
    }

    if (matchedEntry != null) {
      if (rawCustomerId.isEmpty) rawCustomerId = matchedEntry.customerId;
      if (rawAccountNo.isEmpty) rawAccountNo = matchedEntry.accountNumber;
      if (rawMobileNo.isEmpty) rawMobileNo = matchedEntry.mobileNo;
    } else {
      errors.add('Could not match Customer ID "$rawCustomerId" / Account "$rawAccountNo" with any active collection entry.');
    }

    // 4. Iterate detail rows
    final List<ParsedMissingExcelRecord> missingRows = [];
    final List<MissingPaymentRecord> generatedModels = [];
    DateTime? latestDateInSheet;
    DateTime? latestPaidDateInSheet;

    final Set<String> existingDateKeys = {};
    if (matchedEntry != null && collectionProvider != null) {
      final existingForCard = collectionProvider.getMissingRecordsForCollection(matchedEntry.id);
      for (final em in existingForCard) {
        existingDateKeys.add('${em.missedDate.year}-${em.missedDate.month}-${em.missedDate.day}');
      }
    }

    final Set<String> seenDatesInSheet = {};
    final List<DateTime> duplicateDates = [];

    for (int r = headerRowIndex + 1; r < sheet.maxRows; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty || dateCol >= row.length) continue;

      final dynamic rawDate = row[dateCol];
      final dateVal = parseDateValue(rawDate);
      if (dateVal == null) {
        // If date is empty or non-date text like "Pending....." without serial date, check if row has data
        continue;
      }

      if (latestDateInSheet == null || dateVal.isAfter(latestDateInSheet)) {
        latestDateInSheet = dateVal;
      }

      final dayPayment = (dayPaymentCol >= 0 && dayPaymentCol < row.length)
          ? (parseNumericAmount(row[dayPaymentCol]) ?? 0.0)
          : 0.0;
      double missingPay = (missingPayCol >= 0 && missingPayCol < row.length)
          ? (parseNumericAmount(row[missingPayCol]) ?? 0.0)
          : 0.0;
      final missingFine = (missingFineCol >= 0 && missingFineCol < row.length)
          ? (parseNumericAmount(row[missingFineCol]) ?? 0.0)
          : 0.0;
      final missingBalance = (missingBalanceCol >= 0 && missingBalanceCol < row.length)
          ? (parseNumericAmount(row[missingBalanceCol]) ?? 0.0)
          : 0.0;

      if (dayPayment > 0) {
        if (latestPaidDateInSheet == null || dateVal.isAfter(latestPaidDateInSheet)) {
          latestPaidDateInSheet = dateVal;
        }
      }

      // Check if this row is a missing payment record
      // Condition: missingPay > 0 or missingFine > 0 or missingBalance > 0
      final bool isMissingRow = missingPay > 0 || missingFine > 0 || missingBalance > 0;
      if (!isMissingRow) {
        continue;
      }

      // Check duplicate date: same date cannot be inserted
      final dateKey = '${dateVal.year}-${dateVal.month}-${dateVal.day}';
      if (existingDateKeys.contains(dateKey) || seenDatesInSheet.contains(dateKey)) {
        duplicateDates.add(dateVal);
        continue;
      }
      seenDatesInSheet.add(dateKey);

      // If missingPay was removed from template, populate from loan payable amount or summary
      if (missingPay <= 0.0) {
        final entryPayable = matchedEntry?.payableAmount;
        if (entryPayable != null && entryPayable > 0) {
          missingPay = entryPayable;
        } else if (totalMissingAmountInHeader != null &&
            totalMissingInHeader != null &&
            totalMissingInHeader > 0) {
          missingPay = double.parse(
            (totalMissingAmountInHeader / totalMissingInHeader).toStringAsFixed(2),
          );
        }
      }

      // As per user rule: for Excel upload, keep as 1-week gap (always 1 week)
      const int calcWeeks = 1;

      final double calcBal = missingBalance > 0
          ? missingBalance
          : double.parse((missingFine * calcWeeks).toStringAsFixed(2));

      final String status = dayPayment > 0 ? 'partially_resolved' : 'missing';

      final String rowRemarks = missingPay > 0
          ? 'Imported from Excel: Missing Pay ₹${missingPay.toStringAsFixed(2)}, Fine ₹${missingFine.toStringAsFixed(2)}'
          : 'Imported from Excel: Fine ₹${missingFine.toStringAsFixed(2)}';

      final parsedRow = ParsedMissingExcelRecord(
        rowIndex: r + 1,
        missedDate: dateVal,
        dayPayment: dayPayment,
        missingPay: missingPay,
        missingFine: missingFine,
        missingWeek: calcWeeks,
        missingBalance: calcBal,
        status: status,
        remarks: 'Imported from Excel ($sheetName Row ${r + 1})',
      );
      missingRows.add(parsedRow);

      if (matchedEntry != null) {
        final dateStr = '${dateVal.year}${dateVal.month.toString().padLeft(2, '0')}${dateVal.day.toString().padLeft(2, '0')}';
        final recordId = 'MISS-${matchedEntry.id}-$dateStr';

        final model = MissingPaymentRecord(
          id: recordId,
          accountId: matchedEntry.accountNumber,
          collectionId: matchedEntry.id,
          loaneeId: matchedEntry.customerId,
          customerId: matchedEntry.customerId,
          accountNo: matchedEntry.accountNumber,
          loaneeName: matchedEntry.loaneeName,
          mobileNo: matchedEntry.mobileNo,
          route: matchedEntry.route,
          collectionType: matchedEntry.collectionType,
          missedDate: DateTime(dateVal.year, dateVal.month, dateVal.day, 12, 0, 0),
          dayPayment: dayPayment,
          missingPay: missingPay,
          missingFine: missingFine,
          missingWeek: calcWeeks,
          missingBalance: calcBal,
          status: status,
          source: 'excel_import',
          remarks: rowRemarks,
          createdAt: DateTime(dateVal.year, dateVal.month, dateVal.day, 12, 0, 0),
          updatedAt: DateTime.now(),
        );
        generatedModels.add(model);
      }
    }

    if (missingRows.isEmpty) {
      if (duplicateDates.isNotEmpty) {
        warnings.add('All ${duplicateDates.length} missing row(s) in sheet "$sheetName" have dates that were already inserted.');
      } else {
        warnings.add('No missing payment rows found in sheet "$sheetName".');
      }
    }

    if (duplicateDates.isNotEmpty) {
      final dupStr = duplicateDates.map((d) => SettingsProvider.formatDate(d)).join(', ');
      warnings.add('Skipped ${duplicateDates.length} duplicate date(s): $dupStr');
    }

    return MissingExcelCustomerSheetResult(
      sheetName: sheetName,
      rawCustomerId: rawCustomerId,
      rawAccountNumber: rawAccountNo,
      rawMobileNo: rawMobileNo,
      expectedTotalPayment: totalPaymentInHeader,
      expectedTotalMissing: totalMissingInHeader,
      expectedTotalMissingAmount: totalMissingAmountInHeader,
      expectedTotalMissingBalance: totalMissingBalanceInHeader,
      matchedEntry: matchedEntry,
      latestDateInSheet: latestDateInSheet,
      latestPaidDateInSheet: latestPaidDateInSheet,
      missingRows: missingRows,
      generatedModelRecords: generatedModels,
      duplicateDates: duplicateDates,
      warnings: warnings,
      errors: errors,
    );
  }

  /// Executes the import into Supabase and CollectionSheetProvider,
  /// unlocks missing automation for the matched entries, and immediately runs
  /// automation to detect missing dates forward!
  static Future<MissingImportExecutionResult> executeTransactionalImport({
    required MissingExcelParseResult parseResult,
    required CollectionSheetProvider collectionProvider,
    required SettingsProvider settingsProvider,
    LoaneeProvider? loaneeProvider,
  }) async {
    final List<String> messages = [];
    final List<String> importedCollectionIds = [];
    int totalImportedRecords = 0;

    for (final sheet in parseResult.sheets) {
      if (!sheet.isValid || sheet.matchedEntry == null) continue;

      final entry = sheet.matchedEntry!;
      final recordsToSave = sheet.generatedModelRecords;

      // 1. Batch upsert imported records to Supabase missing_payment_records table
      if (SupabaseService.instance.isInitialized && recordsToSave.isNotEmpty) {
        await SupabaseService.instance.saveMissingPaymentRecordsBatch(recordsToSave);
      }

      // 2. Batch update in-memory _missingRecords in CollectionSheetProvider
      if (recordsToSave.isNotEmpty) {
        collectionProvider.addMissingPaymentRecordsBatch(recordsToSave, notify: false);
        totalImportedRecords += recordsToSave.length;
        importedCollectionIds.add(entry.id);
      }

      // 3. Authorize automation and set Excel audit boundary date
      final auditDate = sheet.latestDateInSheet ?? sheet.latestPaidDateInSheet;
      await collectionProvider.authorizeMissingAutomationForEntry(
        entry.id,
        auditEndDate: auditDate,
        notify: false,
      );

      if (recordsToSave.isNotEmpty) {
        messages.add(
          '${entry.loaneeName} (${entry.accountNumber}): Inserted ${recordsToSave.length} historical missing records.',
        );
      }

      if (sheet.duplicateDates.isNotEmpty) {
        final dupStr = sheet.duplicateDates.map((d) => SettingsProvider.formatDate(d)).join(', ');
        messages.add(
          '${entry.loaneeName} (${entry.accountNumber}): Skipped ${sheet.duplicateDates.length} duplicate date(s) already recorded: $dupStr.',
        );
      }
    }

    // Single unified notification after all sheets are inserted
    if (totalImportedRecords > 0) {
      collectionProvider.notifyChanges();
    }

    return MissingImportExecutionResult(
      totalImportedRecords: totalImportedRecords,
      automatedNewRecords: 0,
      importedCollectionIds: importedCollectionIds,
      messages: messages,
      success: totalImportedRecords > 0,
    );
  }
}
