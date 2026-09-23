// lib/widgets/pause_late_fine_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/loanee_provider.dart';

/// Compact, clean Modal Dialog for pausing system auto late fine calculation.
/// Accessible and executable strictly by Administrator.
class PauseLateFineDialog extends StatefulWidget {
  final RoCollectionEntry entry;

  const PauseLateFineDialog({super.key, required this.entry});

  /// Opens the Pause Late Fine Modal Dialog with admin authorization check.
  static Future<bool?> show(
      BuildContext context, RoCollectionEntry entry) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.activeRole == UserType.admin ||
        authProvider.currentUser?.userType == UserType.admin;

    if (!isAdmin) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Access Denied: Only administrators can pause auto late fine calculation.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }

    // Yield control briefly to ensure any active popup menu or pointer events complete
    await Future.delayed(const Duration(milliseconds: 60));
    if (!context.mounted) return null;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PauseLateFineDialog(entry: entry),
    );
  }

  @override
  State<PauseLateFineDialog> createState() => _PauseLateFineDialogState();
}

/// Backward compatibility alias so callers using `PauseLateFineModalSheet.show` continue working seamlessly.
class PauseLateFineModalSheet {
  static Future<bool?> show(BuildContext context, RoCollectionEntry entry) {
    return PauseLateFineDialog.show(context, entry);
  }
}

class _PauseLateFineDialogState extends State<PauseLateFineDialog> {
  late DateTime _fromDate;
  late DateTime _toDate;
  late TextEditingController _reasonController;
  bool _cleanExistingAutoRecords = true;
  bool _isSaving = false;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final existing = settingsProvider.getLateFinePause(
      widget.entry.id,
      widget.entry.customerId,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (existing != null && !existing.isExpired(today)) {
      _fromDate = existing.cleanFromDate;
      _toDate = existing.cleanToDate;
      _reasonController = TextEditingController(text: existing.reason ?? '');
    } else {
      _fromDate = today;
      _toDate = today.add(const Duration(days: 7));
      _reasonController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Pause Start Date (From)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B1A1A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _fromDate = DateTime(picked.year, picked.month, picked.day);
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2035),
      helpText: 'Select Pause End Date (To)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B1A1A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _toDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _applyPresetDays(int days) {
    setState(() {
      _toDate = _fromDate.add(Duration(days: days));
    });
  }

  void _applyEndOfMonth() {
    final lastDay = DateTime(_fromDate.year, _fromDate.month + 1, 0);
    setState(() {
      _toDate = lastDay;
    });
  }

