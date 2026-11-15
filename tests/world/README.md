# R2: mundo y construcción

Ejecutar desde la raíz del proyecto con Godot 4.7:

```powershell
godot --headless --path . res://tests/world/run_world_tests.tscn
```

El test inyecta `ResourceLedger`, `PowerService` y los servicios R2; no sustituye autoloads. Verifica el layout inicial (32 placas, un túnel nuevo para laboratorio y panel), terreno, límites, escaneo, colocación sin cobro inválido, energía, producción, cultivo sin potencia, investigación, reparación única y reconstrucción de `world.tscn`.

R1 debe añadir `BuildingService`, `GridService`, `ProductionService`, `ResearchService`, `ScanService` y `TunnelNetwork` al arranque real. `BuildingService.initialize_layout` inicializa investigación y cuadrícula. `ProductionService` consume la asignación de energía tras `PowerService.step`. `ResearchService` consume lotes terminados de R3; `BuildingService.request_repair` devuelve `task_id` y horas para que R3 ejecute la tarea. R4 conecta `World.placement_requested` con `BuildingService.place`, y usa `World.focus_target`/`target_selected` para el inspector. `World` no cobra ni pausa.

La plataforma dentro de una zona de aterrizaje y el kit de trajes iniciales siguen sujetos a las decisiones D6 y D3 en `roles/dudas-y-supuestos.md`. El render usa geometría proxy. El proyecto todavía arranca la escena de diagnóstico de R1 hasta que R1 componga `World` con los demás servicios.
