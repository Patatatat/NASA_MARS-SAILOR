# R4 — Interfaz y contenido

> Estado actual: Main ya integra los servicios y las pantallas. Las notas de
> integración de abajo documentan la entrega original. La revisión actual está
> en `docs/ui-review/REVIEW.md`; incluye la auditoría gráfica multirresolución.

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/ui/run_layout_audit.tscn ui-audit-result.json
```

El resultado y las capturas se guardan en una carpeta aislada bajo
`.test_playable/mcp-<timestamp>`. La prueba incluye 960×540, 1280×720,
1920×1080, 2560×1440, 3840×2160 y 3440×1440; EN/ES y escala ampliada.

## Ejecutar

Desde la raíz del proyecto:

```powershell
& 'C:\Users\Zilean\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . res://tests/ui/run_ui_tests.tscn
```

La prueba crea una sesión real con los servicios R1–R3, abre las siete pestañas y verifica la repetición de perfil, paridad EN/ES, aviso crítico con x4, filtros, retraducción y restauración repetida. Godot emite en este entorno un error del almacén de certificados y avisos de objetos al salir de las pruebas; el proceso retorna 0 si las aserciones pasan.

## Integración que corresponde a R1

- Registrar `LocalizationDB`, `NasaDataCatalog` y `SettingsService` en `project.godot` apuntando a los tres scripts de `autoload/` de R4. Registrar `LocalizationDB` antes de `SettingsService`.
- Montar `res://scenes/ui/main_menu.tscn` y `res://scenes/ui/hud.tscn` en Main. Conectar `MainMenu.start_requested` con `GameSession.start_new(ids, seed)` y mostrar el error devuelto si falla. Conectar `continue_requested` con SaveService; el menú no escribe GameState ni abre la partida por su cuenta.
- Crear un solo `DialogueService`, llamar `configure(event_service, building_service)`, pasarlo a `MissionHud.configure({...}, world_node)` junto a `ledger`, `power`, `life_support`, `crew`, `building`, `research`, `scan`, `rocket`, `event`, `report`. Invocar `shutdown()` al destruir el servicio. Conectar `world.target_selected` y `placement_requested` queda a cargo de HUD cuando recibe World.
- Tras `GameSession.start_new`, reponer ajustes mediante `SettingsService.apply_settings(SettingsService.get_settings())` si Main necesita conservar las preferencias previas a la nueva sesión. En carga, `state_restored` reconstruye las vistas y el idioma.
- El contrato C5 proponía `LocalizationDB.tr(key, params)`. En Godot 4.7 `Object.tr` ya existe con segunda firma `StringName`, por lo que un método de igual nombre con `Dictionary` no compila. La API concreta es `translate_key(key, params)`; actualizar C5 al integrar.

## Datos científicos

`data/nasa/sources.json` contiene tres fuentes verificadas y la llamarada archivada `2024-05-10T06:27:00-FLR-001`. El [registro de NASA CCMC](https://kauai.ccmc.gsfc.nasa.gov/CMEscoreboard/prediction/detail/3177) identifica la llamarada X3.9 y el pico a las 06:54 UTC del 10 de mayo de 2024. [NASA OSDR RadLab](https://visualization.osdr.nasa.gov/radlab/gui/overview) describe su telemetría de radiación; [Mars Trek](https://trek.nasa.gov/mars/) es la cartografía de referencia. La llamarada archivada aparece solo como contexto en el códice: EventService no declara que su evento simulado derive de esa observación, y el daño pertenece al balance del juego.

## Pendiente tras este rol

La escena principal R1 aún es diagnóstica y no monta el menú/HUD. Tampoco existe una comprobación de exportación Web/Windows o un ensayo visual de 1280×720 y 960×540. El UI usa señales y snapshots, pero Main debe ofrecer los servicios reales para que el juego sea navegable desde el arranque. No se alteró `project.godot`, Main, World ni reglas de simulación por propiedad exclusiva.
