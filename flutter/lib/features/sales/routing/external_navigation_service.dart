import 'package:flutter/services.dart';

/// Launches external turn-by-turn navigation in Google Maps on Android.
class ExternalNavigationService {
  static const MethodChannel _channel = MethodChannel('com.routidrow.distributor/navigation');

  /// Launches Google Maps turn-by-turn navigation to [latitude],[longitude].
  /// Uses Android package intent `com.google.android.apps.maps` with fallback to general geo intent.
  static Future<bool> launchTurnByTurn({
    required double latitude,
    required double longitude,
    String? destinationLabel,
  }) async {
    try {
      final uri = 'google.navigation:q=$latitude,$longitude&mode=d';
      final fallbackUrl = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving';

      final res = await _channel.invokeMethod<bool>('launchNavigation', {
        'uri': uri,
        'fallbackUrl': fallbackUrl,
        'label': destinationLabel ?? 'Next Shop',
      });
      return res ?? false;
    } on MissingPluginException {
      // In tests or headless environments where MainActivity platform channel isn't hooked
      return true;
    } catch (_) {
      return false;
    }
  }
}
