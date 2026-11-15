# Contratos de integración

R1 mantiene este documento y tipos comunes; cada servicio pertenece al rol indicado. Origen: guía «Autoridad», «Contratos públicos mínimos» y «Secuencia determinista». Son especificaciones, no código de producción. Cambios incompatibles requieren actualizar guía, este documento y archivos de consumidores antes de integrar.

## C0. Tipos, IDs y unidades

R1 mantiene res://domain/core/contracts.gd con ValidationResult, PlacementRequest, PlacementResult, EnergySnapshot y tipos de frontera. R2 mantiene BuildingDefinition, BuildingStatus, BuildingLogEntry en domain/buildings; R3 TaskOrder, CrewStatus, EventState, RocketPlan en sus carpetas; R4 DialogueEntry/ScienceCard en domain/dialogue y autoload/nasa_data_catalog.gd. Un archivo por tipo si el lenguaje lo requiere, siempre bajo el propietario indicado.

| Tipo | Campos mínimos |
| --- | --- |
| ValidationResult | ok: bool, error_code/message_key: StringName, params/costs: Dictionary, warnings: Array[StringName] |
| PlacementRequest | building_type: StringName, origin: Vector2i, rotation_quarters: int |
| PlacementResult | ValidationResult más cells: Array[Vector2i], required_connections: Array[StringName] |
| EnergySnapshot | generation/demand/stored/capacity: float, by_building: Dictionary (allocated/demand/powered/priority) |
| BuildingDefinition | type_id, footprint, cost, connection_rule, terrain_rule, power_demand, production_recipe, visual_id; desde datos |
| BuildingStatus | building_id/type, cells, production/demand, powered/enabled, health, condition, modifiers, warnings, next_consequence_keys |
| BuildingLogEntry | id, kind, severity, message_key, params, sol, reason_id |
| TaskOrder | id, crew_id, category, target_id, task_type, required_hours, completed_hours, state, reason_id |
| CrewStatus | id/profile_id, alive, health, morale, fatigue, dose, shelter, task_id, priorities, forbidden_categories |
| EventState | id/type, phase (warning/active/ended), start/end sol, source_id opcional, target_ids, modifiers |
| RocketPlan | id, arrival_sol, manifest, mass_limit, confirmed, zone, landed, cargo_transferred, disposition (available/salvaged/exchanged) |
| DialogueEntry | Campos exactos de guía «HUD, avisos y edificios» |
| ScienceCard | id, source_id, title_key, body_key, model_limit_key |

IDs estables snake_case; IDs de instancia únicos aun repitiendo perfil. En JSON, Vector2i/Rect2i se convierten en arrays/diccionarios de enteros. Consultas devuelven copias de lectura. Propuesta de unidades pendiente: potencia P, energía P·sol; convertir delta_seconds/60 para energía y consumibles por sol. Trabajo en horas de sol, con horas_por_sol explícitas en balance; no inferir 24 horas reales a partir de los 60 segundos de juego. Costes instantáneos de escaneo usan energía almacenada.

## C1. Arranque, reloj y persistencia — R1 → todos

GameSession.start_new(profile_ids: Array[StringName], seed: int) -> ValidationResult valida exactamente cuatro, llama CrewService.create_roster, BuildingService.initialize_layout y carga reservas/config una vez. GameSession es dueño de victoria/derrota; servicios reportan hechos. Interface UI de R4 llama start_new, set_speed y set_paused; eventos/diálogo jamás controlan el reloj.

Cada servicio de simulación expone step(delta_seconds: float) -> void y rebuild_from_state() -> void. Solo SimulationRunner llama step, en el orden de la guía. R1 acuerda la lista concreta de participantes en H0; no conectar también tick a esas reglas. Servicios con cierre/inicio exponen on_sol_started(sol: int) y on_sol_ended(sol: int) llamados por coordinador una vez.

SaveService restaura estado validado y cachés antes de state_restored. Admin usa advance_to_sol y comandos EventService/BuildingService/RocketService; no importaciones arbitrarias desde UI. Stub: reloj detenido, estado mínimo y cuatro perfiles; prueba: restaurar dos veces produce las mismas vistas y una única carga de cohete.

## C2. Recursos, potencia y supervivencia — R1 ↔ R2/R3

ResourceLedger es único escritor de cantidades; spend falla sin cambio si no alcanza. R2 entrega BuildingService.get_all_statuses() -> Array[BuildingStatus] y TunnelNetwork.get_snapshot() -> Dictionary con componentes/links/fugas; R1 produce EnergySnapshot. R2 recibe is_powered y ejecuta producción/consumo industrial. R3 entrega get_snapshot de vivos, ubicación/refugio y necesidades; LifeSupportService consume oxígeno/agua/comida una sola vez y publica deficiencias por astronauta mediante get_crew_supply(crew_id: StringName) -> Dictionary. CrewService aplica salud/agotamiento; no descuenta recursos por segunda vez.

