// lib/services/historical_payment_import_service.dart

import "dart:io";
import "package:excel/excel.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart" show rootBundle;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "../models/collection_payment_model.dart";
import "../models/loanee_model.dart";
import "../models/ro_collection_entry_model.dart";
import "../models/route_model.dart";
import "../providers/collection_sheet_provider.dart";
import "../providers/loanee_provider.dart";
import "../providers/settings_provider.dart";
import "../services/supabase_service.dart";

/// Single parsed historical payment item from a date column or date row
class HistoricalPaymentItem {
  final DateTime paymentDate;
  final double amount;
  final double interest; // Daily/Weekly Late Payment Fees (inserted to table column interest)
  final double latePaymentFee; // Daily/Weekly Late Payment Fees (alias)
  final double postMaturityInterest; // Post Maturity Fine Payment (inserted to table column post_maturity_interest)
  final String roName;
  final bool isDuplicate;
  final String? errorMessage;
  final CollectionPaymentModel? paymentModel;

  HistoricalPaymentItem({
    required this.paymentDate,
    required this.amount,
    this.interest = 0.0,
    double latePaymentFee = 0.0,
    this.postMaturityInterest = 0.0,
    required this.roName,
    this.isDuplicate = false,
    this.errorMessage,
    this.paymentModel,
  }) : latePaymentFee = latePaymentFee > 0 ? latePaymentFee : interest;

  String get formattedDate {
    return "${paymentDate.day.toString().padLeft(2, "0")}/${paymentDate.month.toString().padLeft(2, "0")}/${paymentDate.year}";
  }
}

/// Parsed row record representing one Loanee / Account from the Excel file
class HistoricalImportRowRecord {
  final int rowIndex; // 1-indexed row number from Excel
  final String rawCustomerId;
  final String rawAccountNumber;
  final String rawLoaneeName;
  final String rawRoute;
  final String rawCollectionType;
  final String rawCollectedBy;

  final LoaneeAccount? resolvedLoanee;
  final RoCollectionEntry? resolvedCollectionEntry;
  final bool newCollectionEntryNeeded;
  final RoCollectionEntry? newCollectionEntry;

  final List<HistoricalPaymentItem> payments;
  final bool isValid;
  final bool isDuplicate;
  final bool isUnmapped; // Loan Account Map could not be resolved
  final String? errorMessage;
  final List<String> warnings;

  HistoricalImportRowRecord({
    required this.rowIndex,
    required this.rawCustomerId,
    required this.rawAccountNumber,
    required this.rawLoaneeName,
    required this.rawRoute,
    required this.rawCollectionType,
    required this.rawCollectedBy,
    this.resolvedLoanee,
    this.resolvedCollectionEntry,
    this.newCollectionEntryNeeded = false,
    this.newCollectionEntry,
    required this.payments,
    required this.isValid,
    this.isDuplicate = false,
    this.isUnmapped = false,
    this.errorMessage,
    this.warnings = const [],
  });

  /// Count of valid, non-duplicate payments in this row
  int get validPaymentsCount => payments
      .where((p) =>
          !p.isDuplicate &&
          p.errorMessage == null &&
          (p.amount > 0 || p.interest > 0 || p.postMaturityInterest > 0))
      .length;

  /// Count of duplicate payments in this row
  int get duplicatePaymentsCount => payments.where((p) => p.isDuplicate).length;

  /// Sum of valid non-duplicate payment amounts in this row
  double get totalRowAmount => payments
      .where((p) => !p.isDuplicate && p.errorMessage == null && p.amount > 0)
      .fold(0.0, (sum, p) => sum + p.amount);

  /// Sum of valid non-duplicate daily/weekly late payment fees in this row (stored in interest column)
  double get totalRowLateFees => payments
      .where((p) => !p.isDuplicate && p.errorMessage == null && (p.latePaymentFee > 0 || p.interest > 0))
      .fold(0.0, (sum, p) => sum + (p.latePaymentFee > 0 ? p.latePaymentFee : p.interest));

  /// Sum of valid non-duplicate post maturity interest in this row
  double get totalRowPostMat => payments
      .where((p) => !p.isDuplicate && p.errorMessage == null && p.postMaturityInterest > 0)
      .fold(0.0, (sum, p) => sum + p.postMaturityInterest);

  /// Sum of all overdue / additional interest in this row
  double get totalRowInterest => totalRowLateFees + totalRowPostMat;
}

/// Full aggregate preview result before committing to DB
class HistoricalImportPreviewResult {
  final int totalRows;
  final int validRowsCount;
  final int invalidRowsCount;
  final int unmappedRowsCount;
  final int totalPaymentsParsed;
  final int validPaymentsCount;
  final int duplicatePaymentsCount;
  final double totalAmountToImport;
  final double totalLateFeesToImport;
  final double totalPostMatToImport;
  final double totalInterestToImport;
  final List<HistoricalImportRowRecord> rowRecords;
  final List<String> fileValidationErrors;

  HistoricalImportPreviewResult({
    required this.totalRows,
    required this.validRowsCount,
    required this.invalidRowsCount,
    required this.unmappedRowsCount,
    required this.totalPaymentsParsed,
    required this.validPaymentsCount,
    required this.duplicatePaymentsCount,
    required this.totalAmountToImport,
    this.totalLateFeesToImport = 0.0,
    this.totalPostMatToImport = 0.0,
    double totalInterestToImport = 0.0,
    required this.rowRecords,
    this.fileValidationErrors = const [],
  }) : totalInterestToImport = totalInterestToImport > 0
            ? totalInterestToImport
            : (totalLateFeesToImport + totalPostMatToImport);

  bool get hasFileErrors => fileValidationErrors.isNotEmpty;
  bool get canImport => validPaymentsCount > 0 && !hasFileErrors;
}

/// Outcome of executing the database import
class HistoricalImportExecutionResult {
  final bool success;
  final int collectionEntriesCreatedCount;
  final int paymentsInsertedCount;
  final double totalAmountImported;
  final double totalLateFeesImported;
  final double totalPostMatImported;
  final double totalInterestImported;
  final int duplicatePaymentsSkippedCount;
  final String? errorMessage;
  final List<String> failureDetails;

  HistoricalImportExecutionResult({
    required this.success,
    this.collectionEntriesCreatedCount = 0,
    this.paymentsInsertedCount = 0,
    this.totalAmountImported = 0.0,
    this.totalLateFeesImported = 0.0,
    this.totalPostMatImported = 0.0,
    double totalInterestImported = 0.0,
    this.duplicatePaymentsSkippedCount = 0,
    this.errorMessage,
    this.failureDetails = const [],
  }) : totalInterestImported = totalInterestImported > 0
            ? totalInterestImported
            : (totalLateFeesImported + totalPostMatImported);
}

class HistoricalPaymentImportService {
  /// Asset template path
  static const String templateAssetPath = "assets/template/old_payment_history.xlsx";

  /// Excel epoch date: December 30, 1899 (for Windows Excel 1900 date system accounting for leap year bug)
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
    if (numVal != null && numVal > 1000 && numVal < 100000 && !str.contains("-") && !str.contains("/")) {
      final days = numVal.floor();
      return excelEpoch.add(Duration(days: days));
    }

    // 5. ISO Format (e.g. "2026-07-01", "2026-07-01T00:00:00")
    try {
      final dt = DateTime.parse(str);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {}

    // 6. Standard formats: DD/MM/YYYY, DD-MM-YYYY, YYYY/MM/DD, MM/DD/YYYY, M/D/YYYY
    final partsSlash = str.split("/");
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

    final partsHyphen = str.split("-");
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

    return null;
  }

  /// Parse numeric amount safely from dynamic cell value (e.g. 100, 100.0, "₹ 100", "100.00")
  static double? parseNumericAmount(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is num) return rawValue.toDouble();

    if (rawValue is IntCellValue) return rawValue.value.toDouble();
    if (rawValue is DoubleCellValue) return rawValue.value;
    if (rawValue is TextCellValue) {
      final clean = rawValue.value.text?.replaceAll('₹', '').replaceAll(',', '').trim() ??
          rawValue.value.toString().replaceAll('₹', '').replaceAll(',', '').trim();
      return double.tryParse(clean);
    }

