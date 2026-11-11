// Solar-Grow - Pruebas de widget para programar tareas (sin HTTP real)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/config/theme.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/models/task_model.dart';
import 'package:solar_grow/providers/auth_provider.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/providers/task_provider.dart';
import 'package:solar_grow/screens/home/tasks_tab.dart';
import 'package:solar_grow/screens/plant/plant_detail_screen.dart';
import 'package:solar_grow/widgets/create_task_sheet.dart';
import 'package:solar_grow/widgets/task_card.dart';

const saveErrorMessage = 'No se pudo programar la tarea. Intenta de nuevo.';

class FakeTaskProvider extends TaskProvider {
  bool createResult = true;
  bool completeResult = true;
  bool loading = false;
  int createCalls = 0;
  int? receivedPlantId;
  String? receivedTaskType;
  DateTime? receivedDueDate;
  String? receivedDescription;
  List<TaskModel> today = [];

  @override
  bool get isLoading => loading;

  @override
  List<TaskModel> get todayTasks => today;

  @override
  Future<bool> createTask({
    required int plantId,
    required String taskType,
    required DateTime dueDate,
    String? description,
  }) async {
    createCalls++;
    receivedPlantId = plantId;
    receivedTaskType = taskType;
    receivedDueDate = dueDate;
    receivedDescription = description;
    return createResult;
  }

  @override
  Future<bool> completeTask(int taskId) async => completeResult;
}

class FakePlantProvider extends PlantProvider {
  @override
  PlantModel? get selectedPlant => PlantModel(id: 7, commonName: 'Echeveria');
}

/// Pantalla mínima con un botón que abre el formulario
Widget buildSheetHost(
  FakeTaskProvider provider, {
  void Function(String?)? onClosed,
}) {
  return ChangeNotifierProvider<TaskProvider>.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showCreateTaskSheet(context, plantId: 7);
              onClosed?.call(result);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> selectType(WidgetTester tester, String type) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type).last);
  await tester.pumpAndSettle();
}

