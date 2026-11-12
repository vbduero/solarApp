// Solar-Grow - Pruebas de Inicio con el aviso de modo demo
// Spec 005 · CA-1 a CA-5, CA-7 a CA-9, CA-15, CA-19 y CA-20 (D1, D2, D4, D7 a D9).
//
// Sin red ni esperas reales: los providers son falsos y EXTIENDEN a los reales.
// Los fakes NO sobreescriben `showingDemoPlants` ni `showingDemoTasks`: la
// pantalla usa el getter real sobre la lista falsa, así que si alguien lo
// cambia para mirar otra cosa estas pruebas fallan.
//
// Montaje: HomeScreen no arranca temporizadores ni animaciones propias (solo
// el TabController), así que se monta entero en un MaterialApp plano. Se
// cierra con pumpWidget(SizedBox()) y un pump largo; nunca pumpAndSettle,
// porque el indicador de carga gira sin parar.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/models/task_model.dart';
import 'package:solar_grow/providers/auth_provider.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/providers/task_provider.dart';
import 'package:solar_grow/screens/home/home_screen.dart';

// Textos literales (no las constantes), para que fallen si alguien los cambia.
const _avisoHome =
    'Modo demo: no se pudo conectar con el servidor. Las plantas y tareas que ves son de ejemplo.';
const _noDisponible = 'No disponible en modo demo.';
const _deleteFailed = 'No se pudo eliminar la planta. Intenta de nuevo.';

const _claveAviso = ValueKey('aviso-modo-demo');

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider(this.log);

  final List<String> log;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> logout() async {
    log.add('auth.logout');
  }
}

class FakePlantProvider extends PlantProvider {
  FakePlantProvider(this.log, this.fakePlants);

  final List<String> log;
  List<PlantModel> fakePlants;
  bool fakeLoading = false;

  /// Listas que van devolviendo las próximas llamadas a `loadPlants`.
  /// Si está vacía, `loadPlants` deja la lista como está (el servidor sigue caído).
  final List<List<PlantModel>> scripted = [];

  /// Si no es null, `loadPlants` espera a que la prueba lo complete.
  Completer<void>? gate;

  int loadCalls = 0;
  final List<int> deleteCalls = [];
  bool deleteResult = true;

  @override
  List<PlantModel> get plants => fakePlants;

  @override
  bool get isLoading => fakeLoading;

  @override
  Future<void> loadPlants() async {
    loadCalls++;
    fakeLoading = true;
    notifyListeners();
    final pending = gate;
    if (pending != null) await pending.future;
    if (scripted.isNotEmpty) fakePlants = scripted.removeAt(0);
    fakeLoading = false;
    notifyListeners();
  }

  /// Imita al real: pone `isLoading` mientras borra (la pestaña cambia la
  /// lista por el indicador de carga) y quita la planta solo si sale bien.
  @override
  Future<bool> deletePlant(int plantId) async {
    deleteCalls.add(plantId);
    fakeLoading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (deleteResult) {
      fakePlants = fakePlants.where((p) => p.id != plantId).toList();
    }
    fakeLoading = false;
    notifyListeners();
    return deleteResult;
  }

  @override
  void clearSession() {
    log.add('plants.clear');
    fakePlants = [];
  }
}

class FakeTaskProvider extends TaskProvider {
  FakeTaskProvider(this.log, this.fakeToday);

  final List<String> log;
  List<TaskModel> fakeToday;
  List<TaskModel> fakeUpcoming = [];
  bool fakeLoading = false;

  final List<List<TaskModel>> scripted = [];
  Completer<void>? gate;

  int todayCalls = 0;
  int upcomingCalls = 0;
  final List<int> completeCalls = [];
  bool completeResult = true;

  @override
  List<TaskModel> get todayTasks => fakeToday;

  @override
  List<TaskModel> get upcomingTasks => fakeUpcoming;

  @override
  bool get isLoading => fakeLoading;

  @override
  int get pendingCount => fakeToday.where((t) => !t.isCompleted).length;

