// lib/widgets/loanee_excel_upload_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loanee_provider.dart';
import '../services/loanee_excel_import_service.dart';

class LoaneeExcelUploadDialog extends StatefulWidget {
  final LoaneeImportPreviewResult previewResult;
  final VoidCallback? onImportSuccess;

  const LoaneeExcelUploadDialog({
    super.key,
    required this.previewResult,
    this.onImportSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    required LoaneeImportPreviewResult previewResult,
    VoidCallback? onImportSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LoaneeExcelUploadDialog(
        previewResult: previewResult,
        onImportSuccess: onImportSuccess,
      ),
    );
  }

  @override
  State<LoaneeExcelUploadDialog> createState() =>
      _LoaneeExcelUploadDialogState();
}

class _LoaneeExcelUploadDialogState extends State<LoaneeExcelUploadDialog> {
  bool _isProcessing = false;

  int get _validCount => widget.previewResult.validRowsCount;
  int get _invalidCount => widget.previewResult.invalidRowsCount;

  Future<void> _handleConfirmUpload() async {
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);

    final validRows =
        widget.previewResult.rowRecords.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid loanee records available to import.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final executionResult = await LoaneeExcelImportService.executeImport(
      validRows: widget.previewResult.rowRecords,
      loaneeProvider: loaneeProvider,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    Navigator.of(context).pop(executionResult.success);

    if (widget.onImportSuccess != null && executionResult.success) {
      widget.onImportSuccess!();
    }

    // Show the summary dialog: Total: 100 | Imported: 95 | Failed: 5
    _showFinalSummaryDialog(context, executionResult);
  }

  static void _showFinalSummaryDialog(
      BuildContext context, LoaneeImportExecutionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: result.success
                  ? (result.failed > 0 ? Colors.orange.shade100 : Colors.green.shade100)
                  : Colors.red.shade100,
              child: Icon(
                result.success
                    ? (result.failed > 0
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_rounded)
                    : Icons.error_outline_rounded,
                color: result.success
                    ? (result.failed > 0
                        ? Colors.orange.shade800
                        : Colors.green.shade800)
                    : Colors.red.shade800,
                size: 34,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.success
                  ? 'Loanee Import Complete'
                  : 'Import Failed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Standard format Requirement 12: Total: 100 | Imported: 95 | Failed: 5
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                result.summaryText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (result.success) ...[
              Text(
                '${result.imported} loanee account(s) have been successfully saved to Supabase (loanee_accounts) and local database.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
              if (result.failed > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${result.failed} row(s) were skipped due to validation errors or duplicate records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800),
                ),
              ],
            ] else ...[
              Text(
                result.errorMessage ?? 'Database insertion error.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(120, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width > 700 ? 680 : double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.table_chart_rounded,
                    color: Colors.black87,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Excel Loanee Bulk Import Preview',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        'Validate loanee details and check for duplicates before import',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (!_isProcessing)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Stat Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    title: 'Total Rows',
                    value: '${widget.previewResult.totalRows}',
                    color: Colors.blue.shade800,
                    bgColor: Colors.blue.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip(
                    title: 'Valid Loanees',
                    value: '$_validCount',
                    color: Colors.green.shade800,
                    bgColor: Colors.green.shade50,
                  ),
                ),
                if (_invalidCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatChip(
                      title: 'Invalid / Dups',
                      value: '$_invalidCount',
                      color: Colors.red.shade800,
                      bgColor: Colors.red.shade50,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip(
                    title: 'Total Loan',
                    value: '₹${widget.previewResult.totalLoanAmount.toStringAsFixed(0)}',
                    color: Colors.teal.shade800,
                    bgColor: Colors.teal.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Parsed Rows Header
            const Text(
              'PARSED LOANEE RECORDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            // Parsed Rows List
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.previewResult.rowRecords.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 8),
                  itemBuilder: (ctx, index) {
                    final row = widget.previewResult.rowRecords[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: row.isValid
                            ? Colors.white
                            : Colors.red.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: row.isValid
                              ? Colors.grey.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            row.isValid
                                ? Icons.check_circle_rounded
                                : (row.isDuplicate
                                    ? Icons.copy_rounded
                                    : Icons.error_outline_rounded),
                            size: 18,
                            color: row.isValid
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      row.rawLoaneeName.isNotEmpty
                                          ? row.rawLoaneeName
                                          : 'Row #${row.rowIndex}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: row.isValid
                                            ? Colors.black87
                                            : Colors.red.shade900,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (row.rawCustomerId.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          row.rawCustomerId,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    if (row.rawAccountNumber.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          row.rawAccountNumber,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (!row.isValid && row.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      row.errorMessage!,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Mobile: ${row.rawMobileNo.isNotEmpty ? row.rawMobileNo : "N/A"} • Sanction: ${row.loaneeModel != null ? row.loaneeModel!.formattedSanctionDate : (row.rawSanctionDate.isNotEmpty ? row.rawSanctionDate : "Today")} • Maturity: ${row.loaneeModel != null ? row.loaneeModel!.formattedMaturityDate : (row.rawMaturityDate.isNotEmpty ? row.rawMaturityDate : "Auto")}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (row.rawLoanAmount.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                '₹${row.rawLoanAmount}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing || _validCount == 0
                        ? null
                        : _handleConfirmUpload,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(
                      _isProcessing
                          ? 'Importing Loanees...'
                          : 'Confirm Import ($_validCount Loanees)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 9.5,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
