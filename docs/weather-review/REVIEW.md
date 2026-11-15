# Eventos ambientales reconocibles en el mapa

## WEATHER-001 — Eventos activos sin representación visual

**Reproducción anterior:** activar Tormenta de polvo o Llamarada solar desde Demo,
cerrar el aviso con Entendido y observar el mapa. Los servicios aplicaban las
consecuencias, pero World no consultaba los eventos para representarlos.

**Comportamiento nuevo:**

- Tormenta de polvo: bruma 3D, sol atenuado, velo ámbar y arena arrastrada por el viento.
- Llamarada solar: iluminación cálida, resplandor y ondas amplias de radiación.
  Son una ayuda visual estilizada, sin destellos rápidos.
- Los avisos previos muestran una etiqueta de previsión; el efecto completo comienza
  al activarse el evento. Una tormenta activa y una llamarada anunciada se distinguen.
- Las etiquetas indican el tipo y fase en español o inglés, además del color.
- La capa queda recortada al espacio del mapa, detrás del HUD, sin interceptar
  clics. Se adapta al abrir paneles, cambiar resolución y volver desde el menú.
- Los efectos se retiran al finalizar o expirar el evento y se reconstruyen al
  cargar. Los eventos aleatorios se reconocen por su tipo, aunque usen IDs distintos.

La representación no cambia probabilidades, daño, duración, energía ni reglas de
los eventos. Tampoco consume RNG de la simulación. La animación se congela en pausa.
La iluminación conserva la diferencia entre día y noche. Cada World mantiene una
copia independiente de su Environment para evitar efectos residuales entre instancias.

## Verificación

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_weather_visuals.tscn weather-result.json
```

La prueba gráfica utiliza el cliente MCP local con guardados aislados y servicios
reales. Verifica avisos programados, activación, finalización manual y natural,
guardar/cargar, animación/pausa, ausencia de cambios en el estado/RNG, clic real sobre
un edificio durante la tormenta, traducción, alias aleatorios, retorno al menú y
límites del mapa en 960×540, 1920×1080 y 3440×1440.

Las capturas cierran los avisos existentes mediante su acción Entendido, para poder
revisar el mapa despejado. La primera revisión detectó y corrigió una etiqueta que
crecía demasiado; su altura compacta tiene una comprobación de regresión.

Resultado final: **37 comprobaciones de clima y 23 regresiones gráficas existentes,
todas correctas**. Estas últimas comprueban investigación y ciclo día/noche;
su resultado se conserva en `daylight-regression.json`.

Resultados de clima: `results.json` y `engine.log`, sin errores de ejecución.
Capturas reales del motor:
`clear.png`, `warning.png`, `dust.png`, `flare.png` y `flare-night.png`.
La revisión visual se realizó con el renderizador GL Compatibility en Windows.
No se ha hecho una medición de FPS ni una certificación de exportaciones.
