// lib/services/bulk_collection_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/loanee_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import 'package:provider/provider.dart';

class BulkCollectionEntryRowResult {
  final int rowIndex;
  final String customerId;
  final String accountNumber;
  final String loaneeName;
  final String loaneeAddress;
  final String mobileNo;
  final String collectionType;
  final String route;
  final String status;
  final bool isValid;
  final bool isDuplicate;
  final String? errorMessage;
  final RoCollectionEntry? entryModel;
  final LoaneeAccount? matchedLoanee;

  BulkCollectionEntryRowResult({
    required this.rowIndex,
    required this.customerId,
    required this.accountNumber,
    required this.loaneeName,
    required this.loaneeAddress,
    required this.mobileNo,
    required this.collectionType,
    required this.route,
    this.status = 'Active',
    required this.isValid,
    this.isDuplicate = false,
    this.errorMessage,
    this.entryModel,
    this.matchedLoanee,
  });
}

class BulkCollectionImportService {
  static const String templateSheetName = 'Bulk_Collection_Entries';

  /// Standard Headers for RoCollectionEntry Excel/CSV Template
  static const List<String> headers = [
    'Customer_ID',
    'Account_Number',
    'Loanee_Name',
    'Loanee_Address',
    'Mobile_No',
    'Collection_Type',
    'Route',
    'Status'
  ];

  /// Generate Dummy Template Excel bytes with exactly 1 sample RoCollectionEntry record
  static List<int> generateTemplateExcelBytes({RoCollectionEntry? sampleEntry}) {
    final excelDoc = Excel.createExcel();
    final defaultSheet = excelDoc.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != templateSheetName) {
      excelDoc.rename(defaultSheet, templateSheetName);
    }

    final Sheet sheet = excelDoc[templateSheetName];

    // Header styling
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#8B1A1A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // 1. Add Header row
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // 2. Add exactly 1 dummy sample record for RoCollectionEntry
    final cust = sampleEntry?.customerId.isNotEmpty == true
        ? sampleEntry!.customerId
        : 'CUST-1001';
    final acc = sampleEntry?.accountNumber.isNotEmpty == true
        ? sampleEntry!.accountNumber
        : 'ACC-88239101';
    final name = sampleEntry?.loaneeName.isNotEmpty == true
        ? sampleEntry!.loaneeName
        : 'Thoiba Singh';
    final addr = sampleEntry?.loaneeAddress.isNotEmpty == true
        ? sampleEntry!.loaneeAddress
        : 'Imphal West Market';
    final phone = sampleEntry?.mobileNo.isNotEmpty == true
        ? sampleEntry!.mobileNo
        : '9876543210';
    final colType = sampleEntry?.collectionType.isNotEmpty == true
        ? sampleEntry!.collectionType
        : 'Daily';
    final route = sampleEntry?.route.isNotEmpty == true
        ? sampleEntry!.route
        : 'Office';

    final sampleRow = [
      TextCellValue(cust),
      TextCellValue(acc),
      TextCellValue(name),
      TextCellValue(addr),
      TextCellValue(phone),
      TextCellValue(colType),
      TextCellValue(route),
      TextCellValue('Active'),
    ];