ProductionService produce ISRU/cultivos/mina/refinería/impresora y lleva combustible; PowerService calcula generación usando estado del reactor, paneles/tormenta y red. LifeSupportService computa autonomía solo de producción local útil O2/agua/comida y consumo, sin cargo ni chips/núcleos. ResourceLedger distingue reason de producción, cargo, gasto y fuga. Evitar contar producción que desborda capacidad como útil si existe límite de almacenamiento.

R2 implementa GridService.get_energy_links() -> Array[Dictionary]; R1 mantiene balances/asignación de energía. Red/presión física pertenece R2, pérdida contable de O2 R1. PowerService ofrece validate_energy_spend(amount: float) -> ValidationResult además del comando de gasto. Stub: snapshots de base/ISRU/invernadero/reactor y cuatro tripulantes; prueba: x1/x4 mismos balances, apagado sin producción, fuga cobrada una sola vez.

## C3. Mundo, trabajo y producción — R2 ↔ R3/R4

R2 expone APIs de BuildingService de la guía y:

- validate_action(building_id: StringName, action: StringName, args: Dictionary) -> ValidationResult.
- request_repair(building_id: StringName, mode: StringName, crew_id: StringName) -> ValidationResult; mode seal/weld/spare_parts.
- apply_damage(building_id: StringName, amount: float, reason: StringName) -> void.
- apply_task_result(task_id: StringName, target_id: StringName, result: Dictionary) -> ValidationResult; deduplica task_id.
- get_power_inputs() -> Dictionary para generación/demanda/estado de combustible.
- GridService.validate_zone(rect: Rect2i, purpose: StringName) -> ValidationResult; reserve_zone(owner_id: StringName, rect: Rect2i) -> ValidationResult; release_zone(owner_id: StringName) -> void.
- ResearchService.get_snapshot() -> Dictionary, validate_research(tech_id: StringName) -> ValidationResult, start_research(tech_id: StringName) -> ValidationResult.
- ScanService.validate_scan(sector: Vector2i) -> ValidationResult, scan(sector: Vector2i) -> ValidationResult.

CrewService recibe TaskOrder, devuelve progreso/trabajo y entrega resultado al dueño del edificio; R2 aplica reparación/combustible/construcción. Crear una tarea no la completa. R2 valida costes, R3 disponibilidad/exposición. Revalidar todas las precondiciones antes de cobrar y encolar; en el hilo de simulación no intercalar otro comando entre validación y commit. Tareas canceladas siguen política de devolución explícita en balance, pendiente de decidir; no inventar reembolso total.

Para investigación, R3 expone consume_completed_work(category: StringName) -> Array[Dictionary] con task_id/target_id/work_hours; R2 consume cada lote una sola vez. Escanear valida territorio, investigación y energía antes de modificar cualquiera; el comando completo corre sin yields y revierte si alguna operación falla.

World de R2 expone focus_target(target_id: StringName) -> bool y señales locales target_selected(target_id: StringName), placement_requested(request: PlacementRequest). R4 llama World mediante referencia inyectada por R1; World solicita place al dominio, nunca toca ledger. Solo R2 edita world.tscn. Stub: cuadrícula 32×32 y un edificio por estado. Pruebas: terreno/radio inválido no cobra, reparación finaliza una vez, UI refleja estado tras reload.

## C4. Tripulación, eventos y cohetes — R3 ↔ R1/R2/R4

CrewService añade create_roster(profile_ids: Array[StringName]) -> ValidationResult, validate_order(order: TaskOrder) -> ValidationResult, set_category_allowed(crew_id: StringName, category: StringName, allowed: bool) -> ValidationResult y set_sleep_hours(crew_id: StringName, hours: float) -> ValidationResult. Las cuatro categorías son survival, emergency_eva, production, science_construction; prioridades 1–4, propuesta 1 = máxima. Ocho perfiles, cada uno con una ventaja y una desventaja; mismo perfil repetible con IDs distintos. Apilamiento de médicos pendiente.

EventService expone get_snapshot() -> Array[EventState], set_event_enabled(event_id: StringName, enabled: bool) -> ValidationResult, trigger_event(event_id: StringName) -> ValidationResult y clear_event(event_id: StringName) -> ValidationResult. Publica modificadores/avisos; llama apply_damage, no edita edificios. Tripulación recibe dosis por su servicio, con Medicine sin reducirla. Eventos normales obedecen calendario y límite; admin no salta invariantes ni cobra dos veces un evento al restaurar.

