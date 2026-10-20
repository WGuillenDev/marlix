import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/screens/chat/avatar_controller.dart';
import 'package:marlix/screens/onboarding/profile_controller.dart';
import 'package:marlix/widgets/avatar_marlix.dart';

import '../helpers/fake_backend.dart';

String shownFolder(WidgetTester tester) =>
    tester.widget<AvatarMarlix>(find.byType(AvatarMarlix)).folder;

void main() {
  group('avatarFolderFrom', () {
    test('drops the trailing slash the seed stores', () {
      expect(avatarFolderFrom('assets/avatars/marlix/'), 'assets/avatars/marlix');
      expect(avatarFolderFrom('assets/avatars/otro'), 'assets/avatars/otro');
    });

    test('falls back to marlix when there is no folder or it is not a bundled avatar', () {
      for (final path in [null, '', 'https://example.com/avatars/x', 'assets/avatars/../x']) {
        expect(avatarFolderFrom(path), defaultAvatarFolder, reason: '$path');
      }
    });
  });

  testWidgets('the chat avatar loads the folder the backend sent', (tester) async {
    final backend = FakeBackend()..avatarLayersPath = 'assets/avatars/otro/';
    await openChat(tester, backend: backend);
    await tester.pumpAndSettle();

    expect(shownFolder(tester), 'assets/avatars/otro');
  });

  testWidgets('an older backend that sends no folder keeps marlix', (tester) async {
    final backend = FakeBackend()..avatarLayersPath = null;
    await openChat(tester, backend: backend);
    await tester.pumpAndSettle();

    expect(shownFolder(tester), defaultAvatarFolder);
  });

  testWidgets('the onboarding avatar uses the same folder', (tester) async {
    final backend = FakeBackend()
      ..onboardingDone = false
      ..avatarLayersPath = 'assets/avatars/otro/';
    await openChat(tester, backend: backend);
    await tester.pumpAndSettle();

    expect(shownFolder(tester), 'assets/avatars/otro');
  });

  test('a profile that fails to load leaves marlix, without breaking', () async {
    final container = ProviderContainer(
      overrides: [profileControllerProvider.overrideWith(_FailingProfile.new)],
    );
    addTearDown(container.dispose);

    expect(container.read(avatarFolderProvider), defaultAvatarFolder);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(profileControllerProvider).hasError, isTrue);
    expect(container.read(avatarFolderProvider), defaultAvatarFolder);
  });
}

class _FailingProfile extends ProfileController {
  @override
  Future<Never> build() async => throw StateError('offline');
}
