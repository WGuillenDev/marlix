import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marlix/services/voice/voice_model_store.dart';

List<int> bytesOf(String text) => utf8.encode(text);

VoiceModelFile fileOf(String path, List<int> content) =>
    VoiceModelFile(path: path, bytes: content.length, sha256: sha256.convert(content).toString());

void main() {
  late Directory directory;
  final onnx = bytesOf('o' * 1000);
  final style = bytesOf('s' * 300);
  late VoiceModelManifest manifest;
  late Map<String, List<int>> server;
  late List<http.BaseRequest> requests;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('voice-model-test');
    manifest = VoiceModelManifest(
      repo: 'Supertone/supertonic-3',
      revision: 'abc123',
      files: [fileOf('onnx/model.onnx', onnx), fileOf('voice_styles/F4.json', style)],
    );
    server = {'onnx/model.onnx': onnx, 'voice_styles/F4.json': style};
    requests = [];
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  /// A fake Hugging Face. [cutAfter] drops the connection after that many bytes
  /// of the first answer; [ignoreRange] answers 200 with the whole file.
  VoiceModelStore store({
    int? cutAfter,
    bool ignoreRange = false,
    int? status,
    Duration idleTimeout = const Duration(seconds: 5),
  }) {
    var cut = cutAfter;
    final client = MockClient.streaming((request, _) async {
      requests.add(request);
      final path = request.url.path.split('/resolve/abc123/').last;
      final content = server[path]!;
      if (status != null) return http.StreamedResponse(const Stream.empty(), status);

      final range = request.headers['range'];
      final from = (!ignoreRange && range != null)
          ? int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!)
          : 0;
      final body = content.sublist(from);
      final stream = cut == null
          ? Stream.value(body)
          : (() async* {
              final limit = cut!;
              cut = null;
              yield body.sublist(0, limit);
              throw const SocketException('connection lost');
            })();
      return http.StreamedResponse(stream, from > 0 ? 206 : 200);
    });
    return VoiceModelStore(
      manifest: manifest,
      directory: directory,
      client: client,
      idleTimeout: idleTimeout,
    );
  }

  File file(String path) => File('${directory.path}/$path');

  test('downloads every file from the pinned revision and marks the model ready', () async {
    final progress = <DownloadProgress>[];
    final model = store();
    expect(await model.isReady(), isFalse);

    await model.download(onProgress: progress.add);

    expect(await model.isReady(), isTrue);
    expect(await file('onnx/model.onnx').readAsBytes(), onnx);
    expect(await file('voice_styles/F4.json').readAsBytes(), style);
    expect(requests.map((r) => r.url.toString()), [
      'https://huggingface.co/Supertone/supertonic-3/resolve/abc123/onnx/model.onnx',
      'https://huggingface.co/Supertone/supertonic-3/resolve/abc123/voice_styles/F4.json',
    ]);
    expect(progress.first.receivedBytes, 0);
    expect(progress.last.receivedBytes, manifest.totalBytes);
    expect(progress.last.fraction, 1);
  });

  test('never calls main: a file that does not match is refused and removed', () async {
    server['onnx/model.onnx'] = bytesOf('x' * 1000); // same size, other content
    final model = store();

    await expectLater(model.download(), throwsA(isA<VoiceModelException>()));

    expect(file('onnx/model.onnx').existsSync(), isFalse);
    expect(file('onnx/model.onnx.part').existsSync(), isFalse);
    expect(await model.isReady(), isFalse);
  });

  test('a file of the wrong size is refused', () async {
    server['voice_styles/F4.json'] = style.sublist(0, 100);
    final model = store();

    await expectLater(model.download(), throwsA(isA<VoiceModelException>()));
    expect(await model.isReady(), isFalse);
  });

  test('a server error stops the download with a clear message', () async {
    final model = store(status: 503);

    await expectLater(
      model.download(),
      throwsA(isA<VoiceModelException>().having((e) => e.message, 'message', contains('503'))),
    );
    expect(await model.isReady(), isFalse);
  });

  test('a cut connection keeps the partial file and the next try resumes it', () async {
    final first = store(cutAfter: 400);
    await expectLater(first.download(), throwsA(isA<VoiceModelException>()));
    expect(file('onnx/model.onnx.part').lengthSync(), 400);
    expect(file('onnx/model.onnx').existsSync(), isFalse);

    requests.clear();
    final second = store();
    await second.download();

    expect(requests.first.headers['range'], 'bytes=400-');
    expect(await file('onnx/model.onnx').readAsBytes(), onnx);
    expect(await second.isReady(), isTrue);
  });

  test('a server that ignores the range sends the whole file and it still checks out', () async {
    file('onnx/model.onnx.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(onnx.sublist(0, 250));

    final model = store(ignoreRange: true);
    await model.download();

    expect(await file('onnx/model.onnx').readAsBytes(), onnx);
    expect(await model.isReady(), isTrue);
  });

  test('a partial file that is corrupt is caught by the hash after resuming', () async {
    file('onnx/model.onnx.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytesOf('z' * 400));

    final model = store();
    await expectLater(model.download(), throwsA(isA<VoiceModelException>()));

    expect(file('onnx/model.onnx').existsSync(), isFalse);
    // The bad partial file is gone, so the next try starts clean and works.
    await model.download();
    expect(await model.isReady(), isTrue);
  });

  test('a file already on the phone that matches is not downloaded again', () async {
    file('onnx/model.onnx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(onnx);

    await store().download();

    expect(requests.map((r) => r.url.path), [contains('F4.json')]);
  });

  test('a file on the phone that does not match is replaced', () async {
    file('onnx/model.onnx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytesOf('x' * 1000));

    final model = store();
    await model.download();

    expect(await file('onnx/model.onnx').readAsBytes(), onnx);
  });

  test('a partial file longer than the real one starts over', () async {
    file('onnx/model.onnx.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytesOf('o' * 5000));

    final model = store();
    await model.download();

    expect(requests.first.headers.containsKey('range'), isFalse);
    expect(await model.isReady(), isTrue);
  });

  test('is not ready when a file is missing or has another size afterwards', () async {
    final model = store();
    await model.download();
    expect(await model.isReady(), isTrue);

    file('voice_styles/F4.json').writeAsBytesSync(style.sublist(0, 10));
    expect(await model.isReady(), isFalse);
  });

  test('is not ready for another revision of the model', () async {
    await store().download();
    final other = VoiceModelStore(
      manifest: VoiceModelManifest(repo: manifest.repo, revision: 'def456', files: manifest.files),
      directory: directory,
      client: MockClient((_) async => http.Response('', 500)),
    );

    expect(await other.isReady(), isFalse);
  });

  test('starting a new download takes the ready mark away until it finishes', () async {
    final model = store();
    await model.download();
    server['onnx/model.onnx'] = bytesOf('x' * 1000);
    file('onnx/model.onnx').deleteSync();

    await expectLater(model.download(), throwsA(isA<VoiceModelException>()));
    expect(await model.isReady(), isFalse);
  });

  test('deleteAll frees the folder', () async {
    final model = store();
    await model.download();

    await model.deleteAll();

    expect(directory.existsSync(), isFalse);
    expect(await model.isReady(), isFalse);
  });

  test('a connection that goes silent fails instead of hanging', () async {
    // A socket that sends a little and then stays open and silent.
    final client = MockClient.streaming((request, _) async {
      final silent = StreamController<List<int>>()..add([1, 2, 3]);
      return http.StreamedResponse(silent.stream, 200);
    });
    final model = VoiceModelStore(
      manifest: manifest,
      directory: directory,
      client: client,
      idleTimeout: const Duration(milliseconds: 100),
    );

    await expectLater(model.download(), throwsA(isA<VoiceModelException>()));
  });

  test('the real manifest lists the 16 files with a SHA-256 each', () {
    final json = jsonDecode(
      File('assets/config/voice-model.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final real = VoiceModelManifest.fromJson(json);

    expect(real.revision, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(real.files, hasLength(16));
    expect(real.files.map((f) => f.path), contains('voice_styles/F4.json'));
    for (final f in real.files) {
      expect(f.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: f.path);
      expect(f.bytes, greaterThan(0));
    }
    expect(real.totalBytes, inInclusiveRange(400000000, 402000000));
  });
}