RocketService añade get_snapshot() -> Array[RocketPlan], validate_salvage(rocket_id: StringName, crew_id: StringName) -> ValidationResult, validate_exchange(rocket_id: StringName, crew_id: StringName, profile_id: StringName) -> ValidationResult, exchange(rocket_id: StringName, crew_id: StringName, profile_id: StringName) -> ValidationResult, trigger_arrival(rocket_id: StringName) -> ValidationResult y update_support(autonomy: Dictionary, goals: Dictionary) -> void.

RocketService es dueño de exclusión intercambio/desguace. CrewService.replace_with_rocket delega a RocketService.exchange; exchange llama CrewService.apply_replacement(...) -> ValidationResult para cambiar tripulante después de validar, sin volver a delegar. Ambas mutaciones ocurren como una transacción sin yields y sin estados parciales. Muerte/salud pertenecen CrewService. R2 reserva físicamente celdas por ID de cohete; R3 guarda referencia. Carga al aterrizar usa ledger y bandera cargo_transferred para no duplicar.

El apoyo lee autonomía de R1, metas de misión de R3 y ajusta solo la próxima capacidad. Regla de bloqueo del manifiesto/plataforma/reemplazo pendiente en dudas. Stub: cohete sol 7 y un tripulante apto; prueba: cuatro llegadas, sobrepeso no cobra, desguace invalida intercambio y viceversa, guardado no repite carga.

## C5. UI, idioma, diálogo y audio — R4 ↔ todos

R4 construye main_menu/astronaut_select/settings_menu/hud/activity_log/guide_card/workspace/building_inspector/build_menu/manifest/work_priorities/energy/laboratory/resources/codex/sol_report/final_result/admin_panel.tscn en scenes/ui, con scripts asociados. Escenas dedicadas vital_status_bar/time_controls/workspace_tabs. R1 instancia HUD y menús, inyecta servicios; R4 no cambia main.tscn.

SettingsService.apply_settings(values: Dictionary) -> ValidationResult y get_settings() -> Dictionary; LocalizationDB.set_language(language: StringName) -> ValidationResult y tr(message_key: StringName, params: Dictionary = {}) -> String. NasaDataCatalog.get_source(source_id: StringName) -> Dictionary y get_sources() -> Array[Dictionary]. Publicar todos los datos de texto como claves. R4 añade simultáneamente EN y ES para solicitudes de otros roles.

DialogueService acepta hechos estructurados, valida claves/targets y registra. Focus_target es ID de edificio/astronauta o ui:<panel>, nunca NodePath persistido. AudioController consume event_changed/log_entry_added/building_changed y estado energético; mezcla SFX con prioridad crítica, no modifica estado de juego. Efectos visuales 3D son R2, audio es R4.

Stub: snapshots buenos/vacíos/error y claves dummy declaradas; prueba: alertas a x4 mantienen x4, reconocer no bloquea, cambiar idioma actualiza historial, tutorial omitido no oculta crítico, sonidos críticos no quedan tapados por ambiente.

## C6. Informe y ciencia — R1/R4 con todos los productores

Servicios llaman SolReportService.record_fact con reason_id/source_id/target_id/sol/sim_time/message_key/params/impact. R1 registra movimientos del ledger una vez y agrega hechos sin doble contabilidad. R4 renderiza get_report(sol): production, consumption, balance, damage, explanations (máximo tres). No existe un sistema de decisiones oculto dentro del informe. Una explicación exige evidencia real; alternativas no elegidas no se registran como resultados.

R4 verifica fuentes NASA y mantiene fuentes/eventos curados. R3 consume solo registros existentes mediante NasaDataCatalog; si no hay registro curado, no inventa source_id ni evento NASA. Los valores de daño son balance, no mediciones científicas. Prueba: informe muestra falta de energía respaldada por intervalo observado; fuentes tienen ID, URL y fecha comprobadas.

## C7. Integración, inputs y publicación

R1 edita project.godot y registra acciones propuestas: camera_pan_up/down/left/right, camera_zoom_in/out, select_target, cancel_action, pause_game, speed_down/up, toggle_admin. Asignación de teclas/mouse se fija en H0 con R2/R4; UI consume input primero y el mundo ignora eventos ya manejados. Capas propuestas: 1 terrain_pick, 2 building_pick, 3 crew_pick; R2 usa ray picking sin añadir colisiones de reglas. Estas son convenciones técnicas propuestas, no requisitos heredados.

Nodos públicos: Main/World (R2), Main/HUD (R4), Main/Services (R1); cada escena hija solo la edita su dueño. Datos .tres visuales en assets/world (R2); no trasladar reglas a Resources visuales. Stubs en tests de su propietario, nunca autoloads alternativos. R1 valida que el build final usa implementaciones reales.

Hitos H0–H5 en plan maestro. Cada entrega incluye API, cambios de datos solicitados, prueba reproducible, seed y consumidor afectado. R1 prueba integración; cada dueño corrige fallas en sus archivos. No se publica ni distribuye una build como parte de esta planificación.
