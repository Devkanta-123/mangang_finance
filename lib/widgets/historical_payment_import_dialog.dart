// lib/widgets/historical_payment_import_dialog.dart

import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/collection_sheet_provider.dart";
import "../providers/loanee_provider.dart";
import "../services/historical_payment_import_service.dart";

class HistoricalPaymentImportDialog extends StatefulWidget {
  final HistoricalImportPreviewResult previewResult;

  const HistoricalPaymentImportDialog({
    super.key,
    required this.previewResult,
  });

  static Future<bool?> show(
    BuildContext context, {
    required HistoricalImportPreviewResult previewResult,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HistoricalPaymentImportDialog(previewResult: previewResult),
    );
  }

  @override
  State<HistoricalPaymentImportDialog> createState() =>
      _HistoricalPaymentImportDialogState();
}

class _HistoricalPaymentImportDialogState
    extends State<HistoricalPaymentImportDialog> {
  bool _isProcessing = false;
  String _filterTab = "all"; // "all", "valid", "invalid", "unmapped", "duplicates"

  Future<void> _handleConfirmImport() async {
    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);
    final loaneeProvider = Provider.of<LoaneeProvider>(context, listen: false);

    if (!widget.previewResult.canImport) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No valid historical payments available to import."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final result = await HistoricalPaymentImportService.executeTransactionalImport(
      previewResult: widget.previewResult,
      collectionProvider: collectionProvider,
      loaneeProvider: loaneeProvider,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    Navigator.of(context).pop(result.success);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: result.success ? Colors.green.shade700 : Colors.red.shade700,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              result.success ? "Historical Import Complete" : "Import Failed",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.success) ...[
              Text(
                "Successfully imported ${result.paymentsInsertedCount} historical payment(s)!",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                "Total Amount: ₹${result.totalAmountImported.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
              if (result.totalInterestImported > 0) ...[
                const SizedBox(height: 4),
                Text(
                  "Total Interest Added: ₹${result.totalInterestImported.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange.shade800,
                  ),
                ),
              ],
              if (result.collectionEntriesCreatedCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  "Created ${result.collectionEntriesCreatedCount} new collection card profile(s).",
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
              if (result.duplicatePaymentsSkippedCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  "Skipped ${result.duplicatePaymentsSkippedCount} duplicate payment(s).",
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                ),
              ],
              if (widget.previewResult.unmappedRowsCount > 0 || widget.previewResult.invalidRowsCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    "Skipped ${widget.previewResult.unmappedRowsCount + widget.previewResult.invalidRowsCount} row(s) because the loanees do not exist in loanee_accounts database.",
                    style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ] else ...[
              Text(
                result.errorMessage ?? "An error occurred during import.",
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewResult;

    final List<HistoricalImportRowRecord> displayedRows;
    switch (_filterTab) {
      case "valid":
        displayedRows = preview.rowRecords.where((r) => r.isValid && r.validPaymentsCount > 0).toList();
        break;
      case "invalid":
        displayedRows = preview.rowRecords.where((r) => !r.isValid).toList();
        break;
      case "unmapped":
        displayedRows = preview.rowRecords.where((r) => r.isUnmapped).toList();
        break;
      case "duplicates":
        displayedRows = preview.rowRecords.where((r) => r.duplicatePaymentsCount > 0).toList();
        break;
      case "all":
      default:
        displayedRows = preview.rowRecords;
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: MediaQuery.of(context).size.width > 760 ? 720 : double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_edu_rounded,
                    color: Color(0xFF8B1A1A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Historical Payment Import Preview",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        "Verify historical dates, loan account mappings, and payment amounts",
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
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

            if (preview.rowRecords.any((r) => r.isDuplicate))
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${preview.rowRecords.where((r) => r.isDuplicate).length} record(s) are duplicates or already exist in database and are blocked from duplicate entry.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (preview.unmappedRowsCount + preview.invalidRowsCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${preview.unmappedRowsCount + preview.invalidRowsCount} loanee record(s) do not exist in loanee_accounts and will be skipped. Only payments for registered loanees can be imported.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Metrics Summary Grid
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatChip(
                    title: "Total Rows",
                    value: "${preview.totalRows}",
                    color: Colors.blue.shade900,
                    bgColor: Colors.blue.shade50,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    title: "Payments to Import",
                    value: "${preview.validPaymentsCount}",
                    subtitle: "₹${preview.totalAmountToImport.toStringAsFixed(2)}",
                    color: Colors.green.shade900,
                    bgColor: Colors.green.shade50,
                  ),
                  if (preview.totalInterestToImport > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      title: "Interest Added",
                      value: "₹${preview.totalInterestToImport.toStringAsFixed(2)}",
                      color: Colors.deepOrange.shade900,
                      bgColor: Colors.deepOrange.shade50,
                    ),
                  ],
                  if (preview.duplicatePaymentsCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      title: "Duplicates (Skip)",
                      value: "${preview.duplicatePaymentsCount}",
                      color: Colors.orange.shade900,
                      bgColor: Colors.orange.shade50,
                    ),
                  ],
                  if (preview.unmappedRowsCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      title: "Skipped (Not in DB)",
                      value: "${preview.unmappedRowsCount}",
                      color: Colors.purple.shade900,
                      bgColor: Colors.purple.shade50,
                    ),
                  ],
                  if (preview.invalidRowsCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildStatChip(
                      title: "Invalid Rows",
                      value: "${preview.invalidRowsCount}",
                      color: Colors.red.shade900,
                      bgColor: Colors.red.shade50,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTabButton("all", "All (${preview.rowRecords.length})"),
                  const SizedBox(width: 6),
                  _buildFilterTabButton("valid", "Valid (${preview.validRowsCount})"),
                  if (preview.invalidRowsCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildFilterTabButton("invalid", "Invalid (${preview.invalidRowsCount})"),
                  ],
                  if (preview.unmappedRowsCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildFilterTabButton("unmapped", "Not in DB (${preview.unmappedRowsCount})"),
                  ],
                  if (preview.duplicatePaymentsCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildFilterTabButton("duplicates", "Has Duplicates"),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Rows List
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: displayedRows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            "No rows match selected filter",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: displayedRows.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 10),
                        itemBuilder: (ctx, index) {
                          final row = displayedRows[index];
                          return _buildRowRecordCard(row);
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions (Cancel / Confirm)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                    child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing || !preview.canImport ? null : _handleConfirmImport,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(
                      _isProcessing
                          ? "Importing Payments..."
                          : "Confirm Import (${preview.validPaymentsCount} Payments)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildRowRecordCard(HistoricalImportRowRecord row) {
    final bool isDuplicate = row.isDuplicate;
    final bool hasError = !row.isValid;
    final bool isUnmapped = row.isUnmapped;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDuplicate
            ? Colors.orange.shade50.withValues(alpha: 0.4)
            : (hasError
                ? Colors.red.shade50.withValues(alpha: 0.4)
                : (isUnmapped ? Colors.purple.shade50.withValues(alpha: 0.3) : Colors.white)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDuplicate
              ? Colors.orange.shade300
              : (hasError
                  ? Colors.red.shade200
                  : (isUnmapped ? Colors.purple.shade200 : Colors.grey.shade200)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header with Name, Account, Route, and Status Icon
          Row(
            children: [
              Icon(
                isDuplicate
                    ? Icons.copy_rounded
                    : (hasError
                        ? Icons.cancel_rounded
                        : (isUnmapped ? Icons.help_outline_rounded : Icons.check_circle_rounded)),
                size: 18,
                color: isDuplicate
                    ? Colors.orange.shade800
                    : (hasError
                        ? Colors.red.shade700
                        : (isUnmapped ? Colors.purple.shade700 : Colors.green.shade700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      row.rawLoaneeName.isNotEmpty ? row.rawLoaneeName : "Row #${row.rowIndex}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDuplicate
                            ? Colors.orange.shade900
                            : (hasError ? Colors.red.shade900 : Colors.black87),
                      ),
                    ),
                    if (row.rawAccountNumber.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          row.rawAccountNumber,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    if (row.rawCustomerId.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          row.rawCustomerId,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    if (isDuplicate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "DUPLICATE • BLOCKED",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      )
                    else if (hasError || isUnmapped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "SKIPPED • NOT IN DB",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  row.rawRoute.isNotEmpty ? row.rawRoute : "Office",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B1A1A),
                  ),
                ),
              ),
            ],
          ),

          if (row.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Text(
                row.errorMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          if (row.warnings.isNotEmpty)
            ...row.warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(top: 2, left: 26),
                child: Text(
                  "⚠️ $w",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Payment Badges for this row
          if (row.payments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: row.payments.map((p) {
                  final isDup = p.isDuplicate;
                  final hasErr = p.errorMessage != null && !isDup;

                  Color bg = Colors.green.shade50;
                  Color border = Colors.green.shade200;
                  Color text = Colors.green.shade900;

                  if (isDup) {
                    bg = Colors.orange.shade50;
                    border = Colors.orange.shade200;
                    text = Colors.orange.shade900;
                  } else if (hasErr) {
                    bg = Colors.red.shade50;
                    border = Colors.red.shade200;
                    text = Colors.red.shade900;
                  }

                  final dupLabel = isDup ? " (Dup)" : "";
                  final interestLabel = p.interest > 0 ? " (+₹${p.interest.toStringAsFixed(0)} int)" : "";
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      "${p.formattedDate}: ₹${p.amount.toStringAsFixed(0)}$interestLabel$dupLabel",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: text,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTabButton(String tabKey, String label) {
    final isSelected = _filterTab == tabKey;
    return InkWell(
      onTap: () {
        setState(() {
          _filterTab = tabKey;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String title,
    required String value,
    String? subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Text(
                  "($subtitle)",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
