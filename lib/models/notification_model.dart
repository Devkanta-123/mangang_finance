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
  }) : createdAt = createdAt ?? DateTime.now();

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
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
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

  String get timeAgoFormatted {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
