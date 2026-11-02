import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.isExporting = false,
    this.isClearing = false,
    this.clearSuccess = false,
    this.errorMessage,
  });

  final bool isExporting;
  final bool isClearing;
  final bool clearSuccess;
  final String? errorMessage;

  SettingsState copyWith({
    bool? isExporting,
    bool? isClearing,
    bool? clearSuccess,
    String? Function()? errorMessage,
  }) {
    return SettingsState(
      isExporting: isExporting ?? this.isExporting,
      isClearing: isClearing ?? this.isClearing,
      clearSuccess: clearSuccess ?? this.clearSuccess,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [isExporting, isClearing, clearSuccess, errorMessage];
}

