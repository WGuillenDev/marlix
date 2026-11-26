import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../application/voice_model.dart';

/// Downloads a pinned model and verifies each file before making it available.
class VoiceModelStore implements VoiceModel {
  VoiceModelStore({
    required this.manifest,
    required this.directory,
    required this._client,
    this.idleTimeout = const Duration(seconds: 30),
  });

  @override
  final VoiceModelManifest manifest;

  /// Match the model directory required by the pinned Supertonic package.
  static const packageFolder = 'supertonic_models_v3';

  final Directory directory;
  final http.Client _client;

  final Duration idleTimeout;

  File get _marker => File('${directory.path}/.verified');

  File _file(VoiceModelFile file) => File('${directory.path}/${file.path}');

  /// Trust the stored verification result while the revision and file sizes still match.
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
      // Discard the partial file when the server rejects its range.
      await response.stream.drain<void>();
      await partial.delete();
      return _fetch(file, target, report);
    }
    final resumed = response.statusCode == 206;
    if (response.statusCode != 200 && !resumed) {
      await response.stream.drain<void>();
      throw VoiceModelException('The model server answered ${response.statusCode}');
    }
    // A 200 response to a range request restarts the file from byte zero.
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

class _DigestSink implements Sink<Digest> {
  final events = <Digest>[];

  @override
  void add(Digest data) => events.add(data);

  @override
  void close() {}
}
