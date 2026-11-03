import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/core/ui/app_snackbar.dart';

void main() {
  group('AppSnackBar Top Banner specifications', () {
    testWidgets(
      'shows at top of screen: below safe area, above vertical middle, on screen with AppBar',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.only(top: 44), // Simulate notch / safe area
                size: Size(400, 800),
              ),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Inventory Page')),
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showInfo(context, message: 'Top banner test');
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Top banner test'), findsOneWidget);
        final cardFinder = find.byKey(const Key('app_top_banner_card'));
        expect(cardFinder, findsOneWidget);

        final bannerTopLeft = tester.getTopLeft(cardFinder);
        final bannerBottom = tester.getBottomLeft(cardFinder).dy;

        // 1. Below top safe area (44dp + top padding)
        expect(bannerTopLeft.dy, greaterThanOrEqualTo(44.0));

        // 2. Well above the vertical middle of the screen (800 / 2 = 400)
        expect(bannerBottom, lessThan(400.0));
      },
    );

    testWidgets(
      'remains visible and unaffected when on-screen keyboard is open',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.only(top: 40),
                viewInsets: EdgeInsets.only(bottom: 350), // Keyboard open
                size: Size(400, 800),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showInfo(
                      context,
                      message: 'Message with keyboard',
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

        expect(find.text('Message with keyboard'), findsOneWidget);
        final cardFinder = find.byKey(const Key('app_top_banner_card'));
        final bannerTopLeft = tester.getTopLeft(cardFinder);

        // Banner remains firmly at top of viewport
        expect(bannerTopLeft.dy, greaterThanOrEqualTo(40.0));
        expect(bannerTopLeft.dy, lessThan(100.0));
      },
    );

    testWidgets(
      'two messages in a row leaves exactly one banner (the second), only second Undo works',
      (tester) async {
        var actionACalled = false;
        var actionBCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          AppSnackBar.showWithAction(
                            context,
                            message: 'First item deleted',
                            actionLabel: 'Undo A',
                            onAction: () => actionACalled = true,
                          );
                        },
                        child: const Text('Trigger A'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          AppSnackBar.showWithAction(
                            context,
                            message: 'Second item deleted',
                            actionLabel: 'Undo B',
                            onAction: () => actionBCalled = true,
                          );
                        },
                        child: const Text('Trigger B'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // 1. Show message A
        await tester.tap(find.text('Trigger A'));
        await tester.pumpAndSettle();
        expect(find.text('First item deleted'), findsOneWidget);

        // 2. Rapidly show message B
        await tester.tap(find.text('Trigger B'));
        await tester.pumpAndSettle();

        // Only B is visible, exactly ONE banner in the tree
        expect(find.text('First item deleted'), findsNothing);
        expect(find.text('Second item deleted'), findsOneWidget);
        expect(find.byKey(const Key('app_top_banner')), findsOneWidget);
        expect(find.text('Undo B'), findsOneWidget);

        // 3. Tap Undo on B
        await tester.tap(find.text('Undo B'));
        await tester.pumpAndSettle();

        expect(actionBCalled, isTrue);
        expect(actionACalled, isFalse);
        expect(find.byKey(const Key('app_top_banner')), findsNothing);
      },
    );

    testWidgets(
      'banner disappears after duration with no pending timers and no leftover OverlayEntry',
      (tester) async {
        var dismissed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showInfo(
                      context,
                      message: 'Auto dismiss message',
                      duration: const Duration(seconds: 2),
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
        expect(find.text('Auto dismiss message'), findsOneWidget);

        // Advance time past 2 seconds
        await tester.pump(const Duration(seconds: 2, milliseconds: 100));
        await tester.pumpAndSettle();

        expect(dismissed, isTrue);
        expect(find.text('Auto dismiss message'), findsNothing);
        expect(find.byKey(const Key('app_top_banner')), findsNothing);
      },
    );

    testWidgets('swipe up dismisses banner early and fires onDismissed', (
      tester,
    ) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showInfo(
                    context,
                    message: 'Swipe me up',
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

      expect(find.text('Swipe me up'), findsOneWidget);

      // Fling/drag upward on banner
      await tester.drag(find.text('Swipe me up'), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(find.byKey(const Key('app_top_banner')), findsNothing);
    });

    testWidgets(
      'touching banner pauses auto-dismiss timer and resumes on release',
      (tester) async {
        var dismissed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showInfo(
                      context,
                      message: 'Hold to pause',
                      duration: const Duration(seconds: 2),
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

        // Press and hold pointer on banner
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Hold to pause')),
        );
        await tester.pump();

        // Advance time 3 seconds while held (longer than the 2s duration)
        await tester.pump(const Duration(seconds: 3));
        expect(dismissed, isFalse);
        expect(find.text('Hold to pause'), findsOneWidget);

        // Release hold
        await gesture.up();
        await tester.pump();

        // Now let timer expire
        await tester.pump(const Duration(seconds: 2, milliseconds: 100));
        await tester.pumpAndSettle();

        expect(dismissed, isTrue);
        expect(find.byKey(const Key('app_top_banner')), findsNothing);
      },
    );

    testWidgets(
      'action button has >= 48dp tap target and dismisses banner on press',
      (tester) async {
        var actionTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showWithAction(
                      context,
                      message: 'Action target test',
                      actionLabel: 'Undo',
                      onAction: () => actionTapped = true,
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

        final actionFinder = find.byKey(const Key('top_banner_action_button'));
        final actionSize = tester.getSize(actionFinder);

        expect(actionSize.width, greaterThanOrEqualTo(48.0));
        expect(actionSize.height, greaterThanOrEqualTo(48.0));

        await tester.tap(actionFinder);
        await tester.pumpAndSettle();

        expect(actionTapped, isTrue);
        expect(find.byKey(const Key('app_top_banner')), findsNothing);
      },
    );

    testWidgets(
      'respects MediaQuery.disableAnimations by skipping slide animation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      AppSnackBar.showSuccess(
                        context,
                        message: 'Reduced motion message',
                      );
                    },
                    child: const Text('Show'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester
            .pump(); // No need for pumpAndSettle with animations disabled

        expect(find.text('Reduced motion message'), findsOneWidget);
        expect(find.byKey(const Key('app_top_banner')), findsOneWidget);
      },
    );

    testWidgets(
      'renders large text scale 2.0 without overflow or RenderFlex error',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
                size: Size(360, 640),
              ),
              child: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      AppSnackBar.showWithAction(
                        context,
                        message: 'This is a long notification message that tests large font wrapping behavior',
                        actionLabel: 'Undo',
                        onAction: () {},
                      );
                    },
                    child: const Text('Show'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        // Must be rendered cleanly with zero exceptions
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('app_top_banner')), findsOneWidget);
      },
    );

    testWidgets('accessibility: semantics liveRegion exists on top banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showInfo(context, message: 'Accessible message');
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
