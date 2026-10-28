import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

void main() {
  late MockPantryRepository repository;

  final sampleItem = PantryItem(
    id: 1,
    name: 'Almond Milk',
    quantity: 2,
    category: 'Dairy',
    expiryDate: DateTime(2026, 6, 1),
    addedAt: DateTime(2026, 1, 1),
    notes: 'Unopened',
  );

  setUp(() {
    repository = MockPantryRepository();
    when(() => repository.countAll()).thenAnswer((_) async => 1);
    when(
      () => repository.search(
        query: any(named: 'query'),
        categories: any(named: 'categories'),
        expiringWithinDays: any(named: 'expiringWithinDays'),
      ),
    ).thenAnswer((_) async => [sampleItem]);
  });

  group('InventoryBloc', () {
    test('initial state has default InventoryState values', () {
      final bloc = InventoryBloc(repository);
      expect(bloc.state, const InventoryState());
      expect(bloc.state.searchQuery, '');
      expect(bloc.state.selectedCategories, isEmpty);
      expect(bloc.state.expiringSoonOnly, isFalse);
      expect(bloc.state.hasActiveFilters, isFalse);
    });

    group('InventoryStarted', () {
      blocTest<InventoryBloc, InventoryState>(
        'emits [loading, success] with items and count when repository succeeds',
        build: () => InventoryBloc(repository),
        act: (bloc) => bloc.add(const InventoryStarted()),
        expect: () => [
          const InventoryState(status: InventoryStatus.loading),
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
          ),
        ],
        verify: (_) {
          verify(() => repository.countAll()).called(1);
          verify(
            () => repository.search(
              query: null,
              categories: null,
              expiringWithinDays: null,
            ),
          ).called(1);
        },
      );

      blocTest<InventoryBloc, InventoryState>(
        'emits [loading, failure] when repository throws',
        build: () {
          when(() => repository.countAll())
              .thenThrow(Exception('DB read error'));
          return InventoryBloc(repository);
        },
        act: (bloc) => bloc.add(const InventoryStarted()),
        expect: () => [
          const InventoryState(status: InventoryStatus.loading),
          const InventoryState(
            status: InventoryStatus.failure,
            errorMessage: 'Exception: DB read error',
          ),
        ],
      );
    });

    group('InventorySearchChanged', () {
      blocTest<InventoryBloc, InventoryState>(
        'debounces search input by ~300ms and updates state with query results',
        build: () {
          when(
            () => repository.search(
              query: 'almond',
              categories: any(named: 'categories'),
              expiringWithinDays: any(named: 'expiringWithinDays'),
            ),
          ).thenAnswer((_) async => [sampleItem]);
          return InventoryBloc(repository);
        },
        seed: () => InventoryState(
          status: InventoryStatus.success,
          items: [sampleItem],
          totalItemCount: 1,
        ),
        act: (bloc) {
          // Rapid typing: only the last query should trigger search
          bloc.add(const InventorySearchChanged('a'));
          bloc.add(const InventorySearchChanged('al'));
          bloc.add(const InventorySearchChanged('almond'));
        },
        wait: const Duration(milliseconds: 350),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
            searchQuery: 'almond',
          ),
        ],
        verify: (_) {
          verify(
            () => repository.search(
              query: 'almond',
              categories: any(named: 'categories'),
              expiringWithinDays: any(named: 'expiringWithinDays'),
            ),
          ).called(1);
        },
      );
    });

    group('InventoryCategoryToggled', () {
      blocTest<InventoryBloc, InventoryState>(
        'adds category to filter and searches with active category',
        build: () {
          when(
            () => repository.search(
              query: any(named: 'query'),
              categories: {'Dairy'},
              expiringWithinDays: any(named: 'expiringWithinDays'),
            ),
          ).thenAnswer((_) async => [sampleItem]);
          return InventoryBloc(repository);
        },
        seed: () => const InventoryState(
          status: InventoryStatus.success,
          items: [],
          totalItemCount: 1,
        ),
        act: (bloc) => bloc.add(const InventoryCategoryToggled('Dairy')),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
            selectedCategories: const {'Dairy'},
          ),
        ],
      );

      blocTest<InventoryBloc, InventoryState>(
        'removes category when toggled again',
        build: () => InventoryBloc(repository),
        seed: () => InventoryState(
          status: InventoryStatus.success,
          items: [sampleItem],
          totalItemCount: 1,
          selectedCategories: const {'Dairy'},
        ),
        act: (bloc) => bloc.add(const InventoryCategoryToggled('Dairy')),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
            selectedCategories: const {},
          ),
        ],
      );
    });

    group('InventoryExpiringFilterToggled', () {
      blocTest<InventoryBloc, InventoryState>(
        'toggles expiring soon filter and queries within 3 days',
        build: () {
          when(
            () => repository.search(
              query: any(named: 'query'),
              categories: any(named: 'categories'),
              expiringWithinDays: 3,
            ),
          ).thenAnswer((_) async => [sampleItem]);
          return InventoryBloc(repository);
        },
        seed: () => const InventoryState(
          status: InventoryStatus.success,
          items: [],
          totalItemCount: 1,
        ),
        act: (bloc) => bloc.add(const InventoryExpiringFilterToggled()),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
            expiringSoonOnly: true,
          ),
        ],
      );
    });

    group('InventoryFiltersCleared', () {
      blocTest<InventoryBloc, InventoryState>(
        'resets all search and filter parameters back to defaults',
        build: () => InventoryBloc(repository),
        seed: () => InventoryState(
          status: InventoryStatus.success,
          items: [sampleItem],
          totalItemCount: 1,
          searchQuery: 'milk',
          selectedCategories: const {'Dairy'},
          expiringSoonOnly: true,
        ),
        act: (bloc) => bloc.add(const InventoryFiltersCleared()),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
            searchQuery: '',
            selectedCategories: const {},
            expiringSoonOnly: false,
          ),
        ],
      );
    });

    group('InventoryItemAdded', () {
      blocTest<InventoryBloc, InventoryState>(
        'adds item and refreshes items list successfully',
        build: () {
          when(() => repository.add(sampleItem)).thenAnswer((_) async => 1);
          return InventoryBloc(repository);
        },
        seed: () => const InventoryState(
          status: InventoryStatus.success,
          items: [],
          totalItemCount: 0,
        ),
        act: (bloc) => bloc.add(InventoryItemAdded(sampleItem)),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
          ),
        ],
        verify: (_) {
          verify(() => repository.add(sampleItem)).called(1);
        },
      );
    });

    group('InventoryItemUpdated', () {
      final updatedItem = sampleItem.copyWith(quantity: 5);

      blocTest<InventoryBloc, InventoryState>(
        'updates item and refreshes items list',
        build: () {
          when(() => repository.update(updatedItem)).thenAnswer((_) async {});
          when(
            () => repository.search(
              query: any(named: 'query'),
              categories: any(named: 'categories'),
              expiringWithinDays: any(named: 'expiringWithinDays'),
            ),
          ).thenAnswer((_) async => [updatedItem]);
          return InventoryBloc(repository);
        },
        seed: () => InventoryState(
          status: InventoryStatus.success,
          items: [sampleItem],
          totalItemCount: 1,
        ),
        act: (bloc) => bloc.add(InventoryItemUpdated(updatedItem)),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [updatedItem],
            totalItemCount: 1,
          ),
        ],
        verify: (_) {
          verify(() => repository.update(updatedItem)).called(1);
        },
      );
    });

    group('InventoryItemDeleted and active filters reload', () {
      blocTest<InventoryBloc, InventoryState>(
        'deletes item and reloads preserving active category filter',
        build: () {
          when(() => repository.delete(1)).thenAnswer((_) async {});
          when(() => repository.countAll()).thenAnswer((_) async => 0);
          when(
            () => repository.search(
              query: any(named: 'query'),
              categories: {'Dairy'},
              expiringWithinDays: any(named: 'expiringWithinDays'),
            ),
          ).thenAnswer((_) async => []);
          return InventoryBloc(repository);
        },
        seed: () => InventoryState(
          status: InventoryStatus.success,
          items: [sampleItem],
          totalItemCount: 1,
          selectedCategories: const {'Dairy'},
        ),
        act: (bloc) => bloc.add(const InventoryItemDeleted(1)),
        expect: () => [
          const InventoryState(
            status: InventoryStatus.success,
            items: [],
            totalItemCount: 0,
            selectedCategories: {'Dairy'},
          ),
        ],
        verify: (_) {
          verify(() => repository.delete(1)).called(1);
          verify(
            () => repository.search(
              query: null,
              categories: {'Dairy'},
              expiringWithinDays: null,
            ),
          ).called(1);
        },
      );
    });

    group('Undo delete flow', () {
      blocTest<InventoryBloc, InventoryState>(
        're-inserts deleted item when undo action is triggered',
        build: () {
          when(() => repository.add(sampleItem)).thenAnswer((_) async => 1);
          return InventoryBloc(repository);
        },
        seed: () => const InventoryState(
          status: InventoryStatus.success,
          items: [],
          totalItemCount: 0,
        ),
        act: (bloc) => bloc.add(InventoryItemAdded(sampleItem)),
        expect: () => [
          InventoryState(
            status: InventoryStatus.success,
            items: [sampleItem],
            totalItemCount: 1,
          ),
        ],
        verify: (_) {
          verify(() => repository.add(sampleItem)).called(1);
        },
      );
    });
  });
}
