# R1 — Infraestructura y supervivencia

## Misión y alcance

Una persona y su agente mantienen la autoridad de estado, reloj, recursos, energía, consumo, autonomía, informe, guardado, composición y exportación. Godot 4.7, Web/Windows, 24 h; GDScript y proyecto raíz existentes son supuestos registrados. Campaña: 42 soles de 60 s a x1, x0.5/x1/x2/x4, cuatro llegadas al inicio 7/14/21/28. Victoria al terminar 42 con alguien vivo; derrota cuando no quede nadie. No sistema de decisiones ni pausas automáticas por avisos. Fuentes: handoff §§1–3,6–9; guía «Secuencia determinista» y «Estado».

## Propiedad exclusiva

- res://project.godot, export_presets.cfg y configuración raíz .editorconfig/.gitattributes/.gitignore.
- res://autoload/game_state.gd, game_clock.gd, config_db.gd, signal_bus.gd, save_service.gd; demás autoloads nuevos salvo los tres R4.
- res://domain/core/{game_session,simulation_runner,contracts}.gd; domain/resources/resource_ledger.gd; domain/power/power_service.gd; domain/life_support/life_support_service.gd; domain/reports/sol_report_service.gd y auxiliares dentro de esas carpetas.
- res://scenes/integration/{main,integration}.tscn y scripts; res://tests/core/**, tests/integration/** y herramientas de build/validación.
- res://data/balance.json; custodia del handoff, guía, maestro, contratos y dudas después de esta planificación.

Eres único escritor de balance; R2/R3/R4 proponen parámetros/claves, tú incorporas. No eres propietario de todos los servicios. R4 posee localization_db/nasa_data_catalog/settings_service.gd. R2 escenas 3D; R3 lógica de tripulación/misión; R4 todas las escenas UI y contenido.

## Tareas por fase

| Fase/tarea | Entradas | Salida | Terminado cuando |
| --- | --- | --- | --- |
| 0–2: arranque/contratos | Guía, JSON inicial, proyecto | GameSession, DTO, bus, registro de servicios, stubs | Cuatro secciones conectan sin editar archivos ajenos; primer export mínimo abre |
| 0–2: validar datos | Datos y propuestas de roles | Validador de referencias/rangos, lista de faltantes | Falla con mensaje concreto ante ID inválido; no inventa defaults silenciosos |
| 2–6: reloj/ledger | dt, seed, costes | Paso fijo, pausa manual, spend/add | x4 no cambia fórmulas; gasto fallido no modifica inventario |
| 2–6: potencia y soporte | Red/edificios R2, vivos/necesidades R3 | Asignación, reservas, deficiencias | Noche/batería/ISRU reaccionan; consumo se aplica una sola vez |
| 2–6: final | Estado de vivos | game_over una vez | Cero vivos pierde; no victoria anticipada |
| 6–11: guardar/restaurar | Estado completo por particiones | SaveService validado | Restaurar durante evento/pre-cohete reproduce estado sin duplicar carga/vistas |
| 6–11: autonomía/informe | Ledger y hechos | Producción local útil/consumo, hasta tres causas | Cargo no cuenta como producción; toda explicación tiene evidencia |
| 11–16: integrar misión/admin | R2/R3 completos | Secuencia de campaña y avance forward-only | Llegadas al inicio, apoyo al cierre; avance no omite consumo ni revive muertos |
| 16–20: balance y pruebas | Casos de todos, kit propuesto | Partida viable y derrota reproducible | 42 soles a x4 sin NaN, consumos dobles ni stubs; equivalencia x1/x4 |
| 20–24: builds/demo | Entregas congeladas | Web/Windows probados, ensayo | Ambos arrancan sin red; demo cabe en diez minutos según formato confirmado |

## Contratos expuestos y consumidos

Expón las firmas ResourceLedger, GameClock, PowerService, LifeSupportService, SolReportService y SaveService de la guía. GameSession.start_new(profile_ids: Array[StringName], seed: int) -> ValidationResult acepta exactamente cuatro IDs, incluso idénticos. ValidationResult = ok/error_code/message_key/params/costs/warnings; EnergySnapshot = generation/demand/stored/capacity/by_building. Cada entrada en by_building tiene allocated/demand/powered/priority. ResourceLedger único escritor de cantidades.

Consume R2 BuildingService.get_all_statuses/get_power_inputs, GridService.get_energy_links y TunnelNetwork.get_snapshot: componentes, fugas, edificios activos y combustible. Consume R3 CrewService.get_snapshot y RocketService.update_support; R3 aplica daño a tripulación, tú proporcionas get_crew_supply con deficiencias. Consume UI R4 como escena inyectada, no como dependencia del dominio. Hechos del informe: reason_id, source_id, target_id, sol, sim_time, message_key, params, impact. No agregar consumo al recibir un hecho ya registrado por ledger.

SimulationRunner llama step en orden: eventos/conectividad → potencia → producción R2 → soporte vital → crew R3 → research R2 → derrota; cierra autonomía/apoyo/informe/victoria y luego sol_ended. El reloj publica señales para observación; no permitir segundo camino de ejecución por señales. SaveService emite state_restored después de reconstruir cachés; vistas reconstruyen. Detalle ampliado: contratos C0/C1/C2/C6/C7.

## Dependencias y stubs

H0 necesita snapshots R2/R3 con base/ISRU/invernadero/reactor y cuatro astronautas; mientras, usa tests/core/stubs propios. H1 reemplaza esos mocks por servicios reales. H2 requiere transacciones de llegada y producción. H3 requiere todos los estados guardables. Tú entregas mock de reloj/ledger a consumidores al principio, sin copiar sus scripts a tu carpeta. Las reglas de kit/manifiesto/unidades abiertas se registran antes de fijar balance; otros trabajos siguen.

## Límites

No editar escenas World/HUD, perfiles, locales/NASA/tutorial, servicios de construcción/tripulación. Registrar acciones input y capas acordadas con R2/R4 en project.godot. No HTTP en MVP. No mover datos a Resources visuales. No crear otro proyecto ni cambiar sol/velocidad para hacer caber la demo sin confirmación.

## Checklist y aceptación

- [ ] APIs tipadas, IDs/archivos snake_case, clases PascalCase; serialización sin nodos.
- [ ] Un propietario por archivo; parámetros nuevos de otros roles incorporados por ti.
- [ ] Reloj determinista y seed/estado RNG persistidos; GameState sin dependencias UI.
- [ ] JSON valida IDs/rangos; UI recibe claves, nunca prosa de dominio.
- [ ] Una sola contabilidad y guardado atómico; error deja partida intacta.
- [ ] Pruebas sobrepeso/carga única, fallo de spend, noche/batería, O2/agua/comida/fuga y game_over.
- [ ] Tests de guardado, x1/x4 y 42 soles; export mínimo H0 y final H5.
- [ ] Ningún aviso/tutorial/informe cambia velocidad; informe sin elecciones forzadas.

Carga alta: preservar integración y supervivencia antes de refinar reportes. Cortes permitidos en handoff «Scope order»; no recortar sistemas obligatorios silenciosamente.
