import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/app.dart';

void main() {
  testWidgets('opens on the start screen', (tester) async {
    await tester.pumpWidget(const MarlixApp());

    expect(find.text('marlix'), findsOneWidget);
    expect(find.text('Pronto vamos a poder conversar acá.'), findsOneWidget);
  });
}
