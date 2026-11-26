import 'package:url_launcher/url_launcher.dart';

import '../application/dialer.dart';

/// Opens the dialer for confirmation by the user.
class SystemDialer implements Dialer {
  const SystemDialer();

  @override
  Future<bool> dial(String phone) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: phone));
    } on Exception {
      return false;
    }
  }
}
