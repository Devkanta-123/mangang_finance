// lib/services/historical_payment_import_service.dart

import "dart:io";
import "package:excel/excel.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "../models/collection_payment_model.dart";
import "../models/loanee_model.dart";
import "../models/ro_collection_entry_model.dart";
import "../models/route_model.dart";
import "../providers/collection_sheet_provider.dart";
import "../providers/loanee_provider.dart";
import "../providers/settings_provider.dart";
import "../services/supabase_service.dart";

/// Single parsed historical payment item from a date column
class HistoricalPaymentItem {
  final DateTime paymentDate;
  final double amount;
  final String roName;
  final bool isDuplicate;
  final String? errorMessage;
  final CollectionPaymentModel? paymentModel;

  HistoricalPaymentItem({
    required this.paymentDate,
    required this.amount,
    required this.roName,
    this.isDuplicate = false,
    this.errorMessage,
    this.paymentModel,
  });

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
    this.isUnmapped = false,
    this.errorMessage,
    this.warnings = const [],
  });

  /// Count of valid, non-duplicate payments in this row
  int get validPaymentsCount =>
      payments.where((p) => !p.isDuplicate && p.errorMessage == null && p.amount > 0).length;

  /// Count of duplicate payments in this row
  int get duplicatePaymentsCount => payments.where((p) => p.isDuplicate).length;

  /// Sum of valid non-duplicate payment amounts in this row
  double get totalRowAmount => payments
      .where((p) => !p.isDuplicate && p.errorMessage == null && p.amount > 0)
      .fold(0.0, (sum, p) => sum + p.amount);
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
    required this.rowRecords,
    this.fileValidationErrors = const [],
  });

  bool get hasFileErrors => fileValidationErrors.isNotEmpty;
  bool get canImport => validPaymentsCount > 0 && !hasFileErrors;
}

/// Outcome of executing the database import
class HistoricalImportExecutionResult {
  final bool success;
  final int collectionEntriesCreatedCount;
  final int paymentsInsertedCount;
  final double totalAmountImported;
  final int duplicatePaymentsSkippedCount;
  final String? errorMessage;
  final List<String> failureDetails;

  HistoricalImportExecutionResult({
    required this.success,
    this.collectionEntriesCreatedCount = 0,
    this.paymentsInsertedCount = 0,
    this.totalAmountImported = 0.0,
    this.duplicatePaymentsSkippedCount = 0,
    this.errorMessage,
    this.failureDetails = const [],
  });
}

class HistoricalPaymentImportService {
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

    // 6. Standard formats: DD/MM/YYYY, DD-MM-YYYY, YYYY/MM/DD, MM/DD/YYYY
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

    // Select first sheet with data
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

    // Find Header Row dynamically (look for row containing customer/account/loanee/name)
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

