import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/shopping_repository.dart';

/// Lightweight Cubit that streams only the count of unchecked shopping items.
/// Used by app bar badges so they rebuild without fetching the entire item list.
class ShoppingBadgeCubit extends Cubit<int> {
  ShoppingBadgeCubit(this._repository) : super(0) {
    _subscription = _repository.watchAll().listen((items) {
      final unchecked = items.where((i) => !i.isBought).length;
      if (!isClosed) {
        emit(unchecked);
      }
    });
  }

  final ShoppingRepository _repository;
  StreamSubscription? _subscription;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

