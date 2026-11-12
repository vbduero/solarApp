# Plan · Spec 002

## Lo que se comprobó en el código antes de planear

- `GET /api/ai/diagnosis/{plant_id}` existe en `backend/app/routers/ai.py` (`get_diagnoses`). Busca
  la planta con `Plant.id == plant_id` y `Plant.user_id == current_user.id` (sin `is_active`), si no
  existe responde 404 «Planta no encontrada», y lista `AIDiagnosis` con
  `order_by(desc(AIDiagnosis.created_at)).limit(10)`, sin desempate. El router `ai` está registrado
  en `app/main.py`, pero ninguna prueba lo usa.
- `AIDiagnosisResponse` (`backend/app/schemas/recommendation.py`) declara `health_status: str`. La
  columna es `Enum(HealthStatus)` y `HealthStatus(str, enum.Enum)` tiene valores en español
  (`"Buena"`, `"Critica"`…). SQLAlchemy devuelve el miembro del enum, que es un `str` cuyo texto es el
  valor; Pydantic 2.12 (`requirements.txt`) en modo normal acepta subclases de `str` y conserva ese
  texto. **Conclusión:** hoy debería viajar `"Buena"`, no `"BUENA"`. No se ejecutó; CA-2 se fija con
  una prueba y, si falla, se corrige (D3).
- `created_at` es `DateTime(timezone=True)` con `server_default=func.now()`. En PostgreSQL vuelve con
  zona; en SQLite (pruebas) vuelve sin zona.
- `GET /api/hardware/diagnostico-ia` (`backend/app/routers/hardware.py`): llama a
  `capturar_foto_webcam()` (importada en el módulo del router), escribe
  `static/ultimo_diagnostico.jpg` con ruta relativa, exige `settings.GEMINI_API_KEY`, llama a
  `obtener_datos_actuales()` y crea `genai.Client(api_key=...)` dentro de la función. Prueba tres
  modelos; con error 429/`RESOURCE_EXHAUSTED` hace `time.sleep(2)` (`import time` dentro del bucle) y
  pasa al siguiente; con otro error responde 500. Si Gemini responde, toma
  `get_device_plant(db, settings.ESP8266_PLANT_ID)` y llama a `save_diagnosis` **sin mirar
  `plant.user_id`**; la respuesta trae `diagnosis_id` y `plant_id`.
- `save_diagnosis` y `get_device_plant` (`backend/app/services/hardware_service.py`) ya tienen
  pruebas en `backend/tests/test_hardware_service.py`. `save_diagnosis` escribe la foto en
  `static/diagnosticos/diag_<planta>_<8hex>.jpg` (ruta relativa) y guarda
  `image_url = "/static/diagnosticos/<archivo>"`.
- `backend/tests/test_seguridad_hardware.py` ya importa el router `hardware` (con `cv2`, `serial` y
  `google.genai`), así que las pruebas pueden importarlo en la CI. Usa `monkeypatch` sobre
  `hardware.obtener_datos_actuales` y `get_settings()`, y `monkeypatch.chdir(tmp_path)` para no
  escribir en `static/`. `conftest.py` da `db`, `user`, `other_user`, `plant`, `other_plant`.
- Frontend: `ApiConstants.aiDiagnosis = '/api/ai/diagnosis'` existe, no termina en `/` y nadie la
  usa; la ruta con id es `'${ApiConstants.aiDiagnosis}/$plantId'`. **No hace falta tocar
  `api_constants.dart`.**
- `PlantDetailScreen` (`frontend/lib/screens/plant/plant_detail_screen.dart`) obtiene la planta de
  `PlantProvider.selectedPlant`; los botones circulares «Info» y «Regar» están en
  `_buildActionButtons` (`_buildCircleButton`). Navega con `Navigator.pushNamed`.
- `main.dart` registra `AuthProvider`, `PlantProvider` y `TaskProvider` en un `MultiProvider`
  global. `AuthProvider.logout()` solo borra el token: **los providers globales conservan su estado
  entre sesiones**.