    // Fallback: If not found by full match, check if first non-empty row has header-like columns
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
          "Required header row not found. Ensure columns: Customer ID, Account No, Loanee Name, Route, Collection Types, Collected_BY."
        ],
      );
    }

    final headerRow = rawRows[headerRowIndex];

    // Identify Column Indices
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

      // Check if this column is a Date Header
      final parsedDate = parseDateValue(rawHeader);
      if (parsedDate != null) {
        dateColumns[c] = parsedDate;
      }
    }

    // Default Fallback Indices if fixed names not matched but positioned standardly
    if (custCol == -1 && headerRow.isNotEmpty) custCol = 0;
    if (accCol == -1 && headerRow.length > 1) accCol = 1;
    if (nameCol == -1 && headerRow.length > 2) nameCol = 2;
    if (routeCol == -1 && headerRow.length > 3) routeCol = 3;
    if (typeCol == -1 && headerRow.length > 4) typeCol = 4;
    if (collectedByCol == -1 && headerRow.length > 5) collectedByCol = 5;

    // Check if any date columns could be parsed
    if (dateColumns.isEmpty) {
      // Try parsing headers starting from index 6 onwards
      for (int c = 6; c < headerRow.length; c++) {
        final parsedDate = parseDateValue(headerRow[c]?.value);
        if (parsedDate != null) {
          dateColumns[c] = parsedDate;
        }
      }
    }

    if (dateColumns.isEmpty) {
      fileErrors.add("No valid payment date columns found in Excel header (e.g. 2026-07-01, 46204, or DD/MM/YYYY).");
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
      final dateKey = "${p.collectionId}:${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
      existingPaymentKeys.add(dateKey);
    }

    // In-file duplicate tracker (to prevent duplicates within the same import file)
    final filePaymentKeys = <String>{};

    final List<HistoricalImportRowRecord> parsedRowRecords = [];
    int validRowsCount = 0;
    int invalidRowsCount = 0;
    int unmappedRowsCount = 0;
    int totalPaymentsParsed = 0;
    int validPaymentsCount = 0;
    int duplicatePaymentsCount = 0;
    double totalAmountToImport = 0.0;

    final defaultRoute = existingRoutes.isNotEmpty ? existingRoutes.first.name : "Office";

    // Parse Data Rows
    for (int r = headerRowIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty || row.every((c) => c == null || c.value == null || c.value.toString().trim().isEmpty)) {
        continue; // Skip empty rows
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
      bool isRowUnmapped = false;

      // 1. Basic validation of row identifiers
      if (rawName.isEmpty && rawCustId.isEmpty && rawAccNo.isEmpty) {
        isRowValid = false;
        rowError = "Row is missing Customer ID, Account Number, and Loanee Name.";
      } else if (rawName.isEmpty) {
        isRowValid = false;
        rowError = "Loanee Name is required.";
      } else if (rawCustId.isEmpty && rawAccNo.isEmpty) {
        isRowValid = false;
        rowError = "Customer ID or Account Number is required.";
      }

      // 2. Resolve Loan Account Map
      LoaneeAccount? resolvedLoanee;
      if (rawCustId.isNotEmpty && loaneeByCustId.containsKey(rawCustId.toLowerCase())) {
        resolvedLoanee = loaneeByCustId[rawCustId.toLowerCase()];
      } else if (rawAccNo.isNotEmpty && loaneeByAccNo.containsKey(rawAccNo.toLowerCase())) {
        resolvedLoanee = loaneeByAccNo[rawAccNo.toLowerCase()];
      } else if (rawName.isNotEmpty && loaneeByName.containsKey(rawName.toLowerCase())) {
        resolvedLoanee = loaneeByName[rawName.toLowerCase()];
      }

      // 3. Resolve Collection Entry
      RoCollectionEntry? resolvedEntry;
      if (rawCustId.isNotEmpty && entryByCustId.containsKey(rawCustId.toLowerCase())) {
        resolvedEntry = entryByCustId[rawCustId.toLowerCase()];
      } else if (rawAccNo.isNotEmpty && entryByAccNo.containsKey(rawAccNo.toLowerCase())) {
        resolvedEntry = entryByAccNo[rawAccNo.toLowerCase()];
      } else if (resolvedLoanee != null) {
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
      final resolvedCust = rawCustId.isNotEmpty ? rawCustId : (resolvedLoanee?.customerId ?? "CUST-${1000 + r}");
      final resolvedAcc = rawAccNo.isNotEmpty ? rawAccNo : (resolvedLoanee?.accountNumber ?? "ACC-${88239000 + r}");

      if (isRowValid) {
        if (resolvedEntry == null) {
          // If no existing collection card exists, we can create one automatically or flag if loanee not found
          if (resolvedLoanee == null) {
            isRowUnmapped = true;
            warnings.add("Loan Account Map not found in existing loanee master; collection card will be auto-generated.");
          }

          newCollectionEntryNeeded = true;
          final double rawLoan = (resolvedLoanee != null && resolvedLoanee.loanAmount > 0)
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
            id: "COL-HIST-${DateTime.now().millisecondsSinceEpoch}-$r",
            customerId: resolvedCust,
            accountNumber: resolvedAcc,
            loaneeName: rawName.isNotEmpty ? rawName : (resolvedLoanee?.loaneeName ?? "Loanee $resolvedCust"),
            loaneeAddress: resolvedLoanee?.address ?? "Field Route Zone",
            collectionType: normType,
            route: normRoute,
            mobileNo: resolvedLoanee?.mobileNo ?? "",
            payableAmount: payableAmt,
            loanAmount: breakdown.loanAmount,
            actualPrincipal: breakdown.actualPrincipal,
            interestAmount: breakdown.interestAmount,
            interestRate: breakdown.interestRate,
            frequency: isDaily ? "Day" : "Week",
          );
        }
      }

      // 4. Parse Payments across all Date Columns for this row
      final targetCollectionId = resolvedEntry?.id ?? newCollectionEntry?.id ?? "COL-PENDING-$r";
      final List<HistoricalPaymentItem> rowPayments = [];

      // Sort date columns chronologically
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
          // Zero or negative payment (skip zero, flag negative)
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

        // Valid positive payment amount!
        totalPaymentsParsed++;

        // Duplicate Check against DB/Provider and within File
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
          // Mark as seen in this file
          filePaymentKeys.add(fileAccountKey);
          validPaymentsCount++;
          totalAmountToImport += parsedAmount;

          final paymentModel = CollectionPaymentModel(
            id: "PAY-HIST-${targetCollectionId}_${dateStr.replaceAll("-", "")}",
            collectionId: targetCollectionId,
            paymentAmount: parsedAmount,
            remainingBalance: 0.0, // Computed dynamically upon insertion
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

      try {
        // 1. Gather all new Collection Entries that must be created
        for (final row in previewResult.rowRecords) {
          if (!row.isValid) continue;

          if (row.newCollectionEntryNeeded && row.newCollectionEntry != null) {
            final newEntry = row.newCollectionEntry!;
            // Check if already in provider
            final existing = collectionProvider.getCollectionEntryById(newEntry.id);
            if (existing == null) {
              final saved = await collectionProvider.addCollectionEntry(newEntry);
              if (saved) {
                createdEntries.add(newEntry);
              } else {
                failures.add("Failed to create collection entry for ${row.rawLoaneeName} (${row.rawCustomerId})");
              }
            }
          }
        }

        // 2. Gather all valid, non-duplicate payments and record them
        for (final row in previewResult.rowRecords) {
          if (!row.isValid) continue;

          final targetEntryId = row.resolvedCollectionEntry?.id ?? row.newCollectionEntry?.id;
          if (targetEntryId == null) continue;

          for (final p in row.payments) {
            if (p.isDuplicate) {
              duplicateSkipped++;
              continue;
            }
            if (p.errorMessage != null || p.amount <= 0) {
              continue;
            }

            // Calculate correct remaining balance chronologically
            final currentPaid = collectionProvider.getTotalPaidForCollection(targetEntryId);
            final initialBal = row.resolvedCollectionEntry?.initialBalance ??
                row.newCollectionEntry?.initialBalance ??
                row.resolvedLoanee?.loanAmount ??
                11500.0;
            final newRemaining = (initialBal - (currentPaid + p.amount)).clamp(0.0, double.infinity);

            final paymentToSave = CollectionPaymentModel(
              id: p.paymentModel?.id.isNotEmpty == true
                  ? p.paymentModel!.id
                  : "PAY-HIST-${targetEntryId}_${p.paymentDate.millisecondsSinceEpoch}",
              collectionId: targetEntryId,
              paymentAmount: p.amount,
              remainingBalance: newRemaining,
              lateFine: 0.0,
              paymentType: "Cash",
              roName: p.roName,
              roRoute: row.rawRoute.isNotEmpty ? row.rawRoute : "Office",
              createdAt: p.paymentDate,
              status: "Success",
              remarks: "Historical Excel Import",
            );

            // Pass suppressNotification: true to ensure zero notifications during bulk import
            final saved = await collectionProvider.addCollectionPayment(
              paymentToSave,
              suppressNotification: true,
            );
            if (saved) {
              insertedPayments.add(paymentToSave);
              totalImported += p.amount;

              // Also update Loanee record in memory & provider
              final custId = row.resolvedLoanee?.customerId ?? row.rawCustomerId;
              final accNo = row.resolvedLoanee?.accountNumber ?? row.rawAccountNumber;
              if (custId.isNotEmpty || accNo.isNotEmpty) {
                loaneeProvider.recordPaymentForLoanee(
                  customerId: custId,
                  accountNumber: accNo,
                  paymentAmount: p.amount,
                  newRemainingBalance: newRemaining,
                );
              }
            } else {
              failures.add("Failed to save payment of ₹${p.amount} on ${p.formattedDate} for ${row.rawLoaneeName}");
            }
          }
        }

      // Batch persist to Supabase if connected
      try {
        if (supa.isInitialized && createdEntries.isNotEmpty) {
          await supa.saveCollectionEntriesBatch(createdEntries);
        }
        if (supa.isInitialized && insertedPayments.isNotEmpty) {
          await supa.saveCollectionPaymentsBatch(insertedPayments);
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
