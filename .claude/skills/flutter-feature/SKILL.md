---
name: flutter-feature
description: Agrega o modifica pantallas, formularios y llamadas al API en la app Flutter de Solar-Grow (carpeta frontend/) siguiendo el flujo screen → provider → ApiService, el tema SolarColors y una prueba de widget. Úsala cuando la tarea toque archivos de frontend/lib.
---

# Funcionalidad Flutter para Solar-Grow

Sigue estos pasos en orden cuando agregues o cambies algo en `frontend/lib/`.

## 1. Contrato con el backend
- Confirma la ruta y el JSON exactos leyendo el router en `backend/app/routers/` y su schema en
  `backend/app/schemas/`. No inventes campos.
- Si la ruta no está en `lib/config/api_constants.dart`, agrégala como `static const String`.
- Ojo: varias constantes terminan en `/` (`tasks = '/api/tasks/'`). Para rutas con id usa
  `'${ApiConstants.tasks}$id'`, no `'${ApiConstants.tasks}/$id'`.

## 2. Modelo
- En `lib/models/<x>_model.dart`: campos `final`, constructor con `required`, `factory fromJson`
  que mapea `snake_case` → `camelCase` y, si se envía al API, `Map<String, dynamic> toJson()`.
- Fechas: `DateTime.parse(json['due_date'])` al leer y `.toUtc().toIso8601String()` al enviar.

## 3. Provider
- Método en el provider existente del recurso (`lib/providers/<x>_provider.dart`); solo crea uno
  nuevo si el recurso es nuevo, y regístralo en el `MultiProvider` de `main.dart`.
- Plantilla:
```dart
Future<bool> createX(Map<String, dynamic> body) async {
  _isLoading = true;
  notifyListeners();
  try {
    final data = await ApiService.post(ApiConstants.xs, body: body);
    _items = [..._items, XModel.fromJson(data)];
    return true;
  } catch (e) {
    debugPrint('Error al crear X: $e');
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```
- Las pantallas nunca llaman a `ApiService` ni a `http` directamente.

## 4. Pantalla o widget
- Pantalla nueva: `lib/screens/<seccion>/<nombre>_screen.dart`, clase `NombreScreen`, y su ruta en
  el mapa `routes` de `main.dart`. Para un formulario corto, prefiere un `showModalBottomSheet` en la
  pantalla existente.
- Formularios: `Form` + `GlobalKey<FormState>`, `validator` con mensajes en español, botón
  deshabilitado mientras `isLoading`.
- Colores y estilos de `SolarColors` / `Theme.of(context)`; reutiliza `lib/widgets/` cuando aplique.
- Después de cada `await`: `if (!context.mounted) return;` y luego `SnackBar` en español con el
  resultado.
- Textos de UI en español; valores enviados al API exactamente como los espera el backend
  (`'Regar'`, `'Fertilizar'`, `'Trasplantar'`, `'Podar'`, `'Revisar'`).

## 5. Prueba
- `frontend/test/<nombre>_test.dart` con `testWidgets`. Envuelve el widget en
  `MaterialApp` + `ChangeNotifierProvider<XProvider>.value(value: providerFalso, ...)`, donde
  `providerFalso` extiende el provider y sobreescribe el método de red para no hacer HTTP real.
- Comprueba al menos: el formulario valida campos vacíos y llama al provider con los datos correctos.

## 6. Verificar
```powershell
cd frontend; flutter analyze; flutter test
```
No debe aparecer ningún error nuevo de `flutter analyze` en los archivos que tocaste.
