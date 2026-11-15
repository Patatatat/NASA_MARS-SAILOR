# Pruebas adversariales

## Inicio para principiantes y robot guía

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_beginner_routes.tscn beginner-routes-result.json
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_tutorial_flow.tscn tutorial-result.json
```

Compara cuatro recorridos y prueba los 19 objetivos con controles reales,
guardado/carga, recuperación y layout del robot.
[Informe y evidencias](../../docs/tutorial-review/REVIEW.md).

## Modelos y túneles

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_model_tests.tscn models-result.json
```

Prueba tamaño y colocación de los 11 edificios nuevos, los 16 patrones de túneles,
conectividad, daño, aislamiento y reparación. Informe, hashes y capturas:
[docs/models-review/REVIEW.md](../../docs/models-review/REVIEW.md).

## Música y efectos

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_audio_tests.tscn audio-result.json
```

Revisa temas por pantalla, alternancia real de las pistas de gameplay, eventos,
efectos y volumen con captura de la mezcla. Informe:
[docs/audio-review/REVIEW.md](../../docs/audio-review/REVIEW.md).

## Efectos ambientales del mapa

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_weather_visuals.tscn weather-result.json
```

Comprueba tormenta, llamarada, aviso/activación/fin, guardado/carga, pausa,
selección del mapa y adaptación de los efectos a la resolución. Informe y capturas:
[docs/weather-review/REVIEW.md](../../docs/weather-review/REVIEW.md).

Registro de casos, pasos de reproducción, causas y correcciones:
`docs/qa/BUGS.md`. Los resultados y capturas revisables están junto al registro.

`run_break_tests.tscn` comprueba regresiones dirigidas; `run_stress_tests.tscn`
mezcla 1.000 acciones con semillas fijas e intenta importar guardados dañados.
Ambas usan servicios reales y requieren los autoloads del proyecto.

`run_visual_regressions.tscn` comprueba progreso parcial, foco, guardado/carga,
cancelación, desbloqueo único y ciclo solar. Para ejecutarla con el cliente MCP:

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_visual_regressions.tscn qa-visual-result.json
```

El cliente aísla los guardados bajo `.test_playable/mcp-<timestamp>`. Si ejecutas
las escenas headless directamente, configura antes APPDATA en una carpeta de
pruebas: los escenarios crean y guardan misiones.