- `ApiService.get` arma `'$baseUrl$endpoint'` y lanza `ApiException` con códigos de error;
  `ApiService.baseUrl` es estático. `intl` ya está en `pubspec.yaml`; no hace falta ningún paquete.
- Pruebas de frontend existentes que sirven de patrón: `sensor_history_provider_test.dart`
  (`http.runWithClient` + `MockClient`) y `stats_screen_test.dart` (provider falso que extiende el
  real).

## Decisiones técnicas

- **D1 · Listado: planta activa y desempate.** En `get_diagnoses` se agrega
  `Plant.is_active == True` a la búsqueda de la planta (CA-5) y el orden pasa a
  `desc(AIDiagnosis.created_at), desc(AIDiagnosis.id)` (CA-1). El límite de 10 no cambia.
  *Motivo:* coherencia con `plants.py` y orden determinista, lección de la spec 001. Es lectura y
  respuesta: no hace falta servicio nuevo. `get_recommendations`, en el mismo archivo, no se toca.
- **D2 · Dueño de la planta del ESP8266 (CA-8).** Nueva función en
  `backend/app/services/hardware_service.py`:
  `get_device_plant_for_user(db, configured_plant_id, user_id) -> Optional[Plant]`. Devuelve la
  planta de `get_device_plant` solo si `plant.user_id == user_id`; si no, `None`. En `hardware.py`,
  el bloque de guardado usa esta función con `current_user.id`. Si es `None`, no se guarda, se
  imprime `"[HARDWARE] Diagnóstico no guardado: la planta del ESP8266 no es del usuario."` y la
  respuesta lleva `diagnosis_id` y `plant_id` en `None`, como hoy cuando no hay planta.
  *Motivo:* la regla está en un servicio que se prueba sin hardware; el router cambia una línea.
  `get_device_plant` no cambia porque la usan `clima-actual` y `hardware_helper.py`, y esos quedan
  fuera de alcance.
- **D3 · `health_status`.** No se cambia el schema mientras la prueba de CA-2 pase. Si falla (llega
  `"BUENA"` o `"HealthStatus.BUENA"`), `backend-dev` lo corrige en el schema
  (`field_serializer`/validador que tome `.value`) y lo anota en «Diferencias con lo planeado».
- **D4 · Modelo Dart `DiagnosisModel`** en `frontend/lib/models/diagnosis_model.dart`. Campos `id`
  (`int`), `plantId` (`int`), `healthStatus` (`String`, tal cual llega), `diagnosis` (`String?`),
  `imageUrl` (`String?`) y `createdAt` (`DateTime`), con `fromJson` desde `snake_case`. Ignora
  `confidence`, `detected_issues` y `suggested_actions`.
  - Getter `healthLabel`: `"Critica"` → «Crítica»; los demás valores igual; uno desconocido se
    muestra tal cual.
  - **Fechas:** si `created_at` trae zona (`Z` o `±hh:mm`) se usa `DateTime.parse`; si no la trae
    (SQLite), se interpreta como UTC (se le agrega `Z`). La pantalla siempre muestra `toLocal()`.
    *Motivo:* el backend guarda en UTC; leer una fecha sin zona como hora local la corre 5 horas
    (pendiente n.º 9 de la revisión de la spec 001). Esto solo vale para el modelo nuevo;
    `SensorReadingModel` no se toca.
- **D5 · Provider nuevo `DiagnosisProvider`** en `frontend/lib/providers/diagnosis_provider.dart`.
  Expone `diagnoses` (`List<DiagnosisModel>`), `isLoading`, `error` (`String?`),
  `Future<bool> loadDiagnoses(int plantId)` y `String? imageUrlFor(DiagnosisModel d)` (devuelve
  `'${ApiService.baseUrl}${d.imageUrl}'`, o `null` si no hay `imageUrl`; así la pantalla no toca
  `ApiService`).
  - Al empezar cada carga: vacía la lista, borra el error, `isLoading = true` y notifica.
  - Al terminar: ordena por `createdAt` descendente y luego por `id` descendente.
  - Si falla: lista vacía, `error = 'No se pudieron cargar los diagnósticos.'` y devuelve `false`.
    No hay datos demo.
  - Lleva un contador de petición, como `loadSensorHistory`: una respuesta (buena o mala) de una
    petición que ya no es la última se descarta sin tocar el estado.
  *Motivo:* `PlantProvider` ya es grande y tiene datos demo; un provider propio es más fácil de
  sustituir en pruebas.
