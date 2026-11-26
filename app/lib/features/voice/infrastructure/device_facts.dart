import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../application/device_facts.dart';

class AndroidDeviceFacts implements DeviceFacts {
  const AndroidDeviceFacts();

  static const _storage = MethodChannel('marlix/storage');

  @override
  Future<bool> isLowRam() async => (await DeviceInfoPlugin().androidInfo).isLowRamDevice;

  @override
  Future<int> freeBytes() async => (await _storage.invokeMethod<int>('freeBytes')) ?? 0;

  @override
  Future<ConnectionKind> connection() async {
    final kinds = await Connectivity().checkConnectivity();
    if (kinds.contains(ConnectivityResult.wifi) || kinds.contains(ConnectivityResult.ethernet)) {
      return ConnectionKind.unmetered;
    }
    if (kinds.contains(ConnectivityResult.mobile)) return ConnectionKind.mobile;
    // Treat a VPN with unknown transport as potentially metered.
    return kinds.every((kind) => kind == ConnectivityResult.none)
        ? ConnectionKind.none
        : ConnectionKind.mobile;
  }

  @override
  Future<String> fingerprint() async => (await DeviceInfoPlugin().androidInfo).fingerprint;
}
