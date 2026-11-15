# R4 — Interfaz y contenido

## Misión y alcance

Una persona y su agente presentan el juego con UI clara para 7–12 años, EN/ES, tutorial, fuentes NASA verificables y audio funcional. Godot 4.7, Web/Windows, 24 h y demo de diez minutos. GDScript/proyecto raíz son supuestos. Fuentes: handoff §§1,7–8; guía «HUD», «Datos/localización», «Informe».

No hay Decision Maker ni elecciones obligatorias. Los avisos indican peligro y permiten enfocar objetivo; no pausan, reducen velocidad ni bloquean juego. Las acciones se ofrecen en inspector/Crew/Energy/Rocket con costes del servicio. Mantener pausa manual y x0.5/x1/x2/x4. Selección admite cuatro copias del mismo perfil.

## Propiedad exclusiva

- res://autoload/{localization_db,nasa_data_catalog,settings_service}.gd.
- res://domain/dialogue/{dialogue_service,dialogue_entry}.gd y auxiliares; ScienceCard dentro de nasa_data_catalog.gd o archivo auxiliar en la misma carpeta bajo tu propiedad explícita.
- res://scenes/ui/** y scripts: main_menu, astronaut_select, settings_menu, hud, vital_status_bar, time_controls, activity_log, guide_card, workspace, workspace_tabs, building_inspector, build_menu, manifest, work_priorities, energy, laboratory, resources, codex, sol_report, final_result, admin_panel y audio_controller.
- res://data/tutorial.json, data/locales/{en,es}.json, data/nasa/sources.json y registros curados.
- res://assets/ui/**, assets/audio/**, icon.svg, y .tres de temas/audio; res://tests/ui/**.

No modificas escenas World/Main, servicios de reglas ni balance. R1 incorpora tus autoloads/inputs al proyecto. Todos los textos nuevos de otros roles se solicitan a ti para añadir EN/ES conjuntamente. Fuentes científicas y sonido del antiguo quinto rol ahora son tuyos; pruebas de simulación siguen con cada dueño.

## Tareas por fase

| Fase/tarea | Entradas | Salida | Terminado cuando |
| --- | --- | --- | --- |
| 0–2: wireframe/locales | Zonas handoff, snapshots mock | Escenas shell y claves | O2/agua/comida/presión/moral y velocidad visibles; siete pestañas |
| 0–2: ciencia | sources.json actual | Auditoría de URLs/fechas y evento DONKI faltante | No confundir lista de fuentes con pack curado ya completo |
| 2–6: entrada/HUD | GameSession/estado/crew | Menú, cuatro selecciones, HUD vivo | Permite mismo perfil ×4; bloquea empezar con 3/5; no escribe GameState |
| 2–6: tiempo/avisos | Reloj y mensajes | Pausa manual, log/filtros | Crítico no cambia x4, no se oculta por filtro y no tapa vitales |
| 6–11: paneles | Validadores/snapshots R2/R3 | Build/Lab/Crew/Energy/Rocket/Resources | Previsualiza costes reales y muestra rechazo por message_key |
| 11–16: inspector/reporte/admin | Status/log/report/comandos | Paneles contextual y de administración | Causas reales y forward-only por servicio; ningún cálculo de reglas en UI |
| 11–16: tutorial/codex | Condiciones y claves/fuentes | Guía omitible/reactivable y ciencia | Pasos por hechos; fuentes archivadas con limitación/fecha verificadas |
| 11–16: audio | Señales de estado | SFX/ambiente/alertas discretos | Críticos tienen prioridad, ambiente no se hace pasar por alarma |
| 16–20: idioma/accesibilidad | Estado guardado y builds | EN/ES completos, layout adaptable | Cambiar idioma retraduce historial, icono/texto acompañan color |
| 20–24: demo/fixes | Recorrido aprobado | Ensayo de diez minutos | Presentación legible, sin pausas impuestas ni paneles bloqueantes |

## Contratos expuestos y consumidos

Expón DialogueService de guía, más reactivate_tutorial. DialogueEntry: id/kind/severity/message_key/params/created_sol/acknowledged/resolved/source_id?/focus_target?. Prioridad crítica > tutorial > operación > ambiente. Eres único escritor del log; rutina de edificios queda en inspector, noticias globales/ciencia/pensamientos permanecen en ActivityLog. Reconocer no silencia un peligro aún existente ni pausa.

