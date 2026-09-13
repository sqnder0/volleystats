import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volleystats/toggle_switch.dart';

void main() {
  testWidgets(
    'tapping the switch itself does not swallow the tap when onChanged is '
    'null, so a parent row can still handle it',
    (tester) async {
      var rowTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => rowTapped = true,
              behavior: HitTestBehavior.opaque,
              child: const VToggleSwitch(isOn: false),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(VToggleSwitch));
      await tester.pump();

      expect(
        rowTapped,
        true,
        reason:
            "VToggleSwitch's own GestureDetector must not exist (or must "
            "not claim the tap) when onChanged is null - otherwise it wins "
            "the gesture arena and the parent row's onTap never fires, "
            "which is exactly what happened for every settings toggle in "
            "the app.",
      );
    },
  );

  testWidgets('tapping the switch calls onChanged when it is provided', (
    tester,
  ) async {
    bool? newValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VToggleSwitch(isOn: false, onChanged: (v) => newValue = v),
        ),
      ),
    );

    await tester.tap(find.byType(VToggleSwitch));
    await tester.pump();

    expect(newValue, true);
  });
}
