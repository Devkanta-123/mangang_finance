// lib/screens/holiday_management_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/holiday_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class HolidayManagementPage extends StatefulWidget {
  const HolidayManagementPage({super.key});

  @override
  State<HolidayManagementPage> createState() => _HolidayManagementPageState();
}

class _HolidayManagementPageState extends State<HolidayManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  String _selectedFilter = 'All'; // 'All', 'Upcoming', 'Past'

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B1A1A),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _submitHoliday() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final cleanDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (settingsProvider.isHoliday(cleanDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ A holiday is already declared for ${SettingsProvider.formatDate(cleanDate)}!'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final adminName = authProvider.currentUser?.name.isNotEmpty == true
        ? authProvider.currentUser!.name
        : 'Administrator';

    final success = await settingsProvider.addHoliday(
      date: cleanDate,
      description: _descController.text.trim(),
      createdBy: adminName,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      _descController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✅ Holiday added & broadcast to all users in real-time!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save holiday. Please try again.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _confirmDeleteHoliday(Holiday holiday) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Holiday?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the official holiday for "${holiday.description}" on ${SettingsProvider.formatDate(holiday.date)}?\n\nCollections and penalty calculations will resume as normal.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 36),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final ok = await settingsProvider.deleteHoliday(holiday.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Holiday deleted successfully' : 'Failed to delete holiday'),
            backgroundColor: ok ? Colors.blueGrey.shade800 : Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.activeRole == UserType.admin;

    final allHolidays = settingsProvider.holidays;

    // Filter holidays
    final now = DateTime.now();
    final cleanNow = DateTime(now.year, now.month, now.day);

    final filteredHolidays = allHolidays.where((h) {
      if (_selectedFilter == 'Upcoming') {
        return !h.cleanDate.isBefore(cleanNow);
      } else if (_selectedFilter == 'Past') {
        return h.cleanDate.isBefore(cleanNow);
      }
      return true;
    }).toList();

    final upcomingCount = allHolidays.where((h) => !h.cleanDate.isBefore(cleanNow)).length;
    final holidayToday = settingsProvider.getHolidayForDate(now);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Holiday Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => settingsProvider.loadHolidays(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade900.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official Holiday System',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Declared holidays automatically pause collections, exclude days from late fee calculations, prevent auto late records, and notify all users in real time.',
                            style: TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Metrics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Holidays',
                      value: '${allHolidays.length}',
                      subtitle: '$upcomingCount Upcoming',
                      icon: Icons.calendar_month_rounded,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Today Status',
                      value: holidayToday != null ? 'Holiday' : 'Working Day',
                      subtitle: holidayToday != null ? holidayToday.description : 'Collections Active',
                      icon: holidayToday != null ? Icons.celebration_rounded : Icons.work_outline_rounded,
                      color: holidayToday != null ? Colors.deepOrange.shade800 : Colors.green.shade700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Form: Add Holiday (Admin only)
              if (isAdmin) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add_circle_outline_rounded,
                                  color: Color(0xFF8B1A1A), size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Declare Official Holiday',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Date Selector
                        const Text(
                          'Holiday Date *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickDate(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF8B1A1A)),
                                const SizedBox(width: 12),
                                Text(
                                  SettingsProvider.formatDate(_selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${_getDayOfWeek(_selectedDate)})',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const Spacer(),
                                Text(
                                  'Change Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Quick buttons
                        Row(
                          children: [
                            _buildQuickDateChip('Today', now),
                            const SizedBox(width: 8),
                            _buildQuickDateChip('Tomorrow', now.add(const Duration(days: 1))),
                            const SizedBox(width: 8),
                            _buildQuickDateChip('Pick Date...', null, isCustom: true),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Description Field
                        const Text(
                          'Holiday Description / Reason *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Kang (Rath Yatra), Yaoshang, Independence Day',
                            hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF8B1A1A)),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a description for the holiday';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B1A1A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            onPressed: _isSubmitting ? null : _submitHoliday,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.campaign_rounded),
                            label: Text(
                              _isSubmitting
                                  ? 'Broadcasting Holiday...'
                                  : 'Declare Holiday & Broadcast Realtime',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Registered Holidays Header & Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registered Holidays',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8B1A1A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isDense: true,
                        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Holidays')),
                          DropdownMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                          DropdownMenuItem(value: 'Past', child: Text('Past')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedFilter = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Holiday List
              if (filteredHolidays.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        _selectedFilter == 'Upcoming'
                            ? 'No upcoming holidays registered'
                            : (_selectedFilter == 'Past' ? 'No past holidays found' : 'No holidays registered yet'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Declare holidays above to pause collections on specific dates.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredHolidays.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final h = filteredHolidays[i];
                    return _buildHolidayCard(h, isAdmin);
                  },
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(String label, DateTime? targetDate, {bool isCustom = false}) {
    final isSelected = !isCustom &&
        targetDate != null &&
        _selectedDate.year == targetDate.year &&
        _selectedDate.month == targetDate.month &&
        _selectedDate.day == targetDate.day;

    return InkWell(
      onTap: () {
        if (isCustom) {
          _pickDate(context);
        } else if (targetDate != null) {
          setState(() {
            _selectedDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B1A1A) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayCard(Holiday holiday, bool isAdmin) {
    Color badgeColor;
    String badgeText;

    if (holiday.isToday) {
      badgeColor = Colors.green.shade700;
      badgeText = 'TODAY';
    } else if (holiday.isUpcoming) {
      badgeColor = Colors.orange.shade800;
      badgeText = holiday.relativeLabel.toUpperCase();
    } else {
      badgeColor = Colors.grey.shade600;
      badgeText = 'PAST';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: holiday.isToday ? Colors.green.shade400 : Colors.grey.shade200,
          width: holiday.isToday ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date calendar block
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: holiday.isToday
                  ? Colors.green.shade50
                  : (holiday.isUpcoming ? const Color(0xFF8B1A1A).withValues(alpha: 0.08) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: holiday.isToday
                    ? Colors.green.shade300
                    : (holiday.isUpcoming ? const Color(0xFF8B1A1A).withValues(alpha: 0.2) : Colors.grey.shade300),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getMonthAbbr(holiday.date.month),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: holiday.isToday
                        ? Colors.green.shade800
                        : (holiday.isUpcoming ? const Color(0xFF8B1A1A) : Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  holiday.date.day.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: holiday.isToday
                        ? Colors.green.shade900
                        : (holiday.isUpcoming ? const Color(0xFF8B1A1A) : Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        holiday.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getDayOfWeek(holiday.date)} • ${SettingsProvider.formatDate(holiday.date)}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                if (holiday.createdBy != null && holiday.createdBy!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Declared by ${holiday.createdBy}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),

          // Delete Action
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 20),
              tooltip: 'Delete Holiday',
              onPressed: () => _confirmDeleteHoliday(holiday),
            ),
        ],
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'DATE';
  }

  String _getDayOfWeek(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
}
