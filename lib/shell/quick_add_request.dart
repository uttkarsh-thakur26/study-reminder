import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the shell to open quick add on Today, as Ctrl+K does. The home
/// screen widget's "+" uses it.
final quickAddRequestsProvider = NotifierProvider<QuickAddRequests, int>(
  QuickAddRequests.new,
);

/// Counts the requests; the shell acts on each change.
class QuickAddRequests extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