SettingsService.apply_settings/get_settings y LocalizationDB.set_language/tr son frontera para ajustes. Persisten por su partición de estado, no por escritura UI. NasaDataCatalog.get_source/get_sources entrega fuente con id/provider/title/url/retrieved_on/data_mode/used_for/explanation_key/model_limit_key. ScienceCard referencia source_id; todos los textos se resuelven al mostrar. Sin HTTP ni API key en MVP. La curación previa usa fuentes NASA reales y documenta recuperación; no inventar evento ni fecha.

Consume GameSession.start_new, GameClock.get_snapshot/set_speed/set_paused, ResourceLedger.get_snapshot, PowerService.get_snapshot/set_priority, LifeSupportService.get_status y SolReportService.get_report. Consume R2 BuildingService/ResearchService/ScanService validadores/comandos y R3 CrewService/EventService/RocketService. ValidationResult contiene ok/error_code/message_key/params/costs/warnings: úsalo para coste y error, nunca recalcules masa/energía/autonomía.

Main R1 inyecta servicios y World R2. Consume World.target_selected y llama focus_target con ID; no NodePath guardado. Al state_restored reconstruye UI idempotente; al language_changed refresca textos históricos. AudioController solo escucha señales. Detalle ampliado: contratos C0/C5/C6/C7.

## Dependencias y stubs

Desde H0 usa snapshots fixture con estados normal/vacío/error/peligro en tests/ui/stubs. H1 conecta reloj/recursos/crew; H2 dominio de construcción/manifiesto; H3 inspector/reporte/admin completos. R1 es único editor SignalBus y project.godot; solicita nuevas señales y acciones, no las dupliques. R2 aporta efectos 3D; tú audio.

Tutorial inicial: 32 placas para laboratorio 16, panel 10 y hasta seis túneles nuevos. Enseñar laboratorio/panel antes del primer cohete; batería como paso posterior. R2 valida las conexiones y R1 el tiempo de investigación/trabajo. No prometer otros gastos cubiertos ni carga gratuita. Curated_donki_events está vacío: completar/verificar registro real antes de presentación. Si falta, reportar bloqueo de procedencia sin presentar un dato inventado como NASA.

## Límites y presentación

No reglas de coste, salud, autonomía o probabilidades en scripts UI. Sin ventanas de decisiones ni autoresoluciones. Sol Report es vista no bloqueante. Admin pide advance_to_sol/trigger_event/trigger_arrival/remove, no modifica diccionarios. Menú Quit en Web requiere salida apropiada al navegador, sin prometer cerrar una pestaña; registrar texto/comportamiento antes de entrega.

Guion de demo: 0–1 objetivo/selección; 1–3 laboratorio/panel; 3–5 energía/cohete; 5–7 amenaza/acción; 7–9 autonomía/final; 9–10 fuentes/EN-ES/cierre. Se mantienen diez minutos mediante recorrido guiado con avance admin, según la interpretación documentada de la confirmación. La partida natural a x4 sigue durando 10:30; no se cambian sus reglas.

## Checklist y aceptación

- [ ] Siete pestañas, vitales y tiempo siempre legibles, inspector contextual.
- [ ] Claves EN/ES idénticas; texto dinámico e historial se retraducen.
- [ ] APIs tipadas, snapshots de lectura, no cálculo de reglas.
- [ ] Cuatro perfiles iguales seleccionables; inicio exige exactamente cuatro.
- [ ] Coste/restricción antes de actuar, error visible y efecto inmediato después.
- [ ] Crítico no cambia velocidad; filtros no ocultan peligro; guía/ambiente no lo cubren.
- [ ] Tutorial omitible/reactivable, completados persistidos, sin repetir al cargar.
- [ ] Fuentes NASA verificadas, evento real curado y separación dato/modelo; sin red runtime.
- [ ] Prueba de foco, navegación, audio, cambio idioma y reconstrucción tras load.
- [ ] Layout propuesto 1280×720 y 960×540 probado; resolución final pendiente del usuario.

Carga alta: audio discreto, tutorial mínimo y paneles modulares antes de música/animación avanzada. No sacrificar avisos de supervivencia por contenido decorativo.
