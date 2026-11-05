# Frontend · App Solar-Grow

App **Flutter (Dart SDK ^3.11)** para Android y web. Estado con **provider** (`ChangeNotifier`),
HTTP con `http`, token JWT guardado en `shared_preferences`. Tipografía con `google_fonts`,
gráficas con `fl_chart`.

## Comandos (PowerShell, desde `frontend\`)
```powershell
flutter pub get
flutter run -d chrome          # web: usa http://localhost:8000
flutter run -d emulator-5554   # Android: usa http://10.0.2.2:8000
flutter analyze                # debe quedar sin errores nuevos
dart format lib test
flutter test
```
El backend debe estar corriendo (`uvicorn` en `..\backend`) para ver datos reales; si no responde,
varios providers cargan **datos demo** (p. ej. `TaskProvider._loadDemoTasks`).

## Organización y dependencias permitidas
```
lib/
  main.dart     MultiProvider + MaterialApp con rutas con nombre ('/home', '/plant-detail'…)
  config/       theme.dart (SolarColors, SolarTheme) y api_constants.dart (URLs y endpoints)
  services/     api_service.dart: ÚNICO punto de acceso HTTP (get/post/put/patch/delete/uploadImage)
  models/       clases inmutables con fromJson (snake_case → camelCase)
  providers/    auth, plant, task: llaman a ApiService y exponen estado con notifyListeners()
  screens/      una carpeta por sección (auth, home, plant, stats, notifications, recommendations, profile)
  widgets/      componentes reutilizables (task_card, sensor_card, weather_bar, animated_plant)
```
- Flujo: `screen` → `provider` → `ApiService` → backend. Las pantallas **no** llaman a `http`
  ni a `ApiService` directamente; usan `context.read<XProvider>()` / `context.watch<XProvider>()`.
- Endpoints nuevos se declaran como constantes en `config/api_constants.dart`, nunca como strings
  sueltos en providers o pantallas.
- Navegación con `Navigator.pushNamed` y las rutas de `main.dart`. `go_router` está en `pubspec`
  pero **no se usa**: no lo introduzcas.
- Pantalla nueva → registrar su ruta en `main.dart`.

## Convenciones
- Archivos `snake_case.dart`; pantallas `XxxScreen`, pestañas `XxxTab`, modelos `XxxModel`.
- Colores y estilos siempre desde `SolarColors` / `SolarTheme` (`config/theme.dart`); no uses
  `Color(0x...)` sueltos ni `Colors.green`.
- Textos de UI en español. Valores de enums del backend tal cual (`'Regar'`, `'Pendiente'`,
  `'Completada'`).
- Los métodos de provider que llaman al API devuelven `Future<bool>` (éxito/fallo) y la pantalla
  muestra un `SnackBar` en español.
- Comprueba `if (!mounted) return;` (o `context.mounted`) después de cada `await` antes de usar
  `context`; `flutter analyze` ya marca `use_build_context_synchronously`.
- Pruebas en `test/` (`*_test.dart`). Para widgets que dependen de providers, envuelve el widget en
  `ChangeNotifierProvider` con un provider de prueba; no hagas peticiones HTTP reales en tests.

## Trampas conocidas
- `ApiConstants.tasks` termina en `/` (`'/api/tasks/'`), así que `'${ApiConstants.tasks}/$id'`
  produce `/api/tasks//5`. Para rutas con id usa `'${ApiConstants.tasks}$id'`.
- `test/widget_test.dart` busca el texto `'Solar-Grow'` del splash; si cambias el splash, actualízalo.
- `flutter analyze` ya reporta avisos previos (ver `..\analyze_output.txt`); no los arregles en masa
  dentro de otra tarea, solo no agregues nuevos.

## No hacer
- No cambiar `baseUrl` / `webBaseUrl` de `api_constants.dart` ni el `applicationId` de Android.
- No editar archivos generados: `android/`, `ios/`, `web/`, `pubspec.lock` (salvo al agregar un paquete
  con `flutter pub add`, y solo si se pidió).
- No agregar paquetes nuevos sin justificarlo en el plan.
