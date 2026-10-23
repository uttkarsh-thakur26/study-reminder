import 'package:flutter_test/flutter_test.dart';
import 'package:study_reminder/features/focus/domain/focus_prefs.dart';

void main() {
  test('a flip locks the phone unless turned off', () {
    expect(const FocusPrefs().flipLock, isTrue);
    final off = const FocusPrefs(flipToFocus: true).copyWith(flipLock: false);
    final back = FocusPrefs.decode(off.encode());
    expect(back.flipToFocus, isTrue);
    expect(back.flipLock, isFalse);
    expect(back.withSubject('maths').flipLock, isFalse);
  });

  test('settings saved before the lock existed lock after a flip', () {
    final saved = FocusPrefs.decode('{"flip": true, "minutes": 17}');
    expect(saved.minutes, 17);
    expect(saved.flipLock, isTrue);
  });
}
