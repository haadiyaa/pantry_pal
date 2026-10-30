import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/shopping/domain/models/grouped_shopping_list.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_item.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_source_type.dart';
import 'package:pantry_pal/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:pantry_pal/features/shopping/presentation/bloc/shopping_list_bloc.dart';
import 'package:pantry_pal/features/shopping/presentation/bloc/shopping_list_event.dart';
import 'package:pantry_pal/features/shopping/presentation/bloc/shopping_list_state.dart';

class MockShoppingRepository extends Mock implements ShoppingRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

void main() {
  late MockShoppingRepository shoppingRepo;
  late MockPantryRepository pantryRepo;
  late StreamController<List<ShoppingItem>> streamController;

  final fixedDate = DateTime(2026, 6, 1, 10, 0);

  final sampleItem = ShoppingItem(
    id: 1,
    name: 'Oat Milk',
    normalizedName: 'oat milk',
    quantity: 2,
    category: 'Dairy',
    isBought: false,
    sourceType: ShoppingSourceType.manual,
    sourceLabel: 'Manual',
    addedAt: fixedDate,
  );

  final sampleBoughtItem = ShoppingItem(
    id: 2,
    name: 'Apples',
    normalizedName: 'apples',
    quantity: 4,
    category: 'Produce',
    isBought: true,
    sourceType: ShoppingSourceType.recipe,
    sourceLabel: 'Apple Pie',
    addedAt: fixedDate,
    boughtAt: fixedDate,
  );

  setUpAll(() {
    registerFallbackValue(sampleItem);
  });

  setUp(() {
    shoppingRepo = MockShoppingRepository();
    pantryRepo = MockPantryRepository();
    streamController = StreamController<List<ShoppingItem>>.broadcast();

    when(() => shoppingRepo.watchAll()).thenAnswer((_) => streamController.stream);
    when(() => shoppingRepo.getAll()).thenAnswer((_) async => []);
    when(() => pantryRepo.getAll()).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await streamController.close();
  });

  group('ShoppingListBloc', () {
    test('initial state has default values', () {
      final bloc = ShoppingListBloc(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        nowProvider: () => fixedDate,
      );
      expect(bloc.state.status, equals(ShoppingListStatus.initial));
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.groupedList, equals(const GroupedShoppingList.empty()));
      expect(bloc.state.pantryWarningItem, isNull);
    });

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListStarted emits success when stream yields items',
      build: () => ShoppingListBloc(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        nowProvider: () => fixedDate,
      ),
      act: (bloc) async {
        bloc.add(const ShoppingListStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        streamController.add([sampleItem, sampleBoughtItem]);
      },
      expect: () => [
        const ShoppingListState(status: ShoppingListStatus.loading),
        isA<ShoppingListState>()
            .having((s) => s.status, 'status', ShoppingListStatus.success)
            .having((s) => s.items.length, 'items count', 2)
            .having((s) => s.groupedList.uncheckedCount, 'unchecked count', 1)
            .having((s) => s.groupedList.boughtCount, 'bought count', 1),
      ],
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'Manual item added with no pantry duplicate adds item to repository',
      build: () {
        when(() => shoppingRepo.add(any())).thenAnswer((_) async => 1);
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(
        const ShoppingListManualItemAdded(
          name: 'Oat Milk',
          category: 'Dairy',
          quantity: 2,
        ),
      ),
      verify: (_) {
        verify(
          () => shoppingRepo.add(
            any(
              that: isA<ShoppingItem>()
                  .having((i) => i.name, 'name', 'Oat Milk')
                  .having((i) => i.quantity, 'quantity', 2)
                  .having((i) => i.category, 'category', 'Dairy'),
            ),
          ),
        ).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'Manual item added matching active pantry item emits pantryWarningItem',
      build: () {
        when(() => pantryRepo.getAll()).thenAnswer(
          (_) async => [
            PantryItem(
              id: 10,
              name: 'Oat Milk',
              quantity: 1,
              category: 'Dairy',
              expiryDate: fixedDate.add(const Duration(days: 5)),
              addedAt: fixedDate,
            ),
          ],
        );
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(
        const ShoppingListManualItemAdded(
          name: 'Oat Milk',
          category: 'Dairy',
          quantity: 2,
          forceAdd: false,
        ),
      ),
      expect: () => [
        isA<ShoppingListState>().having(
          (s) => s.pantryWarningItem?.name,
          'warning item name',
          'Oat Milk',
        ),
      ],
      verify: (_) {
        verifyNever(() => shoppingRepo.add(any()));
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'Manual item with forceAdd: true ignores pantry duplicate and adds item',
      build: () {
        when(() => shoppingRepo.add(any())).thenAnswer((_) async => 1);
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(
        const ShoppingListManualItemAdded(
          name: 'Oat Milk',
          category: 'Dairy',
          quantity: 2,
          forceAdd: true,
        ),
      ),
      verify: (_) {
        verify(() => shoppingRepo.add(any())).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListItemEdited calls shoppingRepository.update',
      build: () {
        when(() => shoppingRepo.update(any())).thenAnswer((_) async => 1);
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(ShoppingListItemEdited(sampleItem)),
      verify: (_) {
        verify(() => shoppingRepo.update(sampleItem)).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListItemDeleted deletes item and emits lastDeletedItem for undo',
      build: () {
        when(() => shoppingRepo.getById(1)).thenAnswer((_) async => sampleItem);
        when(() => shoppingRepo.delete(1)).thenAnswer((_) async => 1);
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(const ShoppingListItemDeleted(1)),
      expect: () => [
        isA<ShoppingListState>().having(
          (s) => s.lastDeletedItem,
          'lastDeletedItem',
          sampleItem,
        ),
      ],
      verify: (_) {
        verify(() => shoppingRepo.delete(1)).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListUndoDelete restores deleted item to repository',
      build: () {
        when(() => shoppingRepo.restore(sampleItem)).thenAnswer((_) async => 1);
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(ShoppingListUndoDelete(sampleItem)),
      expect: () => [
        isA<ShoppingListState>().having(
          (s) => s.lastDeletedItem,
          'lastDeletedItem',
          isNull,
        ),
      ],
      verify: (_) {
        verify(() => shoppingRepo.restore(sampleItem)).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListItemBoughtToggled calls repository setBought',
      build: () {
        when(
          () => shoppingRepo.setBought(
            1,
            true,
            boughtAt: any(named: 'boughtAt'),
          ),
        ).thenAnswer((_) async => 1);
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(
        const ShoppingListItemBoughtToggled(id: 1, isBought: true),
      ),
      verify: (_) {
        verify(
          () => shoppingRepo.setBought(1, true, boughtAt: fixedDate),
        ).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListClearBought clears bought items and emits lastClearedBought',
      build: () {
        when(() => shoppingRepo.clearBought()).thenAnswer(
          (_) async => [sampleBoughtItem],
        );
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(const ShoppingListClearBought()),
      expect: () => [
        isA<ShoppingListState>().having(
          (s) => s.lastClearedBought?.length,
          'lastClearedBought length',
          1,
        ),
      ],
      verify: (_) {
        verify(() => shoppingRepo.clearBought()).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListUndoClearBought restores all cleared bought items',
      build: () {
        when(() => shoppingRepo.restore(sampleBoughtItem)).thenAnswer(
          (_) async => 1,
        );
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(
        ShoppingListUndoClearBought([sampleBoughtItem]),
      ),
      expect: () => [
        isA<ShoppingListState>().having(
          (s) => s.lastClearedBought,
          'lastClearedBought',
          isNull,
        ),
      ],
      verify: (_) {
        verify(() => shoppingRepo.restore(sampleBoughtItem)).called(1);
      },
    );

    blocTest<ShoppingListBloc, ShoppingListState>(
      'ShoppingListAddedFromRecipe calls shoppingRepository.addAll',
      build: () {
        when(() => shoppingRepo.addAll(any())).thenAnswer((_) async => [1]);
        return ShoppingListBloc(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          nowProvider: () => fixedDate,
        );
      },
      act: (bloc) => bloc.add(
        ShoppingListAddedFromRecipe([sampleItem]),
      ),
      verify: (_) {
        verify(() => shoppingRepo.addAll([sampleItem])).called(1);
      },
    );
  });
}
