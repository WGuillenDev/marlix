import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The layers of the final artwork (S5-1) must fit when stacked.
const _dir = 'assets/avatars/marlix';
const _layers = [
  'cola',
  'pies',
  'cuerpo',
  'panza',
  'brazo_izq',
  'brazo_der',
  'cabeza',
  'oreja_izq',
  'oreja_der',
  'mejillas',
  'ojos_abiertos',
  'pupilas',
  'ojos_felices',
  'nariz',
  'boca_0',
  'boca_1',
  'boca_2',
  'boca_3',
  'boca_pensando',
];

void main() {
  test('every layer exists and shares the same canvas and origin', () {
    for (final name in _layers) {
      final file = File('$_dir/$name.svg');
      expect(file.existsSync(), isTrue, reason: '$name.svg is missing');
      expect(
        file.readAsStringSync(),
        contains('viewBox="0 0 512 512"'),
        reason: '$name.svg uses a different canvas',
      );
    }
  });

  testWidgets('the layers stack into the character', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            children: [
              for (final name in _layers)
                Positioned.fill(child: SvgPicture.asset('$_dir/$name.svg')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(_layers.length));
  });
}
