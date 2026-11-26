import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/dialer.dart';
import '../infrastructure/dialer.dart';

final dialerProvider = Provider<Dialer>((ref) => const SystemDialer());
