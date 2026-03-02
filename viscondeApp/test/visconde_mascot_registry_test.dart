import 'package:flutter_test/flutter_test.dart';
import 'package:visconde_app/design_system/visconde.dart';

void main() {
  test('all mascot poses resolve to mascot assets', () {
    for (final pose in ViscondeMascotPose.values) {
      final path = ViscondeMascot.resolvePose(pose);
      expect(path, startsWith('assets/design/mascot/'));
      expect(path, endsWith('.png'));
    }
  });
}
