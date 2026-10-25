import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/voice_config.dart';
import 'package:marlix/services/voice/device_facts.dart';
import 'package:marlix/services/voice/voice_engine.dart';
import 'package:marlix/services/voice/voice_memory.dart';
import 'package:marlix/services/voice/voice_model_store.dart';
import 'package:marlix/services/voice/voice_planner.dart';
import 'package:marlix/services/voice/voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_fakes.dart';

/// A phone with its voice service, so each test only says what is different.
class Rig {
  Rig._(this.facts, this.model, this.memory, this.config) {
    service = VoiceService(
      config: () => config,
      facts: facts,
      memory: memory,
      model: model,
      createSupertonic: (_) =>
          supertonic = nextSupertonic ?? FakeEngine(VoiceEngineKind.supertonic),
      createNative: (_) => native,
      onStatus: statuses.add,
    );
  }

  static Future<Rig> create({
    FakeFacts? facts,
    FakeModel? model,
    VoiceConfig config = VoiceConfig.defaults,
    Map<String, Object> saved = const {},
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    final preferences = await SharedPreferences.getInstance();
    return Rig._(
      facts ?? FakeFacts(),
      model ?? FakeModel(ready: true),
      VoiceMemory(preferences),
      config,
    );
  }

  final FakeFacts facts;
  final FakeModel model;
  final VoiceMemory memory;
  final VoiceConfig config;
  final statuses = <VoiceStatus>[];
  final native = FakeEngine(VoiceEngineKind.native);
  late FakeEngine supertonic;
  FakeEngine? nextSupertonic;
  late final VoiceService service;

  VoiceStatus get status => service.status;

  Future<List<VoiceEvent>> say(String text) => service.speak(text).toList();
}

Matcher readyWith(VoiceEngineKind engine, [NativeReason? reason]) => isA<VoiceReady>()
    .having((s) => s.engine, 'engine', engine)
    .having((s) => s.reason, 'reason', reason);

void main() {
  group('choosing the engine for the phone', () {
    test('a capable phone with the model ready speaks with Supertonic', () async {
      final rig = await Rig.create();

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
      expect(rig.supertonic.prepared, 1);
      expect(rig.native.prepared, 0, reason: 'the native voice is only prepared if needed');
    });

    test('the avatar configuration can ask for the native voice', () async {
      final rig = await Rig.create(
        config: const VoiceConfig(
          engine: VoiceEngineKind.native,
          voice: 'default',
          language: 'es',
          steps: 5,
          rate: 1,
          fallback: NativeVoiceConfig(voice: 'default', pitch: 1, rate: 1),
        ),
      );

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.configured));
      expect(rig.model.downloads, 0);
    });

    test('a low-RAM phone never tries Supertonic nor downloads the model', () async {
      final rig = await Rig.create(facts: FakeFacts(lowRam: true), model: FakeModel());

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.lowRam));
      expect(rig.model.downloads, 0);
      expect(rig.native.prepared, 1);
    });

    test('a phone without free space does not offer the download', () async {
      final rig = await Rig.create(
        facts: FakeFacts(free: 500 << 20),
        model: FakeModel(),
      );

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.noSpace));
    });

    test('a phone that already has the model does not need free space', () async {
      final rig = await Rig.create(facts: FakeFacts(free: 10 << 20));

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('a phone too slow for the model uses the native voice and frees the space', () async {
      final rig = await Rig.create();
      rig.nextSupertonic = FakeEngine(VoiceEngineKind.supertonic, speed: 1.0);

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.tooSlow));
      expect(rig.supertonic.disposed, isTrue);
      expect(rig.model.deletions, 1);
    });

    test('exactly the minimum speed is enough', () async {
      final rig = await Rig.create();
      rig.nextSupertonic = FakeEngine(VoiceEngineKind.supertonic, speed: VoicePlanner.minSpeed);

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('the speed is measured once per phone and model, not at every start', () async {
      final rig = await Rig.create();

      await rig.service.start();
      await rig.service.start();

      expect(rig.supertonic.benchmarks, 0, reason: 'the second engine reused the saved speed');
      expect(rig.memory.speed('phone-1|rev1|5|F4'), 3.0);
    });

    test('a slow phone is not offered the download again, until its system changes', () async {
      final rig = await Rig.create();
      rig.nextSupertonic = FakeEngine(VoiceEngineKind.supertonic, speed: 1.0);
      await rig.service.start();

      await rig.service.start();
      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.tooSlow));
      expect(rig.model.downloads, 0);

      rig.facts.print = 'phone-1-updated';
      await rig.service.start();
      expect(rig.status, isA<VoiceNeedsDownload>());
    });

    test('a model that does not load sends the phone to the native voice for good', () async {
      final rig = await Rig.create();
      rig.nextSupertonic = FakeEngine(
        VoiceEngineKind.supertonic,
        prepareError: const VoiceException('out of memory'),
      );

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.loadFailed));
      expect(rig.model.deletions, 1);
      expect(rig.supertonic.disposed, isTrue);

      rig.model.ready = true; // even if the files came back
      await rig.service.start();
      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.loadFailed));
    });

    test('a phone whose app died while loading the model is not tried again', () async {
      final rig = await Rig.create(saved: {'voice_loading_revision': 'rev1'});

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.loadFailed));
      expect(rig.memory.loadStarted, isNull);
      expect(rig.model.downloads, 0);
    });

    test('a load flag of an older model does not condemn the new one', () async {
      final rig = await Rig.create(saved: {'voice_loading_revision': 'older'});

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
      expect(rig.memory.loadStarted, isNull);
    });

    test('a failed model of an older revision gets another chance with the new one', () async {
      final rig = await Rig.create(saved: {'voice_failed_revision': 'older'});

      await rig.service.start();

      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('the load flag is set while loading and cleared after', () async {
      final rig = await Rig.create();
      String? during;
      rig.nextSupertonic = FakeEngine(
        VoiceEngineKind.supertonic,
        onPrepare: () => during = rig.memory.loadStarted,
      );

      await rig.service.start();

      expect(during, 'rev1');
      expect(rig.memory.loadStarted, isNull);
    });
  });

  group('downloading the model', () {
    test('without the model the phone offers the download and speaks natively meanwhile', () async {
      final rig = await Rig.create(model: FakeModel());

      await rig.service.start();

      expect(rig.status, isA<VoiceNeedsDownload>().having((s) => s.totalBytes, 'bytes', 400));
      expect(rig.model.downloads, 0, reason: 'the person decides, nothing downloads by itself');

      await rig.say('Hola. Qué tal.');
      expect(rig.native.spoken, ['Hola.', 'Qué tal.']);
    });

    test('over wifi it downloads, loads the model and switches to Supertonic', () async {
      final rig = await Rig.create(model: FakeModel());
      await rig.service.start();

      await rig.service.download();

      expect(rig.model.downloads, 1);
      expect(rig.statuses.whereType<VoiceDownloading>(), isNotEmpty);
      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('over mobile data it waits for the person to allow it', () async {
      final rig = await Rig.create(
        model: FakeModel(),
        facts: FakeFacts(link: ConnectionKind.mobile),
      );
      await rig.service.start();

      await rig.service.download();
      expect(rig.model.downloads, 0);
      expect(
        rig.status,
        isA<VoiceNeedsDownload>().having((s) => s.connection, 'link', ConnectionKind.mobile),
      );

      await rig.service.download(allowMobileData: true);
      expect(rig.model.downloads, 1);
      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('without a connection it says so and keeps the offer', () async {
      final rig = await Rig.create(
        model: FakeModel(),
        facts: FakeFacts(link: ConnectionKind.none),
      );
      await rig.service.start();

      await rig.service.download();

      expect(rig.model.downloads, 0);
      expect(rig.status, isA<VoiceNeedsDownload>().having((s) => s.failure, 'failure', isNotNull));
    });

    test('a download that fails keeps the offer, and the next try goes on', () async {
      final model = FakeModel()
        ..onDownload = () async => throw const VoiceModelException('The download was cut');
      final rig = await Rig.create(model: model);
      await rig.service.start();

      await rig.service.download();
      expect(
        rig.status,
        isA<VoiceNeedsDownload>().having((s) => s.failure, 'failure', 'The download was cut'),
      );
      expect(model.deletions, 0, reason: 'the partial files are kept to resume');

      model.onDownload = null;
      await rig.service.download();
      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('space that ran out before the download makes it give up cleanly', () async {
      final rig = await Rig.create(model: FakeModel());
      await rig.service.start();
      rig.facts.free = 100 << 20;

      await rig.service.download();

      expect(rig.model.downloads, 0);
      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.noSpace));
    });

    test('downloading does nothing when the voice is not waiting for the model', () async {
      final rig = await Rig.create();
      await rig.service.start();

      await rig.service.download();

      expect(rig.model.downloads, 0);
    });
  });

  group('speaking', () {
    test('says each sentence in order and reports one start, the progress and one end', () async {
      final rig = await Rig.create();
      await rig.service.start();

      final events = await rig.say('Hola. ¿Cómo estás? Bien.');

      expect(rig.supertonic.spoken, ['Hola.', '¿Cómo estás?', 'Bien.']);
      expect(events.whereType<VoiceStarted>(), hasLength(1));
      expect((events.first as VoiceStarted).engine, VoiceEngineKind.supertonic);
      expect(events.last, isA<VoiceFinished>());
      expect(events.whereType<VoiceFinished>(), hasLength(1));

      final progress = events.whereType<VoiceProgress>().map((e) => e.fraction).toList();
      expect(progress, orderedEquals([...progress]..sort()));
      expect(progress.every((p) => p >= 0 && p <= 1), isTrue);
    });

    test(
      'prepares the next sentence while the current one plays, so there is no silence',
      () async {
        final rig = await Rig.create();
        await rig.service.start();

        await rig.say('Uno. Dos. Tres.');

        expect(rig.supertonic.warmed, ['Dos.', 'Tres.'], reason: 'the last one has no next');
        // Each one was asked for once the previous was already playing, never earlier.
        expect(rig.supertonic.spokenWhenWarmed, [1, 2]);
      },
    );

    test('a single sentence prepares nothing', () async {
      final rig = await Rig.create();
      await rig.service.start();

      await rig.say('Solo esta.');

      expect(rig.supertonic.warmed, isEmpty);
    });

    test('if Supertonic fails in the middle of a reply, that reply goes on natively', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.scripts
        ..add([VoiceStarted(VoiceEngineKind.supertonic), const VoiceFinished()])
        ..add([const VoiceException('audio failed')]);

      final events = await rig.say('Uno. Dos. Tres.');

      expect(rig.supertonic.spoken, ['Uno.', 'Dos.']);
      expect(rig.native.spoken, [
        'Dos.',
        'Tres.',
      ], reason: 'the failed sentence is repeated, none is lost');
      expect(events.whereType<VoiceStarted>(), hasLength(1));
      expect(events.last, isA<VoiceFinished>());
    });

    test('the next reply tries Supertonic again after one failure', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.scripts.add([const VoiceException('hiccup')]);
      await rig.say('Uno.');

      await rig.say('Dos.');

      expect(rig.supertonic.spoken, ['Uno.', 'Dos.']);
      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('after three failures in a row Supertonic is dropped until the app restarts', () async {
      final rig = await Rig.create();
      await rig.service.start();
      for (var i = 0; i < VoiceService.failuresToGiveUp; i++) {
        rig.supertonic.scripts.add([const VoiceException('broken')]);
        await rig.say('Frase $i.');
      }

      expect(rig.status, readyWith(VoiceEngineKind.native, NativeReason.loadFailed));
      expect(rig.supertonic.disposed, isTrue);

      await rig.say('Otra.');
      expect(rig.supertonic.spoken, hasLength(VoiceService.failuresToGiveUp));
    });

    test('a success in between resets the count of failures', () async {
      final rig = await Rig.create();
      await rig.service.start();
      for (var i = 0; i < VoiceService.failuresToGiveUp - 1; i++) {
        rig.supertonic.scripts.add([const VoiceException('broken')]);
        await rig.say('Mala $i.');
      }
      await rig.say('Buena.');
      rig.supertonic.scripts.add([const VoiceException('broken')]);
      await rig.say('Mala otra vez.');

      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('without Spanish voices the phone says so and the stream carries an error', () async {
      final rig = await Rig.create(facts: FakeFacts(lowRam: true));
      final noVoice = FakeEngine(
        VoiceEngineKind.native,
        prepareError: const NoSpanishVoiceException(),
      );
      final service = VoiceService(
        config: () => VoiceConfig.defaults,
        facts: rig.facts,
        memory: rig.memory,
        model: rig.model,
        createSupertonic: (_) => FakeEngine(VoiceEngineKind.supertonic),
        createNative: (_) => noVoice,
        onStatus: rig.statuses.add,
      );

      await service.start();
      expect(service.status, isA<VoiceUnavailable>());

      await expectLater(service.speak('Hola.'), emitsError(isA<NoSpanishVoiceException>()));
    });

    test(
      'a Supertonic phone with no Spanish voice only finds out if it needs the fallback',
      () async {
        final rig = await Rig.create();
        final noVoice = FakeEngine(
          VoiceEngineKind.native,
          prepareError: const NoSpanishVoiceException(),
        );
        final service = VoiceService(
          config: () => VoiceConfig.defaults,
          facts: rig.facts,
          memory: rig.memory,
          model: rig.model,
          createSupertonic: (_) => rig.supertonic = FakeEngine(VoiceEngineKind.supertonic),
          createNative: (_) => noVoice,
          onStatus: rig.statuses.add,
        );
        await service.start();
        expect(service.status, readyWith(VoiceEngineKind.supertonic));

        rig.supertonic.scripts.add([const VoiceException('broken')]);
        await expectLater(service.speak('Hola.'), emitsError(isA<NoSpanishVoiceException>()));
        expect(service.status, isA<VoiceUnavailable>());
      },
    );

    test(
      'a native voice that fails ends the reply with an error and says there is no voice',
      () async {
        final rig = await Rig.create(facts: FakeFacts(lowRam: true));
        await rig.service.start();
        rig.native.scripts.add([const VoiceException('engine died')]);

        await expectLater(rig.service.speak('Hola.'), emitsError(isA<VoiceException>()));
        expect(rig.status, isA<VoiceUnavailable>());
      },
    );

    test('a failing native voice does not hide a working Supertonic', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.scripts.add([const VoiceException('broken')]);
      rig.native.scripts.add([const VoiceException('no voice data')]);

      await expectLater(rig.service.speak('Hola.'), emitsError(isA<VoiceException>()));
      expect(rig.status, readyWith(VoiceEngineKind.supertonic));
    });

    test('stop cuts the reply without a finish and speaks nothing more', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.hold = Completer<void>();
      final events = <VoiceEvent>[];
      final done = rig.service.speak('Uno. Dos. Tres.').forEach(events.add);
      await pumpEventQueue();

      await rig.service.stop();
      await done;

      expect(events.whereType<VoiceFinished>(), isEmpty);
      expect(rig.supertonic.spoken, ['Uno.']);
    });

    test('a new reply cuts the one still speaking', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.hold = Completer<void>();
      final first = rig.service.speak('Uno. Dos.').toList();
      await pumpEventQueue();

      final second = await rig.say('Tres.');
      final firstEvents = await first;

      expect(firstEvents.whereType<VoiceFinished>(), isEmpty);
      expect(second.last, isA<VoiceFinished>());
      expect(rig.supertonic.spoken, ['Uno.', 'Tres.']);
    });

    test('pausing holds the engine and resuming lets it go on', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.hold = Completer<void>();
      final events = rig.service.speak('Uno.').toList();
      await pumpEventQueue();

      await rig.service.pause();
      expect(rig.service.isPaused, isTrue);
      expect(rig.supertonic.pauses, 1);

      await rig.service.resume();
      rig.supertonic.hold!.complete();

      expect(rig.service.isPaused, isFalse);
      expect(rig.supertonic.resumes, 1);
      expect((await events).last, isA<VoiceFinished>());
    });

    test('a sentence that ends while paused does not start the next one', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.hold = Completer<void>();
      final events = rig.service.speak('Uno. Dos.').toList();
      await pumpEventQueue();

      await rig.service.pause();
      rig.supertonic.hold!.complete();
      await pumpEventQueue();
      expect(rig.supertonic.spoken, ['Uno.']);

      await rig.service.resume();

      expect((await events).last, isA<VoiceFinished>());
      expect(rig.supertonic.spoken, ['Uno.', 'Dos.']);
    });

    test('stopping while paused ends the speech and drops the rest', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.hold = Completer<void>();
      final events = rig.service.speak('Uno. Dos.').toList();
      await pumpEventQueue();
      await rig.service.pause();
      rig.supertonic.hold!.complete();
      await pumpEventQueue();

      await rig.service.stop();

      expect((await events).whereType<VoiceFinished>(), isEmpty);
      expect(rig.service.isPaused, isFalse);
      expect(rig.supertonic.spoken, ['Uno.']);
    });

    test('a new reply while paused starts speaking at once', () async {
      final rig = await Rig.create();
      await rig.service.start();
      rig.supertonic.hold = Completer<void>();
      final first = rig.service.speak('Uno.').toList();
      await pumpEventQueue();
      await rig.service.pause();

      final second = await rig.say('Dos.');
      await first;

      expect(second.last, isA<VoiceFinished>());
      expect(rig.service.isPaused, isFalse);
    });

    test('an empty text finishes at once without touching an engine', () async {
      final rig = await Rig.create();
      await rig.service.start();

      final events = await rig.say('   ');

      expect(events.single, isA<VoiceFinished>());
      expect(rig.supertonic.spoken, isEmpty);
    });
  });

  test('changing the configuration and starting again loads the new voice', () async {
    final rig = await Rig.create();
    await rig.service.start();
    final first = rig.supertonic;

    await rig.service.start();

    expect(first.disposed, isTrue, reason: 'the old engine is released');
    expect(rig.supertonic, isNot(same(first)));
    expect(rig.status, readyWith(VoiceEngineKind.supertonic));
  });
}
