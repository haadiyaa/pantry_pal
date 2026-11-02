import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_scheduler.dart';
import 'package:pantry_pal/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:pantry_pal/features/onboarding/presentation/pages/onboarding_page.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockNotificationScheduler extends Mock
    implements NotificationScheduler {}

void main() {
  late MockOnboardingRepository onboardingRepo;
  late MockNotificationScheduler scheduler;

  setUp(() {
    onboardingRepo = MockOnboardingRepository();
    scheduler = MockNotificationScheduler();

    when(() => onboardingRepo.completeOnboarding()).thenAnswer((_) async {});
    when(() => scheduler.requestPermission()).thenAnswer((_) async => true);
  });

  Widget createSubject() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<OnboardingRepository>.value(value: onboardingRepo),
        RepositoryProvider<NotificationScheduler>.value(value: scheduler),
      ],
      child: const MaterialApp(
        home: OnboardingPage(),
      ),
    );
  }

  testWidgets('OnboardingPage renders first slide and navigation controls', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Smart Pantry Tracking'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_next_button')), findsOneWidget);
  });

  testWidgets('OnboardingPage tapping skip marks complete', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_skip_button')));
    await tester.pumpAndSettle();

    verify(() => onboardingRepo.completeOnboarding()).called(1);
  });

  testWidgets('OnboardingPage tapping next navigates through slides', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Slide 1 -> Slide 2
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Barcode & Receipt OCR'), findsOneWidget);

    // Slide 2 -> Slide 3
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Zero-Waste Recipes'), findsOneWidget);

    // Slide 3 -> Slide 4
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Timely Expiry Alerts'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // On slide 4, tap Enable Expiry Reminders
    final enableBtn = find.byKey(const Key('enable_notifications_button'));
    expect(enableBtn, findsOneWidget);
    await tester.tap(enableBtn);
    await tester.pumpAndSettle();
    verify(() => scheduler.requestPermission()).called(1);
    expect(find.text('Notifications Enabled'), findsOneWidget);

    // Tap Get Started
    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    verify(() => onboardingRepo.completeOnboarding()).called(1);
  });
}

