// lib/services/witness_excel_import_service.dart

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
import '../services/supabase_service.dart';

/// Single parsed row record representing one Witness mapped to an existing Loanee
class WitnessImportRowRecord {
  final int rowIndex; // 1-indexed row number from Excel
  final String rawCustomerId;
  final String rawAccountNumber;
  final String rawWitnessName;
  final String rawWitnessGuardianName;
  final String rawWitnessAddress;
  final String rawWitnessBusinessType;
  final String rawWitnessPostOffice;
  final String rawWitnessPoliceStation;
  final String rawWitnessDistrict;
  final String rawWitnessPinCode;
  final String rawWitnessMobileNo;
  final String rawWitnessAadhaarNo;
  final String rawWitnessRelationship;

  final LoaneeAccount? matchedLoanee;
  final LoaneeAccount? updatedLoanee;
  final bool isValid;
  final bool isDuplicate;
  final String? errorMessage;
  final List<String> warnings;

  WitnessImportRowRecord({
    required this.rowIndex,
    required this.rawCustomerId,
    required this.rawAccountNumber,
    required this.rawWitnessName,
    this.rawWitnessGuardianName = '',
    this.rawWitnessAddress = '',
    this.rawWitnessBusinessType = '',
    this.rawWitnessPostOffice = '',
    this.rawWitnessPoliceStation = '',
    this.rawWitnessDistrict = '',
    this.rawWitnessPinCode = '',
    this.rawWitnessMobileNo = '',
    this.rawWitnessAadhaarNo = '',
    this.rawWitnessRelationship = '',
    this.matchedLoanee,
    this.updatedLoanee,
    required this.isValid,
    this.isDuplicate = false,
    this.errorMessage,
    this.warnings = const [],
  });
}

/// Full aggregate preview result before committing Witness updates to DB
class WitnessImportPreviewResult {
  final int totalRows;
  final int validRowsCount;
  final int invalidRowsCount;
  final int duplicateRowsCount;
  final List<WitnessImportRowRecord> rowRecords;
  final List<String> fileValidationErrors;

  WitnessImportPreviewResult({
    required this.totalRows,
    required this.validRowsCount,
    required this.invalidRowsCount,
    required this.duplicateRowsCount,
    required this.rowRecords,
    this.fileValidationErrors = const [],
  });

  bool get hasFileErrors => fileValidationErrors.isNotEmpty;
  bool get canImport => validRowsCount > 0 && !hasFileErrors;

  /// Summary string formatted as: Total: X | Valid: Y | Failed: Z
  String get summaryString =>
      'Total: $totalRows | Valid: $validRowsCount | Failed: $invalidRowsCount';
}

/// Outcome of executing the database update for witnesses
class WitnessImportExecutionResult {
  final bool success;
  final int total;
  final int imported;
  final int failed;
  final String? errorMessage;

  WitnessImportExecutionResult({
    required this.success,
    required this.total,
    required this.imported,
    required this.failed,
    this.errorMessage,
  });

  /// Exact summary string format: Total: X | Imported: Y | Failed: Z
  String get summaryText => 'Total: $total | Imported: $imported | Failed: $failed';
}

/// Dedicated Service for importing Loanee Witness Excel spreadsheets
class WitnessExcelImportService {
  static const String templateAssetPath = 'assets/template/loanee_witness.xlsx';
  static const String templateSheetName = 'Loanee Witness';

  static const List<String> headers = [
    'Customer ID',
    'Account Number',
    'Witness Name',
    'Witness Guardian Name',
    'Witness Address',
    'Witness Business Type',
    'Witness Post Office',
    'Witness Police Station',
    'Witness District',
    'Witness PIN Code',
    'Witness Mobile No',
    'Witness Aadhaar No',
    'Witness Relationship',
  ];

  /// Standard normalized headers for case-insensitive matching
  static final List<String> normalizedHeaders =
      headers.map((h) => _normalizeHeader(h)).toList();

  static String _normalizeHeader(String header) {
    return header.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');
  }

  /// Generate a valid Witness Excel workbook as fallback bytes
  static List<int> generateTemplateExcelBytes() {
    final excelDoc = Excel.createExcel();
    final defaultSheet = excelDoc.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != templateSheetName) {
      excelDoc.rename(defaultSheet, templateSheetName);
    }
    final sheet = excelDoc[templateSheetName];

    // Write Header Row
    for (int col = 0; col < headers.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
    }

