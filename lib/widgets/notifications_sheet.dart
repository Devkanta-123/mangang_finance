// lib/widgets/notifications_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final notifications = notifProvider.notifications;
    final unreadCount = notifProvider.unreadCount;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF8B1A1A), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        unreadCount > 0 ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}' : 'All caught up',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFF8B1A1A),
                    ),
                    onPressed: () => notifProvider.markAllAsRead(),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Mark Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                if (notifications.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.grey),
                    tooltip: 'Clear All',
                    onPressed: () => _confirmClearAll(context, notifProvider),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No Notifications Yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Realtime payment and collection alerts will appear here',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return _buildNotificationItem(context, item, notifProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, AppNotification item, NotificationProvider provider) {
    Color iconBg;
    Color iconColor;
    IconData iconData;

    switch (item.notificationType) {
      case 'collection_payment':
        iconBg = Colors.green.shade50;
        iconColor = Colors.green.shade800;
        iconData = Icons.payments_rounded;
        break;
      case 'collection_entry':
        iconBg = Colors.blue.shade50;
        iconColor = Colors.blue.shade800;
        iconData = Icons.badge_rounded;
        break;
      default:
        iconBg = const Color(0xFF8B1A1A).withValues(alpha: 0.1);
        iconColor = const Color(0xFF8B1A1A);
        iconData = Icons.notifications_rounded;
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade600,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        provider.deleteNotification(item.id);
      },
      child: Material(
        color: item.isRead ? Colors.white : const Color(0xFF8B1A1A).withValues(alpha: 0.04),
        child: InkWell(
          onTap: () {
            if (!item.isRead) {
              provider.markAsRead(item.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            item.timeAgoFormatted,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: item.isRead ? Colors.grey.shade500 : const Color(0xFF8B1A1A),
                              fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Unread dot
                if (!item.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B1A1A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAll();
            },
            child: const Text('Clear All', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
