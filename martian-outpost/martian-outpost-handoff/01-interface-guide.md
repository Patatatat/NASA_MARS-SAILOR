# Guía de interfaces y límites

Versión de planificación: cuatro personas con cuatro agentes, Godot 4.7, 24 horas. El handoff define el juego. La petición del usuario retira el sistema dedicado de decisiones: no implementar Decision Maker, DecisionService, DecisionLog, DecisionRecord, DecisionSituation ni plantillas. Se conservan acciones directas, costes, consecuencias, avisos y pausa manual.

## Propietarios e índice de diagnóstico

| Área | Único propietario | Servicios |
| --- | --- | --- |
| Estado, reloj, recursos, potencia, soporte vital, autonomía, informe, integración/exportación | R1 Infraestructura y supervivencia | GameState, GameClock, ConfigDB, SignalBus, SaveService, GameSession, SimulationRunner, ResourceLedger, PowerService, LifeSupportService, SolReportService |
| Mapa, colocación, túneles, producción, reparación, investigación, escaneo, presentación 3D | R2 Mundo y construcción | GridService, BuildingService, TunnelNetwork, ProductionService, ResearchService, ScanService, World |
| Astronautas, tareas, moral/dosis, amenazas, cohetes, apoyo | R3 Tripulación y misión | CrewService, TaskScheduler, EventService, RocketService |
| UI, traducción, tutorial, fuentes NASA, audio | R4 Interfaz y contenido | DialogueService, LocalizationDB, NasaDataCatalog, SettingsService, AudioController |

R1 mantiene esta guía y los contratos. Propiedad exhaustiva de carpetas y excepciones en roles/00-plan-maestro.md; contratos entre roles en roles/contratos-integracion.md. Un propietario por archivo, también para .tscn/.tres y JSON. Compartir una API no permite editar el archivo ajeno.

## Estructura y convenciones

Archivos, propiedades, señales, IDs y claves JSON en snake_case; clases/nodos en PascalCase. APIs públicas tipadas. GDScript y reutilizar el proyecto de la raíz del workspace son supuestos técnicos registrados; Godot 4.7 es confirmado. Las rutas res:// son destinos planificados, no implementación existente.

- autoload/: R1, salvo localization_db.gd, nasa_data_catalog.gd, settings_service.gd de R4.
- domain/core, resources, power, life_support, reports: R1.
- domain/buildings, research, exploration: R2.
- domain/crew, events, rockets: R3.
- domain/dialogue: R4.
- scenes/integration: R1; scenes/world, buildings, crew, rockets: R2; scenes/ui: R4.
- assets/world: R2; assets/ui y assets/audio: R4.
- data/balance.json: R1; data/world: R2; data/crew: R3; data/tutorial.json, locales y nasa: R4.
- tests/core e integration: R1; tests/world: R2; tests/mission: R3; tests/ui: R4.

## Autoridad y dependencia

UI → servicios → GameState/config. Servicios no importan escenas UI. World instancia vistas desde datos y solicita acciones; no cobra costes. GameState almacena valores serializables sin Node/NodePath. Cada servicio escribe solo su partición; ResourceLedger es el único escritor del inventario. Lecturas entre servicios exclusivamente mediante APIs públicas.

GameSession registra servicios e inyecta dependencias. SimulationRunner ejecuta reglas en orden explícito. Ningún rol crea una copia alternativa del servicio ajeno. DialogueService puede almacenar estado de presentación, pero no calcula supervivencia.

## Estado y administración

Guardar schema_version, reloj/sol/velocidad/pausa, inventario, tripulación, edificios/celdas, túneles/presión/daños, potencia/baterías, cultivos/combustible, investigación, sectores, eventos/colas/estado RNG, cohetes/manifiesto/zona, autonomía/apoyo, idioma/ajustes, historial global/local, tutorial completado/omitido, IDs NASA, causas del informe y victoria/derrota. Guardar IDs, nunca referencias.

Solo SaveService llama GameState.to_dict()/from_dict(). Valida todo antes de sustituir estado; error deja intacta la partida. Reconstruye cachés de servicios y emite una vez state_restored; World y UI reconstruyen vistas idempotentes. No snapshots por sol ni rebobinado. Admin llama comandos y GameClock.advance_to_sol; nunca modifica diccionarios.

## Contratos públicos mínimos

Esquemas completos y extensiones en contratos-integracion.md. Tipos RefCounted ligeros; diccionarios validados para serialización.

