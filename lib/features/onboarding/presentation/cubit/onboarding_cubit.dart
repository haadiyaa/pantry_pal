import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../notifications/domain/services/notification_scheduler.dart';
import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required this.onboardingRepository,
    required this.notificationScheduler,
  }) : super(const OnboardingState());

  final OnboardingRepository onboardingRepository;
  final NotificationScheduler notificationScheduler;

  static const totalPages = 4;

  void pageChanged(int index) {
    emit(state.copyWith(pageIndex: index));
  }

  Future<void> requestNotificationPermission() async {
    final granted = await notificationScheduler.requestPermission();
    emit(state.copyWith(permissionGranted: granted));
  }

  Future<void> complete() async {
    await onboardingRepository.completeOnboarding();
    emit(state.copyWith(isCompleted: true));
  }
}