    // Write Sample Row
    final sampleValues = [
      '2026LA000001',
      'MF2026A000001',
      'Suresh Kumar',
      'S/O Ram Kumar',
      'Main Road, Guwahati',
      'Small Business',
      'Dispur',
      'Dispur',
      'Kamrup Metro',
      '781006',
      '9876501234',
      'XXXX XXXX 5678',
      'Friend',
    ];

    for (int col = 0; col < sampleValues.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1));
      cell.value = TextCellValue(sampleValues[col]);
    }

    return excelDoc.save() ?? [];
  }

  /// Download or share the existing `assets/template/loanee_witness.xlsx`
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
          name: 'loanee_witness.xlsx',
        );
        await Share.shareXFiles([xfile],
            text: 'Mangang Finance - Loanee Witness Excel Template');
        return true;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/loanee_witness.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Loanee Witness Excel Template',
        text:
            'Download and fill witness details in this Excel template to bulk import into Mangang Finance.',
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
                    'Template ready! (${result.status.name}) File: loanee_witness.xlsx'),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error downloading Loanee Witness template: $e');
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

  /// Pick an Excel (.xlsx/.xls) or CSV file and parse rows into WitnessImportPreviewResult
  static Future<WitnessImportPreviewResult?> pickAndParseWitnessExcel({
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
      debugPrint('❌ Error picking/parsing Loanee Witness Excel: $e');
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

  /// Convert cell to trimmed string value safely
  static String getCellString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    if (val is TextCellValue) return val.value.text?.trim() ?? '';
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) {
      if (val.value % 1 == 0) {
        return val.value.toInt().toString();
      }
      return val.value.toString();
    }
    if (val is DateCellValue) {
      final d = val.asDateTimeUtc();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    if (val is DateTimeCellValue) {
      final d = val.asDateTimeUtc();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    return val.toString().trim();
  }

  /// Parse workbook bytes from memory against existing Loanees
  static WitnessImportPreviewResult parseWorkbookBytes({
    required List<int> bytes,
    required List<LoaneeAccount> existingLoanees,
  }) {
    if (bytes.isEmpty) {
      return WitnessImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        rowRecords: [],
        fileValidationErrors: ['The selected file is empty.'],
      );
    }

    Excel? excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      // Check if it's CSV
      try {
        final csvStr = utf8.decode(bytes, allowMalformed: true);
        final parsed = parseCsvString(csvStr);
        if (parsed.isNotEmpty) {
          return _parseCsvRows(parsed, existingLoanees);
        }
      } catch (_) {}

      return WitnessImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        rowRecords: [],
        fileValidationErrors: ['Invalid Excel format or corrupt file: $e'],
      );
    }

    // Resolve Sheet
    Sheet? targetSheet;
    for (final name in [templateSheetName, 'Loanee Witness', 'Witness', 'Sheet1']) {
      if (excel.tables.containsKey(name)) {
        targetSheet = excel.tables[name];
        break;
      }
    }
    targetSheet ??= excel.tables.values.firstOrNull;

    if (targetSheet == null || targetSheet.maxRows <= 0) {
      return WitnessImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        rowRecords: [],
        fileValidationErrors: ['No data sheets found in Excel file.'],
      );
    }

    final rows = targetSheet.rows;
    if (rows.isEmpty) {
      return WitnessImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        rowRecords: [],
        fileValidationErrors: ['The Excel worksheet is empty.'],
      );
    }

    // Map Column Headers from Row 0
    final headerRow = rows[0];
    final headerMap = <String, int>{};
    for (int col = 0; col < headerRow.length; col++) {
      final str = getCellString(headerRow[col]);
      if (str.isNotEmpty) {
        headerMap[_normalizeHeader(str)] = col;
      }
    }

    // Required column positions
    int findCol(String headerName, {List<String> altNames = const []}) {
      final norm = _normalizeHeader(headerName);
      if (headerMap.containsKey(norm)) return headerMap[norm]!;
      for (final alt in altNames) {
        final normAlt = _normalizeHeader(alt);
        if (headerMap.containsKey(normAlt)) return headerMap[normAlt]!;
      }
      return -1;
    }

    final custIdCol = findCol('Customer ID', altNames: ['CustID', 'Loanee ID']);
    final accNoCol = findCol('Account Number', altNames: ['Account No', 'AcNo', 'Account']);
    final nameCol = findCol('Witness Name', altNames: ['Name', 'Witness']);
    final guardianCol = findCol('Witness Guardian Name', altNames: ['Guardian Name', 'Father Name', 'Husband Name']);
    final addressCol = findCol('Witness Address', altNames: ['Address', 'Location']);
    final businessCol = findCol('Witness Business Type', altNames: ['Business Type', 'Occupation']);
    final poCol = findCol('Witness Post Office', altNames: ['Post Office', 'PO']);
    final psCol = findCol('Witness Police Station', altNames: ['Police Station', 'PS']);
    final distCol = findCol('Witness District', altNames: ['District']);
    final pinCol = findCol('Witness PIN Code', altNames: ['PIN Code', 'PIN', 'Postal Code']);
    final mobileCol = findCol('Witness Mobile No', altNames: ['Mobile No', 'Mobile', 'Phone']);
    final aadharCol = findCol('Witness Aadhaar No', altNames: ['Aadhaar No', 'Aadhaar', 'UIDAI']);
    final relCol = findCol('Witness Relationship', altNames: ['Relationship', 'Relation']);

    if (custIdCol == -1 && accNoCol == -1) {
      return WitnessImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        rowRecords: [],
        fileValidationErrors: [
          'Required mapping columns "Customer ID" and/or "Account Number" were not found in the Excel header.'
        ],
      );
    }

    // Build Fast Lookup Maps for existing database Loanees
    // Mapping keys:
    // 1. custKey: customerId.toLowerCase()
    // 2. accKey: accountNumber.toLowerCase()
    // 3. combinedKey: customerId.toLowerCase() + '|' + accountNumber.toLowerCase()
    final dbByCustId = <String, LoaneeAccount>{};
    final dbByAccNo = <String, LoaneeAccount>{};
    final dbByCombined = <String, LoaneeAccount>{};

    for (final loanee in existingLoanees) {
      final c = loanee.customerId.trim().toLowerCase();
      final a = loanee.accountNumber.trim().toLowerCase();
      if (c.isNotEmpty) dbByCustId[c] = loanee;
      if (a.isNotEmpty) dbByAccNo[a] = loanee;
      if (c.isNotEmpty && a.isNotEmpty) dbByCombined['$c|$a'] = loanee;
    }

    // Process Data Rows (Starting from Row 1)
    final List<WitnessImportRowRecord> parsedRecords = [];
    final filePairsSeen = <String, int>{}; // '$cust|$acc' -> first row index
    final fileMobilesSeen = <String, int>{};

    int validCount = 0;
    int invalidCount = 0;
    int duplicateCount = 0;

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      String getRawCol(int colIdx) {
        if (colIdx < 0 || colIdx >= row.length) return '';
        return getCellString(row[colIdx]);
      }

      final rawCust = getRawCol(custIdCol);
      final rawAcc = getRawCol(accNoCol);
      final rawName = getRawCol(nameCol);
      final rawGuardian = getRawCol(guardianCol);
      final rawAddress = getRawCol(addressCol);
      final rawBusiness = getRawCol(businessCol);
      final rawPo = getRawCol(poCol);
      final rawPs = getRawCol(psCol);
      final rawDist = getRawCol(distCol);
      final rawPin = getRawCol(pinCol);
      final rawMobile = getRawCol(mobileCol);
      final rawAadhaar = getRawCol(aadharCol);
      final rawRel = getRawCol(relCol);

      // Check if row is completely empty
      final allRowCells = [
        rawCust, rawAcc, rawName, rawGuardian, rawAddress, rawBusiness,
        rawPo, rawPs, rawDist, rawPin, rawMobile, rawAadhaar, rawRel
      ];
      if (allRowCells.every((cell) => cell.isEmpty)) {
        continue; // Skip empty rows
      }

      bool isRowValid = true;
      bool isRowDuplicate = false;
      String? rowError;
      final List<String> warnings = [];

      final normCust = rawCust.trim().toLowerCase();
      final normAcc = rawAcc.trim().toLowerCase();
      final cleanMobile = rawMobile.replaceAll(RegExp(r'\D'), '').trim();
      final cleanPin = rawPin.replaceAll(RegExp(r'\D'), '').trim();

      // 1. Validate Customer ID & Account ID existence in Excel
      if (normCust.isEmpty && normAcc.isEmpty) {
        isRowValid = false;
        rowError = 'Customer ID and Account Number are both missing.';
      } else if (normCust.isEmpty) {
        isRowValid = false;
        rowError = 'Customer ID is required.';
      } else if (normAcc.isEmpty) {
        isRowValid = false;
        rowError = 'Account Number is required.';
      }

      // 2. Validate Matching Loanee in Database
      LoaneeAccount? matchedLoanee;
      if (isRowValid) {
        final loaneeByCust = dbByCustId[normCust];
        final loaneeByAcc = dbByAccNo[normAcc];

        if (loaneeByCust == null && loaneeByAcc == null) {
          isRowValid = false;
          rowError = 'Customer ID "$rawCust" not found in database.';
        } else if (loaneeByCust == null) {
          isRowValid = false;
          rowError = 'Customer ID "$rawCust" not found.';
        } else if (loaneeByAcc == null) {
          isRowValid = false;
          rowError = 'Account Number "$rawAcc" not found in database.';
        } else if (loaneeByCust.customerId.trim().toLowerCase() !=
                   loaneeByAcc.customerId.trim().toLowerCase()) {
          // Both exist, but belong to different Loanees!
          isRowValid = false;
          rowError =
              'Customer ID "$rawCust" and Account Number "$rawAcc" do not belong to the same Loanee.';
        } else {
          matchedLoanee = loaneeByCust;
        }
      }

      // 3. Required Witness Fields Validation
      if (isRowValid) {
        if (rawName.isEmpty) {
          isRowValid = false;
          rowError = 'Witness Name is required.';
        } else if (rawName.length < 3) {
          isRowValid = false;
          rowError = 'Witness Name must be at least 3 letters.';
        } else if (rawGuardian.isEmpty) {
          isRowValid = false;
          rowError = 'Witness Guardian Name (W/O, S/O, D/O) is required.';
        } else if (rawAddress.isEmpty) {
          isRowValid = false;
          rowError = 'Witness Address is required.';
        } else if (rawRel.isEmpty) {
          isRowValid = false;
          rowError = 'Witness Relationship is required.';
        } else if (cleanMobile.isNotEmpty && cleanMobile.length != 10) {
          isRowValid = false;
          rowError = 'Witness Mobile Number must be 10 digits (got: "$rawMobile").';
        } else if (cleanPin.isNotEmpty && cleanPin.length != 6) {
          isRowValid = false;
          rowError = 'Witness PIN Code must be 6 digits (got: "$rawPin").';
        }
      }

      // 4. In-File Duplicate Checking
      if (isRowValid) {
        final pairKey = '$normCust|$normAcc';
        if (filePairsSeen.containsKey(pairKey)) {
          isRowValid = false;
          isRowDuplicate = true;
          rowError =
              'Duplicate witness row for Loanee $rawCust / $rawAcc in Excel (already in row #${filePairsSeen[pairKey]}).';
        } else {
          filePairsSeen[pairKey] = r + 1;
        }

        if (cleanMobile.isNotEmpty && cleanMobile.length == 10) {
          if (fileMobilesSeen.containsKey(cleanMobile)) {
            warnings.add(
                'Witness Mobile $rawMobile is repeated in file (row #${fileMobilesSeen[cleanMobile]}).');
          } else {
            fileMobilesSeen[cleanMobile] = r + 1;
          }
        }
      }

      // 5. Check if existing Loanee already has this exact witness data (Duplicate check)
      if (isRowValid && matchedLoanee != null) {
        final existingWitName = matchedLoanee.witnessName.trim().toLowerCase();
        final existingWitMobile = matchedLoanee.witnessMobileNo.replaceAll(RegExp(r'\D'), '').trim();
        if (existingWitName.isNotEmpty &&
            existingWitName == rawName.trim().toLowerCase() &&
            existingWitMobile.isNotEmpty &&
            existingWitMobile == cleanMobile) {
          warnings.add('Loanee already has this exact witness attached.');
        }
      }

      // 6. Construct Updated Loanee Model
      LoaneeAccount? updatedLoanee;
      if (isRowValid && matchedLoanee != null) {
        final businessVal = rawBusiness.isNotEmpty ? rawBusiness : 'Small Business';
        final distVal = rawDist.isNotEmpty ? rawDist : matchedLoanee.district;
        final poVal = rawPo.isNotEmpty ? rawPo : matchedLoanee.postOffice;
        final psVal = rawPs.isNotEmpty ? rawPs : matchedLoanee.policeStation;
        final pinVal = cleanPin.isNotEmpty ? cleanPin : matchedLoanee.pinCode;

        updatedLoanee = matchedLoanee.copyWith(
          witnessname: rawName,
          witnessguardianname: rawGuardian,
          witnessaddress: rawAddress,
          witnessbusinesstype: businessVal,
          witnesspostoffice: poVal,
          witnesspolicestation: psVal,
          witnessdistrict: distVal,
          witnesspincode: pinVal,
          witnessmobileno: cleanMobile.isNotEmpty ? cleanMobile : rawMobile,
          witnessaadharno: rawAadhaar,
          witnessrelationship: rawRel,
        );
      }

      if (isRowValid) {
        validCount++;
      } else {
        if (isRowDuplicate) {
          duplicateCount++;
        }
        invalidCount++;
      }

      parsedRecords.add(
        WitnessImportRowRecord(
          rowIndex: r + 1, // 1-indexed row number
          rawCustomerId: rawCust,
          rawAccountNumber: rawAcc,
          rawWitnessName: rawName,
          rawWitnessGuardianName: rawGuardian,
          rawWitnessAddress: rawAddress,
          rawWitnessBusinessType: rawBusiness,
          rawWitnessPostOffice: rawPo,
          rawWitnessPoliceStation: rawPs,
          rawWitnessDistrict: rawDist,
          rawWitnessPinCode: rawPin,
          rawWitnessMobileNo: rawMobile,
          rawWitnessAadhaarNo: rawAadhaar,
          rawWitnessRelationship: rawRel,
          matchedLoanee: matchedLoanee,
          updatedLoanee: updatedLoanee,
          isValid: isRowValid,
          isDuplicate: isRowDuplicate,
          errorMessage: rowError,
          warnings: warnings,
        ),
      );
    }

    return WitnessImportPreviewResult(
      totalRows: parsedRecords.length,
      validRowsCount: validCount,
      invalidRowsCount: invalidCount,
      duplicateRowsCount: duplicateCount,
      rowRecords: parsedRecords,
    );
  }

  /// Parse CSV string split into rows
  static List<List<String>> parseCsvString(String csvText) {
    final List<List<String>> rows = [];
    final lines = const LineSplitter().convert(csvText);
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final row = <String>[];
      final regex = RegExp(r'(?:^|,)(?:"([^"]*(?:""[^"]*)*)"|([^",]*))');
      for (final match in regex.allMatches(line)) {
        String val;
        if (match.group(1) != null) {
          val = match.group(1)!.replaceAll('""', '"');
        } else {
          val = match.group(2) ?? '';
        }
        row.add(val.trim());
      }
      rows.add(row);
    }
    return rows;
  }

  static WitnessImportPreviewResult _parseCsvRows(
    List<List<String>> rows,
    List<LoaneeAccount> existingLoanees,
  ) {
    if (rows.isEmpty) {
      return WitnessImportPreviewResult(
        totalRows: 0,
        validRowsCount: 0,
        invalidRowsCount: 0,
        duplicateRowsCount: 0,
        rowRecords: [],
        fileValidationErrors: ['CSV file is empty.'],
      );
    }

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

  /// Convenience method to parse raw CSV content directly
  static WitnessImportPreviewResult parseCsvContent(
    String csvText, {
    required List<LoaneeAccount> existingLoanees,
  }) {
    final parsed = parseCsvString(csvText);
    return _parseCsvRows(parsed, existingLoanees);
  }

  /// Execute batch database update with notification suppression
  static Future<WitnessImportExecutionResult> executeImport({
    required BuildContext context,
    required List<WitnessImportRowRecord> validRows,
    required LoaneeProvider loaneeProvider,
  }) async {
    if (validRows.isEmpty) {
      return WitnessImportExecutionResult(
        success: false,
        total: 0,
        imported: 0,
        failed: 0,
        errorMessage: 'No valid witness rows to import.',
      );
    }

    final updatedLoanees = validRows
        .where((r) => r.isValid && r.updatedLoanee != null)
        .map((r) => r.updatedLoanee!)
        .toList();

    if (updatedLoanees.isEmpty) {
      return WitnessImportExecutionResult(
        success: false,
        total: validRows.length,
        imported: 0,
        failed: validRows.length,
        errorMessage: 'No valid updated loanees constructed.',
      );
    }

    final supa = SupabaseService.instance;

    // Requirement 11: Suppress individual notifications during bulk import
    final result = await supa.runWithNotificationSuppression(() async {
      return await loaneeProvider
          .updateWitnessesBatchWithConnectionCheck(updatedLoanees);
    });

    final success = result['success'] == true;
    final importedCount = success ? updatedLoanees.length : 0;
    final failedCount = success ? 0 : updatedLoanees.length;

    return WitnessImportExecutionResult(
      success: success,
      total: validRows.length,
      imported: importedCount,
      failed: failedCount,
      errorMessage: success ? null : (result['message'] ?? 'Import failed.'),
    );
  }
}
