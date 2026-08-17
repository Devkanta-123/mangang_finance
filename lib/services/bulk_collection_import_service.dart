// lib/services/bulk_collection_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';

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
  final String? errorMessage;
  final RoCollectionEntry? entryModel;

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
    this.errorMessage,
    this.entryModel,
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

  /// Pick an Excel (.xlsx/.xls) or CSV file and parse rows into RoCollectionEntry items
  static Future<List<BulkCollectionEntryRowResult>?> pickAndParseBulkCollectionEntries({
    required BuildContext context,
    required CollectionSheetProvider collectionProvider,
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

      final existingEntries = collectionProvider.collectionEntries;
      final availableRoutes = collectionProvider.routeNames;
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

        bool isValid = true;
        String? error;

        if (nameVal.isEmpty) {
          isValid = false;
          error = 'Loanee Name is required';
        } else if (accVal.isEmpty && custVal.isEmpty) {
          isValid = false;
          error = 'Account Number or Customer ID is required';
        } else {
          // Check for duplicate in existing collection sheet
          final isDuplicate = existingEntries.any((e) =>
              (accVal.isNotEmpty && e.accountNumber.toLowerCase().trim() == accVal.toLowerCase().trim()) ||
              (custVal.isNotEmpty && e.customerId.toLowerCase().trim() == custVal.toLowerCase().trim()));

          if (isDuplicate) {
            isValid = false;
            error = 'Collection card already registered for Acc: "$accVal" / Cust: "$custVal"';
          }
        }

        RoCollectionEntry? entryModel;
        if (isValid) {
          final resolvedCustId = custVal.isNotEmpty ? custVal : 'CUST-${1000 + i}';
          final resolvedAccNo = accVal.isNotEmpty ? accVal : 'ACC-${88239000 + i}';

          entryModel = RoCollectionEntry(
            id: 'COL-${DateTime.now().millisecondsSinceEpoch}-$i',
            customerId: resolvedCustId,
            accountNumber: resolvedAccNo,
            loaneeName: nameVal,
            loaneeAddress: addrVal.isNotEmpty ? addrVal : 'N/A',
            collectionType: typeVal,
            route: routeVal,
            mobileNo: phoneVal.isNotEmpty ? phoneVal : '',
            status: statusVal,
          );
        }

        parsedResults.add(
          BulkCollectionEntryRowResult(
            rowIndex: i + 1,
            customerId: custVal,
            accountNumber: accVal,
            loaneeName: nameVal,
            loaneeAddress: addrVal,
            mobileNo: phoneVal,
            collectionType: typeVal,
            route: routeVal,
            status: statusVal,
            isValid: isValid,
            errorMessage: error,
            entryModel: entryModel,
          ),
        );
      }

      return parsedResults;
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
      if (!row.isValid || row.entryModel == null) {
        failedCount++;
        failedMessages.add('Row ${row.rowIndex}: ${row.errorMessage ?? "Invalid record"}');
        continue;
      }

      final success = await collectionProvider.addCollectionEntry(row.entryModel!);
      if (success) {
        addedCount++;
      } else {
        failedCount++;
        failedMessages.add('Row ${row.rowIndex}: Failed to save collection card entry.');
      }
    }

    return {
      'addedCount': addedCount,
      'failedCount': failedCount,
      'failedMessages': failedMessages,
    };
  }
}