- **D6 · El provider vive solo mientras la pantalla está abierta (CA-15).** No se registra en el
  `MultiProvider` global. La ruta `'/plant-diagnoses'` de `main.dart` crea
  `ChangeNotifierProvider(create: (_) => DiagnosisProvider(), child: DiagnosisHistoryScreen(...))`.
  *Motivo:* al cerrar la pantalla el estado se destruye. Así nunca quedan diagnósticos de otra
  planta ni de otra sesión, aunque `logout()` no limpie los providers. El contador de D5 cubre las
  respuestas fuera de orden dentro de la misma pantalla.
- **D7 · Navegación.** En `_buildActionButtons` de `plant_detail_screen.dart` se agrega un tercer
  `_buildCircleButton` con icono `Icons.history`, etiqueta `'Diagnósticos'` y color
  `SolarColors.primaryDark`. Hace `Navigator.pushNamed(context, '/plant-diagnoses', arguments: plant)`
  (el `PlantModel` seleccionado). La ruta lee `ModalRoute.of(context)?.settings.arguments` como
  `PlantModel?` y construye `DiagnosisHistoryScreen(plantId: plant.id, plantName: plant.commonName)`.
  Sin argumentos, muestra `Scaffold` con «Planta no encontrada», igual que el detalle.
- **D8 · Pantalla `DiagnosisHistoryScreen`** en
  `frontend/lib/screens/plant/diagnosis_history_screen.dart`. Recibe `plantId` y `plantName` por
  constructor (así las pruebas no necesitan rutas).
  - En `initState` lanza `loadDiagnoses(plantId)` después del primer frame (`Future.microtask`/
    `addPostFrameCallback`), nunca en `build`.
  - `AppBar` con título «Diagnósticos» y el nombre de la planta visible debajo.
  - Estados:
    - cargando: `CircularProgressIndicator` y ninguna lista;
    - error: el texto de `error` y un botón «Reintentar» que llama otra vez a
      `loadDiagnoses(plantId)`;
    - vacío: «Esta planta aún no tiene diagnósticos.»;
    - con datos: `ListView` de tarjetas.
  - Cada tarjeta: miniatura de 64×64 con `Image.network(provider.imageUrlFor(d)!)` y `errorBuilder`
    que muestra «Sin foto» (si `imageUrlFor` es `null`, «Sin foto» directamente). Al lado, la fecha
    con `DateFormat('dd/MM/yyyy HH:mm').format(d.createdAt.toLocal())` y `d.healthLabel`.
  - Colores del estado: «Excelente»/«Buena» `SolarColors.success`, «Regular» `SolarColors.warning`,
    «Mala»/«Crítica» `SolarColors.error`. Desconocido: `SolarColors.textSecondary`.
- **D9 · Detalle de un diagnóstico (CA-11).** Al tocar una tarjeta se abre
  `showModalBottomSheet(isScrollControlled: true)` con:
  - la foto grande (mismo `errorBuilder` con «Sin foto»);
  - la fecha y el estado;
  - el texto completo en un `SelectableText` dentro de un scroll, o «Sin descripción» si
    `diagnosis` es `null` o vacío;
  - un botón «Cerrar».
  No se parsean secciones: el texto se muestra tal cual. *Motivo:* no hace falta ruta nueva; es el
  mismo patrón que `create_task_sheet.dart`. Reutilizar `_parseDiagnostico` de `home_screen.dart`
  obligaría a moverlo, y ese diálogo está fuera de alcance.
