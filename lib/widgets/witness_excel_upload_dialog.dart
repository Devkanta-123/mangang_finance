// lib/widgets/witness_excel_upload_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loanee_provider.dart';
import '../services/witness_excel_import_service.dart';

class WitnessExcelUploadDialog extends StatefulWidget {
  final WitnessImportPreviewResult previewResult;
  final VoidCallback? onImportSuccess;

  const WitnessExcelUploadDialog({
    super.key,
    required this.previewResult,
    this.onImportSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    required WitnessImportPreviewResult previewResult,
    VoidCallback? onImportSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WitnessExcelUploadDialog(
        previewResult: previewResult,
        onImportSuccess: onImportSuccess,
      ),
    );
  }

  @override
  State<WitnessExcelUploadDialog> createState() =>
      _WitnessExcelUploadDialogState();
}

class _WitnessExcelUploadDialogState extends State<WitnessExcelUploadDialog> {
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
          content: Text('No valid witness records available to import.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final executionResult = await WitnessExcelImportService.executeImport(
      context: context,
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
      BuildContext context, WitnessImportExecutionResult result) {
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
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded)
                    : Icons.error_outline_rounded,
                color: result.success
                    ? (result.failed > 0
                        ? Colors.orange.shade800
                        : const Color(0xFF1B5E20))
                    : Colors.red.shade800,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.success ? 'Witness Import Completed' : 'Import Failed',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                result.summaryText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (result.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                result.errorMessage!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.red.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewResult;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: Colors.indigo,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Witness Excel Preview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Attach witness details to existing loanees',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Chips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  _buildStatChip(
                    label: 'Total Rows',
                    value: '${preview.totalRows}',
                    color: Colors.black87,
                    icon: Icons.list_alt_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    label: 'Valid Loanees',
                    value: '$_validCount',
                    color: const Color(0xFF2E7D32),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    label: 'Invalid / Errors',
                    value: '$_invalidCount',
                    color: _invalidCount > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                    icon: Icons.error_outline_rounded,
                  ),
                  if (preview.duplicateRowsCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      label: 'Duplicates',
                      value: '${preview.duplicateRowsCount}',
                      color: Colors.orange.shade800,
                      icon: Icons.copy_rounded,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Rows List Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Parsed Rows (${preview.rowRecords.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Mapped by: Customer ID + Account No',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Scrollable List of Parsed Rows
            Expanded(
              child: preview.rowRecords.isEmpty
                  ? Center(
                      child: Text(
                        'No rows found in this file.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: preview.rowRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final record = preview.rowRecords[index];
                        return _buildRowRecordTile(record);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _validCount > 0 ? Colors.black : Colors.grey.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: (_isProcessing || _validCount == 0)
              ? null
              : _handleConfirmUpload,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_isProcessing
              ? 'Importing...'
              : 'Confirm & Import ($_validCount)'),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowRecordTile(WitnessImportRowRecord record) {
    final hasLoanee = record.matchedLoanee != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: record.isValid ? Colors.white : Colors.red.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: record.isValid ? Colors.grey.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Row Index Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Row #${record.rowIndex}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mapping IDs
              Expanded(
                child: Text(
                  'Loanee: ${record.rawCustomerId.isNotEmpty ? record.rawCustomerId : "Missing"} | ${record.rawAccountNumber.isNotEmpty ? record.rawAccountNumber : "Missing"}'
                  '${hasLoanee ? " (${record.matchedLoanee!.loaneeName})" : ""}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Validity Chip
              if (record.isValid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: Colors.green.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'Ready',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 12, color: Colors.red.shade800),
                      const SizedBox(width: 4),
                      Text(
                        record.isDuplicate ? 'Duplicate' : 'Invalid',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // Witness Details summary
          Text(
            'Witness: ${record.rawWitnessName.isNotEmpty ? record.rawWitnessName : "N/A"} (${record.rawWitnessRelationship.isNotEmpty ? record.rawWitnessRelationship : "Relation N/A"}) • Mob: ${record.rawWitnessMobileNo.isNotEmpty ? record.rawWitnessMobileNo : "N/A"} • Guardian: ${record.rawWitnessGuardianName.isNotEmpty ? record.rawWitnessGuardianName : "N/A"}',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade800,
            ),
          ),

          // Error Message
          if (record.errorMessage != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.errorMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Warnings
          for (final w in record.warnings) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orange.shade800),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
