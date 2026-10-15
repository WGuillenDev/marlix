import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer with the number loaded. It never places the call
/// by itself: the person always confirms on the dialer.
class Dialer {
  const Dialer();

  /// False when the device has no dialer (a tablet, for example).
  Future<bool> dial(String phone) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: phone));
    } on Exception {
      return false;
    }
  }
}

/// Overridden in tests to record the numbers instead of opening the dialer.
final dialerProvider = Provider<Dialer>((ref) => const Dialer());
