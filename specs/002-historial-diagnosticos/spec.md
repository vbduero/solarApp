# Spec 002 · Historial de diagnósticos IA

- **Estado:** aprobada
- **Rama:** `feat/002-historial-diagnosticos`
- **Responsable:** Valentina Bermeo

## Qué se construye

Desde el detalle de una planta, la persona abre «Diagnósticos» y ve los diagnósticos de IA que se
han guardado para esa planta, del más reciente al más antiguo, con su fecha, su estado de salud y la
foto que se analizó. Al tocar uno ve el texto completo que devolvió Gemini. Si la planta no tiene
diagnósticos o el servidor falla, la pantalla lo dice en español. Además, un diagnóstico pedido por
una persona deja de guardarse en la planta de otra.

## Por qué

- Hoy la app solo muestra el diagnóstico que se acaba de pedir. El menú lateral de
  `frontend/lib/screens/home/home_screen.dart` («Diagnóstico IA / Cámara En Vivo») abre un diálogo
  (`_abrirDiagnosticoIA`) que llama a `GET /api/hardware/diagnostico-ia`, muestra el resultado y, al
  cerrarlo, se pierde: no hay ninguna pantalla, provider ni modelo Dart que liste diagnósticos
  anteriores (no existe nada de diagnósticos en `frontend/lib/providers/` ni en
  `frontend/lib/models/`).
- El backend ya guarda cada diagnóstico exitoso: `backend/app/routers/hardware.py` llama a
  `save_diagnosis` (`backend/app/services/hardware_service.py`), que crea una fila en `ai_diagnoses`
  (`backend/app/models/recommendation.py`, `AIDiagnosis`) con el texto completo, un estado de salud
  deducido de la sección «ESTADO GENERAL» y una foto propia con nombre único en
  `static/diagnosticos/`. Esto ya tiene pruebas en `backend/tests/test_hardware_service.py`.
- El listado también existe: `GET /api/ai/diagnosis/{plant_id}` (`backend/app/routers/ai.py`) exige
  sesión, comprueba que la planta sea del usuario y devuelve los 10 más recientes. La ruta ya está
  declarada como `aiDiagnosis` en `frontend/lib/config/api_constants.dart`, pero la app no la usa y
  el endpoint **no tiene ninguna prueba** (ningún archivo de `backend/tests/` importa el router `ai`).
- Ese endpoint no comprueba si la planta está activa, a diferencia del detalle de planta
  (`backend/app/routers/plants.py` filtra `is_active == True`): una planta borrada sigue mostrando sus
  diagnósticos. Tampoco desempata cuando dos diagnósticos tienen la misma fecha.
- Los diagnósticos se guardan siempre en la planta del ESP8266 (`get_device_plant`, por
  `ESP8266_PLANT_ID` o la planta activa más antigua), sin comprobar que sea del usuario que pidió el
  diagnóstico. Con más de un usuario, el diagnóstico pedido por uno aparece en el historial de la
  planta de otro.
- Lo que hoy aparece como «Diagnóstico IA» en `frontend/lib/screens/recommendations/recommendations_screen.dart`
  es un texto fijo («Estado general: Bueno (87% confianza)») que no sale de ningún diagnóstico real.
  El único diagnóstico de `backend/seed_data.py` también trae una confianza inventada (87.5) y
  problemas/acciones que Gemini nunca rellena: el flujo real solo guarda texto, estado, foto y fecha.

## Fuera de alcance

- Pedir un diagnóstico nuevo: el diálogo «Diagnóstico IA en Vivo» de la pantalla de inicio, su
  imagen `static/ultimo_diagnostico.jpg` y el prompt a Gemini no cambian. El diálogo sigue sin
  conocer la planta y sigue llamando al API directamente.
- Borrar o editar diagnósticos.
- Paginación o «ver más»: se muestran como máximo los 10 más recientes que ya devuelve el API.
- Guardar diagnósticos fallidos (webcam o Gemini con error): hoy no se guardan y siguen sin guardarse.
- Mostrar `confidence`, `detected_issues` y `suggested_actions`: el flujo real no los rellena.
- Proteger con sesión las imágenes de `/static`: queda como riesgo conocido (decisión 7).
- `GET /api/hardware/clima-actual`, que también usa la planta del ESP8266 sin mirar el dueño: no se
  cambia en esta spec.
- La pantalla «Recomendaciones IA» y sus datos fijos, el endpoint simulado
  `POST /api/ai/request-diagnosis` (responde éxito sin hacer nada) y los textos que aún hablan de
  Raspberry Pi: pertenecen a la limpieza de datos demo (spec 005) o a otra spec.
- Calcular la salud de la planta a partir de los diagnósticos (spec 004), detener el riego (spec 003)
  y el firmware (`esp8266_maceta_inteligente/`).
- Cambiar `backend/seed_data.py`.

## Criterios de aceptación

API (`GET /api/ai/diagnosis/{plant_id}`):

- **CA-1. Listado de la planta.** Dado un usuario con sesión y una planta activa suya con
  diagnósticos, cuando pide `GET /api/ai/diagnosis/{plant_id}`, entonces recibe 200 con solo los
  diagnósticos de esa planta, ordenados del más reciente al más antiguo (si dos tienen la misma
  fecha, primero el de `id` mayor), como máximo 10; cada uno trae `id`, `plant_id`,
  `health_status`, `diagnosis`, `image_url` y `created_at`. (Comportamiento actual salvo el
  desempate: se fija con pruebas.)