```gdscript
# R1: ResourceLedger
func can_afford(cost: Dictionary) -> bool
func spend(cost: Dictionary, reason: String) -> bool
func add(delta: Dictionary, reason: String) -> void
func get_amount(resource_id: StringName) -> float
func get_snapshot() -> Dictionary

# R1: GameClock
func set_speed(multiplier: float) -> ValidationResult
func set_paused(paused: bool) -> void
func advance_to_sol(sol: int) -> ValidationResult
func get_snapshot() -> Dictionary

# R1: PowerService
func get_snapshot() -> EnergySnapshot
func set_priority(building_id: StringName, priority: int) -> void
func is_powered(building_id: StringName) -> bool
func spend_stored_energy(amount: float, reason: StringName) -> ValidationResult

# R1: LifeSupportService
func get_status() -> Dictionary

# R1: SolReportService
func record_fact(fact: Dictionary) -> void
func get_report(sol: int) -> Dictionary

# R2: BuildingService
func validate_placement(request: PlacementRequest) -> PlacementResult
func place(request: PlacementRequest) -> StringName
func remove(building_id: StringName, reason: String) -> bool
func get_status(building_id: StringName) -> BuildingStatus
func get_log(building_id: StringName, limit: int = 20) -> Array[BuildingLogEntry]
func set_storm_protection(building_id: StringName, enabled: bool) -> ValidationResult
func set_enabled(building_id: StringName, enabled: bool, reason: StringName) -> ValidationResult

# R3: CrewService
func set_priority(crew_id: StringName, category: StringName, level: int) -> void
func issue_urgent_order(order: TaskOrder) -> bool
func replace_with_rocket(crew_id: StringName, rocket_id: StringName, profile_id: StringName) -> bool
func assign_eva_repair(crew_id: StringName, target_id: StringName) -> ValidationResult
func order_shelter() -> ValidationResult
func get_snapshot() -> Array[Dictionary]

# R3: RocketService
func quote_next_mass_limit() -> float
func validate_manifest(manifest: Dictionary) -> ValidationResult
func reserve_landing_zone(rect: Rect2i) -> ValidationResult
func confirm_manifest(manifest: Dictionary) -> ValidationResult
func salvage(rocket_id: StringName, crew_id: StringName) -> bool

# R4: DialogueService
func evaluate_tutorial_triggers(context: Dictionary) -> void
func dismiss_guide(dialogue_id: StringName) -> void
func skip_tutorial() -> void
func reactivate_tutorial() -> void
func add_log_entry(entry: DialogueEntry) -> void
func get_log_entries(filter: StringName = &"all") -> Array[DialogueEntry]

# R1: SaveService
func save_to_slot(slot_id: StringName) -> Error
func load_from_slot(slot_id: StringName) -> Error
func export_state() -> Dictionary
func import_state(data: Dictionary) -> Error
```

ValidationResult: ok, error_code, message_key, params, costs, warnings. Validar no muta. Ejecutar revalida y no cobra ni aplica cambios parciales si falla. Los métodos heredados bool/ID tienen validación previa para explicar rechazo. La UI presenta costes/condiciones del dominio; no los recalcula.

## SignalBus

R1 escribe signal_bus.gd; cada servicio origina sus hechos. No procesar una regla tanto por señal como por llamada del coordinador.

| Señal tipada | Emisor | Consumidores |
| --- | --- | --- |
| tick_advanced(sim_seconds: float) | GameClock | Vistas/telemetría |
| sol_started(sol: int), sol_ended(sol: int) | GameClock | UI/tutorial; el coordinador ya ejecutó reglas |
| resources_changed(delta: Dictionary, reason: String) | ResourceLedger | HUD/informe |
| energy_changed(snapshot: EnergySnapshot) | PowerService | Mundo/UI |
| building_changed(building_id: StringName, change_type: StringName) | BuildingService | Mundo/UI/caché de red |
| building_log_added(building_id: StringName, entry: BuildingLogEntry) | BuildingService | Inspector |
| crew_changed(crew_id: StringName) | CrewService | Mundo/UI |
| event_changed(event_id: StringName, state: StringName) | EventService | Mundo/UI/audio |
| rocket_changed(rocket_id: StringName, state: StringName) | RocketService | Mundo/UI |
| research_changed(tech_id: StringName, state: StringName) | ResearchService | UI/tutorial |
| log_entry_added(entry: DialogueEntry) | DialogueService | UI/audio |
| guide_dialogue_changed(dialogue_id: StringName, state: StringName) | DialogueService | Guía/enfoque |
| language_changed(language: StringName) | LocalizationDB | Vistas |
| state_restored() | SaveService | Vistas |
| game_over(result: StringName) | GameState, solicitado por GameSession | UI/admin |

## Secuencia determinista

SimulationRunner es el único coordinador. Paso fijo propuesto de 0.1 segundos simulados configurable; x4 ejecuta más pasos, no modifica fórmulas. No depender del orden de conexión de señales.

1. Al inicio del sol: EventService aplica calendario/avisos y RocketService llega una vez en 7/14/21/28. Después se publica sol_started.
2. Por paso: fase día/noche; efectos de eventos; conectividad invalidada; PowerService; ProductionService con potencia asignada; LifeSupportService consume una vez por tripulante vivo y contabiliza fugas; CrewService resuelve salud/exposición/tareas; ResearchService aplica trabajo; registrar hechos y comprobar derrota.
3. Las tareas finalizadas entregan resultados al servicio propietario antes del paso siguiente. Cambios de red/potencia se reflejan en el siguiente paso, sin consumir dos veces un intervalo.
4. Al cierre: contabilidad/autonomía, apoyo para el próximo manifiesto, informe, victoria tras terminar sol 42. Derrota prevalece si muere el último astronauta. Emitir sol_ended; avanzar solo si sigue activa.

