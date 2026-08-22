import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/notification_model.dart';

void main() {
  group('Notification Timestamp Parsing Tests', () {
    test('Correctly parses Postgres timestamp with +00 timezone as local wall-clock time (e.g. 5:11 PM)', () {
      const sampleRaw = "2026-08-21 17:11:55.822906+00";
      final notif = AppNotification.fromJson({
        'id': 'test-1',
        'recipient_user_id': 'user-1',
        'title': 'Payment Collected',
        'message': '₹100 collected for Daily card',
        'created_at': sampleRaw,
      });

      // The parsed date must preserve 17:11:55 (5:11 PM)
      expect(notif.createdAt.hour, equals(17));
      expect(notif.createdAt.minute, equals(11));
      expect(notif.formattedTime, equals('05:11 PM'));
      expect(notif.formattedDate, equals('21 Aug 2026'));
      expect(notif.formattedDateTime, equals('21 Aug 2026, 05:11 PM'));
    });

    test('Correctly parses 2:18 PM timestamp stored with +00 into 02:18 PM without 5.5h shift to 07:48 PM', () {
      const sampleRaw = "2026-08-22 14:18:29.822906+00";
      final notif = AppNotification.fromJson({
        'id': 'test-2',
        'recipient_user_id': 'user-1',
        'title': 'Recent Payment',
        'message': 'Testing 2:18 PM',
        'created_at': sampleRaw,
      });

      expect(notif.createdAt.hour, equals(14));
      expect(notif.createdAt.minute, equals(18));
      expect(notif.formattedTime, equals('02:18 PM'));
    });

    test('Formats 12-hour time and dates accurately', () {
      final notif = AppNotification(
        id: 'test-4',
        recipientUserId: 'user-1',
        notificationType: 'system',
        title: 'Title',
        message: 'Message',
        createdAt: DateTime(2026, 8, 21, 17, 11, 55),
      );

      expect(notif.formattedTime, equals('05:11 PM'));
      expect(notif.formattedDate, equals('21 Aug 2026'));
      expect(notif.formattedDateTime, equals('21 Aug 2026, 05:11 PM'));
    });
  });
}
