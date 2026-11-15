# Integración de R1

El proyecto Godot está en la raíz del workspace. `scenes/integration/main.tscn` arranca los servicios de R1 y muestra un mensaje de diagnóstico en la consola. La partida no se inicia hasta conectar los servicios reales de R2 y R3. Los dobles de `tests/core/run_core_tests.gd` se usan únicamente en pruebas.

## Conectar servicios

En `scenes/integration/main.gd`, inyectar en `GameSession.configure` los servicios `crew`, `building`, `grid`, `production`, `event`, `rocket` y `research` al estar disponibles. Conectar `PowerService.building_service` y `.grid_service`, y `LifeSupportService.crew_service` y `.tunnel_network`. `GameSession.start_new` requiere cuatro IDs de perfil (se pueden repetir), `CrewService.create_roster` y `BuildingService.initialize_layout`, ambos con `GameContracts.ValidationResult`.

`BuildingService.get_power_inputs()` devuelve `generators` con `{building_id, output, enabled}`, `consumers` con `{building_id, demand, enabled, priority}`, y `battery_capacity`, `battery_charge_rate`, `battery_discharge_rate`. Las magnitudes son potencia por sol; el coordinador convierte `delta_seconds / 60`. `GridService.get_energy_links()` devuelve una entrada `{building_id, connected}` por edificio conectado. `TunnelNetwork.get_snapshot()` ofrece `oxygen_leak_per_sol`. El daño a tripulación corresponde a R3, que lee `LifeSupportService.get_crew_supply(id)` después del consumo.

El orden de `SimulationRunner` es evento → red → potencia → producción → soporte vital → tripulación → investigación → derrota. Al inicio de cada sol aplica calendario y llegada, y registra `started_sol` en el estado antes de emitir la señal. Al cierre calcula autonomía con producción local útil registrada como `production_*`, excluye cargo, actualiza apoyo y comprueba victoria. Los productores deben usar `ResourceLedger.add(..., "production_...")` y la carga `add(..., "cargo_...")` para que el informe clasifique bien las fuentes. Los gastos usan `spend` y una razón específica.

Para que un guardado reconstruya cachés, añadir cada servicio con `rebuild_from_state()` a `SaveService.configure`, antes de exponer la carga a la interfaz. El estado persistido no contiene nodos ni referencias. R2/R3 son responsables de sus particiones y de que sus comandos sean idempotentes con IDs estables.

## Verificación actual

Ejecutar con Godot 4.7.x:

```powershell
godot --headless --path . res://tests/core/run_core_tests.tscn
godot --headless --path . --quit-after 1
```

El primer comando prueba gasto atómico, noche/batería, fuga y escasez, guardado/restauración, x1/x4, pausa, avance administrativo, cuatro llegadas, 42 soles, victoria y derrota con dobles controlados. Falta la prueba de campaña completa con servicios reales de R2/R3, recursos de R4 y exportaciones Web/Windows. No hay plantillas de exportación instaladas en este equipo. La demo de diez minutos también depende de esas secciones.
