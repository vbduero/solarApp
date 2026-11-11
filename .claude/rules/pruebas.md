---
paths:
  - "backend/tests/**/*.py"
  - "frontend/test/**/*.dart"
---

# Reglas para archivos de prueba

- Cada prueba verifica un criterio de aceptación de una spec o un caso límite concreto. El nombre
  dice qué comportamiento comprueba, en español: `test_riego_rechaza_duracion_fuera_de_rango`.
- Una prueba debe poder fallar: si al romper a propósito el código que cubre sigue pasando, no sirve.
  No afirmes lo mismo que acabas de preparar (`x = 5; assert x == 5`).
- No se usa nada real: ni PostgreSQL, ni el ESP8266, ni la webcam, ni Gemini, ni HTTP.
  - Backend: SQLite en memoria de `tests/conftest.py`; el hardware se reemplaza con `monkeypatch`.
  - Frontend: un provider falso que extiende el real y sobreescribe el método de red.
- No cambies una prueba existente para que pase un cambio de código, salvo que la spec cambie el
  comportamiento esperado; en ese caso dilo en el plan.
- No uses `skip`, `xfail` ni comentes pruebas para dejar la CI en verde.