- **CA-2. Estado en español.** Dado un diagnóstico guardado con cualquiera de los estados de salud,
  cuando se lista, entonces `health_status` viaja como el valor del enum en español con mayúscula
  inicial (`"Excelente"`, `"Buena"`, `"Regular"`, `"Mala"`, `"Critica"`), no como el nombre interno
  (`"BUENA"`). (Comportamiento actual según el código —el enum `HealthStatus` hereda de `str` y su
  texto es el valor—; no se ha ejecutado: se fija con pruebas.)
- **CA-3. Sin diagnósticos.** Dada una planta activa del usuario sin diagnósticos, cuando pide el
  listado, entonces recibe 200 y una lista vacía.
- **CA-4. Sesión y dueño.** Dado un usuario con sesión, cuando pide el listado de una planta de otro
  usuario o de un id inexistente, entonces recibe 404 «Planta no encontrada» y ningún diagnóstico;
  sin sesión recibe 401. (Comportamiento actual: se fija con pruebas.)
- **CA-5. Planta borrada.** Dada una planta del usuario borrada (inactiva) que tiene diagnósticos,
  cuando pide su listado, entonces recibe 404 «Planta no encontrada», igual que en el detalle de
  planta.

Guardado (`GET /api/hardware/diagnostico-ia`, sin webcam, Gemini ni ESP8266 reales en las pruebas):

- **CA-6. Diagnóstico nuevo en el historial.** Dado que la planta del ESP8266 es del usuario, cuando
  pide un diagnóstico y Gemini responde, entonces queda guardado en esa planta con su propia foto y
  aparece primero al listar los diagnósticos de la planta. (Comportamiento actual: se fija con
  pruebas.)
- **CA-7. Fallos no dejan rastro.** Dado que la webcam falla, o que Gemini falla con todos los
  modelos, cuando el usuario pide un diagnóstico, entonces recibe el error de hoy (500 o 429 con
  mensaje en español) y no se guarda ningún diagnóstico nuevo. (Comportamiento actual: se fija con
  pruebas.)
- **CA-8. Planta del ESP8266 de otro usuario.** Dado que la planta del ESP8266 pertenece a otro
  usuario, cuando un usuario pide un diagnóstico y Gemini responde, entonces recibe el diagnóstico
  como hoy pero no se guarda en el historial de esa planta, y la respuesta trae `diagnosis_id` y
  `plant_id` vacíos.

Pantalla (app):

- **CA-9. Acceso desde el detalle.** Dado el detalle de una planta, cuando el usuario toca el botón
  «Diagnósticos» (junto a «Info» y «Regar»), entonces se abre el historial de diagnósticos de esa
  planta, con su nombre visible.
- **CA-10. Lista.** Dado que el API devuelve diagnósticos, cuando termina la carga, entonces se ve un
  elemento por diagnóstico, del más reciente al más antiguo, con la fecha y hora en formato
  `dd/MM/yyyy HH:mm` en la hora local del dispositivo, el estado de salud («Excelente», «Buena»,
  «Regular», «Mala» o «Crítica») y una miniatura de su propia foto. No se muestra ningún porcentaje
  de confianza.
- **CA-11. Detalle de un diagnóstico.** Dado el historial con diagnósticos, cuando el usuario toca
  uno, entonces ve el texto completo del diagnóstico, su fecha, su estado y la foto en grande. Si el
  diagnóstico no tiene texto, se muestra «Sin descripción».
- **CA-12. Sin foto.** Dado un diagnóstico sin `image_url`, o cuya imagen no se puede cargar, cuando
  se muestra en la lista o en el detalle, entonces aparece el texto «Sin foto» en lugar de la imagen,
  y nunca la imagen de otro diagnóstico ni `ultimo_diagnostico.jpg`.
- **CA-13. Sin diagnósticos.** Dado que el API devuelve una lista vacía, cuando termina la carga,
  entonces se muestra «Esta planta aún no tiene diagnósticos.» y ningún elemento de lista.
- **CA-14. Error del API.** Dado que el servidor no responde o responde con error, cuando termina la
  carga, entonces se muestra «No se pudieron cargar los diagnósticos.» con un botón «Reintentar» y no
  se muestran diagnósticos inventados ni de otra planta. Al tocar «Reintentar» se vuelve a pedir el
  listado de la misma planta; si responde bien, se ve la lista.
- **CA-15. Carga.** Dado que el usuario abre el historial, cuando la respuesta aún no llega, entonces
  se ve un indicador de carga y ningún diagnóstico de una planta abierta antes; si llegan respuestas
  de peticiones anteriores (por ejemplo, tras tocar «Reintentar» varias veces), se muestra la de la
  última petición.

## Preguntas abiertas

- Ninguna. La responsable (Valentina Bermeo) aprobó la spec el 2026-11-11 con estas decisiones:
  1. **Acceso:** botón «Diagnósticos» en el detalle de la planta, junto a «Info» y «Regar» (CA-9).
  2. **Cantidad:** los 10 más recientes, sin paginación (CA-1, CA-10).
  3. **Foto:** miniatura en la lista y foto grande en el detalle (CA-10 a CA-12).
  4. **Contenido:** fecha, estado y foto en la lista; texto completo en el detalle; sin confianza ni
     problemas/acciones; «Crítica» con tilde en pantalla aunque el JSON lleve `"Critica"` (CA-2,
     CA-10, CA-11).
  5. **Planta del ESP8266 de otro usuario:** se corrige en esta spec; el diagnóstico se devuelve pero
     no se guarda (CA-8).
  6. **Borrar diagnósticos:** no.
  7. **Fotos de `/static`:** no se protegen en esta spec; queda anotado como riesgo en el plan.
  8. **Diagnósticos fallidos:** siguen sin guardarse (CA-7). Un diagnóstico en el que Gemini responde
     pero la foto no muestra una planta se guarda como hoy, con estado «Regular».
  9. **Planta borrada:** 404 (CA-5).