Future<void> selectToday(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextFormField, 'Fecha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

Finder get descriptionField =>
    find.widgetWithText(TextFormField, 'Descripción (opcional)');

void main() {
  group('CreateTaskSheet', () {
    testWidgets('al guardar vacío valida los campos y no llama al provider', (
      tester,
    ) async {
      final provider = FakeTaskProvider();
      await tester.pumpWidget(buildSheetHost(provider));
      await openSheet(tester);

      await save(tester);

      expect(find.text('Selecciona un tipo de tarea'), findsOneWidget);
      expect(find.text('Selecciona una fecha'), findsOneWidget);
      expect(provider.createCalls, 0);
    });

    testWidgets('con datos completos llama al provider y cierra el sheet', (
      tester,
    ) async {
      final provider = FakeTaskProvider();
      String? closedWith;
      await tester.pumpWidget(
        buildSheetHost(provider, onClosed: (value) => closedWith = value),
      );
      await openSheet(tester);

      await selectType(tester, 'Podar');
      await selectToday(tester);
      await tester.enterText(descriptionField, 'Quitar hojas secas');
      await save(tester);

      expect(provider.createCalls, 1);
      expect(provider.receivedPlantId, 7);
      expect(provider.receivedTaskType, 'Podar');
      expect(provider.receivedDueDate, DateUtils.dateOnly(DateTime.now()));
      expect(provider.receivedDescription, 'Quitar hojas secas');
      expect(find.byType(CreateTaskSheet), findsNothing);
      expect(closedWith, 'Podar');
    });

    testWidgets('una descripción en blanco llega como null', (tester) async {
      final provider = FakeTaskProvider();
      await tester.pumpWidget(buildSheetHost(provider));
      await openSheet(tester);

      await selectType(tester, 'Regar');
      await selectToday(tester);
      await tester.enterText(descriptionField, '   ');
      await save(tester);

      expect(provider.createCalls, 1);
      expect(provider.receivedDescription, isNull);
    });

    testWidgets('ofrece exactamente los cinco tipos de tarea', (tester) async {
      await tester.pumpWidget(buildSheetHost(FakeTaskProvider()));
      await openSheet(tester);

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );

      expect(dropdown.items!.map((item) => item.value), [
        'Regar',
        'Fertilizar',
        'Trasplantar',
        'Podar',
        'Revisar',
      ]);
    });

    testWidgets('el selector de fecha no permite fechas pasadas', (
      tester,
    ) async {
      await tester.pumpWidget(buildSheetHost(FakeTaskProvider()));
      await openSheet(tester);

      await tester.tap(find.widgetWithText(TextFormField, 'Fecha'));
      await tester.pumpAndSettle();

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateUtils.dateOnly(DateTime.now()));
    });

    testWidgets(
      'si falla muestra el error sobre Guardar y conserva los datos',
      (tester) async {
        final provider = FakeTaskProvider()..createResult = false;
        await tester.pumpWidget(buildSheetHost(provider));
        await openSheet(tester);

        await selectType(tester, 'Podar');
        await selectToday(tester);
        await tester.enterText(descriptionField, 'Quitar hojas secas');
        await save(tester);

        expect(find.byType(CreateTaskSheet), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        final message = find.text(saveErrorMessage);
        expect(message, findsOneWidget);
        expect(tester.widget<Text>(message).style?.color, SolarColors.error);
        expect(
          tester.getBottomLeft(message).dy,
          lessThan(tester.getTopLeft(find.text('Guardar')).dy),
        );

        expect(find.text('Podar'), findsOneWidget);
        expect(find.text('Quitar hojas secas'), findsOneWidget);
        final dateField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Fecha'),
        );
        expect(dateField.controller!.text, isNotEmpty);
      },
    );

    testWidgets('al reintentar con éxito desaparece el error y se cierra', (
      tester,
    ) async {
      final provider = FakeTaskProvider()..createResult = false;
      await tester.pumpWidget(buildSheetHost(provider));
      await openSheet(tester);
      await selectType(tester, 'Regar');
      await selectToday(tester);
      await save(tester);
      expect(find.text(saveErrorMessage), findsOneWidget);

      provider.createResult = true;
      await save(tester);

      expect(provider.createCalls, 2);
      expect(find.byType(CreateTaskSheet), findsNothing);
    });

    testWidgets('Guardar queda deshabilitado mientras isLoading', (
      tester,
    ) async {
      final provider = FakeTaskProvider()..loading = true;
      await tester.pumpWidget(buildSheetHost(provider));
      await openSheet(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar'),
      );

      expect(button.onPressed, isNull);
    });
  });

  group('PlantDetailScreen', () {
    testWidgets(
      'Programar tarea abre el sheet y al guardar avisa con SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final tasks = FakeTaskProvider();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(
                create: (_) => AuthProvider(),
              ),
              ChangeNotifierProvider<PlantProvider>(
                create: (_) => FakePlantProvider(),
              ),
              ChangeNotifierProvider<TaskProvider>.value(value: tasks),
            ],
            child: const MaterialApp(home: PlantDetailScreen()),
          ),
        );

        // La planta animada se repite: pumpAndSettle no terminaría nunca
        Future<void> settle() async {
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        final button = find.widgetWithText(ElevatedButton, 'Programar tarea');
        await tester.ensureVisible(button);
        await settle();
        await tester.tap(button);
        await settle();
        expect(find.byType(CreateTaskSheet), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await settle();
        await tester.tap(find.text('Regar').last);
        await settle();
        await tester.tap(find.widgetWithText(TextFormField, 'Fecha'));
        await settle();
        await tester.tap(find.text('Aceptar'));
        await settle();
        await tester.tap(find.text('Guardar'));
        await settle();

        expect(tasks.receivedPlantId, 7);
        expect(find.byType(CreateTaskSheet), findsNothing);
        expect(find.text('Tarea programada: Regar'), findsOneWidget);

        // El parpadeo de la planta usa un Future.delayed de hasta 5,5 s que no
        // se cancela: se desmonta la pantalla y se deja vencer.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      },
    );
  });

  group('TasksTab', () {
    final pendingTask = TaskModel(
      id: 5,
      plantId: 7,
      plantName: 'Echeveria',
      taskType: 'Regar',
      status: 'Pendiente',
      dueDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );

    Future<void> tapCheckbox(
      WidgetTester tester,
      FakeTaskProvider provider,
    ) async {
      provider.today = [pendingTask];
      await tester.pumpWidget(
        ChangeNotifierProvider<TaskProvider>.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: TasksTab())),
        ),
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(TaskCard),
              matching: find.byType(GestureDetector),
            )
            .last,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('si no se puede completar la tarea muestra un SnackBar', (
      tester,
    ) async {
      await tapCheckbox(tester, FakeTaskProvider()..completeResult = false);

      expect(
        find.text('No se pudo completar la tarea. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('si se completa no muestra error', (tester) async {
      await tapCheckbox(tester, FakeTaskProvider());

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
