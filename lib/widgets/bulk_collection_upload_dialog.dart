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
  String _filter = 'all'; // 'all', 'valid', 'duplicates', 'missing', 'skipped'

  int get _validCount =>
      widget.parsedRows.where((r) => r.isValid && !r.isDuplicate).length;
  int get _duplicateCount =>
      widget.parsedRows.where((r) => r.isDuplicate).length;
  int get _missingLoaneeCount =>
      widget.parsedRows.where((r) => !r.isValid && !r.isDuplicate).length;
  int get _invalidCount => widget.parsedRows.where((r) => !r.isValid).length;

  Future<void> _handleConfirmUpload() async {
    final collectionProvider =
        Provider.of<CollectionSheetProvider>(context, listen: false);

    final validRows =
        widget.parsedRows.where((r) => r.isValid && !r.isDuplicate).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No new valid collection card records available to import. Duplicate entries and unregistered loanees are blocked.'),
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
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
            SizedBox(width: 10),
            Text('Bulk Import Complete'),
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Failed to save $failedCount card(s) to database.',
                        style: TextStyle(fontSize: 11.5, color: Colors.red.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_duplicateCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 16, color: Colors.orange.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Blocked $_duplicateCount duplicate entry(s) because data already exists for the same Customer ID or Account Number.',
                        style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_missingLoaneeCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Skipped $_missingLoaneeCount record(s) because loanees do not exist in loanee_accounts database.',
                        style: TextStyle(fontSize: 11.5, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
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

            if (_invalidCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _duplicateCount > 0 ? Colors.orange.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _duplicateCount > 0 ? Colors.orange.shade200 : Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      _duplicateCount > 0 ? Icons.copy_rounded : Icons.warning_amber_rounded,
                      color: _duplicateCount > 0 ? Colors.orange.shade800 : Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _duplicateCount > 0 && _missingLoaneeCount > 0
                            ? '$_duplicateCount duplicate row(s) already exist (blocked). $_missingLoaneeCount row(s) not found in loanee_accounts.'
                            : (_duplicateCount > 0
                                ? '$_duplicateCount duplicate row(s) already exist in RO Collection Sheet or Excel and are blocked from import.'
                                : '$_missingLoaneeCount row(s) cannot be added and will be skipped. Loanees must exist in loanee_accounts database first.'),
                        style: TextStyle(
                          color: _duplicateCount > 0 ? Colors.orange.shade900 : Colors.red.shade900,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                    title: 'Ready to Add',
                    value: '$_validCount',
                    color: Colors.green.shade800,
                    bgColor: Colors.green.shade50,
                  ),
                ),
                if (_duplicateCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatChip(
                      title: 'Duplicates',
                      value: '$_duplicateCount',
                      color: Colors.orange.shade900,
                      bgColor: Colors.orange.shade50,
                    ),
                  ),
                ],
                if (_missingLoaneeCount > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatChip(
                      title: 'Not in DB',
                      value: '$_missingLoaneeCount',
                      color: Colors.red.shade800,
                      bgColor: Colors.red.shade50,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTabButton('all', 'All (${widget.parsedRows.length})'),
                  const SizedBox(width: 6),
                  _buildFilterTabButton('valid', 'Ready to Add ($_validCount)'),
                  if (_duplicateCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildFilterTabButton('duplicates', 'Duplicates ($_duplicateCount)'),
                  ],
                  if (_missingLoaneeCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildFilterTabButton('missing', 'Not in DB ($_missingLoaneeCount)'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Builder(
                  builder: (context) {
                    final displayedRows = _filter == 'valid'
                        ? widget.parsedRows.where((r) => r.isValid && !r.isDuplicate).toList()
                        : (_filter == 'duplicates'
                            ? widget.parsedRows.where((r) => r.isDuplicate).toList()
                            : (_filter == 'missing'
                                ? widget.parsedRows.where((r) => !r.isValid && !r.isDuplicate).toList()
                                : (_filter == 'skipped'
                                    ? widget.parsedRows.where((r) => !r.isValid || r.isDuplicate).toList()
                                    : widget.parsedRows)));

                    if (displayedRows.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No rows match selected filter',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: displayedRows.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 8),
                      itemBuilder: (ctx, index) {
                        final row = displayedRows[index];
                        final isDup = row.isDuplicate;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: row.isValid && !isDup
                                ? Colors.white
                                : (isDup
                                    ? Colors.orange.shade50.withValues(alpha: 0.5)
                                    : Colors.red.shade50.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: row.isValid && !isDup
                                  ? Colors.grey.shade200
                                  : (isDup ? Colors.orange.shade300 : Colors.red.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                row.isValid && !isDup
                                    ? Icons.check_circle_rounded
                                    : (isDup ? Icons.copy_rounded : Icons.error_outline_rounded),
                                size: 18,
                                color: row.isValid && !isDup
                                    ? Colors.green.shade700
                                    : (isDup ? Colors.orange.shade800 : Colors.red.shade700),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          row.loaneeName.isNotEmpty
                                              ? row.loaneeName
                                              : 'Row #${row.rowIndex}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: row.isValid && !isDup
                                                ? Colors.black87
                                                : (isDup ? Colors.orange.shade900 : Colors.red.shade900),
                                          ),
                                        ),
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
                                        if (row.customerId.isNotEmpty)
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
                                        if (isDup)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'DUPLICATE • BLOCKED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          )
                                        else if (!row.isValid)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'SKIPPED • NOT IN DB',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade900,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'READY TO ADD',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if ((!row.isValid || isDup) && row.errorMessage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          row.errorMessage!,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDup ? Colors.orange.shade900 : Colors.red.shade700,
                                            fontWeight: FontWeight.w600,
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

  Widget _buildFilterTabButton(String tabKey, String label) {
    final isSelected = _filter == tabKey;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _filter = tabKey;
        });
      },
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
}
