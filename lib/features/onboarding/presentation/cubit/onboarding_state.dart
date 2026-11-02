import 'package:equatable/equatable.dart';

class OnboardingState extends Equatable {
  const OnboardingState({
    this.pageIndex = 0,
    this.isCompleted = false,
    this.permissionGranted = false,
  });

  final int pageIndex;
  final bool isCompleted;
  final bool permissionGranted;

  OnboardingState copyWith({
    int? pageIndex,
    bool? isCompleted,
    bool? permissionGranted,
  }) {
    return OnboardingState(
      pageIndex: pageIndex ?? this.pageIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }

  @override
  List<Object?> get props => [pageIndex, isCompleted, permissionGranted];
}