  @override
  Future<void> loadTodayTasks() async {
    todayCalls++;
    fakeLoading = true;
    notifyListeners();
    final pending = gate;
    if (pending != null) await pending.future;
    if (scripted.isNotEmpty) fakeToday = scripted.removeAt(0);
    fakeLoading = false;
    notifyListeners();
  }

  @override
  Future<void> loadUpcomingTasks() async {
    upcomingCalls++;
  }

  @override
  Future<bool> completeTask(int taskId) async {
    completeCalls.add(taskId);
    return completeResult;
  }

  @override
  void clearSession() {
    log.add('tasks.clear');
    fakeToday = [];
    fakeUpcoming = [];
  }
}

// ---------------------------------------------------------------------------
// Datos
// ---------------------------------------------------------------------------

PlantModel _plant(int id, String name, {bool demo = false}) =>
    PlantModel(id: id, commonName: name, isDemo: demo);

TaskModel _task(int id, {bool demo = false, int plantId = 1}) => TaskModel(
  id: id,
  plantId: plantId,
  plantName: 'Echeveria',
  taskType: 'Regar',
  status: 'Pendiente',
  dueDate: DateTime(2026, 11, 12),
  createdAt: DateTime(2026, 11, 1),
  isDemo: demo,
);

class _Rig {
  _Rig({
    required List<PlantModel> plants,
    required List<TaskModel> tasks,
    List<String>? sharedLog,
  }) : log = sharedLog ?? [] {
    auth = FakeAuthProvider(log);
    plantProvider = FakePlantProvider(log, plants);
    taskProvider = FakeTaskProvider(log, tasks);
  }

  final List<String> log;
  late final FakeAuthProvider auth;
  late final FakePlantProvider plantProvider;
  late final FakeTaskProvider taskProvider;
}

Future<void> _mount(
  WidgetTester tester,
  _Rig rig, {
  double width = 800,
  double height = 1400,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: rig.auth),
        ChangeNotifierProvider<PlantProvider>.value(value: rig.plantProvider),
        ChangeNotifierProvider<TaskProvider>.value(value: rig.taskProvider),
      ],
      child: MaterialApp(
        home: const HomeScreen(),
        routes: {'/login': (_) => const Scaffold(body: Text('LOGIN'))},
      ),
    ),
  );
  // initState lanza la carga en un microtask
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 15));
  expect(tester.takeException(), isNull);
}