- **D10 · Textos fijos** (las pruebas los buscan tal cual): «Diagnósticos», «Esta planta aún no
  tiene diagnósticos.», «No se pudieron cargar los diagnósticos.», «Reintentar», «Sin foto», «Sin
  descripción», «Cerrar», «Planta no encontrada», y las etiquetas «Excelente», «Buena», «Regular»,
  «Mala», «Crítica».
- **Sin migraciones, sin columnas nuevas, sin paquetes nuevos, sin cambios en firmware,
  `api_constants.dart`, `seed_data.py`, schemas (salvo D3) ni en el diálogo de `home_screen.dart`.**

## Archivos que se tocan

| Archivo | Cambio |
|---|---|
| `backend/app/routers/ai.py` | `get_diagnoses`: filtro `is_active` y desempate por `id` (D1). Nada más. |
| `backend/app/services/hardware_service.py` | Nueva `get_device_plant_for_user` (D2). |
| `backend/app/routers/hardware.py` | `diagnostico_ia`: usa `get_device_plant_for_user` con `current_user.id` antes de guardar (D2). Nada más. |
| `backend/app/schemas/recommendation.py` | **Solo si falla la prueba de CA-2** (D3). |
| `backend/tests/test_ai_diagnoses.py` | **Nuevo.** Listado (CA-1 a CA-5). |
| `backend/tests/test_diagnostico_ia.py` | **Nuevo.** Guardado con webcam y Gemini sustituidos (CA-6 a CA-8). |
| `backend/tests/test_hardware_service.py` | Se **agregan** pruebas de `get_device_plant_for_user`; no se cambian las existentes. |
| `frontend/lib/models/diagnosis_model.dart` | **Nuevo.** `DiagnosisModel` (D4). |
| `frontend/lib/providers/diagnosis_provider.dart` | **Nuevo.** `DiagnosisProvider` (D5). |
| `frontend/lib/screens/plant/diagnosis_history_screen.dart` | **Nuevo.** `DiagnosisHistoryScreen` y la hoja de detalle (D8, D9, D10). |
| `frontend/lib/main.dart` | Ruta `'/plant-diagnoses'` con su `ChangeNotifierProvider` local (D6, D7). |
| `frontend/lib/screens/plant/plant_detail_screen.dart` | Botón «Diagnósticos» en `_buildActionButtons` (D7). Nada más. |
| `frontend/test/diagnosis_provider_test.dart` | **Nuevo.** Modelo y provider con `MockClient`. |
| `frontend/test/diagnosis_history_screen_test.dart` | **Nuevo.** Pruebas de widget con un `DiagnosisProvider` falso. |
| `frontend/test/plant_detail_diagnoses_button_test.dart` | **Nuevo.** Botón del detalle (CA-9). |
| `specs/002-historial-diagnosticos/*` | Spec, plan, tareas y, al final, `revision.md`. |

No se modifica ninguna prueba existente. `frontend/lib/config/api_constants.dart` **no** se toca y
no debe entrar en ningún commit (tiene un cambio local de la responsable).

## Pruebas por criterio

