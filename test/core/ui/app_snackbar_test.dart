import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/core/ui/app_snackbar.dart';
import 'package:pantry_pal/core/ui/ui_message.dart';

void main() {
  group('AppSnackBar specifications', () {
    testWidgets('shows floating snackbar with rounded corners and margins', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showInfo(context, message: 'Floating snackbar test');
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();

      expect(find.text('Floating snackbar test'), findsOneWidget);

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);

      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.margin, AppSnackBar.defaultMargin);
      expect(
        snackBar.shape,
        isA<RoundedRectangleBorder>().having(
          (s) => s.borderRadius,
          'borderRadius',
          BorderRadius.circular(12),
        ),
      );
      expect(snackBar.duration, AppSnackBar.defaultDuration);
    });

    testWidgets('showWithAction sets 6-second duration and invokes callbacks', (tester) async {
      var actionTapped = false;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showWithAction(
                    context,
                    message: 'Deleted item',
                    actionLabel: 'Undo',
                    onAction: () => actionTapped = true,
                    onDismissed: () => dismissed = true,
                  );
                },
                child: const Text('Show Action'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Action'));
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, AppSnackBar.actionDuration);
      expect(snackBar.duration, const Duration(seconds: 6));
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
      // If action is tapped, onDismissed is not called (because closedReason is action)
      expect(dismissed, isFalse);
    });

    testWidgets('onDismissed fires when snackbar times out naturally', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showWithAction(
                    context,
                    message: 'Timed message',
                    actionLabel: 'Undo',
                    duration: const Duration(seconds: 1),
                    onAction: () {},
                    onDismissed: () => dismissed = true,
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(dismissed, isFalse);

      // Rebuild so ScaffoldMessenger sees controller.isCompleted and schedules timer
      await tester.pump();
      // Advance past timer and settle exit animation
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('rapid invocations clear previous snackbars immediately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AppSnackBar.showInfo(context, message: 'First message'),
                    child: const Text('First'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppSnackBar.showInfo(context, message: 'Second message'),
                    child: const Text('Second'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pump();
      expect(find.text('First message'), findsOneWidget);

      // Immediately tap second button
      await tester.tap(find.text('Second'));
      await tester.pump();

      // First should be immediately evicted by clearSnackBars(), only Second remains
      expect(find.text('First message'), findsNothing);
      expect(find.text('Second message'), findsOneWidget);
    });

    testWidgets('showUiMessage correctly renders semantic types', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  final msg = UiMessage<String>.create(
                    text: 'Success event',
                    type: UiMessageType.success,
                  );
                  AppSnackBar.showUiMessage(context, msg);
                },
                child: const Text('Show UiMessage'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show UiMessage'));
      await tester.pump();

      expect(find.text('Success event'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}