  Future<void> _handleSave() async {
    if (_toDate.isBefore(_fromDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: End Date cannot be before Start Date.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final collectionProvider =
          Provider.of<CollectionSheetProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final adminName = authProvider.currentUser?.name ?? 'Admin';

      // 1. Save pause configuration to settings
      await settingsProvider.setLateFinePause(
        collectionId: widget.entry.id,
        customerId: widget.entry.customerId,
        accountNumber: widget.entry.accountNumber,
        loaneeName: widget.entry.loaneeName,
        fromDate: _fromDate,
        toDate: _toDate,
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : null,
        pausedBy: adminName,
      );

      // 2. Clean existing auto-assessed late fees in this range if toggled
      int cleanedCount = 0;
      if (_cleanExistingAutoRecords) {
        cleanedCount = await collectionProvider.removeAutoLateFeesInDateRange(
          collectionId: widget.entry.id,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      }

      if (mounted) {
        final totalDays = _toDate.difference(_fromDate).inDays + 1;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⏸️ Auto late fine paused for ${widget.entry.loaneeName} (${_formatDate(_fromDate)} - ${_formatDate(_toDate)}, $totalDays days).'
              '${cleanedCount > 0 ? " ($cleanedCount auto entries cleared)." : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Defer pop and background sync to post-frame to ensure clean animation unmount
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context, true);
            LoaneeProvider? lp;
            try {
              lp = Provider.of<LoaneeProvider>(context, listen: false);
            } catch (_) {}
            collectionProvider.syncAutoLateFeesForEntry(
              entry: widget.entry,
              settingsProvider: settingsProvider,
              loaneeProvider: lp,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save pause setting: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleResume() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.play_circle_filled_rounded, color: Color(0xFF8B1A1A)),
            SizedBox(width: 8),
            Text('Resume Late Fine?'),
          ],
        ),
        content: Text(
          'Resume automatic late fine calculations for ${widget.entry.loaneeName}?\n\n'
          'The system will immediately calculate fines for subsequent missed collection days.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Resume Auto Fine'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRemoving = true);

    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final collectionProvider =
          Provider.of<CollectionSheetProvider>(context, listen: false);

      await settingsProvider.removeLateFinePause(
        widget.entry.id,
        widget.entry.customerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '▶️ Auto late fine calculation resumed for ${widget.entry.loaneeName}.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context, true);
            LoaneeProvider? lp;
            try {
              lp = Provider.of<LoaneeProvider>(context, listen: false);
            } catch (_) {}
            collectionProvider.syncAutoLateFeesForEntry(
              entry: widget.entry,
              settingsProvider: settingsProvider,
              loaneeProvider: lp,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume auto late fine: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final existing = settingsProvider.getLateFinePause(
      widget.entry.id,
      widget.entry.customerId,
    );

    final totalDays = _toDate.difference(_fromDate).inDays + 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bool isCurrentlyPaused =
        existing != null && existing.isCurrentlyActive(today);

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 550;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Compact Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A1A), Color(0xFF651212)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause_circle_filled_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pause Auto Late Fine',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Admin Override • ${widget.entry.loaneeName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 2. Dialog Body (Scrollable if viewport is small)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Compact Account Pill Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'ACNO: ',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600),
                              ),
                              Text(
                                widget.entry.accountNumber,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'ID: ',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600),
                              ),
                              Text(
                                widget.entry.customerId,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrentlyPaused
                                  ? Colors.deepPurple.shade50
                                  : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isCurrentlyPaused
                                    ? Colors.deepPurple.shade200
                                    : Colors.teal.shade200,
                              ),
                            ),
                            child: Text(
                              isCurrentlyPaused ? 'PAUSED' : 'RUNNING',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isCurrentlyPaused
                                    ? Colors.deepPurple.shade800
                                    : Colors.teal.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // B. Active Pause Warning/Notice (if paused)
                    if (isCurrentlyPaused) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 15, color: Colors.deepPurple.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Current pause active: ${_formatDate(existing.cleanFromDate)} - ${_formatDate(existing.cleanToDate)} (${existing.totalDays} days)${existing.reason != null && existing.reason!.isNotEmpty ? " • \"${existing.reason}\"" : ""}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepPurple.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // C. Date Range Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pause Date Range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: totalDays > 0
                                ? Colors.blue.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            totalDays > 0
                                ? '$totalDays ${totalDays == 1 ? "day" : "days"} selected'
                                : 'Invalid range',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: totalDays > 0
                                  ? Colors.blue.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // D. Side-by-Side Date Pickers
                    Row(
                      children: [
                        // From Date
                        Expanded(
                          child: InkWell(
                            onTap: _pickFromDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FROM DATE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded,
                                          size: 13, color: Color(0xFF8B1A1A)),
                                      const SizedBox(width: 5),
                                      Text(
                                        _formatDate(_fromDate),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E1E1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 14, color: Colors.grey),
                        ),
                        // To Date
                        Expanded(
                          child: InkWell(
                            onTap: _pickToDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _toDate.isBefore(_fromDate)
                                      ? Colors.red
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TO DATE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_available_rounded,
                                          size: 13, color: Color(0xFF8B1A1A)),
                                      const SizedBox(width: 5),
                                      Text(
                                        _formatDate(_toDate),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E1E1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // E. Quick Preset Chips
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildPresetChip('+3d', () => _applyPresetDays(3)),
                        _buildPresetChip('+7d', () => _applyPresetDays(7)),
                        _buildPresetChip('+14d', () => _applyPresetDays(14)),
                        _buildPresetChip('+30d', () => _applyPresetDays(30)),
                        _buildPresetChip('Month End', _applyEndOfMonth),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // F. Reason Input
                    const Text(
                      'Reason (Optional)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'e.g. Medical emergency, flood grace period',
                        hintStyle: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      style: const TextStyle(fontSize: 11.5),
                    ),

                    const SizedBox(height: 10),

                    // G. Clean Existing Records Waiver Checkbox
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _cleanExistingAutoRecords,
                            onChanged: (v) {
                              setState(() {
                                _cleanExistingAutoRecords = v ?? true;
                              });
                            },
                            activeColor: const Color(0xFF8B1A1A),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Waiver: clean auto late records in range',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Deletes existing auto PAY-LATE entries between ${_formatDate(_fromDate)} and ${_formatDate(_toDate)}.',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // H. Policy Note
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_mode_rounded,
                              size: 13, color: Colors.blue.shade800),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Auto continuation: After ${_formatDate(_toDate)}, auto fines automatically resume for subsequent missed days.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Footer Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  if (existing != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed:
                          (_isSaving || _isRemoving) ? null : _handleResume,
                      icon: _isRemoving
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow_rounded, size: 14),
                      label: const Text('Resume Fine',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                  ],
                  TextButton(
                    onPressed: (_isSaving || _isRemoving)
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1A1A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: (_isSaving || _isRemoving) ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 14),
                    label: Text(
                      existing != null ? 'Update Pause' : 'Apply Pause',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
