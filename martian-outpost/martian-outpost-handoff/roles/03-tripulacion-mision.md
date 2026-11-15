# R3 — Tripulación y misión

## Misión y alcance

Una persona y su agente desarrollan astronautas, trabajo/sueño/moral/dosis, amenazas y logística terrestre. Godot 4.7, 24 h, Web/Windows; GDScript/proyecto raíz como supuestos. Ocho perfiles, dos por especialidad; elegir exactamente cuatro permite repetir el mismo perfil. Cada instancia tiene ID propio, una ventaja y una desventaja. Fuente: handoff §§4–6; guía «Secuencia determinista» y «Contratos».

No implementar un sistema de decisiones. Refugio, EVA, prioridades, reemplazo/desguace son comandos directos; peligros continúan sin pausas forzadas. La medicina nunca reduce dosis acumulada. Llegadas al inicio 7/14/21/28; no llegan más hasta victoria al terminar 42. Tierra no cancela programa.

## Propiedad exclusiva

- res://domain/crew/{astronaut,crew_service,crew_status,task_scheduler,task_order}.gd y auxiliares.
- res://domain/events/{event_service,event_state}.gd y auxiliares.
- res://domain/rockets/{rocket_service,rocket_plan}.gd y auxiliares.
- res://data/crew/profiles.json y sus datos descriptivos por claves; res://tests/mission/**.

No posees escenas 3D de astronautas/cohetes (R2), UI (R4), balance/ledger/estado (R1). Propón parámetros a R1; cada archivo sigue teniendo un solo escritor. Salud/moral/dosis/tareas son tu partición de GameState; inventario se cambia por ledger.

## Tareas por fase

| Fase/tarea | Entradas | Salida | Terminado cuando |
| --- | --- | --- | --- |
| 0–2: perfiles/contratos | Especialidades y formato | Ocho perfiles, roster/task/rocket mocks | Cuatro perfiles iguales crean cuatro IDs y no comparten salud |
| 2–6: vida y trabajo | Deficiencias R1, tareas R2 | CrewService y scheduler | Trabajo/sueño/prohibición/prioridad se reflejan; no doble consumo |
| 2–6: salud/final | Reservas asignadas/exposición | Astronautas vivos/muertos | Informa cero vivos a R1; no emite victoria por su cuenta |
| 6–11: carga/llegada | Masa, zona R2, apoyo | Validar/confirmar/aterrizar | Sobrepeso rechaza; sol 7 transfiere carga una vez |
| 6–11: operaciones cohete | Trabajador/carga de reemplazo | Desguace/intercambio | Una operación impide la otra; recargar partida no duplica ganancia |
| 6–11: primera amenaza | Calendario sol 6 | Brecha vía R2 y aviso R4 | Daño deriva de evento reproducible, no del frame rate |
| 11–16: eventos | Calendario/seed/datos | Tormenta sol 12 cuatro soles, flare 16, aleatorios desde 22 | Avisos de 1/2 soles, máximo activo acordado, sin auto-pausa |
| 11–16: personas/riesgo | Exposición, sueño, tareas | Dosis/moral/mini-break/refugio/EVA | Trabajo exterior aumenta riesgo; reposo/medicina no borran dosis |
| 11–16: apoyo/campaña | Autonomía R1/metas | Próxima masa, cuatro cohetes | No toca inventario retroactivo; última llegada al inicio 28 |
| 16–20: bordes | Escenarios guardados | Casos deterministas | Mismo seed/acciones reproduce eventos, tareas y cohetes |
| 20–24: estabilizar | Fallas integradas | Correcciones propias | Partida de demo ensayada sin saltarse reglas |

## Contratos expuestos y consumidos

Expón CrewService de guía: set_priority, issue_urgent_order, replace_with_rocket, assign_eva_repair, order_shelter, get_snapshot. Añade create_roster, validate_order, set_category_allowed y set_sleep_hours. Prioridades 1–4; propuesta 1 máxima; prohibición separada. Categorías survival/emergency_eva/production/science_construction. TaskOrder: id/crew_id/category/target_id/task_type/required_hours/completed_hours/state/reason_id. CrewStatus: id/profile_id/alive/health/morale/fatigue/dose/shelter/task_id/priorities/forbidden_categories.

