import '../domain/sync_record.dart';

/// The sync server, as the app uses it. Every call passes this device's
/// secret, which is the only credential.
abstract interface class SyncApi {
  /// Registers this device, or refreshes its name. Returns its space.
  Future<Registration> register({
    required String secret,
    required String name,
    required bool isPhone,
  });

  Future<PairingCode> createPairingCode(String secret);

  /// Joins the space of the device that showed [code]. Returns the space id.
  /// Throws [PairingException] for a wrong or expired code.
  Future<String> joinSpace(String secret, String code);

  /// Unpairs this device into a new space of its own. Returns its id.
  Future<String> leaveSpace(String secret);

  Future<List<SyncedDevice>> listDevices(String secret);

  /// Merges [records] into the space. Returns how many changed there.
  Future<int> push(String secret, List<SyncRecord> records);

  /// Records changed after [after], oldest first.
  Future<List<SyncRecord>> pull(String secret, {required int after, int limit});

  /// Saves this phone's push token, or clears it with null.
  Future<void> setPushToken(String secret, String? token);

  /// Asks the server to wake the other devices about the phone's focus
  /// session it now has, and to hand them [notice] to show. Best effort: may
  /// do nothing when push is not set up.
  Future<void> wakeOtherDevices(String secret, {Map<String, Object?>? notice});

  /// Fires when another device changes something in [spaceId]. May never
  /// fire (no connection); the app also syncs on its own schedule.
  Stream<void> changes(String spaceId);

  Future<void> close();
}

class Registration {
  const Registration({required this.deviceId, required this.spaceId});

  final String deviceId;
  final String spaceId;
}

/// The server no longer knows this device (for example the project was
/// reset). The app registers again and pushes everything.
class UnknownDeviceException implements Exception {
  const UnknownDeviceException();
}

enum PairingProblem { wrongCode, tooManyTries }

class PairingException implements Exception {
  const PairingException(this.problem);

  final PairingProblem problem;

  String get message => switch (problem) {
    PairingProblem.wrongCode =>
      'That code did not work. Codes last 10 minutes and work once.',
    PairingProblem.tooManyTries =>
      'Too many wrong codes. Wait 10 minutes and try again.',
  };
}

/// The server could not be reached, or answered with something unexpected.
class SyncUnavailable implements Exception {
  const SyncUnavailable(this.cause);

  final Object cause;

  @override
  String toString() => 'Sync unavailable: $cause';
}
