import '../domain/voice_config.dart';

enum NativeReason {
  configured,

  lowRam,

  // Remember a failed model load so restarting the app does not repeat it.
  loadFailed,

  noSpace,

  /// The phone makes audio too slowly for one sentence to be ready before the
  /// previous one ends.
  tooSlow,
}

sealed class VoicePlan {
  const VoicePlan();
}

final class PlanNative extends VoicePlan {
  const PlanNative(this.reason);

  final NativeReason reason;
}

final class PlanSupertonic extends VoicePlan {
  const PlanSupertonic({required this.needsDownload});

  final bool needsDownload;
}

abstract final class VoicePlanner {
  /// Leave space for model files and normal device use.
  static const minFreeBytes = 1 << 30;

  /// Require synthesis headroom so the next sentence is ready before playback catches up.
  static const minSpeed = 1.3;

  static VoicePlan plan({
    required VoiceConfig config,
    required bool lowRam,
    required bool modelFailedBefore,
    required bool modelReady,
    required int freeBytes,
  }) {
    if (config.engine == VoiceEngineKind.native) return const PlanNative(NativeReason.configured);
    if (lowRam) return const PlanNative(NativeReason.lowRam);
    if (modelFailedBefore) return const PlanNative(NativeReason.loadFailed);
    if (!modelReady && freeBytes < minFreeBytes) return const PlanNative(NativeReason.noSpace);
    return PlanSupertonic(needsDownload: !modelReady);
  }

  static bool fastEnough(double speed) => speed >= minSpeed;
}
