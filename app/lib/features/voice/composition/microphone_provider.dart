import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/microphone_permission.dart';
import '../infrastructure/microphone_permission.dart';

final microphonePermissionProvider = Provider<MicrophonePermission>(
  (ref) => const SystemMicrophonePermission(),
);