| Criterio | Prueba | Archivo |
|---|---|---|
| CA-1 | `test_listado_devuelve_solo_los_diagnosticos_de_la_planta_del_mas_reciente_al_mas_antiguo` | `backend/tests/test_ai_diagnoses.py` |
| CA-1 | `test_listado_devuelve_como_maximo_los_10_mas_recientes` | `backend/tests/test_ai_diagnoses.py` |
| CA-1 | `test_listado_con_la_misma_fecha_desempata_por_id_descendente` | `backend/tests/test_ai_diagnoses.py` |
| CA-1 | `test_listado_trae_los_campos_del_contrato` | `backend/tests/test_ai_diagnoses.py` |
| CA-2 | `test_listado_envia_health_status_en_espanol` (parametrizada con los 5 estados) | `backend/tests/test_ai_diagnoses.py` |
| CA-3 | `test_listado_sin_diagnosticos_devuelve_lista_vacia` | `backend/tests/test_ai_diagnoses.py` |
| CA-4 | `test_listado_de_planta_ajena_devuelve_404` | `backend/tests/test_ai_diagnoses.py` |
| CA-4 | `test_listado_de_planta_inexistente_devuelve_404` | `backend/tests/test_ai_diagnoses.py` |
| CA-4 | `test_listado_sin_token_devuelve_401` | `backend/tests/test_ai_diagnoses.py` |
| CA-5 | `test_listado_de_planta_borrada_devuelve_404` | `backend/tests/test_ai_diagnoses.py` |
| CA-6 | `test_diagnostico_exitoso_se_guarda_con_su_foto_y_sale_primero_en_el_listado` | `backend/tests/test_diagnostico_ia.py` |
| CA-7 | `test_si_falla_la_webcam_responde_500_y_no_guarda` | `backend/tests/test_diagnostico_ia.py` |
| CA-7 | `test_si_gemini_falla_responde_500_y_no_guarda` | `backend/tests/test_diagnostico_ia.py` |
| CA-7 | `test_si_todos_los_modelos_estan_ocupados_responde_429_y_no_guarda` | `backend/tests/test_diagnostico_ia.py` |
| CA-7 | `test_sin_api_key_de_gemini_responde_500_y_no_guarda` | `backend/tests/test_diagnostico_ia.py` |
| CA-8 | `test_si_la_planta_del_esp8266_es_de_otro_usuario_devuelve_el_diagnostico_sin_guardarlo` | `backend/tests/test_diagnostico_ia.py` |
| CA-8 | `test_device_plant_for_user_devuelve_la_planta_si_es_del_usuario` | `backend/tests/test_hardware_service.py` |
| CA-8 | `test_device_plant_for_user_devuelve_none_si_es_de_otro_usuario` | `backend/tests/test_hardware_service.py` |
| CA-8 | `test_device_plant_for_user_devuelve_none_sin_planta` | `backend/tests/test_hardware_service.py` |
| CA-9 | `el botón Diagnósticos del detalle abre /plant-diagnoses con la planta seleccionada` | `frontend/test/plant_detail_diagnoses_button_test.dart` |
| CA-9 | `muestra el título Diagnósticos y el nombre de la planta` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-10 | `con diagnósticos muestra uno por elemento del más reciente al más antiguo con fecha y estado` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-10 | `cada miniatura usa la URL de su propio diagnóstico` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-10 | `no muestra ningún porcentaje de confianza` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-10 | `healthLabel muestra Crítica con tilde y deja los demás valores igual` | `frontend/test/diagnosis_provider_test.dart` |
| CA-10 | `fromJson lee una fecha sin zona como UTC y una con zona tal cual` | `frontend/test/diagnosis_provider_test.dart` |
| CA-10 | `loadDiagnoses pide /api/ai/diagnosis/7 y ordena del más reciente al más antiguo desempatando por id` | `frontend/test/diagnosis_provider_test.dart` |
| CA-11 | `al tocar un diagnóstico muestra su texto completo, fecha, estado y foto grande` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-11 | `un diagnóstico sin texto muestra Sin descripción` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-12 | `un diagnóstico sin image_url muestra Sin foto y ninguna imagen` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-12 | `si la imagen no carga muestra Sin foto` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-12 | `imageUrlFor arma la URL con image_url y devuelve null sin imagen` | `frontend/test/diagnosis_provider_test.dart` |
| CA-13 | `sin diagnósticos muestra el estado vacío y ninguna tarjeta` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-14 | `si el API falla muestra el error con Reintentar y ningún diagnóstico` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-14 | `Reintentar vuelve a pedir la misma planta y muestra la lista` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-14 | `si el API falla devuelve false, vacía la lista y deja el mensaje exacto` | `frontend/test/diagnosis_provider_test.dart` |
| CA-15 | `mientras carga muestra el indicador y ningún diagnóstico` | `frontend/test/diagnosis_history_screen_test.dart` |
| CA-15 | `al empezar una carga vacía los diagnósticos anteriores` | `frontend/test/diagnosis_provider_test.dart` |
| CA-15 | `si una respuesta anterior llega tarde se conserva la de la última petición` | `frontend/test/diagnosis_provider_test.dart` |
| CA-15 | `si una respuesta anterior llega tarde y falla no pisa los datos de la última petición` | `frontend/test/diagnosis_provider_test.dart` |

