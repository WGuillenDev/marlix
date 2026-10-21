import '../../models/voice_config.dart';

/// Why a phone speaks with its native voice although marlix prefers Supertonic.
enum NativeReason {
  /// The avatar's configuration asks for it.
  configured,

  /// The phone is marked as low on memory.
  lowRam,

  /// The model did not load on this phone, or the app was killed while loading
  /// it, or it failed too many times.
  loadFailed,

  /// Not enough free space for the model.
  noSpace,

  /// The phone makes audio too slowly for one sentence to be ready before the
  /// previous one ends.
  tooSlow,
}

/// What to do with Supertonic on a phone, before anything is downloaded.
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

/// The rules of docs/decisions.md ("Scaling to any phone"). Pure, so every
/// kind of phone can be described in a test.
abstract final class VoicePlanner {
  /// Free space needed to download the model: its 401 MB plus room to write and
  /// to keep the phone usable.
  static const minFreeBytes = 1 << 30;

  /// Seconds of audio per second of work. Speaking sentence by sentence only
  /// works if the next one is ready before the current one ends; 1.3 leaves a
  /// 30 % margin. S6-12 calibrates it on a low-end phone.
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

  /// After loading the model: is the phone fast enough?
  static bool fastEnough(double speed) => speed >= minSpeed;
}
