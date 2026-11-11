---
paths:
  - "specs/**/*.md"
---

# Reglas para specs

- Una spec vive en `specs/NNN-nombre/` con `spec.md`, `plan.md`, `tasks.md` y `revision.md`.
- `spec.md` dice qué y por qué, nunca cómo. Los criterios de aceptación se numeran `CA-1`, `CA-2`… y
  cada uno se puede comprobar con una prueba automática o con un paso manual descrito.
- `plan.md` dice cómo: decisiones técnicas, archivos que se tocan y qué prueba cubre cada criterio.
- `tasks.md` es una lista de casillas. Una tarea se marca `[x]` solo cuando su prueba pasa.
- Si al implementar cambia algo de lo especificado, se corrige la spec y se anota en la sección
  «Diferencias con lo planeado» del plan. No se dejan diferencias sin explicar.
