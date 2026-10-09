// lib/models/locked_device_session_model.dart

import 'user_model.dart';

/// Represents an account currently locked to an active device session
class LockedDeviceSession {
  final String settingKey;
  final String mobileNo;
  final UserType userType;
  final String deviceId;
  final DateTime? updatedAt;
  final String? userName;
  final String? customerId;

  LockedDeviceSession({
    required this.settingKey,
    required this.mobileNo,
    required this.userType,
    required this.deviceId,
    this.updatedAt,
    this.userName,
    this.customerId,
  });

  String get roleLabel => userType.name.toUpperCase();

  String get displayName => (userName != null && userName!.trim().isNotEmpty)
      ? userName!.trim()
      : 'Account +91 $mobileNo';

  String get formattedDate {
    if (updatedAt == null) return 'N/A';
    final d = updatedAt!;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }
}
