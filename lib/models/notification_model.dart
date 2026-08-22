// lib/models/notification_model.dart

class AppNotification {
  final String id;
  final String recipientUserId;
  final String? senderUserId;
  final String notificationType; // 'collection_payment', 'collection_entry', 'loanee_created', 'system'
  final String title;
  final String message;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.recipientUserId,
    this.senderUserId,
    required this.notificationType,
    required this.title,
    required this.message,
    this.referenceId,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = (createdAt ?? DateTime.now()).toLocal();

  bool get isPayment => notificationType == 'collection_payment';
  bool get isCard => notificationType == 'collection_entry';

  AppNotification copyWith({
    String? id,
    String? recipientUserId,
    String? senderUserId,
    String? notificationType,
    String? title,
    String? message,
    String? referenceId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      senderUserId: senderUserId ?? this.senderUserId,
      notificationType: notificationType ?? this.notificationType,
      title: title ?? this.title,
      message: message ?? this.message,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Robust date-time parser capable of parsing all Postgres, ISO-8601, and timestamp formats
  /// Correctly handles timestamps stored by Postgres with +00 where digits are already local wall-clock time.
  static DateTime parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    }

    final str = value.toString().trim();
    if (str.isEmpty) return DateTime.now();

    final now = DateTime.now();

    // Regex match to extract raw year, month, day, hour, minute, second, microsecond, and timezone
    final fullRegex = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2}):(\d{1,2})(?:\.(\d+))?)?(?:\s*([+-]\d{1,2})(?::?(\d{2}))?|\s*(Z))?$',
    );
    final match = fullRegex.firstMatch(str);

    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = match.group(4) != null ? int.parse(match.group(4)!) : 0;
      final minute = match.group(5) != null ? int.parse(match.group(5)!) : 0;
      final second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
      final microStr = (match.group(7) ?? '0').padRight(6, '0').substring(0, 6);
      final micro = int.parse(microStr);

      final tzHourStr = match.group(8);
      final tzMinStr = match.group(9);
      final isZ = match.group(10) != null;

      final tzHour = tzHourStr != null ? int.parse(tzHourStr) : 0;
      final tzMin = tzMinStr != null ? int.parse(tzMinStr) : 0;
      final isZeroTz = (tzHourStr == null && !isZ) || (tzHour == 0 && tzMin == 0 && !isZ);

      // In Supabase, local timestamps sent by the client are saved into timestamptz and returned with +00.
      // The digits (hour, minute, second) ARE ALREADY the local wall-clock time.
      if (isZeroTz) {
        return DateTime(year, month, day, hour, minute, second, 0, micro);
      }

      if (isZ) {
        final utcDt = DateTime.utc(year, month, day, hour, minute, second, 0, micro).toLocal();
        // Guard: If utcDt is erroneously in the future by > 1 minute, the digits were already local!
        if (utcDt.isAfter(now.add(const Duration(minutes: 1)))) {
          return DateTime(year, month, day, hour, minute, second, 0, micro);
        }
        return utcDt;
      } else {
        final totalMinutesOffset = (tzHour * 60) + (tzHour < 0 ? -tzMin : tzMin);
        final utcEquivalent = DateTime.utc(year, month, day, hour, minute, second, 0, micro)
            .subtract(Duration(minutes: totalMinutesOffset));
        final localDt = utcEquivalent.toLocal();
        if (localDt.isAfter(now.add(const Duration(minutes: 1)))) {
          return DateTime(year, month, day, hour, minute, second, 0, micro);
        }
        return localDt;
      }
    }

    // Fallback: standard tryParse
    final dt = DateTime.tryParse(str);
    if (dt != null) {
      final local = dt.toLocal();
      if (local.isAfter(now.add(const Duration(minutes: 1)))) {
        return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
      }
      return local;
    }

    return DateTime.now();
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      recipientUserId: json['recipient_user_id']?.toString() ?? json['recipientUserId']?.toString() ?? '',
      senderUserId: json['sender_user_id']?.toString() ?? json['senderUserId']?.toString(),
      notificationType: json['notification_type']?.toString() ?? json['notificationType']?.toString() ?? 'system',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? json['referenceId']?.toString(),
      isRead: json['is_read'] == true || json['isRead'] == true,
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_user_id': recipientUserId,
      if (senderUserId != null) 'sender_user_id': senderUserId,
      'notification_type': notificationType,
      'title': title,
      'message': message,
      if (referenceId != null) 'reference_id': referenceId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Human-friendly relative time string (e.g. "Just now", "5 mins ago", "2 hours ago", "Yesterday", "3 days ago", "21/08/2026")
  String get timeAgoFormatted {
    final now = DateTime.now();
    final localTime = createdAt.toLocal();
    final difference = now.difference(localTime);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "min" : "mins"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    } else {
      final d = localTime.day.toString().padLeft(2, '0');
      final m = localTime.month.toString().padLeft(2, '0');
      return '$d/$m/${localTime.year}';
    }
  }

  /// 12-hour formatted real time with AM/PM (e.g. "05:11 PM")
  String get formattedTime {
    final local = createdAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = (hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0');
    return '$formattedHour:$minute $period';
  }

  /// Formatted date (e.g. "21 Aug 2026")
  String get formattedDate {
    final local = createdAt.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    return '$day $month ${local.year}';
  }

  /// Combined date & time (e.g. "21 Aug 2026, 05:11 PM")
  String get formattedDateTime {
    return '$formattedDate, $formattedTime';
  }

  /// Contextual real time display
  /// e.g. "Today, 05:11 PM (15 mins ago)" or "Yesterday, 05:11 PM" or "21 Aug 2026, 05:11 PM"
  String get detailedTimeDisplay {
    final now = DateTime.now();
    final local = createdAt.toLocal();
    final diff = now.difference(local);

    final isToday = now.year == local.year && now.month == local.month && now.day == local.day;
    final isYesterday = now.subtract(const Duration(days: 1)).year == local.year &&
        now.subtract(const Duration(days: 1)).month == local.month &&
        now.subtract(const Duration(days: 1)).day == local.day;

    if (diff.isNegative || diff.inSeconds < 45) {
      return 'Just now • $formattedTime';
    } else if (isToday) {
      return 'Today at $formattedTime ($timeAgoFormatted)';
    } else if (isYesterday) {
      return 'Yesterday at $formattedTime';
    } else {
      return '$formattedDate at $formattedTime';
    }
  }
}
