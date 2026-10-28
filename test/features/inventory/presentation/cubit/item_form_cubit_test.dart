import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_category.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/inventory/presentation/cubit/item_form_cubit.dart';
import 'package:pantry_pal/features/inventory/presentation/cubit/item_form_state.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class FakePantryItem extends Fake implements PantryItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePantryItem());
  });

  late MockPantryRepository repository;

  setUp(() {
    repository = MockPantryRepository();
  });

  final testExpiry = DateTime(2026, 12, 31);
  final existingItem = PantryItem(
    id: 42,
    name: 'Greek Yogurt',
    quantity: 2,
    category: 'Dairy',
    expiryDate: testExpiry,
    barcode: '1234567890',
    notes: 'Low fat',
    addedAt: DateTime(2026, 1, 1),
  );

  group('ItemFormCubit', () {
    test('initial state for new item sets defaults and isEditing false', () {
      final cubit = ItemFormCubit(repository: repository);
      expect(cubit.state.isEditing, isFalse);
      expect(cubit.state.name, '');
      expect(cubit.state.quantity, 1);
      expect(cubit.state.category, PantryCategory.other);
      expect(cubit.state.status, ItemFormStatus.initial);
      expect(cubit.state.nameError, isNull);
    });

    test('initial state for existing item pre-populates fields and isEditing true', () {
      final cubit = ItemFormCubit(
        repository: repository,
        initialItem: existingItem,
      );
      expect(cubit.state.isEditing, isTrue);
      expect(cubit.state.name, 'Greek Yogurt');
      expect(cubit.state.quantity, 2);
      expect(cubit.state.category, PantryCategory.dairy);
      expect(cubit.state.barcode, '1234567890');
      expect(cubit.state.notes, 'Low fat');
      expect(cubit.state.expiryDate, testExpiry);
    });

    blocTest<ItemFormCubit, ItemFormState>(
      'nameChanged updates name and clears nameError if non-empty',
      build: () => ItemFormCubit(repository: repository),
      seed: () => ItemFormCubit(repository: repository)
          .state
          .copyWith(nameError: () => 'Item name is required'),
      act: (cubit) => cubit.nameChanged('Sourdough Bread'),
      expect: () => [
        isA<ItemFormState>()
            .having((s) => s.name, 'name', 'Sourdough Bread')
            .having((s) => s.nameError, 'nameError', isNull),
      ],
    );

    blocTest<ItemFormCubit, ItemFormState>(
      'quantityIncremented and quantityDecremented manage quantity safely',
      build: () => ItemFormCubit(repository: repository),
      act: (cubit) {
        cubit.quantityIncremented();
        cubit.quantityIncremented();
        cubit.quantityDecremented();
        cubit.quantityDecremented();
        cubit.quantityDecremented(); // should not drop below 1
      },
      expect: () => [
        isA<ItemFormState>().having((s) => s.quantity, 'quantity', 2),
        isA<ItemFormState>().having((s) => s.quantity, 'quantity', 3),
        isA<ItemFormState>().having((s) => s.quantity, 'quantity', 2),
        isA<ItemFormState>().having((s) => s.quantity, 'quantity', 1),
      ],
    );

    blocTest<ItemFormCubit, ItemFormState>(
      'categoryChanged and expiryDateChanged update their respective state fields',
      build: () => ItemFormCubit(repository: repository),
      act: (cubit) {
        cubit.categoryChanged(PantryCategory.fruits);
        cubit.expiryDateChanged(testExpiry);
      },
      expect: () => [
        isA<ItemFormState>()
            .having((s) => s.category, 'category', PantryCategory.fruits),
        isA<ItemFormState>()
            .having((s) => s.expiryDate, 'expiryDate', testExpiry),
      ],
    );

    group('submit validation', () {
      blocTest<ItemFormCubit, ItemFormState>(
        'fails validation when name is empty and does not call repository',
        build: () => ItemFormCubit(repository: repository),
        act: (cubit) => cubit.submit(),
        expect: () => [
          isA<ItemFormState>()
              .having((s) => s.nameError, 'nameError', 'Item name is required')
              .having((s) => s.status, 'status', ItemFormStatus.initial),
        ],
        verify: (_) {
          verifyNever(() => repository.add(any()));
          verifyNever(() => repository.update(any()));
        },
      );
    });

    group('submit execution', () {
      blocTest<ItemFormCubit, ItemFormState>(
        'submits new item to repository and emits [submitting, success]',
        build: () {
          when(() => repository.add(any())).thenAnswer((_) async => 1);
          return ItemFormCubit(repository: repository);
        },
        seed: () => ItemFormCubit(repository: repository)
            .state
            .copyWith(name: 'Fresh Spinach', quantity: 2),
        act: (cubit) => cubit.submit(),
        expect: () => [
          isA<ItemFormState>()
              .having((s) => s.status, 'status', ItemFormStatus.submitting),
          isA<ItemFormState>()
              .having((s) => s.status, 'status', ItemFormStatus.success),
        ],
        verify: (_) {
          verify(
            () => repository.add(
              any(
                that: isA<PantryItem>()
                    .having((i) => i.name, 'name', 'Fresh Spinach')
                    .having((i) => i.quantity, 'quantity', 2),
              ),
            ),
          ).called(1);
        },
      );

      blocTest<ItemFormCubit, ItemFormState>(
        'submits updated existing item and emits [submitting, success]',
        build: () {
          when(() => repository.update(any())).thenAnswer((_) async {});
          return ItemFormCubit(
            repository: repository,
            initialItem: existingItem,
          );
        },
        seed: () => ItemFormCubit(
          repository: repository,
          initialItem: existingItem,
        ).state.copyWith(quantity: 5),
        act: (cubit) => cubit.submit(),
        expect: () => [
          isA<ItemFormState>()
              .having((s) => s.status, 'status', ItemFormStatus.submitting),
          isA<ItemFormState>()
              .having((s) => s.status, 'status', ItemFormStatus.success),
        ],
        verify: (_) {
          verify(
            () => repository.update(
              any(
                that: isA<PantryItem>()
                    .having((i) => i.id, 'id', 42)
                    .having((i) => i.quantity, 'quantity', 5),
              ),
            ),
          ).called(1);
        },
      );

      blocTest<ItemFormCubit, ItemFormState>(
        'emits [submitting, failure] when repository throws',
        build: () {
          when(() => repository.add(any()))
              .thenThrow(Exception('Database disk full'));
          return ItemFormCubit(repository: repository);
        },
        seed: () => ItemFormCubit(repository: repository)
            .state
            .copyWith(name: 'Apples'),
        act: (cubit) => cubit.submit(),
        expect: () => [
          isA<ItemFormState>()
              .having((s) => s.status, 'status', ItemFormStatus.submitting),
          isA<ItemFormState>()
              .having((s) => s.status, 'status', ItemFormStatus.failure)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                'Exception: Database disk full',
              ),
        ],
      );
    });
  });
}