Consume LifeSupportService.get_crew_supply: deficiencias ya contabilizadas por R1; aplicas efectos humanos, no restas O2/agua/comida. Consume R2 validate_action y apply_task_result para reparación/construcción/combustible; entregas lotes consume_completed_work(category) para investigación. No completas tarea sin horas y no aplicas su resultado dos veces. Refugio cancela/suspende EVA según política documentada, sin ejecutar reparación mágicamente.

EventService.get_snapshot/set_event_enabled/trigger_event/clear_event devuelve ValidationResult o snapshots. Consume BuildingService.apply_damage, publica modificadores; nunca edita edificios directamente. Conserva source_id solo si NasaDataCatalog R4 ofrece registro real. Reglas ajustables en balance R1.

RocketService ofrece quote_next_mass_limit/validate_manifest/reserve_landing_zone/confirm_manifest/salvage y get_snapshot/validate_salvage/validate_exchange/exchange/trigger_arrival/update_support. RocketPlan: id/arrival_sol/manifest/mass_limit/confirmed/zone/landed/cargo_transferred/disposition. Reserva celdas vía GridService R2 y carga vía ledger R1. Propietario de exclusión es RocketService: CrewService.replace_with_rocket delega a exchange; exchange valida y llama apply_replacement de CrewService sin delegación circular. Operación atómica sin yields.

Publica crew_changed/event_changed/rocket_changed; pasa mensajes a DialogueService R4 y hechos a SolReportService R1. Datos públicos usan message_key/params, nunca prosa. Detalle ampliado: contratos C0/C1/C3/C4/C6.

## Dependencias y stubs

H0 ledger/reloj/red/NASA mock en tests/mission/stubs; H1 consume supervivencia real; H2 reserva de zona real y tareas; H3 eventos/soporte integrados. Servicios step/on_sol_started/on_sol_ended se llaman únicamente por SimulationRunner R1, no también por señales. Rebuild restaura estado RNG/colas/banderas sin volver a entregar carga. R4 arma UI con tus snapshots desde H0.

Reglas pendientes: apilamiento del +18% de médicos, carga permitida/masas faltantes, cuándo se congela manifiesto, reemplazo de fallecidos, zona inválida al llegar, plataforma y retiro del cohete. Entrega validadores/snapshots sin fijar silenciosamente esas políticas; consulta dudas y solicita cierre antes de H2. No asumir defaults científicos ni manifiestos gratuitos.

## Límites

No editar escenas, UI, JSON balance, scripts de supervivencia/research/scan ni bus. No crear IA compleja o árbol de habilidades. No cancelar programa terrestre. Sin APIs NASA en runtime. No modificar velocidad ante urgencias y sin colas de elecciones forzadas.

## Checklist y aceptación

- [ ] Cuatro instancias de un perfil independientes; exactamente cuatro al empezar.
- [ ] APIs tipadas, estado serializable y textos por claves; configuraciones por propietario.
- [ ] Trabajo interrumpible, prioridades/prohibición/sueño y mini-break comprobados.
- [ ] Medicine recupera salud/fatiga, nunca dosis; refugio y EVA producen resultados distintos.
- [ ] Sobrepeso/zona inválida no cobran; cuatro llegadas únicas incluso tras save/load.
- [ ] Intercambio/desguace excluyentes y transaccionales; muerte no deja tarea activa.
- [ ] Calendario/advertencias/semilla reproducibles y máximo de eventos respetado.
- [ ] Hechos para informe explican dosis, carga y trabajo; no inventan causalidad.
- [ ] Tormenta/flare a x4 mantienen x4 y aviso operativo visible mediante R4.

Carga alta: limitar animación e IA, no recortar loops de cohete/consumo/supervivencia para ahorrar tiempo.
