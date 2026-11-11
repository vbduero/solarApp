---
paths:
  - "frontend/lib/screens/**/*.dart"
  - "frontend/lib/widgets/**/*.dart"
---

# Reglas para pantallas y widgets

- Las pantallas no llaman a `ApiService` ni a `http`: usan un provider.
- No muestres datos inventados como si fueran reales. Si no hay datos, muestra un estado vacío o de
  error en español; si son de demostración, dilo en pantalla.
- Un fallo del API se le muestra al usuario (`SnackBar` o mensaje en pantalla); no se oculta.
- Después de cada `await`, comprueba `mounted` antes de usar `context`.
- Colores y estilos solo desde `SolarColors` / `SolarTheme`.
