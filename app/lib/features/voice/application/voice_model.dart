import '../../../shared/json_reader.dart';
import 'voice_engine.dart';

class VoiceModelFile {
  const VoiceModelFile({required this.path, required this.bytes, required this.sha256});

  factory VoiceModelFile.fromJson(Map<String, Object?> json) => VoiceModelFile(
    path: json.requireString('path'),
    bytes: json.requireInt('bytes'),
    sha256: json.requireString('sha256'),
  );

  final String path;
  final int bytes;
  final String sha256;
}

/// Pin the model revision and checksums so downloads cannot silently change voices.
class VoiceModelManifest {
  const VoiceModelManifest({required this.repo, required this.revision, required this.files});

  factory VoiceModelManifest.fromJson(Map<String, Object?> json) => VoiceModelManifest(
    repo: json.requireString('repo'),
    revision: json.requireString('revision'),
    files: json.requireList('files', VoiceModelFile.fromJson),
  );

  final String repo;
  final String revision;
  final List<VoiceModelFile> files;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.bytes);

  Uri urlOf(VoiceModelFile file) =>
      Uri.https('huggingface.co', '/$repo/resolve/$revision/${file.path}');
}

class DownloadProgress {
  const DownloadProgress({required this.receivedBytes, required this.totalBytes});

  final int receivedBytes;
  final int totalBytes;

  double get fraction => totalBytes == 0 ? 0 : receivedBytes / totalBytes;
}

class VoiceModelException extends VoiceException {
  const VoiceModelException(super.message);
}

abstract interface class VoiceModel {
  VoiceModelManifest get manifest;

  /// Downloaded, checked and complete for this revision.
  Future<bool> isReady();

  /// Verifies downloads and resumes incomplete files on retry.
  Future<void> download({void Function(DownloadProgress progress)? onProgress});

  Future<void> deleteAll();
}