Notas para quien escribe las pruebas:

- **Qué pasa desde el principio y qué debe fallar.**
  - Fijan comportamiento actual y **deberían pasar ya**: CA-1 (salvo el desempate), CA-2, CA-3,
    CA-4, CA-6 y CA-7.
  - **Deben fallar** antes del código:
    - el desempate de CA-1: en SQLite los empates suelen salir por orden de inserción, o sea id
      ascendente. Si pasara por casualidad, anotarlo;
    - CA-5;
    - las de CA-8 (la de servicio falla por importación de una función que no existe; la del
      endpoint, porque hoy sí guarda);
    - todas las de frontend.
  - Si la de CA-2 falla, avisar a `backend-dev` (D3).
- **Backend, listado.**
  - App de prueba con `ai.router`, como `test_seguridad_hardware.py`, con `get_db` y
    `get_current_user` sobreescritos. Para 401, un cliente sin sobreescribir `get_current_user`.
  - Crear los `AIDiagnosis` con `created_at` explícito y con zona
    (`datetime.now(timezone.utc) - timedelta(...)`); no depender de `server_default`.
  - Para el desempate, dos con el mismo `created_at`.
  - Para el límite, 12 diagnósticos: deben volver los 10 más recientes.
  - Planta borrada: `plant.is_active = False` y commit.
- **Backend, `diagnostico-ia`.** Sin webcam, Gemini, ESP8266 ni red. App de prueba con
  `hardware.router` y `ai.router`. Con `monkeypatch`:
  - `monkeypatch.chdir(tmp_path)`, para que `static/ultimo_diagnostico.jpg` y
    `static/diagnosticos/` se escriban en la carpeta temporal;
  - `hardware.capturar_foto_webcam` → `lambda: b"\xff\xd8jpeg"` (o una función que lanza
    `RuntimeError` para CA-7);
  - `hardware.obtener_datos_actuales` → un diccionario como el de `test_clima_actual_con_sesion…`;
  - `get_settings().GEMINI_API_KEY` → `"clave-de-prueba"` (y `None` para la prueba sin clave), y
    `get_settings().ESP8266_PLANT_ID` → el id de `plant` u `other_plant` según la prueba;
  - `hardware.genai.Client` → una clase falsa cuyo `models.generate_content(model=..., contents=...)`
    devuelve un objeto con `.text = "ESTADO GENERAL: Saludable\n..."`, o lanza
    `Exception("boom")` (500) o `Exception("429 RESOURCE_EXHAUSTED")` (429);
  - para la de 429, `monkeypatch.setattr("time.sleep", lambda s: None)`, porque el router hace
    `import time` dentro de la función y usa el módulo global.

  En cada caso de CA-7 y CA-8: `db.query(AIDiagnosis).count() == 0`. En CA-8 además: la respuesta
  trae `diagnostico`, `diagnosis_id is None` y `plant_id is None`, y no existe
  `tmp_path/static/diagnosticos`. En CA-6: `diagnosis_id` no es `None`, el primer elemento de
  `GET /api/ai/diagnosis/{plant.id}` tiene ese id, su `image_url` empieza por
  `/static/diagnosticos/` y el archivo existe bajo `tmp_path`.
- **Frontend, provider.** `http.runWithClient` + `MockClient`, como `sensor_history_provider_test.dart`.
  Comprobar `request.url.path == '/api/ai/diagnosis/7'`. Para fuera de orden, retrasar la primera
  respuesta con un `Completer`. `imageUrlFor` se compara con `'${ApiService.baseUrl}/static/...'`.