advance_to_sol ejecuta pasos normales hasta el inicio solicitado, sin retroceder, sin omitir consumos/eventos ni superar game_over. Semilla y estado RNG guardados.

## Datos y localización

ConfigDB valida todos los archivos, IDs, referencias y rangos antes de iniciar. Balance.json contiene valores ajustables y fórmulas; R1 incorpora propuestas de los demás. R2 mantiene distribución inicial, R3 perfiles, R4 tutorial/traducciones/NASA. No duplicar parámetros. El balance actual está incompleto: cada rol propone lo que falta, sin inventar datos científicos.

Todo texto visible usa message_key y params. LocalizationDB.tr(message_key, params) resuelve EN/ES, cae a inglés y registra faltantes en desarrollo. Ambos locales tienen las mismas claves. SettingsService pide a LocalizationDB cambiar idioma y persistirlo; UI nunca escribe GameState. Retraducir historial al cambiar idioma.

Tutorial: IDs, condiciones, prioridad, claves, foco, acciones y finalización; sin prosa. Omitir no oculta peligros; reactivar conserva pasos completados. NASA: sources.json es índice único, con id/provider/title/URL oficial/retrieved_on/data_mode archived/used_for/explanation_key/model_limit_key. ScienceCard retiene source_id. No HTTP ni API keys en MVP, ni dosis reales convertidas directamente en daño humano.

La lista curated_donki_events está vacía: R4 debe obtener y verificar al menos un evento real con ID/fecha antes de afirmar que se usa un paquete de eventos archivados. No dar por verificadas las fechas por mera presencia del campo.

## HUD, avisos y edificios

VitalStatusBar arriba izquierda; TimeControls arriba derecha; ActivityLog abajo izquierda; WorkspaceTabs abajo centro/derecha; GuideCard. Siete pestañas: Build, Crew, Energy, Rocket, Laboratory, Resources, Codex. Inspector contextual separado.

Avisos, tutoriales e informe no pausan, no fuerzan velocidad ni bloquean interacción. Solo usuario controla pausa/velocidad, salvo detener la partida al finalizar. Riesgos avanzan a la velocidad elegida; pausa manual congela todo.

DialogueEntry: id, kind (critical/operational/astronaut_thought/science_fact/tutorial), severity, message_key, params, created_sol, acknowledged, resolved, source_id opcional y focus_target opcional. DialogueService es único escritor. Prioridad critical > tutorial > operational > ambient. Críticos permanecen visibles mientras exista peligro, incluso reconocidos; reconocer no bloquea ni pausa. Ambientales se suprimen durante críticos. Noticias/ciencia/pensamientos permanecen globales; rutina de edificios solo en inspector.

BuildingStatus: ID/tipo, producción/demanda, potencia, salud/condición, modificadores, warnings y claves de próxima consecuencia. BuildingLogEntry: kind/severity/message_key/params/sol/reason_id. Inspector ofrece protección, encendido y reparación directamente; Crew ofrece refugio/EVA. Mostrar coste y restricciones antes de actuar y reflejar el resultado.

## Informe sin sistema de decisiones

SolReportService agrega producción/consumo y hechos con reason_id, source_id, target_id, sol, sim_time, message_key, params e impact. No administra elecciones exclusivas ni situaciones. El servicio causante registra tiempo sin potencia, pérdida de cultivo, dosis u otro hecho. Seleccionar hasta tres explicaciones demostrables. No atribuir culpa al jugador cuando solo se conoce falta de potencia. No duplicar totales contables al añadir hechos explicativos.

## Pruebas mínimas

- 42 soles a x4 sin errores/NaN, victoria y derrota reproducibles; misma secuencia simulada a x1/x4.
- Sobrepeso/zona ocupada, cuatro llegadas únicas y exclusión intercambio/desguace.
- Noche/tormenta/batería/cultivos, brecha/aislamiento/soldadura/repuestos, combustible.
- Guardado en evento, antes de llegada y con zona: no duplicar nodos/carga al restaurar.
- Escaneo fuera de límite/repetido, terreno inválido y cuatro selecciones del mismo perfil.
- EN/ES completas, cambio de idioma actualiza historial; tutorial no repite completados.
- Fuentes NASA verificadas, etiquetas archivadas, ejecución sin red.
- Crítico visible/enfocable/audible sin cambiar x4; tutorial e informe tampoco cambian tiempo.
- Acciones con coste visible, efecto real e informe sustentado por reason_id.
- Exportaciones Web/Windows ejecutables y ensayo de diez minutos; resolución mínima registrada.
