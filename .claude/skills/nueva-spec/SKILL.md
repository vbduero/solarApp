---
name: nueva-spec
description: Crea o completa una spec de Solar-Grow con desarrollo guiado por especificaciones (carpeta specs/NNN-nombre/ con spec.md, plan.md y tasks.md). Úsala cuando se pida especificar, planear o dividir en tareas una funcionalidad antes de programarla.
---

# Nueva spec (SDD) para Solar-Grow

El flujo es **especificación → plan → tareas → código**. Esta skill cubre los tres primeros pasos.
No escribas código de la app mientras la usas.

## 1. Preparar
- Numera la spec con el siguiente número libre de `specs/` (tres dígitos: `001`, `002`…).
- Copia `specs/_plantilla/` a `specs/NNN-nombre-corto/`.
- La rama se llama `feat/NNN-nombre-corto` (o `fix/...`) y sale de `main` actualizado.

## 2. Especificación (`spec.md`)
- Lee primero el código actual: el router, el provider y la pantalla que se van a tocar. Cita los
  archivos reales en «Por qué». No describas de memoria.
- Escribe qué y por qué, nunca cómo: sin nombres de funciones ni de librerías.
- Criterios de aceptación `CA-1`, `CA-2`… en formato «Dado / cuando / entonces». Cada uno debe poder
  comprobarse con una prueba. Incluye siempre:
  - el caso normal;
  - el caso sin datos (planta sin lecturas, lista vacía);
  - el caso de error (API caído, ESP8266 desconectado, recurso de otro usuario).
- Si algo no está claro, escríbelo en «Preguntas abiertas» y **detente**: la persona responde antes
  de planear. No inventes la respuesta.
- La persona aprueba la spec (cambia el estado a `aprobada`) antes del plan.

## 3. Plan (`plan.md`)
- Decisiones técnicas con su motivo, respetando `backend/CLAUDE.md` y `frontend/CLAUDE.md`.
- Tabla de archivos que se tocan. Lo que no esté en la tabla no se modifica; el revisor lo comprueba
  con `git diff --name-only main...HEAD`.
- Tabla «Pruebas por criterio»: cada CA con el nombre de su prueba y su archivo.
- Verifica que cada endpoint, campo JSON o método que menciones existe de verdad (búscalo con Grep).
  Si hay que crearlo, dilo como tarea.
- Si el cambio necesita una columna nueva en una tabla existente, avisa: no hay migraciones.

## 4. Tareas (`tasks.md`)
- Una tarea por paso, con el agente responsable: `pruebas`, `backend-dev`, `frontend-dev`, `revisor`.
- Orden fijo: pruebas que fallan → backend → frontend → revisión → pull request.
- Cada tarea debe caber en un commit con formato Conventional Commits en español.

## 5. Entregar
Devuelve la ruta de la carpeta, la lista de criterios y las preguntas abiertas. No sigas a la
implementación: eso lo decide la persona.
