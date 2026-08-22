// lib/services/sound_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService instance = SoundService._internal();
  SoundService._internal() {
    _initPlayer();
  }

  AudioPlayer? _player;
  bool isMuted = false;

  void _initPlayer() {
    try {
      _player = AudioPlayer();
      _player?.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('⚠️ Error initializing AudioPlayer in SoundService: $e');
    }
  }

  /// Play appropriate sound for incoming notification
  Future<void> playNotificationSound({bool isPayment = false}) async {
    if (isMuted) return;

    try {
      // Trigger haptic vibration on mobile devices
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}

      final player = _player ?? AudioPlayer();
      _player = player;

      // Stop any current sound before playing new one
      await player.stop();

      final assetPath = isPayment
          ? 'sounds/payment_success.wav'
          : 'sounds/notification_ding.wav';

      await player.play(AssetSource(assetPath), volume: 1.0);
    } catch (e) {
      debugPrint('⚠️ AudioPlayer play error, falling back to SystemSound: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Play payment received sound explicitly
  Future<void> playPaymentSound() async {
    await playNotificationSound(isPayment: true);
  }

  /// Play general notification ding explicitly
  Future<void> playDingSound() async {
    await playNotificationSound(isPayment: false);
  }

  void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
  }
}
