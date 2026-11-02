import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_scheduler.dart';
import 'package:pantry_pal/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:pantry_pal/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:pantry_pal/features/onboarding/presentation/cubit/onboarding_state.dart';

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockNotificationScheduler extends Mock
    implements NotificationScheduler {}

void main() {
  late MockOnboardingRepository onboardingRepo;
  late MockNotificationScheduler scheduler;

  setUp(() {
    onboardingRepo = MockOnboardingRepository();
    scheduler = MockNotificationScheduler();
  });

  group('OnboardingCubit', () {
    test('initial state has pageIndex 0 and incomplete', () {
      final cubit = OnboardingCubit(
        onboardingRepository: onboardingRepo,
        notificationScheduler: scheduler,
      );
      expect(cubit.state, const OnboardingState(pageIndex: 0, isCompleted: false));
      cubit.close();
    });

    blocTest<OnboardingCubit, OnboardingState>(
      'pageChanged emits updated pageIndex',
      build: () => OnboardingCubit(
        onboardingRepository: onboardingRepo,
        notificationScheduler: scheduler,
      ),
      act: (cubit) => cubit.pageChanged(2),
      expect: () => [
        const OnboardingState(pageIndex: 2),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'requestNotificationPermission requests system permission and emits result',
      build: () {
        when(() => scheduler.requestPermission())
            .thenAnswer((_) async => true);
        return OnboardingCubit(
          onboardingRepository: onboardingRepo,
          notificationScheduler: scheduler,
        );
      },
      act: (cubit) => cubit.requestNotificationPermission(),
      expect: () => [
        const OnboardingState(permissionGranted: true),
      ],
      verify: (_) {
        verify(() => scheduler.requestPermission()).called(1);
      },
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'complete calls completeOnboarding and marks isCompleted true',
      build: () {
        when(() => onboardingRepo.completeOnboarding())
            .thenAnswer((_) async {});
        return OnboardingCubit(
          onboardingRepository: onboardingRepo,
          notificationScheduler: scheduler,
        );
      },
      act: (cubit) => cubit.complete(),
      expect: () => [
        const OnboardingState(isCompleted: true),
      ],
      verify: (_) {
        verify(() => onboardingRepo.completeOnboarding()).called(1);
      },
    );
  });
}

