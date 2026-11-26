import '../domain/help_resource.dart';

abstract interface class HelpResourcesGateway {
  Future<HelpResources> helpResources();
}