    for (int col = 0; col < sampleRow.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1));
      cell.value = sampleRow[col];
    }

    // Auto fit column widths
    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 22.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 28.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 18.0);
    sheet.setColumnWidth(7, 14.0);

    return excelDoc.save() ?? [];
  }

  /// Generate CSV String as a fallback with exactly 1 sample record
  static String generateTemplateCsvString({RoCollectionEntry? sampleEntry}) {
    final cust = sampleEntry?.customerId.isNotEmpty == true
        ? sampleEntry!.customerId
        : 'CUST-1001';
    final acc = sampleEntry?.accountNumber.isNotEmpty == true
        ? sampleEntry!.accountNumber
        : 'ACC-88239101';
    final name = sampleEntry?.loaneeName.isNotEmpty == true
        ? sampleEntry!.loaneeName
        : 'Thoiba Singh';
    final addr = sampleEntry?.loaneeAddress.isNotEmpty == true
        ? sampleEntry!.loaneeAddress
        : 'Imphal West Market';
    final phone = sampleEntry?.mobileNo.isNotEmpty == true
        ? sampleEntry!.mobileNo
        : '9876543210';
    final colType = sampleEntry?.collectionType.isNotEmpty == true
        ? sampleEntry!.collectionType
        : 'Daily';
    final route = sampleEntry?.route.isNotEmpty == true
        ? sampleEntry!.route
        : 'Office';

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    buffer.writeln('"$cust","$acc","$name","$addr","$phone","$colType","$route","Active"');
    return buffer.toString();
  }

  /// Download or Share the Bulk Collection Template Excel file for RoCollectionEntry
  static Future<bool> downloadTemplate(BuildContext context, {RoCollectionEntry? sampleEntry}) async {
    try {
      final excelBytes = generateTemplateExcelBytes(sampleEntry: sampleEntry);

      if (kIsWeb) {
        final xfile = XFile.fromData(
          Uint8List.fromList(excelBytes),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: 'mangang_bulk_collection_template.xlsx',
        );
        await Share.shareXFiles([xfile], text: 'Mangang Finance - Loanee Collection Entry Template');
        return true;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/mangang_bulk_collection_template.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excelBytes);

      // Trigger native share/save dialog for Android / iOS / Desktop
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Loanee Collection Sheet Entry Template',
        text: 'Download/Edit this template with loanee collection card records and upload to RO Collection Sheet.',
      );

      if (!context.mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Template ready! (${result.status.name}) File: mangang_bulk_collection_template.xlsx'),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('⚠️ Error generating/downloading Excel template: $e');

      // Fallback: Share CSV
      try {
        final csvStr = generateTemplateCsvString(sampleEntry: sampleEntry);
        final dir = await getTemporaryDirectory();
        final csvPath = '${dir.path}/mangang_bulk_collection_template.csv';
        final file = File(csvPath);
        await file.writeAsString(csvStr);

        await Share.shareXFiles(
          [XFile(csvPath)],
          subject: 'Loanee Collection Sheet Entry Template (CSV)',
          text: 'Mangang Finance Collection Entry Template (CSV)',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('CSV Template exported successfully!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
        return true;
      } catch (e2) {
        debugPrint('⚠️ Fallback CSV failed: $e2');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to export template: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return false;
      }
    }
  }

  /// Helper to parse CSV lines safely
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
            i++; // skip escaped quote
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

  /// Parse rows into BulkCollectionEntryRowResult items with loanee_accounts validation
  static List<BulkCollectionEntryRowResult> parseRows({
    required List<List<dynamic>> rawRows,
    required List<LoaneeAccount> existingLoanees,
    required List<RoCollectionEntry> existingEntries,
    List<String> availableRoutes = const [],
  }) {
    if (rawRows.isEmpty) return [];

    // Map column headers dynamically
    final headerRow = rawRows.first.map((e) => e.toString().toLowerCase().trim().replaceAll(' ', '_')).toList();

    int custCol = headerRow.indexWhere((h) => h.contains('customer') || h == 'cust_id' || h == 'cust');
    int accCol = headerRow.indexWhere((h) => h.contains('account') || h == 'acc_no' || h == 'acc');
    int nameCol = headerRow.indexWhere((h) => h.contains('name') || h == 'loanee');
    int addrCol = headerRow.indexWhere((h) => h.contains('address') || h == 'addr');
    int phoneCol = headerRow.indexWhere((h) => h.contains('mobile') || h.contains('phone') || h == 'contact');
    int typeCol = headerRow.indexWhere((h) => h.contains('type') || h == 'collection_type');
    int routeCol = headerRow.indexWhere((h) => h.contains('route'));
    int statusCol = headerRow.indexWhere((h) => h.contains('status'));

    // Fallback default indices if headers not recognized
    if (custCol == -1) custCol = 0;
    if (accCol == -1) accCol = 1;
    if (nameCol == -1) nameCol = 2;
    if (addrCol == -1) addrCol = 3;
    if (phoneCol == -1) phoneCol = 4;
    if (typeCol == -1) typeCol = 5;
    if (routeCol == -1) routeCol = 6;
    if (statusCol == -1) statusCol = 7;

    final dbByCustId = <String, LoaneeAccount>{};
    final dbByAccNo = <String, LoaneeAccount>{};

    for (final loanee in existingLoanees) {
      final c = loanee.customerId.trim().toLowerCase();
      final a = loanee.accountNumber.trim().toLowerCase();
      if (c.isNotEmpty) dbByCustId[c] = loanee;
      if (a.isNotEmpty) dbByAccNo[a] = loanee;
    }

    // Database duplicate trackers (already registered in RO Collection Sheet)
    final dbCustIdsInSheet = <String>{};
    final dbAccNosInSheet = <String>{};
    for (final entry in existingEntries) {
      final c = entry.customerId.trim().toLowerCase();
      final a = entry.accountNumber.trim().toLowerCase();
      if (c.isNotEmpty) dbCustIdsInSheet.add(c);
      if (a.isNotEmpty) dbAccNosInSheet.add(a);
    }

    // In-file duplicate trackers (mapping identifier -> first row index where seen)
    final fileCustIds = <String, int>{};
    final fileAccNos = <String, int>{};

    final List<BulkCollectionEntryRowResult> parsedResults = [];

    for (int i = 1; i < rawRows.length; i++) {
      final row = rawRows[i];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
        continue; // Skip empty rows
      }

      String getColVal(int colIdx) {
        if (colIdx >= 0 && colIdx < row.length) {
          return row[colIdx].toString().trim();
        }
        return '';
      }

      final custVal = getColVal(custCol);
      final accVal = getColVal(accCol);
      final nameVal = getColVal(nameCol);
      final addrVal = getColVal(addrCol);
      final phoneVal = getColVal(phoneCol);
      String typeVal = getColVal(typeCol);
      String routeVal = getColVal(routeCol);
      final statusVal = getColVal(statusCol).isNotEmpty ? getColVal(statusCol) : 'Active';

      // Normalizations
      if (typeVal.isEmpty) typeVal = 'Daily';
      if (routeVal.isEmpty) {
        routeVal = availableRoutes.isNotEmpty ? availableRoutes.first : 'Office';
      }

      final normCust = custVal.toLowerCase().trim();
      final normAcc = accVal.toLowerCase().trim();

      bool isValid = true;
      bool isRowDuplicate = false;
      String? error;
      LoaneeAccount? matchedLoanee;

      // 1. Loanee existence validation against loanee_accounts
      if (normCust.isEmpty && normAcc.isEmpty) {
        isValid = false;
        error = 'Customer ID and Account Number are both missing. Loanee must exist in loanee_accounts first.';
      } else if (normCust.isNotEmpty && normAcc.isNotEmpty) {
        final loaneeByCust = dbByCustId[normCust];
        final loaneeByAcc = dbByAccNo[normAcc];

        if (loaneeByCust == null && loaneeByAcc == null) {
          isValid = false;
          error = 'Loanee does not exist in loanee_accounts database (Customer ID: "$custVal", Account No: "$accVal"). Skipped.';
        } else if (loaneeByCust == null) {
          isValid = false;
          error = 'Customer ID "$custVal" does not exist in loanee_accounts database. Skipped.';
        } else if (loaneeByAcc == null) {
          isValid = false;
          error = 'Account Number "$accVal" does not exist in loanee_accounts database. Skipped.';
        } else if (loaneeByCust.customerId.trim().toLowerCase() != loaneeByAcc.customerId.trim().toLowerCase()) {
          isValid = false;
          error = 'Customer ID "$custVal" and Account Number "$accVal" belong to different loanee accounts in database. Skipped.';
        } else {
          matchedLoanee = loaneeByCust;
        }
      } else if (normCust.isNotEmpty) {
        final loaneeByCust = dbByCustId[normCust];
        if (loaneeByCust == null) {
          isValid = false;
          error = 'Customer ID "$custVal" does not exist in loanee_accounts database. Loanee must exist first.';
        } else {
          matchedLoanee = loaneeByCust;
        }
      } else {
        final loaneeByAcc = dbByAccNo[normAcc];
        if (loaneeByAcc == null) {
          isValid = false;
          error = 'Account Number "$accVal" does not exist in loanee_accounts database. Loanee must exist first.';
        } else {
          matchedLoanee = loaneeByAcc;
        }
      }

      // 2. Validate Loanee details & check for duplicates (In-file & Database)
      if (matchedLoanee != null && isValid) {
        final effectiveName = nameVal.isNotEmpty ? nameVal : matchedLoanee.loaneeName;
        if (effectiveName.isEmpty) {
          isValid = false;
          error = 'Loanee Name is required';
        } else {
          final resolvedCustId = matchedLoanee.customerId.trim();
          final resolvedAccNo = matchedLoanee.accountNumber.trim();
          final normResCust = resolvedCustId.toLowerCase();
          final normResAcc = resolvedAccNo.toLowerCase();

          // 2a. In-file duplicate check
          if (normResCust.isNotEmpty && fileCustIds.containsKey(normResCust)) {
            isValid = false;
            isRowDuplicate = true;
            error = 'Duplicate Customer ID "$resolvedCustId" in Excel (already in row #${fileCustIds[normResCust]}). Duplicate entry blocked.';
          } else if (normResAcc.isNotEmpty && fileAccNos.containsKey(normResAcc)) {
            isValid = false;
            isRowDuplicate = true;
            error = 'Duplicate Account Number "$resolvedAccNo" in Excel (already in row #${fileAccNos[normResAcc]}). Duplicate entry blocked.';
          }
          // 2b. Database duplicate check (against existing collection sheet records)
          else if (normResCust.isNotEmpty && dbCustIdsInSheet.contains(normResCust)) {
            isValid = false;
            isRowDuplicate = true;
            error = 'Loanee already registered / already exists in RO Collection Sheet with Customer ID "$resolvedCustId". Duplicate entry blocked.';
          } else if (normResAcc.isNotEmpty && dbAccNosInSheet.contains(normResAcc)) {
            isValid = false;
            isRowDuplicate = true;
            error = 'Loanee already registered / already exists in RO Collection Sheet with Account Number "$resolvedAccNo". Duplicate entry blocked.';
          }

          if (isValid) {
            if (normResCust.isNotEmpty) fileCustIds[normResCust] = i + 1;
            if (normResAcc.isNotEmpty) fileAccNos[normResAcc] = i + 1;
          }
        }
      }

      RoCollectionEntry? entryModel;
      if (isValid && !isRowDuplicate && matchedLoanee != null) {
        final resolvedCustId = matchedLoanee.customerId;
        final resolvedAccNo = matchedLoanee.accountNumber;
        final effectiveName = nameVal.isNotEmpty ? nameVal : matchedLoanee.loaneeName;
        final resolvedAddr = addrVal.isNotEmpty ? addrVal : (matchedLoanee.address.isNotEmpty ? matchedLoanee.address : 'N/A');
        final resolvedMobile = phoneVal.isNotEmpty ? phoneVal : matchedLoanee.mobileNo;

        entryModel = RoCollectionEntry(
          id: 'COL-${DateTime.now().millisecondsSinceEpoch}-$i',
          customerId: resolvedCustId,
          accountNumber: resolvedAccNo,
          loaneeName: effectiveName,
          loaneeAddress: resolvedAddr,
          collectionType: typeVal,
          route: routeVal,
          mobileNo: resolvedMobile,
          status: statusVal,
          loanAmount: matchedLoanee.loanAmount > 0 ? matchedLoanee.loanAmount : 0.0,
        );
      }

      parsedResults.add(
        BulkCollectionEntryRowResult(
          rowIndex: i + 1,
          customerId: custVal.isNotEmpty ? custVal : (matchedLoanee?.customerId ?? ''),
          accountNumber: accVal.isNotEmpty ? accVal : (matchedLoanee?.accountNumber ?? ''),
          loaneeName: nameVal.isNotEmpty ? nameVal : (matchedLoanee?.loaneeName ?? ''),
          loaneeAddress: addrVal.isNotEmpty ? addrVal : (matchedLoanee?.address ?? ''),
          mobileNo: phoneVal.isNotEmpty ? phoneVal : (matchedLoanee?.mobileNo ?? ''),
          collectionType: typeVal,
          route: routeVal,
          status: statusVal,
          isValid: isValid,
          isDuplicate: isRowDuplicate,
          errorMessage: error,
          entryModel: entryModel,
          matchedLoanee: matchedLoanee,
        ),
      );
    }

    return parsedResults;
  }

  /// Pick an Excel (.xlsx/.xls) or CSV file and parse rows into RoCollectionEntry items
  static Future<List<BulkCollectionEntryRowResult>?> pickAndParseBulkCollectionEntries({
    required BuildContext context,
    required CollectionSheetProvider collectionProvider,
    LoaneeProvider? loaneeProvider,
  }) async {
    try {
      final lp = loaneeProvider ?? Provider.of<LoaneeProvider>(context, listen: false);
      // Ensure both loanee_accounts and ro_collection_entries are fresh from Supabase
      try {
        await Future.wait([
          lp.fetchFromSupabase(),
          collectionProvider.fetchFromSupabase(),
        ]);
      } catch (syncErr) {
        debugPrint('⚠️ Pre-import sync note: $syncErr');
      }

      final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (pickedFiles.isEmpty) {
        return null;
      }

      final file = pickedFiles.first;
      final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
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
              content: const Text('Could not read file content. Please select a valid file.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return null;
      }

      final List<List<dynamic>> rawRows = [];

      if (extension == 'csv') {
        final csvString = utf8.decode(bytes, allowMalformed: true);
        final parsed = parseCsvString(csvString);
        rawRows.addAll(parsed);
      } else {
        // Excel (.xlsx or .xls)
        final excelDoc = Excel.decodeBytes(bytes);
        Sheet? sheet;
        if (excelDoc.tables.containsKey(templateSheetName)) {
          sheet = excelDoc.tables[templateSheetName];
        } else if (excelDoc.tables.isNotEmpty) {
          sheet = excelDoc.tables.values.first;
        }

        if (sheet == null || sheet.rows.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('The Excel file is empty.'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return null;
        }

        for (final row in sheet.rows) {
          final rowList = row.map((cell) => cell?.value?.toString() ?? '').toList();
          rawRows.add(rowList);
        }
      }

      if (rawRows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No records found in uploaded file.'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        return null;
      }

      return parseRows(
        rawRows: rawRows,
        existingLoanees: lp.loanees,
        existingEntries: collectionProvider.collectionEntries,
        availableRoutes: collectionProvider.routeNames,
      );
    } catch (e) {
      debugPrint('⚠️ Error picking/parsing bulk file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to parse file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return null;
    }
  }

  /// Process valid RoCollectionEntry rows and insert them into ro_collection_entries table
  static Future<Map<String, dynamic>> processBulkEntryUpload({
    required List<BulkCollectionEntryRowResult> validRows,
    required CollectionSheetProvider collectionProvider,
  }) async {
    int addedCount = 0;
    int failedCount = 0;
    List<String> failedMessages = [];

    for (final row in validRows) {
      if (!row.isValid || row.isDuplicate || row.entryModel == null) {
        failedCount++;
        failedMessages.add('Row ${row.rowIndex}: ${row.errorMessage ?? "Duplicate or invalid record blocked"}');
        continue;
      }

      final success = await collectionProvider.addCollectionEntry(row.entryModel!);
      if (success) {
        addedCount++;
      } else {
        failedCount++;
        failedMessages.add('Row ${row.rowIndex}: Failed to save collection card entry (duplicate or database error).');
      }
    }

    return {
      'addedCount': addedCount,
      'failedCount': failedCount,
      'failedMessages': failedMessages,
    };
  }
}
