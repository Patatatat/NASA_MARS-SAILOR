# R2 — Mundo y construcción

## Misión y alcance

Una persona y su agente construyen mundo, cámara, colocación, edificios, red, producción, investigación, escaneo y presentación 3D. Godot 4.7, 24 h, Web/Windows; estilo low-poly cel-shaded legible desde arriba. Reutilización del proyecto raíz y GDScript son supuestos técnicos. Fuentes: handoff §§1–3,5–6 y guía «Autoridad», «Contratos» y «HUD».

Área inicial 32×32, límite 256×256, revelado contiguo 8×8. Mina requiere mineral e ISRU acuífero. Proximidad energética tres tiles; exclusión reactor ocho. Reactor inicial es excepción de alimentación global. Tamaños exactos en handoff §2/balance. No sistema de decisiones: acciones en inspector/paneles, peligros y consecuencias permanecen.

## Propiedad exclusiva

- res://domain/buildings/{building_definition,building_service,building_status,building_log_entry,grid_service,tunnel_network,production_service}.gd y auxiliares.
- res://domain/research/research_service.gd y exploration/scan_service.gd y auxiliares.
- res://scenes/world/{world,camera_rig,placement_preview}.tscn y scripts; scenes/buildings/**, scenes/crew/astronaut.tscn, scenes/rockets/rocket.tscn y scripts visuales.
- res://assets/world/**: terreno, túnel, Base, ISRU, invernadero, laboratorio, panel, batería, mina, refinería, impresora, reactor, plataforma, cohete, astronauta; modelos/materiales/texturas/FX/.tres.
- res://data/world/initial_layout.json y datos de terreno; res://tests/world/**.

Las vistas de astronautas/cohetes te pertenecen, su lógica pertenece R3. Balance es R1; costes/recetas/tiempos se solicitan a R1. UI es R4; no colocar lógica UI en World. Propietario único por cada escena/material, sin ediciones simultáneas.

## Tareas por fase

| Fase/tarea | Entradas | Salida | Terminado cuando |
| --- | --- | --- | --- |
| 0–2: terreno/cámara | Tamaños/config, mock estado | Grid, picking, cámara pan/zoom, proxies | Seleccionar tile en 32×32 sin poblar todo 256×256 |
| 0–2: layout y presupuesto | Kit actual y tutorial | Layout válido y coste de conexiones | ISRU válido, reactor fuera de radio, ruta laboratorio/panel cuantificada |
| 2–6: colocación | PlacementRequest, ledger R1 | Validación/previsualización/alta | Fuera de mapa, solapamiento y terreno inválido no cobran |
| 2–6: red/producción | Conexiones y EnergySnapshot | Base/ISRU/invernadero/túneles funcionales | Sin potencia no producen; plantas cambian de estado tras gracia |
| 6–11: economía | Config y trabajo R3 | Mina/refinería/impresora, recetas | Cada conversión cobra insumos una vez; no produce sin condiciones |
| 6–11: research/scan | Trabajo, tecnología, energía/research | Desbloqueos y sector nuevo | Coste previo; fallo no consume; sectores repetidos/fuera de límite rechazados |
| 11–16: daño/reparación | Evento R3, tareas/tiempo | Brecha, aislamiento, soldadura, repuestos | Fuga informada a R1, reparación requiere trabajo; soldadura deja fragilidad |
| 11–16: reactor/landing | Núcleos, tareas, zona R3 | Reposición manual, plataforma y zona | Combustible no infinito; reservas respetan ocupación/regla confirmada |
| 16–20: visuales/bordes | Estado real | Daño, polvo, radiación, apagado, cultivos | Cada estado distinguible con señal adicional al color; proxies aceptables |
| 20–24: fixes | Pruebas integración | Sección estable en export | Cámara/picking funcionan en Web/Windows, sin materiales faltantes |

## Contratos expuestos y consumidos

