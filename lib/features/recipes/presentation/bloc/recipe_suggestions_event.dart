import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_item.dart';

abstract class RecipeSuggestionsEvent extends Equatable {
  const RecipeSuggestionsEvent();

  @override
  List<Object?> get props => [];
}

class RecipeSuggestionsStarted extends RecipeSuggestionsEvent {
  const RecipeSuggestionsStarted();
}

class RecipeSuggestionsRefreshed extends RecipeSuggestionsEvent {
  const RecipeSuggestionsRefreshed();
}

class RecipeSuggestionsVegetarianToggled extends RecipeSuggestionsEvent {
  const RecipeSuggestionsVegetarianToggled();
}

class RecipeSuggestionsExpiringOnlyToggled extends RecipeSuggestionsEvent {
  const RecipeSuggestionsExpiringOnlyToggled();
}

class RecipeSuggestionsMinMatchChanged extends RecipeSuggestionsEvent {
  const RecipeSuggestionsMinMatchChanged(this.minMatchPercentage);

  final double minMatchPercentage;

  @override
  List<Object?> get props => [minMatchPercentage];
}

class RecipeSuggestionsRetried extends RecipeSuggestionsEvent {
  const RecipeSuggestionsRetried();
}

class RecipeSuggestionsInventoryChanged extends RecipeSuggestionsEvent {
  const RecipeSuggestionsInventoryChanged(this.items);

  final List<PantryItem> items;

  @override
  List<Object?> get props => [items];
}

