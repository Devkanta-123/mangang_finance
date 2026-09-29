// lib/widgets/missing_records_excel_upload_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ro_collection_entry_model.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/settings_provider.dart';
import '../services/missing_records_excel_import_service.dart';

class MissingRecordsExcelUploadDialog extends StatefulWidget {
  final MissingExcelParseResult parseResult;

  const MissingRecordsExcelUploadDialog({
    super.key,
    required this.parseResult,
  });

  /// Alternate clean entry-point: picks file, parses, settles mouse tracking, and shows dialog
  static Future<bool?> pickAndShow(
    BuildContext context, {
    RoCollectionEntry? preselectedEntry,
  }) async {
    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);
    final loaneeProvider =
        Provider.of<LoaneeProvider>(context, listen: false);

    // Yield so button click pointer/hover events finish before opening OS file picker
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!context.mounted) return false;

    final parseResult =
        await MissingRecordsExcelImportService.pickAndParseMissingExcel(
      context: context,
      collectionProvider: collectionProvider,
      preselectedEntry: preselectedEntry,
      loaneeProvider: loaneeProvider,
    );

    if (parseResult == null) {
      return false;
    }

    if (!context.mounted) return false;

    if (!parseResult.hasValidRecords) {
      final errText = parseResult.fileErrors.isNotEmpty
          ? parseResult.fileErrors.first
          : (parseResult.sheets.isNotEmpty && parseResult.sheets.first.errors.isNotEmpty
              ? parseResult.sheets.first.errors.first
              : 'No valid missing payment records found in Excel.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errText),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }

    // Allow window focus and mouse tracking to settle before showing preview dialog
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MissingRecordsExcelUploadDialog(
        parseResult: parseResult,
      ),
    );

    // Settle pointer and route disposal before returning to caller
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return result;
  }

  /// Backward-compatible show method
  static Future<bool?> show(
    BuildContext context, {
    RoCollectionEntry? preselectedEntry,
  }) {
    return pickAndShow(context, preselectedEntry: preselectedEntry);
  }

  @override
  State<MissingRecordsExcelUploadDialog> createState() =>
      _MissingRecordsExcelUploadDialogState();
}

