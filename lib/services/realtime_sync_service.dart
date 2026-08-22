// lib/services/realtime_sync_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collection_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/loanee_model.dart';
import '../models/notification_model.dart';
import '../providers/collection_sheet_provider.dart';
import '../providers/loanee_provider.dart';
import '../providers/notification_provider.dart';
import 'supabase_service.dart';

class RealtimeSyncService {
  static final RealtimeSyncService instance = RealtimeSyncService._internal();
  RealtimeSyncService._internal();

  RealtimeChannel? _realtimeChannel;
  bool _isSubscribed = false;

  CollectionSheetProvider? _collectionProvider;
  LoaneeProvider? _loaneeProvider;
  NotificationProvider? _notificationProvider;

  /// Register providers once to prevent duplicate listeners
  void registerProviders({
    required CollectionSheetProvider collectionProvider,
    required LoaneeProvider loaneeProvider,
    required NotificationProvider notificationProvider,
  }) {
    _collectionProvider = collectionProvider;
    _loaneeProvider = loaneeProvider;
    _notificationProvider = notificationProvider;
  }

  /// Initialize and start Supabase Realtime Postgres Changes Subscription
  Future<void> startRealtimeSubscription() async {
    if (_isSubscribed && _realtimeChannel != null) {
      debugPrint('ℹ️ Realtime channel already active. Skipping duplicate subscription.');
      return;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      debugPrint('⚠️ Cannot start realtime: Supabase client is null.');
      return;
    }

    try {
      // Clean up previous channel if any
      if (_realtimeChannel != null) {
        await client.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
      }

      _realtimeChannel = client.channel('public_mangang_realtime_channel');

      // 1. Listen to 'ro_collection_payments' table
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ro_collection_payments',
        callback: (PostgresChangePayload payload) {
          _handlePaymentChange(payload);
        },
      );

      // 2. Listen to 'ro_collection_entries' table
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ro_collection_entries',
        callback: (PostgresChangePayload payload) {
          _handleCollectionEntryChange(payload);
        },
      );

      // 3. Listen to 'loanee_accounts' table
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'loanee_accounts',
        callback: (PostgresChangePayload payload) {
          _handleLoaneeAccountChange(payload);
        },
      );

      // 4. Listen to 'notifications' table
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        callback: (PostgresChangePayload payload) {
          _handleNotificationChange(payload);
        },
      );

      _realtimeChannel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _isSubscribed = true;
          debugPrint('🟢 Supabase Realtime connected & listening to (payments, entries, loanees, notifications)');
        } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.channelError) {
          _isSubscribed = false;
          debugPrint('🔴 Supabase Realtime channel status: $status, error: $error');
        }
      });
    } catch (e) {
      debugPrint('❌ Error starting realtime subscription: $e');
      _isSubscribed = false;
    }
  }

  // --- Handlers for Postgres Changes ---

  void _handlePaymentChange(PostgresChangePayload payload) {
    try {
      debugPrint('⚡ Realtime Payment Event: ${payload.eventType}');
      if (payload.eventType == PostgresChangeEvent.insert) {
        if (payload.newRecord.isNotEmpty) {
          final payment = CollectionPaymentModel.fromJson(Map<String, dynamic>.from(payload.newRecord));
          _collectionProvider?.handleRealtimePaymentInsert(payment);
          
          // Also update loanee account balance live
          final card = _collectionProvider?.getCardForPayment(payment);
          if (card != null) {
            _loaneeProvider?.recordPaymentForLoanee(
              customerId: card.customerId,
              accountNumber: card.accountNumber,
              paymentAmount: payment.paymentAmount,
              newRemainingBalance: payment.remainingBalance,
            );
          }
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord.isNotEmpty) {
          final payment = CollectionPaymentModel.fromJson(Map<String, dynamic>.from(payload.newRecord));
          _collectionProvider?.handleRealtimePaymentUpdate(payment);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null && id.isNotEmpty) {
          _collectionProvider?.handleRealtimePaymentDelete(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error processing realtime payment change: $e');
    }
  }

  void _handleCollectionEntryChange(PostgresChangePayload payload) {
    try {
      debugPrint('⚡ Realtime Collection Entry Event: ${payload.eventType}');
      if (payload.eventType == PostgresChangeEvent.insert) {
        if (payload.newRecord.isNotEmpty) {
          final entry = RoCollectionEntry.fromJson(Map<String, dynamic>.from(payload.newRecord));
          _collectionProvider?.handleRealtimeEntryInsert(entry);
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord.isNotEmpty) {
          final entry = RoCollectionEntry.fromJson(Map<String, dynamic>.from(payload.newRecord));
          _collectionProvider?.handleRealtimeEntryUpdate(entry);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null && id.isNotEmpty) {
          _collectionProvider?.handleRealtimeEntryDelete(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error processing realtime entry change: $e');
    }
  }

  void _handleLoaneeAccountChange(PostgresChangePayload payload) {
    try {
      debugPrint('⚡ Realtime Loanee Account Event: ${payload.eventType}');
      if (payload.eventType == PostgresChangeEvent.insert) {
        if (payload.newRecord.isNotEmpty) {
          final loanee = LoaneeAccount.fromJson(Map<String, dynamic>.from(payload.newRecord));
          _loaneeProvider?.handleRealtimeLoaneeInsert(loanee);
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord.isNotEmpty) {
          final loanee = LoaneeAccount.fromJson(Map<String, dynamic>.from(payload.newRecord));
          _loaneeProvider?.handleRealtimeLoaneeUpdate(loanee);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        final custId = payload.oldRecord['customerid']?.toString();
        if (custId != null && custId.isNotEmpty) {
          _loaneeProvider?.handleRealtimeLoaneeDelete(custId);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error processing realtime loanee change: $e');
    }
  }

  void _handleNotificationChange(PostgresChangePayload payload) {
    try {
      debugPrint('⚡ Realtime Notification Event: ${payload.eventType}');
      if (payload.eventType == PostgresChangeEvent.insert) {
        if (payload.newRecord.isNotEmpty) {
          final notif = AppNotification.fromJson(Map<String, dynamic>.from(payload.newRecord));
          _notificationProvider?.handleIncomingRealtimeNotification(notif);
        }
      } else if (payload.eventType == PostgresChangeEvent.update) {
        // Re-fetch or sync read status
        _notificationProvider?.fetchNotifications();
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null && id.isNotEmpty) {
          _notificationProvider?.deleteNotification(id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error processing realtime notification change: $e');
    }
  }

  /// Stop and unsubscribe when logging out or terminating
  Future<void> stopRealtimeSubscription() async {
    final client = SupabaseService.instance.client;
    if (client != null && _realtimeChannel != null) {
      try {
        await client.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
        _isSubscribed = false;
        debugPrint('⏹️ Supabase Realtime channel stopped and removed.');
      } catch (e) {
        debugPrint('⚠️ Error stopping realtime channel: $e');
      }
    }
  }
}