- **Frontend, pantalla.**
  - `FakeDiagnosisProvider extends DiagnosisProvider`: sobreescribe `loadDiagnoses`, `diagnoses`,
    `isLoading`, `error` e `imageUrlFor`, y registra los `plantId` pedidos.
  - Se monta con
    `ChangeNotifierProvider<DiagnosisProvider>.value(value: fake, child: MaterialApp(home: DiagnosisHistoryScreen(plantId: 7, plantName: 'Echeveria')))`.
  - La fecha esperada se calcula en la prueba con el mismo `DateFormat` y `toLocal()`: no depende
    de la zona de la máquina de CI.
  - Las miniaturas se buscan con
    `find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == ...)`.
  - En `flutter_test` toda petición HTTP de imagen responde con error, así que «si la imagen no
    carga» se prueba con una URL cualquiera y `await tester.pump()` hasta que aparece «Sin foto».
    Si resulta inestable, usar `tester.runAsync`.
- **Frontend, CA-9.**
  - Montar `PlantDetailScreen` con un `PlantProvider` falso (`selectedPlant` fijo, `loadSensorData`
    sin red) y un `AuthProvider` sin sesión, para que no arranque el temporizador de 3 s.
  - El `MaterialApp` de prueba registra una ruta `'/plant-diagnoses'` que guarda los `arguments`.
  - Usar `pump()`, no `pumpAndSettle()`: `AnimatedPlant` tiene animaciones que se repiten.
  - Si el detalle no se puede montar en prueba (p. ej. por `GoogleFonts` o la animación), anotarlo
    y dejar CA-9 como comprobación manual en T8. No se cambia el detalle para hacerlo testeable sin
    pasar por el plan.

## Riesgos y lo que no se puede verificar

- **Fotos sin protección (decisión 7 de la spec).** `/static` se sirve sin sesión
  (`app.mount("/static", ...)` en `main.py`). Las fotos de diagnóstico solo están protegidas por los
  8 caracteres hexadecimales del nombre (32 bits). `static/ultimo_diagnostico.jpg` tiene un nombre
  fijo: cualquiera que alcance el backend ve la última foto de la webcam, incluso en el caso de CA-8.
- **CA-8 deja la foto en `ultimo_diagnostico.jpg`.** El diagnóstico no se guarda en el historial,
  pero el diálogo en vivo sigue escribiendo y mostrando esa foto. Es el comportamiento de hoy y
  queda fuera de alcance.
- **`clima-actual` sigue sin mirar el dueño.** Devuelve el `plant_id` de la planta del ESP8266
  aunque sea de otro usuario. Fuera de alcance.
- **CA-2 deducido, no ejecutado.** Si Pydantic no se comporta como se dedujo, se aplica D3.
- **SQLite frente a PostgreSQL.** Las pruebas corren en SQLite (fechas sin zona). El orden por
  `created_at` y el formato de la fecha en PostgreSQL real no se prueban de forma automática: queda
  para T8. D4 hace que la app lea bien los dos formatos.
- **Webcam y Gemini reales** no se prueban de forma automática. Pedir un diagnóstico real y verlo
  en el historial es parte de T8 (necesita webcam, `GEMINI_API_KEY` y conexión).
- **Diagnóstico del seed.** En una base sembrada, la primera planta tiene un diagnóstico sin foto
  (`image_url` nulo): se verá con «Sin foto» y estado «Buena». No muestra su confianza inventada
  (87.5) porque la pantalla no muestra confianza.
- **Imágenes en web.** `Image.network` en Chrome necesita CORS. El backend tiene
  `allow_origins=["*"]`, pero los archivos de `StaticFiles` montados pueden no llevar esas cabeceras
  según el renderizador de Flutter web. Las fotos de plantas ya usan `Image.network` en
  `my_plants_tab.dart`, así que se espera el mismo comportamiento. Se comprueba a mano en T8.
