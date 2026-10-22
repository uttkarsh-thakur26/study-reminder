import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something for the shell to do that comes from outside its pages, like a
/// global shortcut on Windows.
enum ShellRequest {
  /// Open Today with the cursor in the quick add field.
  quickAdd,

  /// Open the Focus page.
  focus,
}

/// The latest request. Its number grows with each one, so asking for the
/// same thing twice reaches the shell twice.
typedef NumberedShellRequest = ({ShellRequest request, int number});

final shellRequestsProvider =
    NotifierProvider<ShellRequests, NumberedShellRequest?>(ShellRequests.new);

class ShellRequests extends Notifier<NumberedShellRequest?> {
  @override
  NumberedShellRequest? build() => null;

  void send(ShellRequest request) =>
      state = (request: request, number: (state?.number ?? 0) + 1);
}
