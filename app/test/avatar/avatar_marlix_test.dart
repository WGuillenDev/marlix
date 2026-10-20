import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/widgets/avatar_marlix.dart';

const _folder = 'assets/avatars/marlix';

Widget _avatar(AvatarState state, {double volume = 0, String folder = _folder}) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: 300,
      height: 300,
      child: AvatarMarlix(state: state, volume: volume, folder: folder),
    ),
  ),
);

void main() {
  test('the mouth follows the volume and never returns the closed smile', () {
    expect(mouthForVolume(0), 1);
    expect(mouthForVolume(0.19), 1);
    expect(mouthForVolume(0.2), 2);
    expect(mouthForVolume(0.59), 2);
    expect(mouthForVolume(0.6), 3);
    expect(mouthForVolume(1), 3);
  });

  testWidgets('every state renders and keeps animating without errors', (tester) async {
    for (final state in AvatarState.values) {
      await tester.pumpWidget(_avatar(state));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(tester.takeException(), isNull, reason: '$state');
    }
  });

  testWidgets('speaking picks the mouth from the volume', (tester) async {
    await tester.pumpWidget(_avatar(AvatarState.speaking, volume: 0.1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('boca_1')), findsOneWidget);

    await tester.pumpWidget(_avatar(AvatarState.speaking, volume: 0.9));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('boca_3')), findsOneWidget);
  });

  testWidgets('outside speaking the volume is ignored', (tester) async {
    await tester.pumpWidget(_avatar(AvatarState.idle, volume: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('boca_0')), findsOneWidget);
  });

  testWidgets('thinking has its own mouth', (tester) async {
    await tester.pumpWidget(_avatar(AvatarState.thinking));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('boca_pensando')), findsOneWidget);
  });

  testWidgets('changing state eases instead of jumping', (tester) async {
    await tester.pumpWidget(_avatar(AvatarState.idle));
    await tester.pumpWidget(_avatar(AvatarState.happy));
    await tester.pump(const Duration(milliseconds: 100));
    // Halfway through the transition the avatar is still on screen and not failing.
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AvatarMarlix), findsOneWidget);
  });

  testWidgets('a folder without layers leaves a gap instead of an error', (tester) async {
    await tester.pumpWidget(_avatar(AvatarState.idle, folder: 'assets/avatars/missing'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