- **Cobertura.** El umbral de `backend/.coveragerc` no debe bajar. Las pruebas nuevas cubren además
  ramas de `hardware.py` que hoy no tenían prueba.

## Diferencias con lo planeado

- **Sin cambios de comportamiento** respecto de las decisiones del plan.
- **D3 no se aplicó:** las pruebas de CA-2 pasaron desde el principio (el API ya devuelve
  `health_status` en español), así que `backend/app/schemas/recommendation.py` no se tocó.
- **CA-9 quedó con prueba automática:** el detalle de la planta se pudo montar en una prueba de
  widget sin cambiar código de la app, así que no pasó a comprobación manual.
- **Añadido en la pantalla** (`frontend-dev`): un indicador interno `_started` para que no se vea
  por un instante el estado vacío antes de que arranque la primera carga (que ocurre tras el primer
  frame).
- **Pruebas extra fuera de la tabla «Pruebas por criterio»** (`pruebas`): en el provider,
  `fromJson lee los campos en snake_case…`, `con una lista vacía devuelve true…`,
  `al empezar una carga borra el error anterior y notifica` y
  `al terminar la última petición isLoading queda en false aunque una anterior siga abierta`; en la
  pantalla, `pide los diagnósticos de la planta recibida, una sola vez`.
- **Detalles que fijaron las pruebas y la spec no decía:** la fecha de la hoja de detalle usa el
  mismo formato `dd/MM/yyyy HH:mm` que la lista; una `image_url` vacía se trata como sin foto; hay
  una sola imagen de red por tarjeta.
- **Vuelta 1 de corrección (el revisor rechazó la primera entrega):**
  - La ruta `/plant-diagnoses` hacía `arguments as PlantModel` y reventaba sin argumentos; ahora, si
    el argumento no es un `PlantModel`, muestra «Planta no encontrada» sin crear el provider ni pedir
    diagnósticos (D7/D10, que la primera entrega no había cumplido).
  - `DiagnosisProvider` deja de notificar después de `dispose` (cerrar la pantalla mientras carga
    lanzaba «used after being disposed» en debug).
  - La pantalla de historial se alineó con D8 y D9: color por estado con `SolarColors` (Excelente y
    Buena `success`, Regular `warning`, Mala y Crítica `error`, desconocido `textSecondary`), texto
    del detalle como `SelectableText` y miniatura de 64.
  - La fila Info / Regar / Diagnósticos del detalle usa `Flexible` y `FittedBox` para no desbordarse
    a 320 ni a 360 px.
  - El mensaje de log de CA-8 se corrigió para que sea cierto también cuando no hay planta del
    dispositivo.
  - Pruebas agregadas: `frontend/test/diagnosis_route_test.dart` (ruta real montando `SolarGrowApp`),
    `diagnosis_provider_dispose_test.dart`, `diagnosis_history_review_test.dart`,
    `plant_detail_overflow_test.dart`, y tres de regresión en `backend/tests/test_diagnostico_ia.py`
    (diagnóstico nuevo primero con uno anterior; sin `ESP8266_PLANT_ID` y planta más antigua ajena;
    sin ninguna planta de dispositivo).
  - **Fuera de alcance, detectado en esta vuelta:** el detalle de la planta tiene otras cuatro filas
    (barra «Mis Plantas | Tareas» y filas de sensores) que ya se desbordan en `main` a 320 y 360 px
    en `flutter_test`. No se tocaron; la prueba de desborde mide solo la fila de los tres botones.
  - Sin prueba, por no haber forma fiable: que falte `toLocal()` solo se detecta en una máquina que
    no esté en UTC (hallazgo 6); queda para la comprobación manual.
- **Decisiones del plan que la responsable no tomó expresamente** (se siguió la propuesta del
  planificador): las fechas sin zona se leen como UTC solo en `DiagnosisModel`; con CA-8 la foto de
  la webcam sigue quedando en `static/ultimo_diagnostico.jpg` (riesgo de `/static`, fuera de
  alcance).
