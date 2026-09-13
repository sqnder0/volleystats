import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volleystats/stat_card.dart';

void main() {
  testWidgets(
    'VStatCard cards in a row stay the same height regardless of label length',
    (tester) async {
      // Mirrors _buildStatsRow's four-card layout in main.dart: Gewonnen was
      // the only label long enough to wrap to two lines at this width,
      // making that one card taller than its siblings.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(child: VStatCard(value: 12, label: 'Gewonnen')),
                const SizedBox(width: 10),
                Expanded(child: VStatCard(value: 3, label: 'Verloren')),
                const SizedBox(width: 10),
                Expanded(child: VStatCard(value: 5, label: 'Sets +/-')),
                const SizedBox(width: 10),
                Expanded(child: VStatCard(value: 30, label: 'Punten')),
              ],
            ),
          ),
        ),
      );

      final heights = tester
          .widgetList(find.byType(VStatCard))
          .map((w) => tester.getSize(find.byWidget(w)).height)
          .toSet();

      expect(
        heights.length,
        1,
        reason: 'all four stat cards should render at the same height',
      );
    },
  );

  testWidgets('VStatCard label never wraps past one line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            child: VStatCard(value: 1, label: 'A much longer label than fits'),
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(
      find.text('A much longer label than fits'),
    );
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
