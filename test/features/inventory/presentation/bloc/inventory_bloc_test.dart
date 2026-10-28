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
  );

  setUp(() {
    repository = MockPantryRepository();
  });

  group('InventoryBloc', () {
    test('initial state has default InventoryState values', () {
      final bloc = InventoryBloc(repository);
      expect(bloc.state, const InventoryState());
    });

    group('InventoryStarted', () {
      blocTest<InventoryBloc, InventoryState>(
        'emits [loading, success] with items when repository succeeds',
        build: () {
          when(() => repository.getAll()).thenAnswer((_) async => [sampleItem]);
          return InventoryBloc(repository);
        },
        act: (bloc) => bloc.add(const InventoryStarted()),
        expect: () => [
          const InventoryState(status: InventoryStatus.loading),
          InventoryState(status: InventoryStatus.success, items: [sampleItem]),
        ],
        verify: (_) {
          verify(() => repository.getAll()).called(1);
        },
      );

      blocTest<InventoryBloc, InventoryState>(
        'emits [loading, failure] when repository throws',
        build: () {
          when(() => repository.getAll()).thenThrow(Exception('DB read error'));
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

    group('InventoryItemAdded', () {
      blocTest<InventoryBloc, InventoryState>(
        'adds item and refreshes items list successfully',
        build: () {
          when(() => repository.add(sampleItem)).thenAnswer((_) async => 1);
          when(() => repository.getAll()).thenAnswer((_) async => [sampleItem]);
          return InventoryBloc(repository);
        },
        seed: () => const InventoryState(
          status: InventoryStatus.success,
          items: [],
        ),
        act: (bloc) => bloc.add(InventoryItemAdded(sampleItem)),
        expect: () => [
          InventoryState(status: InventoryStatus.success, items: [sampleItem]),
        ],
        verify: (_) {
          verify(() => repository.add(sampleItem)).called(1);
          verify(() => repository.getAll()).called(1);
        },
      );

      blocTest<InventoryBloc, InventoryState>(
        'emits failure when repository.add throws',
        build: () {
          when(() => repository.add(sampleItem))
              .thenThrow(Exception('Insert failed'));
          return InventoryBloc(repository);
        },
        act: (bloc) => bloc.add(InventoryItemAdded(sampleItem)),
        expect: () => [
          const InventoryState(
            status: InventoryStatus.failure,
            errorMessage: 'Exception: Insert failed',
          ),
        ],
      );
    });

    group('InventoryItemUpdated', () {
      final updatedItem = sampleItem.copyWith(quantity: 5);

      blocTest<InventoryBloc, InventoryState>(
        'updates item and refreshes items list',
        build: () {
          when(() => repository.update(updatedItem)).thenAnswer((_) async {});
          when(() => repository.getAll())
              .thenAnswer((_) async => [updatedItem]);
          return InventoryBloc(repository);
        },
        seed: () => InventoryState(
          status: InventoryStatus.success,
          items: [sampleItem],
        ),
        act: (bloc) => bloc.add(InventoryItemUpdated(updatedItem)),
        expect: () => [
          InventoryState(status: InventoryStatus.success, items: [updatedItem]),
        ],
        verify: (_) {
          verify(() => repository.update(updatedItem)).called(1);
          verify(() => repository.getAll()).called(1);
        },
      );

      blocTest<InventoryBloc, InventoryState>(
        'emits failure when repository.update throws',
        build: () {
          when(() => repository.update(updatedItem))
              .thenThrow(Exception('Update failed'));
          return InventoryBloc(repository);
        },
        act: (bloc) => bloc.add(InventoryItemUpdated(updatedItem)),
        expect: () => [
          const InventoryState(
            status: InventoryStatus.failure,
            errorMessage: 'Exception: Update failed',
          ),
        ],
      );
    });

    group('InventoryItemDeleted', () {
      blocTest<InventoryBloc, InventoryState>(
        'deletes item and refreshes items list',
        build: () {
          when(() => repository.delete(1)).thenAnswer((_) async {});
          when(() => repository.getAll()).thenAnswer((_) async => []);
          return InventoryBloc(repository);
        },
        seed: () => InventoryState(
          status: InventoryStatus.success,
          items: [sampleItem],
        ),
        act: (bloc) => bloc.add(const InventoryItemDeleted(1)),
        expect: () => [
          const InventoryState(status: InventoryStatus.success, items: []),
        ],
        verify: (_) {
          verify(() => repository.delete(1)).called(1);
          verify(() => repository.getAll()).called(1);
        },
      );

      blocTest<InventoryBloc, InventoryState>(
        'emits failure when repository.delete throws',
        build: () {
          when(() => repository.delete(1)).thenThrow(Exception('Delete failed'));
          return InventoryBloc(repository);
        },
        act: (bloc) => bloc.add(const InventoryItemDeleted(1)),
        expect: () => [
          const InventoryState(
            status: InventoryStatus.failure,
            errorMessage: 'Exception: Delete failed',
          ),
        ],
      );
    });
  });
}