    final str = rawValue.toString().replaceAll('₹', '').replaceAll(',', '').trim();
    if (str.isEmpty) return null;
    return double.tryParse(str);
  }

  /// Extract cell string content cleanly
  static String getCellString(dynamic cell) {
    if (cell == null) return '';
    if (cell is TextCellValue) return cell.value.text?.trim() ?? cell.value.toString().trim();
    if (cell is IntCellValue) return cell.value.toString().trim();
    if (cell is DoubleCellValue) return cell.value.toString().trim();
    if (cell is DateCellValue) return '${cell.year}-${cell.month}-${cell.day}';
    if (cell is DateTimeCellValue) return '${cell.year}-${cell.month}-${cell.day}';
    if (cell is Data) {
      final val = cell.value;
      if (val == null) return '';
      if (val is TextCellValue) return val.value.text?.trim() ?? val.value.toString().trim();
      if (val is IntCellValue) return val.value.toString().trim();
      if (val is DoubleCellValue) return val.value.toString().trim();
      return val.toString().trim();
    }
    return cell.toString().trim();
  }

  /// Helper to normalize collection frequency/type strings
  static String normalizeCollectionType(String raw) {
    final clean = raw.toLowerCase().trim();
    if (clean.contains("dali") || clean.contains("daily") || clean == "day") return "Daily";
    if (clean.startsWith("mon")) return "Mon";
    if (clean.startsWith("tue")) return "Tue";
    if (clean.startsWith("wed")) return "Wed";
    if (clean.startsWith("thu")) return "Thur";
    if (clean.startsWith("fri")) return "Fri";
    if (clean.startsWith("sat")) return "Sat";
    if (clean.startsWith("sun")) return "Sun";
    if (clean.contains("week")) return "Weekly";
    return raw.isNotEmpty ? raw : "Daily";
  }

  /// Download or share the existing `assets/template/old_payment_history.xlsx`
  static Future<bool> downloadTemplate(BuildContext context) async {
    try {
      List<int> bytes = [];

      try {
        final byteData = await rootBundle.load(templateAssetPath);
        bytes = byteData.buffer.asUint8List();
      } catch (assetErr) {
        debugPrint(
            "ℹ️ Asset load note: $assetErr, generating exact template bytes dynamically");
        bytes = generateTemplateExcelBytes();
      }

      if (bytes.isEmpty) {
        bytes = generateTemplateExcelBytes();
      }

      if (kIsWeb) {
        final xfile = XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType:
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          name: "old_payment_history.xlsx",
        );
        await Share.shareXFiles([xfile],
            text: "Mangang Finance - Old Payment History Excel Template");
        return true;
      }

      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/old_payment_history.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: "Old Payment History Excel Template",
        text:
            "Download and fill historical payment details in this Excel template to bulk import into Mangang Finance.",
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
                    "Template ready! (${result.status.name}) File: old_payment_history.xlsx"),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (e) {
      debugPrint("❌ Error downloading template: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to download template: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
  }

  /// Generate fallback template Excel bytes matching the exact new vertical structure
  static List<int> generateTemplateExcelBytes() {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? "Sheet1";
    final sheet = excel[sheetName];

    // Metadata Block
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue("Coustomer ID");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue("26LA000001");

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue("Account No.");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value =
        TextCellValue("MF2026A000001");

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value =
        TextCellValue("Loanee Name");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value =
        TextCellValue("Ramesh Kumar");

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value =
        TextCellValue("Route");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value =
        TextCellValue("Angom");

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value =
        TextCellValue("Collection Types");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value =
        TextCellValue("Daily");

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5)).value =
        TextCellValue("Collected By");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 5)).value =
        TextCellValue("Dev");

    // Payments Table Header
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6)).value =
        TextCellValue("Date");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6)).value =
        TextCellValue("Payment Amount");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 6)).value =
        TextCellValue("Late Payment Interest");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 6)).value =
        TextCellValue("Post Maturity Interest");

    // Sample Payments
    final samplePayments = [
      [DateTime(2026, 3, 24), 29.0, 0.0, 0.0],
      [DateTime(2026, 3, 25), 120.0, 0.0, 0.0],
      [DateTime(2026, 3, 26), 0.0, 3.0, 0.0],
      [DateTime(2026, 6, 9), 60.0, 1.0, 0.0],
      [DateTime(2026, 8, 24), 120.0, 0.0, 577.0],
    ];

    for (int i = 0; i < samplePayments.length; i++) {
      final r = 7 + i;
      final dt = samplePayments[i][0] as DateTime;
      final amt = samplePayments[i][1] as double;
      final lateFee = samplePayments[i][2] as double;
      final postMat = samplePayments[i][3] as double;

      final dateCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r));
      dateCell.value =
          DateCellValue(year: dt.year, month: dt.month, day: dt.day);

      final amtCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r));
      amtCell.value = DoubleCellValue(amt);

      final lateCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r));
      lateCell.value = DoubleCellValue(lateFee);

      final postMatCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r));
      postMatCell.value = DoubleCellValue(postMat);
    }

    return excel.save() ?? [];
  }

  /// Parse historical payment Excel workbook bytes and generate full validation preview
  static HistoricalImportPreviewResult parseWorkbookBytes({
    required List<int> bytes,
    required List<LoaneeAccount> existingLoanees,
    required List<RoCollectionEntry> existingEntries,
    required List<CollectionPaymentModel> existingPayments,
    List<RouteModel> existingRoutes = const [],
    double defaultInterestRate = 15.0,
    double defaultBasePrincipal = 10000.0,
    double defaultBaseDaily = 100.0,
    double defaultBaseWeekly = 650.0,
  }) {
    final List<String> fileErrors = [];
    if (bytes.isEmpty) {
      return HistoricalImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 0,
        validPaymentsCount: 0,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 0.0,
        rowRecords: [],
        fileValidationErrors: ["The selected file is empty."],
      );
    }

    Excel? excelDoc;
    try {
      excelDoc = Excel.decodeBytes(bytes);
    } catch (e) {
      return HistoricalImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 0,
        validPaymentsCount: 0,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 0.0,
        rowRecords: [],
        fileValidationErrors: ["Failed to decode Excel workbook: $e"],
      );
    }

    if (excelDoc.tables.isEmpty) {
      return HistoricalImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 0,
        validPaymentsCount: 0,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 0.0,
        rowRecords: [],
        fileValidationErrors: ["Excel workbook contains no sheets."],
      );
    }

    // Fast Lookups for Loanee Accounts, Collection Entries, and Payments
    final loaneeByCustId = <String, LoaneeAccount>{};
    final loaneeByAccNo = <String, LoaneeAccount>{};
    final loaneeByName = <String, LoaneeAccount>{};
    for (final l in existingLoanees) {
      if (l.customerId.trim().isNotEmpty) {
        loaneeByCustId[l.customerId.trim().toLowerCase()] = l;
      }
      if (l.accountNumber.trim().isNotEmpty) {
        loaneeByAccNo[l.accountNumber.trim().toLowerCase()] = l;
      }
      if (l.loaneeName.trim().isNotEmpty) {
        loaneeByName[l.loaneeName.trim().toLowerCase()] = l;
      }
    }

    final entryByCustId = <String, RoCollectionEntry>{};
    final entryByAccNo = <String, RoCollectionEntry>{};
    for (final e in existingEntries) {
      if (e.customerId.trim().isNotEmpty) {
        entryByCustId[e.customerId.trim().toLowerCase()] = e;
      }
      if (e.accountNumber.trim().isNotEmpty) {
        entryByAccNo[e.accountNumber.trim().toLowerCase()] = e;
      }
    }

    // Map of existing payment dates per collection ID (format: "COLLECTION_ID:YYYY-MM-DD")
    final existingPaymentKeys = <String>{};
    for (final p in existingPayments) {
      final d = p.createdAt;
      final dateKey =
          "${p.collectionId}:${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
      existingPaymentKeys.add(dateKey);
    }

    // In-file duplicate tracker (format: "CUSTOMER_ID:YYYY-MM-DD")
    final filePaymentKeys = <String>{};

    final List<HistoricalImportRowRecord> parsedRowRecords = [];
    int validRowsCount = 0;
    int invalidRowsCount = 0;
    int unmappedRowsCount = 0;
    int totalPaymentsParsed = 0;
    int validPaymentsCount = 0;
    int duplicatePaymentsCount = 0;
    double totalAmountToImport = 0.0;
    double totalInterestToImport = 0.0;
    double totalLateFeesToImport = 0.0;
    double totalPostMatToImport = 0.0;

    final defaultRoute =
        existingRoutes.isNotEmpty ? existingRoutes.first.name : "Office";

    // 1. First, check if sheets use the NEW Vertical Template Layout (like assets/template/old_payment_history.xlsx)
    bool foundVerticalLayout = false;
    final fileSeenCustVertical = <String, String>{};
    final fileSeenAccVertical = <String, String>{};

    for (final tableEntry in excelDoc.tables.entries) {
      final sheetName = tableEntry.key;
      final sheet = tableEntry.value;
      if (sheet.maxRows == 0 || sheet.rows.isEmpty) continue;
      final rawRows = sheet.rows;

      // Look for vertical key-value metadata in Column A and Column B
      int paymentHeaderIndex = -1;
      final Map<String, String> metadata = {};

      for (int r = 0; r < rawRows.length; r++) {
        final row = rawRows[r];
        if (row.isEmpty) continue;

        final col0 = getCellString(row[0]).toLowerCase().replaceAll("_", " ").trim();
        final col1 = row.length > 1 ? getCellString(row[1]).trim() : "";

        if (col0.contains("customer") || col0.contains("coustomer") || col0 == "cust id" || col0 == "cust") {
          metadata["customer_id"] = col1;
        } else if (col0.contains("account") || col0 == "acc no" || col0 == "acc no." || col0 == "acno") {
          metadata["account_number"] = col1;
        } else if (col0.contains("loanee") || col0 == "name" || col0 == "loanee name") {
          metadata["loanee_name"] = col1;
        } else if (col0.contains("route") || col0.contains("zone")) {
          metadata["route"] = col1;
        } else if (col0.contains("collection type") || col0.contains("frequency") || col0 == "collection types") {
          metadata["collection_type"] = col1;
        } else if (col0.contains("collected by") || col0.contains("officer") || col0.contains("ro")) {
          metadata["collected_by"] = col1;
        }

        // Check for payment table header (e.g. "Date" in Col A and "Payment Amount" / "Amount" in Col B)
        if (col0 == "date" || col0.contains("payment date") || col0 == "dt") {
          final col1Low = col1.toLowerCase();
          if (col1Low.contains("amount") || col1Low.contains("payment") || col1Low.contains("paid") || col1Low.contains("rupees") || col1Low.contains("rs") || col1Low.isEmpty) {
            paymentHeaderIndex = r;
            foundVerticalLayout = true;
            break;
          }
        }
      }

      if (paymentHeaderIndex != -1) {
        final rawCustId = metadata["customer_id"] ?? "";
        final rawAccNo = metadata["account_number"] ?? "";
        final rawName = metadata["loanee_name"] ?? "";
        final rawRoute = metadata["route"] ?? "";
        final rawType = metadata["collection_type"] ?? "";
        final rawCollectedBy = metadata["collected_by"] ?? "";

        // Check column indices for Date, Payment Amount, Late Payment Interest, and Post Maturity Interest
        int dateColIdx = -1;
        int amountColIdx = -1;
        int lateFeeColIdx = -1;
        int postMaturityColIdx = -1;
        int genericInterestColIdx = -1;

        final pHeaderRow = rawRows[paymentHeaderIndex];
        for (int c = 0; c < pHeaderRow.length; c++) {
          final hText = getCellString(pHeaderRow[c]).toLowerCase().replaceAll("_", " ").trim();
          if (hText.contains("post maturity") || hText.contains("post mat") || hText.contains("overdue interest")) {
            postMaturityColIdx = c;
          } else if (hText.contains("late payment") || hText.contains("late fine") || hText.contains("late fee") || hText.contains("late int") || (hText.contains("late") && (hText.contains("fee") || hText.contains("fine") || hText.contains("interest")))) {
            lateFeeColIdx = c;
          } else if (hText == "date" || hText.contains("payment date") || hText == "dt" || hText.contains("collection date")) {
            dateColIdx = c;
          } else if (hText.contains("amount") || hText.contains("payment") || hText.contains("paid") || hText.contains("rupees") || hText.contains("rs") || hText.contains("installment")) {
            amountColIdx = c;
          } else if (hText.contains("interest") || hText == "int") {
            genericInterestColIdx = c;
          }
        }

        // Fallbacks
        if (dateColIdx == -1 && pHeaderRow.isNotEmpty) {
          dateColIdx = 0;
        }
        if (amountColIdx == -1 && pHeaderRow.length > 1) {
          amountColIdx = 1;
        }
        if (lateFeeColIdx == -1 && postMaturityColIdx == -1 && genericInterestColIdx == -1 && pHeaderRow.length > 2) {
          final col2Header = getCellString(pHeaderRow[2]).toLowerCase().trim();
          if (col2Header.contains("interest") || col2Header.isNotEmpty) {
            genericInterestColIdx = 2;
          }
        }

        final List<String> warnings = [];
        String? rowError;
        bool isRowValid = true;
        bool isRowDuplicate = false;
        bool isRowUnmapped = false;

        // 1. Validate existence in loanee_accounts
        final normCust = rawCustId.trim().toLowerCase();
        final normAcc = rawAccNo.trim().toLowerCase();

        LoaneeAccount? resolvedLoanee;
        if (normCust.isEmpty && normAcc.isEmpty) {
          isRowValid = false;
          rowError = "Sheet '$sheetName' is missing Customer ID and Account Number. Loanee must exist in loanee_accounts first.";
        } else if (normCust.isNotEmpty && normAcc.isNotEmpty) {
          final loaneeByCust = loaneeByCustId[normCust];
          final loaneeByAcc = loaneeByAccNo[normAcc];

          if (loaneeByCust == null && loaneeByAcc == null) {
            isRowValid = false;
            rowError = 'Loanee does not exist in loanee_accounts database (Customer ID: "$rawCustId", Account No: "$rawAccNo"). Loanee must exist first.';
          } else if (loaneeByCust == null) {
            isRowValid = false;
            rowError = 'Customer ID "$rawCustId" does not exist in loanee_accounts database. Loanee must exist first.';
          } else if (loaneeByAcc == null) {
            isRowValid = false;
            rowError = 'Account Number "$rawAccNo" does not exist in loanee_accounts database. Loanee must exist first.';
          } else if (loaneeByCust.customerId.trim().toLowerCase() != loaneeByAcc.customerId.trim().toLowerCase()) {
            isRowValid = false;
            rowError = 'Customer ID "$rawCustId" and Account Number "$rawAccNo" belong to different loanee accounts in database.';
          } else {
            resolvedLoanee = loaneeByCust;
          }
        } else if (normCust.isNotEmpty) {
          final loaneeByCust = loaneeByCustId[normCust];
          if (loaneeByCust == null) {
            isRowValid = false;
            rowError = 'Customer ID "$rawCustId" does not exist in loanee_accounts database. Loanee must exist first.';
          } else {
            resolvedLoanee = loaneeByCust;
          }
        } else {
          final loaneeByAcc = loaneeByAccNo[normAcc];
          if (loaneeByAcc == null) {
            isRowValid = false;
            rowError = 'Account Number "$rawAccNo" does not exist in loanee_accounts database. Loanee must exist first.';
          } else {
            resolvedLoanee = loaneeByAcc;
          }
        }

        if (resolvedLoanee == null) {
          isRowValid = false;
          isRowUnmapped = true;
          rowError ??= 'Loanee does not exist in loanee_accounts database. Loanee must exist first before importing collection payments.';
        }

        // Check for in-file duplicate sheet
        if (isRowValid && resolvedLoanee != null) {
          final normResCust = resolvedLoanee.customerId.trim().toLowerCase();
          final normResAcc = resolvedLoanee.accountNumber.trim().toLowerCase();

          if (normResCust.isNotEmpty && fileSeenCustVertical.containsKey(normResCust)) {
            isRowValid = false;
            isRowDuplicate = true;
            rowError = 'Duplicate Customer ID "${resolvedLoanee.customerId}" in Excel file (already in sheet "${fileSeenCustVertical[normResCust]}"). Duplicate entry blocked.';
          } else if (normResAcc.isNotEmpty && fileSeenAccVertical.containsKey(normResAcc)) {
            isRowValid = false;
            isRowDuplicate = true;
            rowError = 'Duplicate Account Number "${resolvedLoanee.accountNumber}" in Excel file (already in sheet "${fileSeenAccVertical[normResAcc]}"). Duplicate entry blocked.';
          }

          if (isRowValid) {
            if (normResCust.isNotEmpty) fileSeenCustVertical[normResCust] = sheetName;
            if (normResAcc.isNotEmpty) fileSeenAccVertical[normResAcc] = sheetName;
          }
        }

        // 2. Resolve Collection Entry
        RoCollectionEntry? resolvedEntry;
        if (resolvedLoanee != null) {
          if (entryByCustId.containsKey(resolvedLoanee.customerId.toLowerCase())) {
            resolvedEntry = entryByCustId[resolvedLoanee.customerId.toLowerCase()];
          } else if (entryByAccNo.containsKey(resolvedLoanee.accountNumber.toLowerCase())) {
            resolvedEntry = entryByAccNo[resolvedLoanee.accountNumber.toLowerCase()];
          }
        }

        bool newCollectionEntryNeeded = false;
        RoCollectionEntry? newCollectionEntry;

        final normRoute = rawRoute.isNotEmpty ? rawRoute : defaultRoute;
        final normType = normalizeCollectionType(rawType.isNotEmpty ? rawType : "Daily");
        final resolvedCust = resolvedLoanee != null ? resolvedLoanee.customerId : (rawCustId.isNotEmpty ? rawCustId : "N/A");
        final resolvedAcc = resolvedLoanee != null ? resolvedLoanee.accountNumber : (rawAccNo.isNotEmpty ? rawAccNo : "N/A");
        final resolvedName = rawName.isNotEmpty ? rawName : (resolvedLoanee?.loaneeName ?? "Unknown Loanee");

        if (isRowValid && resolvedLoanee != null) {
          if (resolvedEntry == null) {
            newCollectionEntryNeeded = true;
            final double rawLoan = resolvedLoanee.loanAmount > 0
                ? resolvedLoanee.loanAmount
                : defaultBasePrincipal * 1.15; // default ₹11,500

            final breakdown = LoanPrincipalBreakdown.calculate(
              loanAmount: rawLoan,
              interestRate: defaultInterestRate,
              basePrincipal: defaultBasePrincipal,
              baseDailyAmount: defaultBaseDaily,
              baseWeeklyAmount: defaultBaseWeekly,
            );

            final bool isDaily = normType.toLowerCase() == "daily";
            final double payableAmt = isDaily ? breakdown.dailyPayable : breakdown.weeklyPayable;

            newCollectionEntry = RoCollectionEntry(
              id: "COL-HIST-${DateTime.now().millisecondsSinceEpoch}-${parsedRowRecords.length + 1}",
              customerId: resolvedCust,
              accountNumber: resolvedAcc,
              loaneeName: resolvedName,
              loaneeAddress: resolvedLoanee.address.isNotEmpty ? resolvedLoanee.address : "Field Route Zone",
              collectionType: normType,
              route: normRoute,
              mobileNo: resolvedLoanee.mobileNo,
              payableAmount: payableAmt,
              loanAmount: breakdown.loanAmount,
              actualPrincipal: breakdown.actualPrincipal,
              interestAmount: breakdown.interestAmount,
              interestRate: breakdown.interestRate,
              frequency: isDaily ? "Day" : "Week",
            );
          }
        }

        // 4. Parse Payments list from subsequent rows (paymentHeaderIndex + 1 to end)
        final targetCollectionId = resolvedEntry?.id ?? newCollectionEntry?.id ?? "COL-PENDING-${parsedRowRecords.length + 1}";
        final List<HistoricalPaymentItem> rowPayments = [];

        for (int r = paymentHeaderIndex + 1; r < rawRows.length; r++) {
          final row = rawRows[r];
          if (row.isEmpty || row.every((c) => c == null || c.value == null || c.value.toString().trim().isEmpty)) {
            continue;
          }

          final rawDateCell = row.length > dateColIdx ? row[dateColIdx]?.value : null;
          final parsedDate = parseDateValue(rawDateCell);

          if (parsedDate == null) {
            final dateStr = row.length > dateColIdx ? getCellString(row[dateColIdx]) : "";
            if (dateStr.isNotEmpty) {
              rowPayments.add(
                HistoricalPaymentItem(
                  paymentDate: DateTime.now(),
                  amount: 0.0,
                  interest: 0.0,
                  roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                  errorMessage: "Invalid date format at row ${r + 1}: \"$dateStr\"",
                ),
              );
            }
            continue;
          }

          final rawAmountCell = (amountColIdx != -1 && row.length > amountColIdx) ? row[amountColIdx]?.value : null;
          final double? parsedAmount = parseNumericAmount(rawAmountCell);

          final rawLateFeeCell = (lateFeeColIdx != -1 && row.length > lateFeeColIdx)
              ? row[lateFeeColIdx]?.value
              : null;
          final double parsedLateFee = (rawLateFeeCell != null)
              ? (parseNumericAmount(rawLateFeeCell) ?? 0.0)
              : 0.0;

          final rawPostMatCell = (postMaturityColIdx != -1 && row.length > postMaturityColIdx)
              ? row[postMaturityColIdx]?.value
              : null;
          final double parsedPostMat = (rawPostMatCell != null)
              ? (parseNumericAmount(rawPostMatCell) ?? 0.0)
              : 0.0;

          final rawGenericIntCell = (genericInterestColIdx != -1 && row.length > genericInterestColIdx)
              ? row[genericInterestColIdx]?.value
              : null;
          final double parsedGenericInt = (rawGenericIntCell != null)
              ? (parseNumericAmount(rawGenericIntCell) ?? 0.0)
              : 0.0;

          // Late Payment data (daily/weekly late fee) from Excel is stored in interest column
          final double parsedInterest = parsedLateFee + parsedGenericInt;

          final amtStr = (amountColIdx != -1 && row.length > amountColIdx) ? getCellString(row[amountColIdx]) : "";
          final bool isAmountBlank = rawAmountCell == null || amtStr.trim().isEmpty || amtStr.trim() == "-" || amtStr.trim() == "0";

          double effectiveAmount = 0.0;
          if (parsedAmount != null) {
            if (parsedAmount < 0) {
              rowPayments.add(
                HistoricalPaymentItem(
                  paymentDate: parsedDate,
                  amount: parsedAmount,
                  interest: parsedInterest,
                  latePaymentFee: parsedInterest,
                  postMaturityInterest: parsedPostMat,
                  roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                  errorMessage: "Payment amount cannot be negative (₹$parsedAmount) at row ${r + 1}",
                ),
              );
              continue;
            }
            effectiveAmount = parsedAmount;
          } else if (isAmountBlank || parsedInterest > 0 || parsedPostMat > 0) {
            effectiveAmount = 0.0;
          } else {
            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: parsedDate,
                amount: 0.0,
                interest: parsedInterest,
                latePaymentFee: parsedInterest,
                postMaturityInterest: parsedPostMat,
                roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                errorMessage: "Invalid payment amount at row ${r + 1}: \"$amtStr\"",
              ),
            );
            continue;
          }

          if (parsedInterest < 0) {
            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: parsedDate,
                amount: effectiveAmount,
                interest: parsedInterest,
                latePaymentFee: parsedInterest,
                postMaturityInterest: parsedPostMat,
                roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                errorMessage: "Interest amount cannot be negative (₹$parsedInterest) at row ${r + 1}",
              ),
            );
            continue;
          }

          if (parsedPostMat < 0) {
            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: parsedDate,
                amount: effectiveAmount,
                interest: parsedInterest,
                latePaymentFee: parsedInterest,
                postMaturityInterest: parsedPostMat,
                roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                errorMessage: "Post maturity interest cannot be negative (₹$parsedPostMat) at row ${r + 1}",
              ),
            );
            continue;
          }

          // If payment amount, interest, and post maturity interest are all 0, there is no transaction on this date to record
          if (effectiveAmount == 0 && parsedInterest == 0 && parsedPostMat == 0) {
            continue;
          }

          if (!isRowValid) {
            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: parsedDate,
                amount: effectiveAmount,
                interest: parsedInterest,
                latePaymentFee: parsedInterest,
                postMaturityInterest: parsedPostMat,
                roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                errorMessage: "Payment skipped: Loanee does not exist in loanee_accounts database.",
              ),
            );
            continue;
          }

          totalPaymentsParsed++;

          // Duplicate Check against DB and within-file
          final dateStr =
              "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, "0")}-${parsedDate.day.toString().padLeft(2, "0")}";
          final dbPaymentKey = "$targetCollectionId:$dateStr";
          final fileAccountKey = "${resolvedCust.toLowerCase()}:$dateStr";

          final bool isDuplicate = existingPaymentKeys.contains(dbPaymentKey) ||
              filePaymentKeys.contains(fileAccountKey);

          if (isDuplicate) {
            duplicatePaymentsCount++;
            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: parsedDate,
                amount: effectiveAmount,
                interest: parsedInterest,
                latePaymentFee: parsedInterest,
                postMaturityInterest: parsedPostMat,
                roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                isDuplicate: true,
                errorMessage:
                    "Duplicate payment: Record already exists for this account on $dateStr (Excel row ${r + 1}).",
              ),
            );
          } else {
            filePaymentKeys.add(fileAccountKey);
            validPaymentsCount++;
            totalAmountToImport += effectiveAmount;
            totalLateFeesToImport += parsedInterest;
            totalPostMatToImport += parsedPostMat;

            String remarksText;
            if (parsedPostMat > 0 && parsedInterest > 0) {
              remarksText = "Historical Excel Import (Daily/Weekly Late Fee: ₹${parsedInterest.toStringAsFixed(2)}, Post Maturity: ₹${parsedPostMat.toStringAsFixed(2)})";
            } else if (parsedPostMat > 0) {
              remarksText = "Historical Excel Import (Post Maturity: ₹${parsedPostMat.toStringAsFixed(2)})";
            } else if (parsedInterest > 0) {
              remarksText = "Historical Excel Import (Daily/Weekly Late Fee: ₹${parsedInterest.toStringAsFixed(2)})";
            } else {
              remarksText = "Historical Excel Import";
            }

            final paymentModel = CollectionPaymentModel(
              id: "PAY-HIST-${targetCollectionId}_${dateStr.replaceAll("-", "")}",
              collectionId: targetCollectionId,
              paymentAmount: effectiveAmount,
              interest: parsedInterest,
              lateFine: 0.0,
              postMaturityInterest: parsedPostMat,
              remainingBalance: 0.0,
              paymentType: "Cash",
              roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
              roRoute: normRoute,
              createdAt: parsedDate,
              status: "Success",
              remarks: remarksText,
            );

            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: parsedDate,
                amount: effectiveAmount,
                interest: parsedInterest,
                latePaymentFee: parsedInterest,
                postMaturityInterest: parsedPostMat,
                roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
                paymentModel: paymentModel,
              ),
            );
          }
        }

        final bool isAllPaymentsDuplicate = rowPayments.isNotEmpty && rowPayments.every((p) => p.isDuplicate);
        if (isAllPaymentsDuplicate) {
          warnings.add("All payment dates in this sheet already exist in database.");
        }

        if (rowPayments.isEmpty && isRowValid) {
          warnings.add("No payment records found below Date header in sheet '$sheetName'.");
        }

        if (isRowUnmapped) {
          unmappedRowsCount++;
        }

        if (isRowValid && rowError == null) {
          validRowsCount++;
        } else {
          invalidRowsCount++;
        }

        parsedRowRecords.add(
          HistoricalImportRowRecord(
            rowIndex: 1,
            rawCustomerId: resolvedCust,
            rawAccountNumber: resolvedAcc,
            rawLoaneeName: resolvedName,
            rawRoute: normRoute,
            rawCollectionType: normType,
            rawCollectedBy: rawCollectedBy,
            resolvedLoanee: resolvedLoanee,
            resolvedCollectionEntry: resolvedEntry,
            newCollectionEntryNeeded: newCollectionEntryNeeded,
            newCollectionEntry: newCollectionEntry,
            payments: rowPayments,
            isValid: isRowValid && rowError == null,
            isDuplicate: isRowDuplicate || isAllPaymentsDuplicate,
            isUnmapped: isRowUnmapped,
            errorMessage: rowError,
            warnings: warnings,
          ),
        );
      }
    }

    if (foundVerticalLayout && parsedRowRecords.isNotEmpty) {
      return HistoricalImportPreviewResult(
        totalRows: parsedRowRecords.length,
        validRowsCount: validRowsCount,
        invalidRowsCount: invalidRowsCount,
        unmappedRowsCount: unmappedRowsCount,
        totalPaymentsParsed: totalPaymentsParsed,
        validPaymentsCount: validPaymentsCount,
        duplicatePaymentsCount: duplicatePaymentsCount,
        totalAmountToImport: totalAmountToImport,
        totalInterestToImport: totalInterestToImport,
        totalLateFeesToImport: totalLateFeesToImport,
        totalPostMatToImport: totalPostMatToImport,
        rowRecords: parsedRowRecords,
        fileValidationErrors: fileErrors,
      );
    }

    // 2. Fallback to Horizontal Matrix Layout (Legacy Table with date columns)
    Sheet? targetSheet;
    for (final sheet in excelDoc.tables.values) {
      if (sheet.maxRows > 0 && sheet.rows.any((r) => r.any((c) => c?.value != null))) {
        targetSheet = sheet;
        break;
      }
    }

    if (targetSheet == null || targetSheet.rows.isEmpty) {
      return HistoricalImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 0,
        validPaymentsCount: 0,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 0.0,
        rowRecords: [],
        fileValidationErrors: ["The Excel worksheet is empty."],
      );
    }

    final rawRows = targetSheet.rows;

    // Find Header Row dynamically
    int headerRowIndex = -1;
    for (int r = 0; r < rawRows.length && r < 10; r++) {
      final rowText = rawRows[r].map((c) => getCellString(c).toLowerCase()).join(" ");
      if ((rowText.contains("customer") || rowText.contains("coustomer") || rowText.contains("cust")) &&
          (rowText.contains("account") || rowText.contains("acc")) &&
          (rowText.contains("loanee") || rowText.contains("name"))) {
        headerRowIndex = r;
        break;
      }
    }

    if (headerRowIndex == -1) {
      for (int r = 0; r < rawRows.length && r < 5; r++) {
        final nonNullCells = rawRows[r].where((c) => c?.value != null).toList();
        if (nonNullCells.length >= 4) {
          headerRowIndex = r;
          break;
        }
      }
    }

    if (headerRowIndex == -1) {
      return HistoricalImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 0,
        validPaymentsCount: 0,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 0.0,
        rowRecords: [],
        fileValidationErrors: [
          "Required template headers not found. Please download and use the official template.",
        ],
      );
    }

    final headerRow = rawRows[headerRowIndex];

    int custCol = -1;
    int accCol = -1;
    int nameCol = -1;
    int routeCol = -1;
    int typeCol = -1;
    int collectedByCol = -1;
    final Map<int, DateTime> dateColumns = {};

    for (int c = 0; c < headerRow.length; c++) {
      final rawHeader = headerRow[c]?.value;
      final headerStr = getCellString(headerRow[c]).toLowerCase().replaceAll("_", " ").trim();

      if (custCol == -1 && (headerStr.contains("customer") || headerStr.contains("coustomer") || headerStr == "cust id" || headerStr == "cust")) {
        custCol = c;
        continue;
      }
      if (accCol == -1 && (headerStr.contains("account") || headerStr == "acc no" || headerStr == "acc no." || headerStr == "acno")) {
        accCol = c;
        continue;
      }
      if (nameCol == -1 && (headerStr.contains("name") || headerStr.contains("loanee"))) {
        nameCol = c;
        continue;
      }
      if (routeCol == -1 && (headerStr.contains("route") || headerStr.contains("zone"))) {
        routeCol = c;
        continue;
      }
      if (typeCol == -1 && (headerStr.contains("type") || headerStr.contains("frequency") || headerStr.contains("collection"))) {
        typeCol = c;
        continue;
      }
      if (collectedByCol == -1 && (headerStr.contains("collected") || headerStr.contains("officer") || headerStr.contains("ro"))) {
        collectedByCol = c;
        continue;
      }

      final parsedDate = parseDateValue(rawHeader);
      if (parsedDate != null) {
        dateColumns[c] = parsedDate;
      }
    }

    if (custCol == -1 && headerRow.isNotEmpty) custCol = 0;
    if (accCol == -1 && headerRow.length > 1) accCol = 1;
    if (nameCol == -1 && headerRow.length > 2) nameCol = 2;
    if (routeCol == -1 && headerRow.length > 3) routeCol = 3;
    if (typeCol == -1 && headerRow.length > 4) typeCol = 4;
    if (collectedByCol == -1 && headerRow.length > 5) collectedByCol = 5;

    if (dateColumns.isEmpty) {
      for (int c = 6; c < headerRow.length; c++) {
        final parsedDate = parseDateValue(headerRow[c]?.value);
        if (parsedDate != null) {
          dateColumns[c] = parsedDate;
        }
      }
    }

    if (dateColumns.isEmpty) {
      fileErrors.add("No valid payment date columns or payment records found in Excel file.");
      return HistoricalImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 0,
        validPaymentsCount: 0,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 0.0,
        rowRecords: [],
        fileValidationErrors: fileErrors,
      );
    }

    // Parse Data Rows
    final fileSeenCustHorizontal = <String, int>{};
    final fileSeenAccHorizontal = <String, int>{};

    for (int r = headerRowIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty || row.every((c) => c == null || c.value == null || c.value.toString().trim().isEmpty)) {
        continue;
      }

      String getCol(int colIdx) {
        if (colIdx >= 0 && colIdx < row.length) {
          return getCellString(row[colIdx]);
        }
        return "";
      }

      final rawCustId = getCol(custCol);
      final rawAccNo = getCol(accCol);
      final rawName = getCol(nameCol);
      final rawRoute = getCol(routeCol);
      final rawType = getCol(typeCol);
      final rawCollectedBy = getCol(collectedByCol);

      final List<String> warnings = [];
      String? rowError;
      bool isRowValid = true;
      bool isRowDuplicate = false;
      bool isRowUnmapped = false;

      final normCust = rawCustId.trim().toLowerCase();
      final normAcc = rawAccNo.trim().toLowerCase();

      LoaneeAccount? resolvedLoanee;
      if (normCust.isEmpty && normAcc.isEmpty) {
        isRowValid = false;
        rowError = "Row is missing Customer ID and Account Number. Loanee must exist in loanee_accounts first.";
      } else if (normCust.isNotEmpty && normAcc.isNotEmpty) {
        final loaneeByCust = loaneeByCustId[normCust];
        final loaneeByAcc = loaneeByAccNo[normAcc];

        if (loaneeByCust == null && loaneeByAcc == null) {
          isRowValid = false;
          rowError = 'Loanee does not exist in loanee_accounts database (Customer ID: "$rawCustId", Account No: "$rawAccNo"). Loanee must exist first.';
        } else if (loaneeByCust == null) {
          isRowValid = false;
          rowError = 'Customer ID "$rawCustId" does not exist in loanee_accounts database. Loanee must exist first.';
        } else if (loaneeByAcc == null) {
          isRowValid = false;
          rowError = 'Account Number "$rawAccNo" does not exist in loanee_accounts database. Loanee must exist first.';
        } else if (loaneeByCust.customerId.trim().toLowerCase() != loaneeByAcc.customerId.trim().toLowerCase()) {
          isRowValid = false;
          rowError = 'Customer ID "$rawCustId" and Account Number "$rawAccNo" belong to different loanee accounts in database.';
        } else {
          resolvedLoanee = loaneeByCust;
        }
      } else if (normCust.isNotEmpty) {
        final loaneeByCust = loaneeByCustId[normCust];
        if (loaneeByCust == null) {
          isRowValid = false;
          rowError = 'Customer ID "$rawCustId" does not exist in loanee_accounts database. Loanee must exist first.';
        } else {
          resolvedLoanee = loaneeByCust;
        }
      } else {
        final loaneeByAcc = loaneeByAccNo[normAcc];
        if (loaneeByAcc == null) {
          isRowValid = false;
          rowError = 'Account Number "$rawAccNo" does not exist in loanee_accounts database. Loanee must exist first.';
        } else {
          resolvedLoanee = loaneeByAcc;
        }
      }

      if (resolvedLoanee == null) {
        isRowValid = false;
        isRowUnmapped = true;
        rowError ??= 'Loanee does not exist in loanee_accounts database. Loanee must exist first before importing collection payments.';
      }

      // Check for in-file duplicate row
      if (isRowValid && resolvedLoanee != null) {
        final normResCust = resolvedLoanee.customerId.trim().toLowerCase();
        final normResAcc = resolvedLoanee.accountNumber.trim().toLowerCase();

        if (normResCust.isNotEmpty && fileSeenCustHorizontal.containsKey(normResCust)) {
          isRowValid = false;
          isRowDuplicate = true;
          rowError = 'Duplicate Customer ID "${resolvedLoanee.customerId}" in Excel file (already in row #${fileSeenCustHorizontal[normResCust]}). Duplicate entry blocked.';
        } else if (normResAcc.isNotEmpty && fileSeenAccHorizontal.containsKey(normResAcc)) {
          isRowValid = false;
          isRowDuplicate = true;
          rowError = 'Duplicate Account Number "${resolvedLoanee.accountNumber}" in Excel file (already in row #${fileSeenAccHorizontal[normResAcc]}). Duplicate entry blocked.';
        }

        if (isRowValid) {
          if (normResCust.isNotEmpty) fileSeenCustHorizontal[normResCust] = r + 1;
          if (normResAcc.isNotEmpty) fileSeenAccHorizontal[normResAcc] = r + 1;
        }
      }

      RoCollectionEntry? resolvedEntry;
      if (resolvedLoanee != null) {
        if (entryByCustId.containsKey(resolvedLoanee.customerId.toLowerCase())) {
          resolvedEntry = entryByCustId[resolvedLoanee.customerId.toLowerCase()];
        } else if (entryByAccNo.containsKey(resolvedLoanee.accountNumber.toLowerCase())) {
          resolvedEntry = entryByAccNo[resolvedLoanee.accountNumber.toLowerCase()];
        }
      }

      bool newCollectionEntryNeeded = false;
      RoCollectionEntry? newCollectionEntry;

      final normRoute = rawRoute.isNotEmpty ? rawRoute : defaultRoute;
      final normType = normalizeCollectionType(rawType);
      final resolvedCust = resolvedLoanee != null ? resolvedLoanee.customerId : (rawCustId.isNotEmpty ? rawCustId : "N/A");
      final resolvedAcc = resolvedLoanee != null ? resolvedLoanee.accountNumber : (rawAccNo.isNotEmpty ? rawAccNo : "N/A");
      final resolvedName = rawName.isNotEmpty ? rawName : (resolvedLoanee?.loaneeName ?? "Unknown Loanee");

      if (isRowValid && resolvedLoanee != null) {
        if (resolvedEntry == null) {
          newCollectionEntryNeeded = true;
          final double rawLoan = (resolvedLoanee.loanAmount > 0)
              ? resolvedLoanee.loanAmount
              : defaultBasePrincipal * 1.15;

          final breakdown = LoanPrincipalBreakdown.calculate(
            loanAmount: rawLoan,
            interestRate: defaultInterestRate,
            basePrincipal: defaultBasePrincipal,
            baseDailyAmount: defaultBaseDaily,
            baseWeeklyAmount: defaultBaseWeekly,
          );

          final bool isDaily = normType.toLowerCase() == "daily";
          final double payableAmt = isDaily ? breakdown.dailyPayable : breakdown.weeklyPayable;

          newCollectionEntry = RoCollectionEntry(
            id: "COL-HIST-${DateTime.now().millisecondsSinceEpoch}-$r",
            customerId: resolvedCust,
            accountNumber: resolvedAcc,
            loaneeName: resolvedName,
            loaneeAddress: resolvedLoanee.address.isNotEmpty ? resolvedLoanee.address : "Field Route Zone",
            collectionType: normType,
            route: normRoute,
            mobileNo: resolvedLoanee.mobileNo,
            payableAmount: payableAmt,
            loanAmount: breakdown.loanAmount,
            actualPrincipal: breakdown.actualPrincipal,
            interestAmount: breakdown.interestAmount,
            interestRate: breakdown.interestRate,
            frequency: isDaily ? "Day" : "Week",
          );
        }
      }

      final targetCollectionId = resolvedEntry?.id ?? newCollectionEntry?.id ?? "COL-PENDING-$r";
      final List<HistoricalPaymentItem> rowPayments = [];

      final sortedCols = dateColumns.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (final colEntry in sortedCols) {
        final colIdx = colEntry.key;
        final paymentDate = colEntry.value;

        if (colIdx >= row.length) continue;
        final cell = row[colIdx];
        if (cell == null || cell.value == null) continue;

        final rawAmount = cell.value;
        final double? parsedAmount = parseNumericAmount(rawAmount);

        if (parsedAmount == null) {
          final str = getCellString(cell);
          if (str.isNotEmpty) {
            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: paymentDate,
                amount: 0.0,
                roName: rawCollectedBy,
                errorMessage: 'Invalid payment amount "$str"',
              ),
            );
          }
          continue;
        }

        if (parsedAmount <= 0) {
          if (parsedAmount < 0) {
            rowPayments.add(
              HistoricalPaymentItem(
                paymentDate: paymentDate,
                amount: parsedAmount,
                roName: rawCollectedBy,
                errorMessage: "Payment amount cannot be negative (₹$parsedAmount)",
              ),
            );
          }
          continue;
        }

        if (!isRowValid) {
          rowPayments.add(
            HistoricalPaymentItem(
              paymentDate: paymentDate,
              amount: parsedAmount,
              roName: rawCollectedBy,
              errorMessage: "Payment skipped: Loanee does not exist in loanee_accounts database.",
            ),
          );
          continue;
        }

        totalPaymentsParsed++;

        final dateStr = "${paymentDate.year}-${paymentDate.month.toString().padLeft(2, "0")}-${paymentDate.day.toString().padLeft(2, "0")}";
        final dbPaymentKey = "$targetCollectionId:$dateStr";
        final fileAccountKey = "${resolvedCust.toLowerCase()}:$dateStr";

        final bool isDuplicate = existingPaymentKeys.contains(dbPaymentKey) || filePaymentKeys.contains(fileAccountKey);

        if (isDuplicate) {
          duplicatePaymentsCount++;
          rowPayments.add(
            HistoricalPaymentItem(
              paymentDate: paymentDate,
              amount: parsedAmount,
              roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
              isDuplicate: true,
              errorMessage: "Duplicate payment: Record already exists for this account on $dateStr.",
            ),
          );
        } else {
          filePaymentKeys.add(fileAccountKey);
          validPaymentsCount++;
          totalAmountToImport += parsedAmount;

          final paymentModel = CollectionPaymentModel(
            id: "PAY-HIST-${targetCollectionId}_${dateStr.replaceAll("-", "")}",
            collectionId: targetCollectionId,
            paymentAmount: parsedAmount,
            remainingBalance: 0.0,
            lateFine: 0.0,
            paymentType: "Cash",
            roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
            roRoute: normRoute,
            createdAt: paymentDate,
            status: "Success",
            remarks: "Historical Excel Import",
          );

          rowPayments.add(
            HistoricalPaymentItem(
              paymentDate: paymentDate,
              amount: parsedAmount,
              roName: rawCollectedBy.isNotEmpty ? rawCollectedBy : "RO Officer",
              paymentModel: paymentModel,
            ),
          );
        }
      }

      final bool isAllPaymentsDuplicate = rowPayments.isNotEmpty && rowPayments.every((p) => p.isDuplicate);
      if (isAllPaymentsDuplicate) {
        warnings.add("All payment dates in this row already exist in database.");
      }

      if (rowPayments.isEmpty && isRowValid) {
        warnings.add("No payment amounts found in date columns for this row.");
      }

      if (isRowUnmapped) {
        unmappedRowsCount++;
      }

      if (isRowValid && rowError == null) {
        validRowsCount++;
      } else {
        invalidRowsCount++;
      }

      parsedRowRecords.add(
        HistoricalImportRowRecord(
          rowIndex: r + 1,
          rawCustomerId: rawCustId,
          rawAccountNumber: rawAccNo,
          rawLoaneeName: rawName,
          rawRoute: rawRoute,
          rawCollectionType: rawType,
          rawCollectedBy: rawCollectedBy,
          resolvedLoanee: resolvedLoanee,
          resolvedCollectionEntry: resolvedEntry,
          newCollectionEntryNeeded: newCollectionEntryNeeded,
          newCollectionEntry: newCollectionEntry,
          payments: rowPayments,
          isValid: isRowValid && rowError == null,
          isDuplicate: isRowDuplicate || isAllPaymentsDuplicate,
          isUnmapped: isRowUnmapped,
          errorMessage: rowError,
          warnings: warnings,
        ),
      );
    }

    return HistoricalImportPreviewResult(
      totalRows: parsedRowRecords.length,
      validRowsCount: validRowsCount,
      invalidRowsCount: invalidRowsCount,
      unmappedRowsCount: unmappedRowsCount,
      totalPaymentsParsed: totalPaymentsParsed,
      validPaymentsCount: validPaymentsCount,
      duplicatePaymentsCount: duplicatePaymentsCount,
      totalAmountToImport: totalAmountToImport,
      totalInterestToImport: totalInterestToImport,
      rowRecords: parsedRowRecords,
      fileValidationErrors: fileErrors,
    );
  }

  /// Pick an Excel/CSV file from device and parse it into HistoricalImportPreviewResult
  static Future<HistoricalImportPreviewResult?> pickAndParseHistoricalPayments({
    required BuildContext context,
    required LoaneeProvider loaneeProvider,
    required CollectionSheetProvider collectionProvider,
    SettingsProvider? settingsProvider,
  }) async {
    try {
      final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["xlsx", "xls", "csv"],
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
              content: const Text("Could not read file content. Please select a valid Excel file."),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return null;
      }

      if (loaneeProvider.loanees.isEmpty) {
        try {
          await loaneeProvider.fetchFromSupabase();
        } catch (_) {}
      }

      return parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: loaneeProvider.loanees,
        existingEntries: collectionProvider.collectionEntries,
        existingPayments: collectionProvider.payments,
        existingRoutes: collectionProvider.routes,
        defaultInterestRate: settingsProvider?.investmentInterestRate ?? 15.0,
        defaultBasePrincipal: settingsProvider?.investmentBaseAmount ?? 10000.0,
        defaultBaseDaily: settingsProvider?.baseDailyAmount ?? 100.0,
        defaultBaseWeekly: settingsProvider?.weeklyInstallmentAmount ?? 650.0,
      );
    } catch (e) {
      debugPrint("⚠️ Error picking/parsing historical payments Excel: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to parse file: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return null;
    }
  }

  /// Execute transactional import of all verified historical payments and collection cards
  static Future<HistoricalImportExecutionResult> executeTransactionalImport({
    required HistoricalImportPreviewResult previewResult,
    required CollectionSheetProvider collectionProvider,
    required LoaneeProvider loaneeProvider,
    SupabaseService? supabaseService,
  }) async {
    final supa = supabaseService ?? SupabaseService.instance;

    return await supa.runWithNotificationSuppression<HistoricalImportExecutionResult>(() async {
      final List<RoCollectionEntry> createdEntries = [];
      final List<CollectionPaymentModel> insertedPayments = [];
      final List<String> failures = [];
      int duplicateSkipped = 0;
      double totalImported = 0.0;
      double totalInterestImported = 0.0;
      double totalLateFeesImported = 0.0;
      double totalPostMatImported = 0.0;

      try {
        // 1. Gather all new Collection Entries that must be created
        for (final row in previewResult.rowRecords) {
          if (!row.isValid) continue;

          if (row.newCollectionEntryNeeded && row.newCollectionEntry != null) {
            final newEntry = row.newCollectionEntry!;
            // Check if already in provider
            final existing = collectionProvider.getCollectionEntryById(newEntry.id);
            if (existing == null) {
              final saved = await collectionProvider.addCollectionEntry(
                newEntry,
                saveToRemote: false,
              );
              if (saved) {
                createdEntries.add(newEntry);
              } else {
                failures.add("Failed to create collection entry for ${row.rawLoaneeName} (${row.rawCustomerId})");
              }
            }
          }
        }

        final Map<String, LoaneeAccount> affectedLoanees = {};

        // 2. Gather all valid, non-duplicate payments and record them
        for (final row in previewResult.rowRecords) {
          if (!row.isValid) continue;

          final targetEntryId = row.resolvedCollectionEntry?.id ?? row.newCollectionEntry?.id;
          if (targetEntryId == null) continue;

          // Initial loan balance directly from DB records (prefer authoritative loanee loan amount if available)
          final initialBal = (row.resolvedLoanee?.loanAmount != null && row.resolvedLoanee!.loanAmount > 0)
              ? row.resolvedLoanee!.loanAmount
              : ((row.resolvedCollectionEntry?.initialBalance != null && row.resolvedCollectionEntry!.initialBalance > 0)
                  ? row.resolvedCollectionEntry!.initialBalance
                  : ((row.newCollectionEntry?.initialBalance != null && row.newCollectionEntry!.initialBalance > 0)
                      ? row.newCollectionEntry!.initialBalance
                      : (row.resolvedLoanee?.dueAmount ?? 0.0)));

          // Prior payments recorded in collectionProvider
          final priorPaid = collectionProvider.getTotalPaidForCollection(targetEntryId);
          final priorInterest = collectionProvider.getTotalInterestForCollection(targetEntryId);

          // Running remaining balance and tracking totals
          double runningBalance = initialBal + priorInterest - priorPaid;
          double runningTotalCollected = priorPaid;
          double runningCumulativeInterest = priorInterest;

          debugPrint('======================================================================');
          debugPrint('=== [HISTORICAL PAYMENT IMPORT CALCULATION PIPELINE] ===');
          debugPrint('Loanee: ${row.rawLoaneeName} | Customer ID: ${row.rawCustomerId} | Account: ${row.rawAccountNumber}');
          debugPrint('Original loan amount: ₹${initialBal.toStringAsFixed(2)}');
          debugPrint('Prior collected: ₹${priorPaid.toStringAsFixed(2)} | Prior interest: ₹${priorInterest.toStringAsFixed(2)}');
          debugPrint('Starting remaining balance: ₹${runningBalance.toStringAsFixed(2)}');
          debugPrint('----------------------------------------------------------------------');

          // Ensure payments are processed chronologically in ascending order
          final sortedPayments = List<HistoricalPaymentItem>.from(row.payments)
            ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

          double rowAmountImported = 0.0;
          int paymentIdx = 1;
          for (final p in sortedPayments) {
            if (p.isDuplicate) {
              duplicateSkipped++;
              continue;
            }
            if (p.errorMessage != null || (p.amount <= 0 && p.interest <= 0 && p.postMaturityInterest <= 0)) {
              continue;
            }

            // Correct formula: Interest increases remaining amount, payment decreases it
            runningTotalCollected += p.amount;
            runningCumulativeInterest += (p.interest + p.postMaturityInterest);
            runningBalance = (runningBalance + p.interest + p.postMaturityInterest - p.amount).clamp(0.0, double.infinity);
            final newRemaining = runningBalance;

            debugPrint('  Payment #$paymentIdx: Date=${p.formattedDate} | Payment Amount=₹${p.amount.toStringAsFixed(2)} | Interest=₹${p.interest.toStringAsFixed(2)} | Post Maturity=₹${p.postMaturityInterest.toStringAsFixed(2)} | Running Total Collected=₹${runningTotalCollected.toStringAsFixed(2)} | Running Remaining Balance=₹${newRemaining.toStringAsFixed(2)}');
            paymentIdx++;

            String paymentRemarks;
            if (p.postMaturityInterest > 0 && p.interest > 0) {
              paymentRemarks = "Historical Excel Import (Daily/Weekly Late Fee: ₹${p.interest.toStringAsFixed(2)}, Post Maturity: ₹${p.postMaturityInterest.toStringAsFixed(2)})";
            } else if (p.postMaturityInterest > 0) {
              paymentRemarks = "Historical Excel Import (Post Maturity: ₹${p.postMaturityInterest.toStringAsFixed(2)})";
            } else if (p.interest > 0) {
              paymentRemarks = "Historical Excel Import (Daily/Weekly Late Fee: ₹${p.interest.toStringAsFixed(2)})";
            } else {
              paymentRemarks = "Historical Excel Import";
            }

            final paymentToSave = CollectionPaymentModel(
              id: p.paymentModel?.id.isNotEmpty == true
                  ? p.paymentModel!.id
                  : "PAY-HIST-${targetEntryId}_${p.paymentDate.millisecondsSinceEpoch}",
              collectionId: targetEntryId,
              paymentAmount: p.amount,
              interest: p.interest > 0 ? p.interest : (p.paymentModel?.interest ?? 0.0),
              lateFine: 0.0,
              postMaturityInterest: p.postMaturityInterest > 0 ? p.postMaturityInterest : (p.paymentModel?.postMaturityInterest ?? 0.0),
              remainingBalance: newRemaining,
              paymentType: "Cash",
              roName: p.roName,
              roRoute: row.rawRoute.isNotEmpty ? row.rawRoute : "Office",
              createdAt: p.paymentDate,
              status: "Success",
              remarks: (p.paymentModel?.remarks?.isNotEmpty == true)
                  ? p.paymentModel!.remarks
                  : paymentRemarks,
            );

            // Pass saveToRemote: false to avoid sequential network calls (batch saved below)
            final saved = await collectionProvider.addCollectionPayment(
              paymentToSave,
              suppressNotification: true,
              saveToRemote: false,
            );
            if (saved) {
              insertedPayments.add(paymentToSave);
              totalImported += p.amount;
              totalLateFeesImported += p.interest;
              totalPostMatImported += p.postMaturityInterest;
              totalInterestImported += (p.interest + p.postMaturityInterest);
              rowAmountImported += p.amount;
            } else {
              failures.add(p.interest > 0 && p.amount == 0
                  ? "Failed to save daily/weekly late fee of ₹${p.interest.toStringAsFixed(2)} on ${p.formattedDate} for ${row.rawLoaneeName}"
                  : p.postMaturityInterest > 0 && p.amount == 0
                      ? "Failed to save post maturity interest of ₹${p.postMaturityInterest.toStringAsFixed(2)} on ${p.formattedDate} for ${row.rawLoaneeName}"
                      : "Failed to save payment of ₹${p.amount.toStringAsFixed(2)} on ${p.formattedDate} for ${row.rawLoaneeName}");
            }
          }

          // Update Loanee record in memory & provider once per loanee row
          final custId = row.resolvedLoanee?.customerId ?? row.rawCustomerId;
          final accNo = row.resolvedLoanee?.accountNumber ?? row.rawAccountNumber;
          if (custId.isNotEmpty || accNo.isNotEmpty) {
            loaneeProvider.recordPaymentForLoanee(
              customerId: custId,
              accountNumber: accNo,
              paymentAmount: rowAmountImported,
              newRemainingBalance: runningBalance,
            );
            final updatedLoanee = loaneeProvider.loanees.cast<LoaneeAccount?>().firstWhere(
              (l) => l != null &&
                  ((custId.isNotEmpty && l.customerId.trim().toLowerCase() == custId.trim().toLowerCase()) ||
                   (accNo.isNotEmpty && l.accountNumber.trim().toLowerCase() == accNo.trim().toLowerCase())),
              orElse: () => null,
            );
            if (updatedLoanee != null) {
              affectedLoanees[updatedLoanee.customerId] = updatedLoanee;
            }
          }

          debugPrint('----------------------------------------------------------------------');
          debugPrint('Total collected from all imported payment records: ₹${runningTotalCollected.toStringAsFixed(2)}');
          debugPrint('Remaining before overdue/additional interest: ₹${(initialBal - runningTotalCollected).toStringAsFixed(2)}');
          debugPrint('Accumulated overdue/additional interest: ₹${runningCumulativeInterest.toStringAsFixed(2)}');
          debugPrint('Final remaining balance: ₹${runningBalance.toStringAsFixed(2)}');
          debugPrint('======================================================================');
        }

        // Notify collection provider once for all newly added payments and entries
        collectionProvider.notifyChanges();

        // Batch persist to Supabase if connected
        try {
          if (supa.isInitialized && createdEntries.isNotEmpty) {
            await supa.saveCollectionEntriesBatch(createdEntries);
          }
          if (supa.isInitialized && insertedPayments.isNotEmpty) {
            await supa.saveCollectionPaymentsBatch(insertedPayments);
          }
          if (supa.isInitialized && affectedLoanees.isNotEmpty) {
            await supa.saveLoaneeAccountsBatch(affectedLoanees.values.toList());
          }
        } catch (dbErr) {
          debugPrint("⚠️ Supabase background sync note: $dbErr");
        }

        final bool overallSuccess = insertedPayments.isNotEmpty || createdEntries.isNotEmpty;

        return HistoricalImportExecutionResult(
          success: overallSuccess,
          collectionEntriesCreatedCount: createdEntries.length,
          paymentsInsertedCount: insertedPayments.length,
          totalAmountImported: totalImported,
          totalInterestImported: totalInterestImported,
          totalLateFeesImported: totalLateFeesImported,
          totalPostMatImported: totalPostMatImported,
          duplicatePaymentsSkippedCount: duplicateSkipped,
          errorMessage: failures.isNotEmpty ? failures.join("\n") : null,
          failureDetails: failures,
        );
      } catch (e) {
        debugPrint("❌ Fatal exception during transactional import: $e");

        // Attempt rollback of created entries and payments
        try {
          for (final payment in insertedPayments) {
            collectionProvider.handleRealtimePaymentDelete(payment.id);
            if (supa.isInitialized) {
              await supa.deleteCollectionPayment(payment.id);
            }
          }
          for (final entry in createdEntries) {
            collectionProvider.handleRealtimeEntryDelete(entry.id);
            if (supa.isInitialized) {
              await supa.deleteCollectionEntry(entry.id);
            }
          }
        } catch (rollbackErr) {
          debugPrint("⚠️ Error during rollback: $rollbackErr");
        }

        return HistoricalImportExecutionResult(
          success: false,
          errorMessage: "Import failed and was rolled back: $e",
          failureDetails: [e.toString()],
        );
      }
    });
  }
}
