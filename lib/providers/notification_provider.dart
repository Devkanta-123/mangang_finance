// lib/providers/notification_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  bool _isLoading = false;
  User? _currentUser;

  // Stream for in-app popups / toast notifications
  final StreamController<AppNotification> _notificationStreamController =
      StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get notificationStream => _notificationStreamController.stream;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Update current active user and fetch notifications
  Future<void> initForUser(User? user) async {
    _currentUser = user;
    if (user != null) {
      await fetchNotifications();
    } else {
      _notifications.clear();
      notifyListeners();
    }
  }

  List<String> get currentRecipientIds {
    if (_currentUser == null) return [];
    final set = <String>{};
    if (_currentUser!.mobileNo.isNotEmpty) set.add(_currentUser!.mobileNo);
    if (_currentUser!.customerId != null && _currentUser!.customerId!.isNotEmpty) {
      set.add(_currentUser!.customerId!);
    }
    if (_currentUser!.userType == UserType.admin) {
      set.add('admin');
      set.add('ADM-01');
    }
    return set.toList();
  }

  /// Fetch notifications from Supabase
  Future<void> fetchNotifications() async {
    if (_currentUser == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final list = await SupabaseService.instance.fetchNotificationsForUser(
        userId: _currentUser!.mobileNo,
        customerId: _currentUser!.customerId,
        mobileNo: _currentUser!.mobileNo,
        isAdmin: _currentUser!.userType == UserType.admin,
      );

      _notifications.clear();
      _notifications.addAll(list);
    } catch (e) {
      debugPrint('⚠️ Error fetching notifications in provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Process incoming realtime notification
  void handleIncomingRealtimeNotification(AppNotification notification) {
    // Check if this notification is intended for the current user
    final recipients = currentRecipientIds;
    final isForMe = recipients.any((r) =>
        r.toLowerCase().trim() == notification.recipientUserId.toLowerCase().trim() ||
        (_currentUser?.userType == UserType.admin &&
            (notification.recipientUserId == 'admin' || notification.recipientUserId.startsWith('ADM-'))));

    if (!isForMe) return;

    // Check if already in list (deduplicate by id or reference_id + type)
    final existingIndex = _notifications.indexWhere((n) =>
        n.id == notification.id ||
        (n.referenceId != null &&
            n.referenceId!.isNotEmpty &&
            n.referenceId == notification.referenceId &&
            n.notificationType == notification.notificationType));

    if (existingIndex == -1) {
      _notifications.insert(0, notification);
      // Emit event for in-app alert banner
      _notificationStreamController.add(notification);
      notifyListeners();
    }
  }

  /// Mark single notification as read
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
      await SupabaseService.instance.markNotificationAsRead(id);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    bool hasUnread = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        hasUnread = true;
      }
    }
    if (hasUnread) {
      notifyListeners();
      await SupabaseService.instance.markAllNotificationsAsRead(currentRecipientIds);
    }
  }

  /// Delete single notification
  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    await SupabaseService.instance.deleteNotification(id);
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
    await SupabaseService.instance.clearAllNotifications(currentRecipientIds);
  }

  @override
  void dispose() {
    _notificationStreamController.close();
    super.dispose();
  }
}
