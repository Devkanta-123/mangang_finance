// lib/widgets/bulk_collection_upload_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/collection_sheet_provider.dart';
import '../services/bulk_collection_import_service.dart';

class BulkCollectionUploadDialog extends StatefulWidget {
  final List<BulkCollectionEntryRowResult> parsedRows;

  const BulkCollectionUploadDialog({
    super.key,
    required this.parsedRows,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<BulkCollectionEntryRowResult> parsedRows,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BulkCollectionUploadDialog(parsedRows: parsedRows),
    );
  }

  @override
  State<BulkCollectionUploadDialog> createState() =>
      _BulkCollectionUploadDialogState();
}

class _BulkCollectionUploadDialogState
    extends State<BulkCollectionUploadDialog> {
  bool _isProcessing = false;

  int get _validCount => widget.parsedRows.where((r) => r.isValid).length;
  int get _invalidCount => widget.parsedRows.where((r) => !r.isValid).length;

  Future<void> _handleConfirmUpload() async {
    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);

    final validRows = widget.parsedRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid collection card records available to import.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final result = await BulkCollectionImportService.processBulkEntryUpload(
      validRows: validRows,
      collectionProvider: collectionProvider,
    );

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    final int addedCount = result['addedCount'] ?? 0;
    final int failedCount = result['failedCount'] ?? 0;

    Navigator.of(context).pop(true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
            const SizedBox(width: 10),
            const Text('Bulk Import Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$addedCount loanee collection card(s) added to RO Collection Sheet!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'All imported loanee records are now registered under their respective routes.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            if (failedCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Skipped / Duplicate: $failedCount records',
                style: const TextStyle(fontSize: 12, color: Colors.red),
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
            child: const Text('Done'),
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
        width: MediaQuery.of(context).size.width > 680
            ? 650
            : double.infinity,
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
                    color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.post_add_rounded,
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
                        'Bulk Loanee Collection Card Import',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Text(
                        'Review and import loanee entries to RO Collection Sheet',
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
                    value: '${widget.parsedRows.length}',
                    color: Colors.blue.shade800,
                    bgColor: Colors.blue.shade50,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatChip(
                    title: 'Valid Cards',
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
              ],
            ),
            const SizedBox(height: 14),

            // Parsed Rows List
            const Text(
              'PARSED LOANEE COLLECTION CARDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

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
                  itemCount: widget.parsedRows.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 8),
                  itemBuilder: (ctx, index) {
                    final row = widget.parsedRows[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: row.isValid ? Colors.white : Colors.red.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: row.isValid ? Colors.grey.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            row.isValid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 18,
                            color: row.isValid ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      row.loaneeName.isNotEmpty
                                          ? row.loaneeName
                                          : 'Row #${row.rowIndex}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: row.isValid ? Colors.black87 : Colors.red.shade900,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Acc: ${row.accountNumber.isNotEmpty ? row.accountNumber : "N/A"}',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                    if (row.customerId.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          row.customerId,
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
                                      'Route: ${row.route} • Type: ${row.collectionType} • Addr: ${row.loaneeAddress} • Phone: ${row.mobileNo}',
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              row.route,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
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
                    onPressed: _isProcessing || _validCount == 0 ? null : _handleConfirmUpload,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(
                      _isProcessing
                          ? 'Importing Cards...'
                          : 'Confirm Import ($_validCount Cards)',
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
            style: TextStyle(fontSize: 9.5, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