Expón BuildingService de la guía: validate_placement/place/remove/get_status/get_log/set_storm_protection/set_enabled. PlacementRequest = building_type/origin/rotation_quarters; PlacementResult incluye validación y cells/required_connections. BuildingStatus = ID/tipo/celdas/producción/demanda/potencia/health/condition/modifiers/warnings/next_consequence_keys. get_all_statuses y get_power_inputs entregan copias de lectura a R1.

GridService.get_energy_links da conexiones; validate_zone/reserve_zone/release_zone sirven a R3 con owner_id. TunnelNetwork.get_snapshot da componentes y fugas: R1 descuenta O2, tú no lo descuentas otra vez. ProductionService mantiene plantas, recetas y combustible; PowerService de R1 mantiene energía almacenada/asignada.

Expón validate_action/request_repair/apply_damage/apply_task_result. Tareas tienen task_id,target_id,work_hours/state; R3 ejecuta trabajo, tú aplicas resultado una vez. Investigación: get_snapshot/validate_research/start_research; consume_completed_work de R3 entrega lotes que no se pueden reutilizar. ScanService.validate_scan/scan valida sector, investigación y energía antes de cobrar atómicamente. Costes y errores de dominio devuelven ValidationResult (ok/error_code/message_key/params/costs/warnings).

Consume ledger can_afford/spend/add, PowerService.is_powered/get_snapshot/spend_stored_energy, CrewService.issue_urgent_order y lotes de trabajo, EventService.get_snapshot. Mundo emite target_selected/placement_requested; expone focus_target(target_id) -> bool a UI con referencia inyectada por R1. No persistir NodePath. Detalle ampliado: contratos C0/C2/C3/C7.

## Dependencias y stubs

H0 usa ledger/potencia mock y tarea completada controlable en tests/world/stubs; H1 conecta R1 real. H2 conecta trabajo R3 y paneles R4. Emite building_changed/building_log_added/research_changed mediante SignalBus de R1. World reconstruye nodos idempotentes al state_restored. Renderiza estados de R3, nunca determina muerte/dosis/llegadas por animación.

Kit inicial actualizado: 32 placas cubren laboratorio 16 + panel 10 + hasta seis túneles nuevos. Diseña y verifica una ruta inicial con T <= 6 y conexiones de los edificios iniciales preinstaladas; no descontar su construcción del inventario disponible. Debe permitir laboratorio y panel antes del cohete del sol 7. La batería se construye después, sin prometer que este presupuesto también la cubre. Si el layout excede seis túneles, corrígelo o informa del déficit a R1 antes de integrarlo.

## Límites

No editar project.godot, bus, main/integration, balance, HUD, perfiles ni servicios R1/R3/R4. Solicita inputs/capas a R1: cámara, selección/cancelación, terrain_pick/building_pick/crew_pick. UI consume primero el input; mundo ignora eventos manejados. Sin costos en escenas ni animaciones. Sin mapa completo activo ni arte avanzado que bloquee loops.

## Checklist y aceptación

- [ ] Archivos snake_case, class_name PascalCase, APIs tipadas y JSON sin prosa visible.
- [ ] Colocación inválida no consume; efectos/costos revalidados al ejecutar.
- [ ] Todas las piezas del inventario tienen proxy y estado visual funcional.
- [ ] Pruebas de límites 256×256, sectores 8×8, terreno, proximidad y radio según métrica acordada.
- [ ] Test sin potencia/cultivo muerto, recetas sin insumos, batería/reactor mediante R1.
- [ ] Test brecha/aislar/soldar/repuestos y aplicación única de tarea.
- [ ] Mundo restaura sin duplicados; selección se limpia si objetivo ya no existe.
- [ ] Ninguna acción abre un sistema de decisiones ni fuerza pausa/velocidad.

Carga alta: entregar proxies modulares y reglas antes de pulir materiales. Minijuego de soldadura y animación avanzada son primeros cortes autorizados por handoff.