class _MissingRecordsExcelUploadDialogState
    extends State<MissingRecordsExcelUploadDialog> {
  bool _isImporting = false;
  MissingImportExecutionResult? _execResult;

  Future<void> _handleConfirmImport() async {
    if (!widget.parseResult.hasValidRecords || _isImporting) return;

    setState(() {
      _isImporting = true;
    });

    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final loaneeProvider =
        Provider.of<LoaneeProvider>(context, listen: false);

    final execResult =
        await MissingRecordsExcelImportService.executeTransactionalImport(
      parseResult: widget.parseResult,
      collectionProvider: collectionProvider,
      settingsProvider: settingsProvider,
      loaneeProvider: loaneeProvider,
    );

    if (!mounted) return;

    // Settle before updating state to avoid mouse tracker collisions during layout changes
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    setState(() {
      _isImporting = false;
      _execResult = execResult.success ? execResult : null;
    });

    if (!execResult.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to import missing records. Please check file format.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDone() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final bool isSmallScreen = screenWidth < 650;

    // Smaller, responsive modal sizing
    final double targetWidth = _execResult != null
        ? (screenWidth * 0.9).clamp(300.0, 480.0)
        : (screenWidth * 0.92).clamp(320.0, isSmallScreen ? 480.0 : 640.0);
    final double targetMaxHeight = (screenHeight * 0.82).clamp(360.0, 680.0);

    return ExcludeSemantics(
      child: AbsorbPointer(
        absorbing: _isImporting,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: targetWidth,
              maxHeight: targetMaxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _execResult != null
                  ? _buildSuccessView(_execResult!)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const Divider(height: 16),
                        Flexible(
                          child: _buildParsedReviewView(targetWidth),
                        ),
                        const SizedBox(height: 10),
                        _buildBottomActions(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B1A1A).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.upload_file_rounded,
            color: Color(0xFF8B1A1A),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Missing Records Excel Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B1A1A),
                ),
              ),
              Text(
                'Review parsed records before importing & resuming auto',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Close',
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildParsedReviewView(double targetWidth) {
    final res = widget.parseResult;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        res.fileName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '${res.totalRecordsToInsert} Missing Records',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...res.sheets.map((sheet) => _buildSheetCard(sheet)),
        ],
      ),
    );
  }

  Widget _buildSheetCard(MissingExcelCustomerSheetResult sheet) {
    final entry = sheet.matchedEntry;
    final auditDateStr = sheet.latestDateInSheet != null
        ? '${sheet.latestDateInSheet!.day}/${sheet.latestDateInSheet!.month}/${sheet.latestDateInSheet!.year}'
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: sheet.isValid ? Colors.grey.shade300 : Colors.red.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: sheet.isValid
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Icon(
                    sheet.isValid ? Icons.check_rounded : Icons.warning_rounded,
                    size: 14,
                    color: sheet.isValid ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry != null
                            ? '${entry.loaneeName} (${entry.accountNumber})'
                            : 'Unmatched Account (${sheet.rawAccountNumber})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${sheet.rawCustomerId} • Mob: ${sheet.rawMobileNo} • Route: ${entry?.route ?? "Unknown"}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Compact Stat Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  _buildStatItem('Miss Days', '${sheet.missingRows.length}', Colors.deepOrange),
                  _buildStatDivider(),
                  _buildStatItem('Miss Pay', '₹${sheet.totalMissingAmount.toStringAsFixed(0)}', Colors.black87),
                  _buildStatDivider(),
                  _buildStatItem('Miss Bal', '₹${sheet.totalMissingBalance.toStringAsFixed(1)}', const Color(0xFF8B1A1A)),
                  _buildStatDivider(),
                  _buildStatItem('Audit Thru', auditDateStr, Colors.blue.shade900),
                ],
              ),
            ),
            if (sheet.duplicateDates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Skipped ${sheet.duplicateDates.length} duplicate date(s) already recorded:\n${sheet.duplicateDates.map((d) => SettingsProvider.formatDate(d)).join(", ")}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            const Text(
              'PARSED MISSING PAYMENT ROWS:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 5),

            // Responsive Scrollable Table (Cannot squish or overflow)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 490,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 85, child: Text('Date', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                            SizedBox(width: 80, child: Text('Basic Pay', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                            SizedBox(width: 70, child: Text('Fine', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                            SizedBox(width: 65, child: Text('Weeks', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                            SizedBox(width: 80, child: Text('Balance', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                            SizedBox(width: 80, child: Text('Status', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sheet.missingRows.length > 8 ? 8 : sheet.missingRows.length,
                        separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (ctx, idx) {
                          final row = sheet.missingRows[idx];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            color: idx.isEven ? Colors.white : Colors.grey.shade50,
                            child: Row(
                              children: [
                                SizedBox(width: 85, child: Text(row.formattedDate, style: const TextStyle(fontSize: 10.5))),
                                SizedBox(width: 80, child: Text('₹${row.missingPay.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5))),
                                SizedBox(width: 70, child: Text('₹${row.missingFine.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10.5))),
                                SizedBox(width: 65, child: Text('${row.missingWeek} wk', style: const TextStyle(fontSize: 10.5))),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    '₹${row.missingBalance.toStringAsFixed(1)}',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A)),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    row.status == 'partially_resolved' ? 'Partial' : 'Missing',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: row.status == 'partially_resolved' ? Colors.orange.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (sheet.missingRows.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '+ ${sheet.missingRows.length - 8} more rows will be inserted',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String val, Color valColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: valColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(width: 1, height: 20, color: Colors.grey.shade300);

  Widget _buildBottomActions() {
    final bool canImport = widget.parseResult.hasValidRecords && !_isImporting;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(0, 34),
            textStyle: const TextStyle(fontSize: 11.5),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B1A1A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(0, 34),
          ),
          onPressed: canImport ? _handleConfirmImport : null,
          icon: _isImporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_rounded, size: 16),
          label: Text(
            _isImporting
                ? 'Inserting...'
                : 'Confirm & Insert Records',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(MissingImportExecutionResult execResult) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Missing Records Inserted',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E7E34),
                    ),
                  ),
                  Text(
                    'Historical missing records saved to database',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 18),
        Text(
          'Successfully inserted ${execResult.totalImportedRecords} historical missing records.',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Automation authorized: You can now click "Start Auto" in the table or modal to calculate missing dates forward.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E7E34),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...execResult.messages.map(
          (msg) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $msg',
              style: const TextStyle(fontSize: 10.5, color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              minimumSize: const Size(0, 34),
            ),
            onPressed: _handleDone,
            child: const Text('Done', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
