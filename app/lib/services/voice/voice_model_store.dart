import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../models/json_reader.dart';
import 'voice_engine.dart';

/// One file of the Supertonic model, with the size and SHA-256 it must have.
class VoiceModelFile {
  const VoiceModelFile({required this.path, required this.bytes, required this.sha256});

  factory VoiceModelFile.fromJson(Map<String, Object?> json) => VoiceModelFile(
    path: json.requireString('path'),
    bytes: json.requireInt('bytes'),
    sha256: json.requireString('sha256'),
  );

  /// Relative to the model folder, such as `onnx/vocoder.onnx`.
  final String path;
  final int bytes;
  final String sha256;
}

/// `assets/config/voice-model.json`: which model the app uses, pinned to one
/// revision of the Hugging Face repository, and what each file must hash to. A
/// new model is a new revision and a new list, shipped in a release, so the
/// voice never changes under a phone without an app update.
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

/// How much of the model is on the phone.
class DownloadProgress {
  const DownloadProgress({required this.receivedBytes, required this.totalBytes});

  final int receivedBytes;
  final int totalBytes;

  double get fraction => totalBytes == 0 ? 0 : receivedBytes / totalBytes;
}

/// The download failed or the files do not match the manifest.
class VoiceModelException extends VoiceException {
  const VoiceModelException(super.message);
}

/// The Supertonic model on the phone, as the voice service needs it.
abstract interface class VoiceModel {
  VoiceModelManifest get manifest;

  /// Downloaded, checked and complete for this revision.
  Future<bool> isReady();

  /// Downloads what is missing and checks it all. Throws [VoiceModelException]
  /// and can be called again to continue.
  Future<void> download({void Function(DownloadProgress progress)? onProgress});

  /// Frees the space: the model is not used on this phone.
  Future<void> deleteAll();
}

/// Downloads the Supertonic model and checks it, in the folder where the
/// package looks for it. It is the only code that fetches the model:
///
/// - From the pinned revision, never from `main`.
/// - Every file is checked against its SHA-256 before it takes its final name,
///   so a cut or tampered download never reaches the engine.
/// - A broken download resumes where it stopped.
/// - The caller decides when to run it (wifi, free space), not this class.
class VoiceModelStore implements VoiceModel {
  VoiceModelStore({
    required this.manifest,
    required this.directory,
    required this._client,
    this.idleTimeout = const Duration(seconds: 30),
  });

  @override
  final VoiceModelManifest manifest;

  /// The folder name `supertonic_flutter` 2.0.0 reads its model from, inside the
  /// app's support folder. A new version of the package can change it, which is
  /// why the package is pinned: an update is a decision, with this checked.
  static const packageFolder = 'supertonic_models_v3';

  /// The folder the Supertonic package reads: its `onnx` and `voice_styles`
  /// folders live inside.
  final Directory directory;
  final http.Client _client;

  /// How long the connection may stay silent before the download fails.
  final Duration idleTimeout;

  File get _marker => File('${directory.path}/.verified');

  File _file(VoiceModelFile file) => File('${directory.path}/${file.path}');

  /// True when a download finished and checked every file for this revision,
  /// and nothing was removed or cut since. The hashes are not read again here:
  /// that would take seconds on every start.
  @override
  Future<bool> isReady() async {
    if (!await _marker.exists() || (await _marker.readAsString()) != manifest.revision) {
      return false;
    }
    for (final file in manifest.files) {
      final local = _file(file);
      if (!await local.exists() || await local.length() != file.bytes) return false;
    }
    return true;
  }

  /// Downloads what is missing and checks it all. Safe to call again after a
  /// failure: it picks up the partial files.
  @override
  Future<void> download({void Function(DownloadProgress progress)? onProgress}) async {
    await directory.create(recursive: true);
    if (await _marker.exists()) await _marker.delete();

    var done = 0;
    void report(int inCurrent) => onProgress?.call(
      DownloadProgress(receivedBytes: done + inCurrent, totalBytes: manifest.totalBytes),
    );

    report(0);
    for (final file in manifest.files) {
      final local = _file(file);
      await local.parent.create(recursive: true);

      // A final file can only be here from an earlier run, and it is trusted
      // only if it still matches.
      if (await local.exists()) {
        if (await _sha256Of(local) == file.sha256) {
          done += file.bytes;
          report(0);
          continue;
        }
        await local.delete();
      }
      await _fetch(file, local, report);
      done += file.bytes;
      report(0);
    }
    await _marker.writeAsString(manifest.revision, flush: true);
  }

  Future<void> _fetch(VoiceModelFile file, File target, void Function(int) report) async {
    final partial = File('${target.path}.part');
    var resumeFrom = await partial.exists() ? await partial.length() : 0;
    if (resumeFrom > file.bytes) {
      await partial.delete();
      resumeFrom = 0;
    }

    final request = http.Request('GET', manifest.urlOf(file));
    if (resumeFrom > 0) request.headers['range'] = 'bytes=$resumeFrom-';

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(idleTimeout);
    } on Object catch (error) {
      throw VoiceModelException('Could not reach the model server: $error');
    }

    if (response.statusCode == 416) {
      // The partial file does not fit what the server has: start that file over.
      await response.stream.drain<void>();
      await partial.delete();
      return _fetch(file, target, report);
    }
    final resumed = response.statusCode == 206;
    if (response.statusCode != 200 && !resumed) {
      await response.stream.drain<void>();
      throw VoiceModelException('The model server answered ${response.statusCode}');
    }
    // A 200 to a Range request means the server sent the whole file again.
    if (!resumed) resumeFrom = 0;

    final sink = partial.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var received = resumeFrom;
    try {
      if (resumed) {
        await for (final chunk in partial.openRead(0, resumeFrom)) {
          hasher.add(chunk);
        }
      }
      await for (final chunk in response.stream.timeout(idleTimeout)) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        report(received);
      }
      await sink.flush();
    } on Object catch (error) {
      // The partial file stays for the next try.
      await sink.close();
      throw VoiceModelException('The download was cut: $error');
    }
    await sink.close();
    hasher.close();

    if (received != file.bytes || digest.events.single.toString() != file.sha256) {
      await partial.delete();
      throw VoiceModelException('${file.path} does not match the expected file');
    }
    await partial.rename(target.path);
  }

  Future<String> _sha256Of(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  @override
  Future<void> deleteAll() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Collects the digest a chunked conversion produces.
class _DigestSink implements Sink<Digest> {
  final events = <Digest>[];

  @override
  void add(Digest data) => events.add(data);

  @override
  void close() {}
}