Future<void> _openTasksTab(WidgetTester tester) async {
  await tester.tap(find.text('Tareas'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder get _aviso => find.byKey(_claveAviso);
Finder get _textoAviso =>
    find.descendant(of: _aviso, matching: find.text(_avisoHome));
Finder get _reintentar => find.widgetWithText(TextButton, 'Reintentar');

/// Arrastra la tarjeta de la planta, confirma el diálogo y deja correr el tiempo.
Future<void> _swipeAndConfirmDelete(WidgetTester tester, int plantId) async {
  await tester.drag(find.byKey(Key('plant_$plantId')), const Offset(-600, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('Eliminar Planta'), findsOneWidget);
  await tester.tap(find.text('Eliminar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// CA-20: el texto no solo cabe en su rectángulo: no se recorta (D7, nota del
/// plan sobre la obs. 2 de la revisión de la spec 004).
void _expectTextoEntero(WidgetTester tester, Finder texto, double ancho) {
  final widget = tester.widget<Text>(texto);
  expect(widget.maxLines, isNull);
  expect(widget.softWrap, isNot(false));
  expect(
    widget.overflow,
    isNot(anyOf(TextOverflow.ellipsis, TextOverflow.fade)),
  );

  final p = tester.renderObject<RenderParagraph>(texto);
  expect(p.didExceedMaxLines, isFalse);
  // La palabra más ancha cabe: con softWrap:false o ancho forzado esto falla
  expect(
    p.getMinIntrinsicWidth(double.infinity),
    lessThanOrEqualTo(p.size.width + 0.5),
  );
  final rect = tester.getRect(texto);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(ancho));
}

/// Origen de un desborde de `RenderFlex`, identificado por su widget (no por el
/// texto del mensaje ni por números de línea).
enum _Origen { filaPestanas, cabeceraMenu, otro }

class _Desborde {
  _Desborde(this.origen, this.pixeles, this.descripcion);

  final _Origen origen;
  final double pixeles;
  final String descripcion;
}

/// Textos de todos los `RenderParagraph` bajo [ro].
Set<String> _textosBajo(RenderObject ro) {
  final textos = <String>{};
  void visitar(RenderObject o) {
    if (o is RenderParagraph) textos.add(o.text.toPlainText());
    o.visitChildren(visitar);
  }

  visitar(ro);
  return textos;
}

/// ¿Algún ancestro del `RenderObject` es un widget de tipo [T]?
bool _dentroDe<T extends Widget>(RenderObject ro) {
  final creador = ro.debugCreator;
  if (creador is! DebugCreator) return false;
  var encontrado = false;
  creador.element.visitAncestorElements((e) {
    if (e.widget is T) {
      encontrado = true;
      return false;
    }
    return true;
  });
  return encontrado;
}

/// Clasifica un error al recibirlo (con el árbol vivo): solo es conocido si es un
/// desborde de un `RenderFlex` que es (a) la `Row` que contiene los textos
/// «Mis Plantas» y «Tareas», o (b) la `Column` de un `DrawerHeader`.
_Desborde _clasificar(FlutterErrorDetails details) {
  final e = details.exception;
  final texto = details.toString();
  if (!e.toString().contains('overflowed')) {
    return _Desborde(_Origen.otro, 0, 'No es un desborde: $e');
  }
  final m = RegExp(r'overflowed by ([0-9.]+) pixels').firstMatch(e.toString());
  final pixeles = m == null ? double.infinity : double.parse(m.group(1)!);
  RenderObject? culpable;
  final nodos = details.informationCollector?.call() ?? const <DiagnosticsNode>[];
  for (final n in nodos) {
    if (n.value is RenderObject) {
      culpable = n.value as RenderObject;
      break;
    }
  }
  if (culpable is! RenderFlex) {
    return _Desborde(_Origen.otro, pixeles, 'Sin RenderFlex culpable: $texto');
  }
  if (culpable.direction == Axis.horizontal) {
    final textos = _textosBajo(culpable);
    if (textos.contains('Mis Plantas') && textos.contains('Tareas')) {
      return _Desborde(_Origen.filaPestanas, pixeles, texto);
    }
  } else if (_dentroDe<DrawerHeader>(culpable)) {
    return _Desborde(_Origen.cabeceraMenu, pixeles, texto);
  }
  return _Desborde(_Origen.otro, pixeles, texto);
}

/// Inicio tiene dos desbordes que ya existen en main y son ajenos a la spec 005:
/// la fila «Mis Plantas | Tareas» (149 px a 320, 109 px a 360 con la insignia de tareas) y la cabecera del
/// menú lateral (8 px abajo). Se recogen los errores de toda la prueba y se
/// toleran SOLO esos dos `RenderFlex`, identificados por su widget, con tope de
/// píxeles y de repeticiones. La cabecera del menú solo se tolera si la prueba
/// abre el menú (`conMenu: true`). Cualquier otro error o desborde, incluido el
/// del aviso (`DataNoticeBanner`), hace fallar la prueba.
Future<void> Function(WidgetTester) _tolerante(
  Future<void> Function(WidgetTester) cuerpo, {
  bool conMenu = false,
}) {
  const maxPixelesFila = 150.0; // medido: 149 a 320 px y 109 a 360 px, con la insignia de tareas
  const maxPixelesMenu = 10.0;
  const maxRepeticiones = 4;
  return (tester) async {
    final original = FlutterError.onError;
    final recogidos = <_Desborde>[];
    FlutterError.onError = (details) => recogidos.add(_clasificar(details));
    try {
      await cuerpo(tester);
    } finally {
      FlutterError.onError = original;
    }
    var filas = 0;
    var menus = 0;
    for (final d in recogidos) {
      switch (d.origen) {
        case _Origen.filaPestanas:
          filas++;
          expect(
            d.pixeles,
            lessThanOrEqualTo(maxPixelesFila),
            reason: 'La fila de pestañas desborda más que en main: ${d.descripcion}',
          );
        case _Origen.cabeceraMenu:
          menus++;
          expect(
            conMenu,
            isTrue,
            reason: 'Desborde del menú en una prueba que no lo abre: ${d.descripcion}',
          );
          expect(
            d.pixeles,
            lessThanOrEqualTo(maxPixelesMenu),
            reason: 'La cabecera del menú desborda más que en main: ${d.descripcion}',
          );
        case _Origen.otro:
          fail('Error o desborde no tolerado: ${d.descripcion}');
      }
    }
    expect(
      filas,
      lessThanOrEqualTo(maxRepeticiones),
      reason: 'Demasiados desbordes de la fila de pestañas',
    );
    expect(
      menus,
      lessThanOrEqualTo(maxRepeticiones),
      reason: 'Demasiados desbordes de la cabecera del menú',
    );
  };
}

void main() {
  group('CA-1 a CA-4 · el aviso de Inicio', () {
    testWidgets(
      'con plantas de ejemplo se ve el aviso en Mis Plantas y en Tareas',
      (tester) async {
        final rig = _Rig(
          plants: [_plant(1, 'Echeveria', demo: true)],
          tasks: [_task(1, demo: true)],
        );
        await _mount(tester, rig);

        expect(_textoAviso, findsOneWidget);
        expect(_reintentar, findsOneWidget);
        expect(find.byKey(const Key('plant_1')), findsOneWidget);
        // Encima de la fila «Mis Plantas | Tareas»
        expect(
          tester.getTopLeft(_aviso).dy,
          lessThan(tester.getTopLeft(find.text('Mis Plantas')).dy),
        );

        await _openTasksTab(tester);
        // Sigue visible en la otra pestaña, y es uno solo
        expect(_aviso, findsOneWidget);
        expect(_textoAviso, findsOneWidget);
        expect(_reintentar, findsOneWidget);

        await _finish(tester);
      },
    );

    testWidgets(
      'con plantas de ejemplo y sin tareas de ejemplo también se ve el aviso',
      (tester) async {
        final rig = _Rig(
          plants: [_plant(1, 'Echeveria', demo: true)],
          tasks: [_task(1)],
        );
        await _mount(tester, rig);
        expect(_textoAviso, findsOneWidget);
        await _finish(tester);
      },
    );

    testWidgets('con plantas reales y tareas de ejemplo se ve el aviso', (
      tester,
    ) async {
      final rig = _Rig(
        plants: [_plant(1, 'Echeveria')],
        tasks: [_task(1, demo: true)],
      );
      await _mount(tester, rig);

      expect(_textoAviso, findsOneWidget);
      expect(_reintentar, findsOneWidget);
      await _openTasksTab(tester);
      expect(_textoAviso, findsOneWidget);

      await _finish(tester);
    });

    testWidgets('sin ejemplos, con listas llenas o vacías, no hay aviso', (
      tester,
    ) async {
      final casos = <String, _Rig>{
        'llenas': _Rig(plants: [_plant(1, 'Echeveria')], tasks: [_task(1)]),
        'vacías': _Rig(plants: [], tasks: []),
        'plantas sin tareas': _Rig(plants: [_plant(1, 'Echeveria')], tasks: []),
        'tareas sin plantas': _Rig(plants: [], tasks: [_task(1)]),
      };
      for (final entry in casos.entries) {
        await _mount(tester, entry.value);
        expect(_aviso, findsNothing, reason: entry.key);
        expect(find.textContaining('Modo demo'), findsNothing,
            reason: entry.key);
        expect(_reintentar, findsNothing, reason: entry.key);
        await _openTasksTab(tester);
        expect(_aviso, findsNothing, reason: entry.key);
        await _finish(tester);
      }
    });

    testWidgets('con listas vacías reales no hay plantas ni tareas de ejemplo', (
      tester,
    ) async {
      final rig = _Rig(plants: [], tasks: []);
      await _mount(tester, rig);
      expect(find.byKey(const Key('plant_1')), findsNothing);
      expect(find.text('Echeveria'), findsNothing);
      await _openTasksTab(tester);
      expect(find.text('¡No tienes tareas pendientes hoy!'), findsOneWidget);
      await _finish(tester);
    });
  });

  group('CA-5 · Reintentar', () {
    testWidgets(
      'Reintentar recarga plantas y tareas y el aviso desaparece cuando llegan datos reales',
      (tester) async {
        final rig = _Rig(
          plants: [_plant(1, 'Echeveria', demo: true)],
          tasks: [_task(1, demo: true)],
        );
        await _mount(tester, rig);
        // La carga de initState dejó los ejemplos (el servidor sigue caído)
        expect(rig.plantProvider.loadCalls, 1);
        expect(rig.taskProvider.todayCalls, 1);
        expect(rig.taskProvider.upcomingCalls, 1);
        expect(_aviso, findsOneWidget);

        // Primer reintento: sigue fallando -> sigue un solo aviso
        await tester.tap(_reintentar);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(rig.plantProvider.loadCalls, 2);
        expect(rig.taskProvider.todayCalls, 2);
        expect(rig.taskProvider.upcomingCalls, 2);
        expect(_aviso, findsOneWidget);
        expect(_textoAviso, findsOneWidget);

        // Segundo reintento: el servidor volvió
        rig.plantProvider.scripted.add([_plant(1, 'Echeveria')]);
        rig.taskProvider.scripted.add([_task(1)]);
        await tester.tap(_reintentar);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(rig.plantProvider.loadCalls, 3);
        expect(rig.taskProvider.todayCalls, 3);
        expect(rig.taskProvider.upcomingCalls, 3);
        expect(_aviso, findsNothing);
        expect(_reintentar, findsNothing);
        expect(find.byKey(const Key('plant_1')), findsOneWidget);

        await _finish(tester);
      },
    );

    testWidgets(
      'el aviso sigue mientras quede cualquiera de las dos listas con ejemplos',
      (tester) async {
        final rig = _Rig(
          plants: [_plant(1, 'Echeveria', demo: true)],
          tasks: [_task(1, demo: true)],
        );
        await _mount(tester, rig);

        // Vuelven las plantas reales pero las tareas siguen de ejemplo
        rig.plantProvider.scripted.add([_plant(1, 'Echeveria')]);
        await tester.tap(_reintentar);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(_aviso, findsOneWidget);

        await _finish(tester);
      },
    );

    for (final cual in ['plantas', 'tareas']) {
      testWidgets('Reintentar está desactivado mientras se cargan las $cual', (
        tester,
      ) async {
        final rig = _Rig(
          plants: [_plant(1, 'Echeveria', demo: true)],
          tasks: [_task(1, demo: true)],
        );
        await _mount(tester, rig);
        TextButton boton() => tester.widget<TextButton>(_reintentar);
        expect(boton().onPressed, isNotNull);

        final gate = Completer<void>();
        if (cual == 'plantas') {
          rig.plantProvider.gate = gate;
        } else {
          rig.taskProvider.gate = gate;
        }
        await tester.tap(_reintentar);
        await tester.pump();

        // Cargando: el aviso sigue (sigue habiendo ejemplos) y el botón no responde
        expect(_aviso, findsOneWidget);
        expect(_reintentar, findsOneWidget);
        expect(boton().onPressed, isNull);
        final antes = rig.plantProvider.loadCalls;
        await tester.tap(_reintentar, warnIfMissed: false);
        await tester.pump();
        expect(rig.plantProvider.loadCalls, antes, reason: 'sin peticiones dobles');

        // Termina la carga: el botón vuelve a estar activo
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(boton().onPressed, isNotNull);

        await _finish(tester);
      });
    }
  });

  group('CA-7 · acciones sobre ejemplos', () {
    testWidgets(
      'completar una tarea de ejemplo no llama a completeTask y avisa No disponible en modo demo',
      (tester) async {
        final rig = _Rig(
          plants: [_plant(1, 'Echeveria', demo: true)],
          tasks: [_task(1, demo: true)],
        );
        await _mount(tester, rig);
        await _openTasksTab(tester);

        final casilla = find
            .descendant(
              of: find.byType(Scrollable).last,
              matching: find.byType(GestureDetector),
            )
            .last;
        await tester.tap(casilla);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(rig.taskProvider.completeCalls, isEmpty);
        expect(find.text(_noDisponible), findsOneWidget);
        expect(find.textContaining('No se pudo completar'), findsNothing);
        // La tarea sigue en su lista, sin completar
        expect(rig.taskProvider.todayTasks.single.isCompleted, isFalse);

        await _finish(tester);
      },
    );

    testWidgets('completar una tarea real sí llama a completeTask', (
      tester,
    ) async {
      final rig = _Rig(plants: [_plant(1, 'Echeveria')], tasks: [_task(5)]);
      await _mount(tester, rig);
      await _openTasksTab(tester);

      final casilla = find
          .descendant(
            of: find.byType(Scrollable).last,
            matching: find.byType(GestureDetector),
          )
          .last;
      await tester.tap(casilla);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(rig.taskProvider.completeCalls, [5]);
      expect(find.text(_noDisponible), findsNothing);

      await _finish(tester);
    });

    testWidgets(
      'eliminar una planta de ejemplo no llama a deletePlant y la planta sigue',
      (tester) async {
        final rig = _Rig(
          plants: [_plant(1, 'Echeveria', demo: true)],
          tasks: [_task(1, demo: true)],
        );
        await _mount(tester, rig);

        await _swipeAndConfirmDelete(tester, 1);

        expect(rig.plantProvider.deleteCalls, isEmpty);
        expect(find.text(_noDisponible), findsOneWidget);
        expect(find.textContaining('eliminada'), findsNothing);
        expect(find.byKey(const Key('plant_1')), findsOneWidget);
        expect(rig.plantProvider.plants, hasLength(1));

        await _finish(tester);
      },
    );

    testWidgets(
      'en modo demo Diagnóstico IA del menú avisa y no abre el diálogo',
      _tolerante((tester) async {
        final requests = <http.Request>[];
        await http.runWithClient(() async {
          final rig = _Rig(
            plants: [_plant(1, 'Echeveria', demo: true)],
            tasks: [_task(1, demo: true)],
          );
          await _mount(tester, rig);
          await _openDrawer(tester);

          await tester.tap(find.text('Diagnóstico IA / Cámara En Vivo'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text(_noDisponible), findsOneWidget);
          expect(find.text('Diagnóstico IA en Vivo'), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          // El menú se cerró
          expect(find.text('Cerrar Sesión'), findsNothing);

          await _finish(tester);
        }, () => MockClient((r) async {
          requests.add(r);
          return http.Response(jsonEncode({'detail': 'x'}), 500);
        }));
        expect(
          requests.where((r) => r.url.path.contains('diagnostico-ia')),
          isEmpty,
        );
      }, conMenu: true),
    );
  });

  group('CA-8 · eliminar una planta real', () {
    testWidgets(
      'eliminar una planta real que falla avisa el error y la planta sigue',
      (tester) async {
        final rig = _Rig(
          plants: [_plant(7, 'Echeveria')],
          tasks: [],
        );
        rig.plantProvider.deleteResult = false;
        await _mount(tester, rig);

        await _swipeAndConfirmDelete(tester, 7);

        expect(rig.plantProvider.deleteCalls, [7]);
        expect(find.text(_deleteFailed), findsOneWidget);
        expect(find.textContaining('eliminada'), findsNothing);
        expect(find.text(_noDisponible), findsNothing);
        expect(find.byKey(const Key('plant_7')), findsOneWidget);
        expect(rig.plantProvider.plants, hasLength(1));

        await _finish(tester);
      },
    );

    testWidgets('eliminar una planta real que se borra muestra eliminada', (
      tester,
    ) async {
      final rig = _Rig(plants: [_plant(7, 'Echeveria')], tasks: []);
      await _mount(tester, rig);

      await _swipeAndConfirmDelete(tester, 7);

      expect(rig.plantProvider.deleteCalls, [7]);
      expect(find.text('Echeveria eliminada'), findsOneWidget);
      expect(find.text(_deleteFailed), findsNothing);
      expect(find.byKey(const Key('plant_7')), findsNothing);

      await _finish(tester);
    });
  });

  group('CA-9 · cerrar sesión', () {
    testWidgets('Cerrar Sesión limpia los dos providers antes de salir al login', _tolerante((
      tester,
    ) async {
      final rig = _Rig(
        plants: [_plant(1, 'Echeveria', demo: true)],
        tasks: [_task(1, demo: true)],
      );
      await _mount(tester, rig);
      await _openDrawer(tester);

      await tester.tap(find.text('Cerrar Sesión'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Las dos limpiezas, en este orden, y después logout (D4)
      expect(rig.log, ['plants.clear', 'tasks.clear', 'auth.logout']);
      expect(find.text('LOGIN'), findsOneWidget);

      await _finish(tester);
    }, conMenu: true));
  });

  group('CA-15 y CA-19 · nada inventado', () {
    testWidgets('Inicio no muestra clima', (tester) async {
      final rig = _Rig(
        plants: [_plant(1, 'Echeveria', demo: true)],
        tasks: [_task(1, demo: true)],
      );
      await _mount(tester, rig);

      expect(find.textContaining('Parcialmente'), findsNothing);
      expect(find.textContaining('nublado'), findsNothing);
      expect(find.textContaining('soleado'), findsNothing);
      expect(find.textContaining('26°'), findsNothing);
      expect(find.textContaining('26 °'), findsNothing);
      // Se queda el resto de la pantalla
      expect(find.text('Mis Plantas'), findsOneWidget);
      expect(find.text('Tareas'), findsOneWidget);

      await _finish(tester);
    });

    testWidgets('el menú no tiene Panel Solar y conserva los demás elementos', _tolerante((
      tester,
    ) async {
      final rig = _Rig(plants: [_plant(1, 'Echeveria')], tasks: []);
      await _mount(tester, rig);
      await _openDrawer(tester);

      final drawer = find.byType(Drawer);
      expect(drawer, findsOneWidget);
      expect(find.text('Panel Solar'), findsNothing);
      expect(find.byIcon(Icons.solar_power), findsNothing);
      for (final titulo in [
        'Mi Jardín',
        'Estadísticas',
        'Diagnóstico IA / Cámara En Vivo',
        'Editar Perfil',
        'Configuración',
        'Ayuda',
        'Cerrar Sesión',
      ]) {
        expect(
          find.descendant(of: drawer, matching: find.text(titulo)),
          findsOneWidget,
          reason: titulo,
        );
      }

      await _finish(tester);
    }, conMenu: true));
  });

  group('CA-20 · el aviso se ve entero', () {
    for (final ancho in [320.0, 360.0]) {
      testWidgets(
        'el aviso de Inicio con Reintentar se ve entero a ${ancho.toInt()} px',
        _tolerante((tester) async {
          final rig = _Rig(
            plants: [_plant(1, 'Echeveria', demo: true)],
            tasks: [_task(1, demo: true)],
          );
          await _mount(tester, rig, width: ancho);

          expect(_aviso, findsOneWidget);
          // Los desbordes ajenos (fila de pestañas) los recoge _tolerante; uno
          // del propio aviso haría fallar la prueba allí y en las mediciones.

          _expectTextoEntero(tester, _textoAviso, ancho);
          // El aviso y el botón caben en el ancho
          final caja = tester.getRect(_aviso);
          expect(caja.left, greaterThanOrEqualTo(0));
          expect(caja.right, lessThanOrEqualTo(ancho));
          final boton = tester.getRect(_reintentar);
          expect(boton.left, greaterThanOrEqualTo(caja.left));
          expect(boton.right, lessThanOrEqualTo(caja.right + 0.5));
          // El botón va debajo del texto, no compite por el ancho
          expect(
            boton.top,
            greaterThanOrEqualTo(tester.getRect(_textoAviso).bottom - 0.5),
          );

          await _finish(tester);
        }),
      );
    }
  });
}
