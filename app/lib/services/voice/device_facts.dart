import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

/// How the phone is connected, for deciding whether to download 400 MB.
enum ConnectionKind {
  /// Wifi or a cable: not billed by the megabyte.
  unmetered,

  /// Mobile data.
  mobile,
  none,
}

/// What the voice choice needs to know about the phone. An interface so tests
/// can describe any phone, from a flagship to one with no space.
abstract interface class DeviceFacts {
  /// Android marks phones with little memory (the "Go" ones): the voice model
  /// needs about 640 MB while loaded, so those phones do not try it.
  Future<bool> isLowRam();

  /// Free bytes where the app keeps its files.
  Future<int> freeBytes();

  Future<ConnectionKind> connection();

  /// Changes when the phone or its system updates, so a speed measured before
  /// is measured again.
  Future<String> fingerprint();
}

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
    // A VPN or another kind of link says nothing about its cost: be careful.
    return kinds.every((kind) => kind == ConnectivityResult.none)
        ? ConnectionKind.none
        : ConnectionKind.mobile;
  }

  @override
  Future<String> fingerprint() async => (await DeviceInfoPlugin().androidInfo).fingerprint;
}
