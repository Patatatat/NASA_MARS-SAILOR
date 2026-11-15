# Pruebas adversariales

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
