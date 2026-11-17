import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cfm/player/widgets/volume_meter.dart';

void main() {
  Future<List<int>> pumpMeter(WidgetTester tester, {int volume = 50}) async {
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VolumeMeter(
              volume: volume,
              muted: false,
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('tapping a bar sets the volume up to that bar', (tester) async {
    final changes = await pumpMeter(tester);
    final box = tester.getRect(find.byType(VolumeMeter));

    await tester.tapAt(box.centerRight - const Offset(6, 0));
    await tester.tapAt(box.centerLeft + const Offset(6, 0));

    expect(changes, [100, 0]);
  });

  testWidgets('arrow keys step the volume when focused', (tester) async {
    final changes = await pumpMeter(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

    // The parent never rebuilds with the new value, so both step from 50.
    expect(changes, [60, 40]);
  });
}
