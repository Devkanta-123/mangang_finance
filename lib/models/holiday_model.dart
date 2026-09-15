// lib/models/holiday_model.dart

class Holiday {
  final String id;
  final DateTime date;
  final String description;
  final String? createdBy;
  final DateTime createdAt;

  Holiday({
    required this.id,
    required this.date,
    required this.description,
    this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Normalized date (year, month, day only with zero hours/minutes)
  DateTime get cleanDate => DateTime(date.year, date.month, date.day);

  /// Check if this holiday is today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if this holiday is in the future
  bool get isUpcoming {
    final now = DateTime.now();
    final cleanNow = DateTime(now.year, now.month, now.day);
    return cleanDate.isAfter(cleanNow);
  }

  /// Check if this holiday is in the past
  bool get isPast {
    final now = DateTime.now();
    final cleanNow = DateTime(now.year, now.month, now.day);
    return cleanDate.isBefore(cleanNow);
  }

  /// Days difference from today
  int get daysFromToday {
    final now = DateTime.now();
    final cleanNow = DateTime(now.year, now.month, now.day);
    return cleanDate.difference(cleanNow).inDays;
  }

  /// Relative human label (e.g. "Today", "Tomorrow", "In 3 days", "5 days ago")
  String get relativeLabel {
    final diff = daysFromToday;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1) return 'In $diff days';
    if (diff == -1) return 'Yesterday';
    return '${diff.abs()} days ago';
  }

  factory Holiday.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['holiday_date'] ?? json['date'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime parsedCreated;
    final rawCreated = json['created_at'] ?? json['createdAt'];
    if (rawCreated is DateTime) {
      parsedCreated = rawCreated;
    } else if (rawCreated != null) {
      parsedCreated = DateTime.tryParse(rawCreated.toString()) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    return Holiday(
      id: json['id']?.toString() ?? 'HOL-${parsedDate.year}${parsedDate.month.toString().padLeft(2, '0')}${parsedDate.day.toString().padLeft(2, '0')}',
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      description: json['description']?.toString() ?? 'Official Holiday',
      createdBy: json['created_by']?.toString() ?? json['createdBy']?.toString(),
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toJson() {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'holiday_date': dateStr,
      'description': description,
      if (createdBy != null) 'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
