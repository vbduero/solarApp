---
paths:
  - "backend/app/routers/**/*.py"
---

# Reglas para routers del backend

- Todo endpoint lleva `current_user: User = Depends(get_current_user)`. La única excepción es
  `POST /api/sensors/`, que usa la cabecera `X-Device-Key`.
- Toda consulta filtra por el dueño (`Model.user_id == current_user.id`). Un recurso de otro usuario
  responde 404, no 403.
- Los datos de entrada se validan en el schema Pydantic (`Field(ge=..., le=...)`), no con `if` dentro
  del endpoint.
- Si un comando al ESP8266 no se pudo enviar, responde 503. Nunca devuelvas éxito sin haberlo enviado.
- La lógica que no sea leer la petición y armar la respuesta va en `app/services/`, donde se puede
  probar sin hardware.
- Mensajes de error (`detail`) en español.
