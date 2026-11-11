---
name: revisar-cambios
description: Revisa el código de una spec de Solar-Grow antes del pull request y deja el informe en specs/NNN-nombre/revision.md. Úsala cuando se pida revisar una rama, una spec implementada o código escrito por la IA.
---

# Revisar los cambios de una spec

Quien revisa no es quien escribió el código. No corrijas nada: informa.

## 1. Reunir
```powershell
git diff --name-only main...HEAD
git diff main...HEAD
```
Lee `spec.md`, `plan.md` y `tasks.md` de la spec.

## 2. Ejecutar (no confíes en lo que diga el resumen de otro agente)
```powershell
cd backend; .\venv\Scripts\python.exe -m pytest -q --cov --cov-config=.coveragerc
cd ..\frontend; flutter analyze --no-fatal-infos --no-fatal-warnings; flutter test
```
Copia al informe el resultado real: número de pruebas, cobertura total, errores.

## 3. Comprobar, en este orden
1. **Alcance.** Todos los archivos cambiados están en la tabla del plan. Ninguno de: `.env`,
   `backend/venv/`, `frontend/build/`, imágenes de `backend/static/`, `database/init.sql`,
   `backend/seed_data.py`, `baseUrl` / `webBaseUrl`, `SECRET_KEY`, archivos generados de Flutter.
2. **Criterios.** Cada `CA-n` tiene al menos una prueba que lo nombra o lo cubre claramente.
3. **Pruebas que no prueban.** Busca pruebas sin `assert` / `expect`, que afirman lo que acaban de
   preparar, que solo comprueban que «no lanza error» o que simulan justo la función que dicen probar.
   Para la más importante, di qué línea del código habría que romper para que falle.
4. **Cosas inventadas.** Cada endpoint, campo JSON, método o paquete usado existe: compara la ruta en
   el router, el nombre del campo en el schema Pydantic y el `fromJson` del modelo Dart.
5. **Contrato backend ↔ frontend.** Rutas en `api_constants.dart`, `snake_case` en el JSON, enums en
   español tal cual.
6. **Seguridad.** Endpoint con `get_current_user`, consultas filtradas por dueño, entradas con
   límites, 503 real si el ESP8266 no recibió el comando.
7. **Datos falsos.** La pantalla no muestra valores fijos como si fueran lecturas reales ni oculta un
   error del API.
8. **Tareas.** Lo marcado `[x]` en `tasks.md` está hecho de verdad.

## 4. Informe
Escribe `specs/NNN-nombre/revision.md` con la plantilla de `specs/_plantilla/revision.md`:
- gravedad **alta** (bloquea el PR), **media** o **baja** por observación, con archivo y línea;
- deja vacías las columnas «Decisión del equipo» y «Motivo»: las llena una persona;
- termina con lo que no pudiste comprobar (hardware real, webcam, Gemini, aspecto visual).

Veredicto en la primera línea de tu respuesta: `APROBADA`, `APROBADA CON OBSERVACIONES` o
`RECHAZADA` (si hay alguna observación alta o una comprobación del paso 2 falla).
