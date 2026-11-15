# Plan maestro — cuatro secciones, 24 horas

## Visión y decisiones confirmadas

Cuatro personas, cada una con un agente, construyen cuatro secciones integrables de un simulador marciano 3D isométrico low-poly/cel-shaded para Web y Windows. Godot 4.7; EN/ES; público principal 7–12 años. Sobrevivir 42 soles, 60 segundos por sol a x1, cuatro cohetes al inicio de 7/14/21/28, victoria al terminar 42 con alguien vivo y derrota al morir el último. Origen: handoff §§1–8.

Confirmado por el usuario: sobrescribir cinco roles por cuatro, único propietario por archivo, perfiles repetibles, retirar sistema dedicado de decisiones, plazo 24 h y presentación de 10 minutos. Se conservan decisiones ordinarias de gestión, consecuencias observables y Sol Report con hechos reales. Alertas y tutorial no pausan ni fuerzan velocidad. Pausa manual disponible. No implementar código durante esta planificación.

## Reparto e inventario

| Rol / sección | Interfaces y sistemas asignados | Motivo | Carga |
| --- | --- | --- | --- |
| R1 Infraestructura y supervivencia | GameState, GameSession, SimulationRunner, GameClock, ConfigDB, SignalBus, SaveService, ResourceLedger, PowerService, LifeSupportService, SolReportService; autonomía, arranque, balance, integración y builds | Mantiene juntas autoridad, contabilidad y tiempo; un único camino de consumo/energía/guardado | Alta |
| R2 Mundo y construcción | GridService, BuildingDefinition, BuildingService, TunnelNetwork, ProductionService, ResearchService, ScanService; cámara, selección, mapa, colocación, minería/refinado/impresión/cultivos/combustible, reparación y todas las vistas 3D | Edificio, terreno, producción y visualización comparten IDs/estado; evita separar colocación de validación | Alta |
| R3 Tripulación y misión | Astronaut, CrewService, TaskScheduler, TaskOrder, CrewStatus, EventService, EventState, RocketService, RocketPlan; necesidades físicas/salud, prioridades, sueño, moral, dosis, tareas, amenazas, manifiesto, reemplazo/desguace, apoyo de Tierra | Reúne trabajo humano, peligros y logística que lo interrumpen; consume reservas sin duplicar su contabilidad | Alta |
| R4 Interfaz y contenido | LocalizationDB, SettingsService, NasaDataCatalog, ScienceCard, DialogueService, DialogueEntry, AudioController; menús, selección, HUD, siete paneles, inspector, Sol Report visual, admin visual, tutorial, Codex, EN/ES, NASA y sonido | Una sola cadena de texto/explicación/presentación, independiente de fórmulas | Alta |

No existe quinto rol de QA/audio/NASA: cada sección prueba sus reglas; R1 mantiene integración/exportación; R4 audio y procedencia científica. Se equilibra con modelos proxy, tutorial corto y audio por estados. No prometer contenido pulido completo en 24 h: se congela funcionalidad a las 20 h.

## Propiedad de archivos y escenas

Raíz técnica propuesta: proyecto existente `C:/Users/Zilean/Documents/beyond-our-home/project.godot`; `res://` corresponde a esa carpeta. Fuentes documentales y JSON iniciales están en `martian-outpost/martian-outpost-handoff/`. Al implementar, cada propietario traslada sus datos a los destinos siguientes; no cargar dos copias del balance. GDScript es supuesto explícito.

| Ruta de destino / ámbito | Propietario exclusivo |
| --- | --- |
| res://project.godot, export_presets.cfg, .editorconfig, .gitattributes, .gitignore | R1 |
| res://autoload/** | R1, salvo las tres excepciones siguientes |
| res://autoload/localization_db.gd, nasa_data_catalog.gd, settings_service.gd | R4 |
| res://domain/core/**, resources/**, power/**, life_support/**, reports/** | R1 |
| res://domain/buildings/**, research/**, exploration/** | R2 |
| res://domain/crew/**, events/**, rockets/** | R3 |
| res://domain/dialogue/** | R4 |
| res://scenes/integration/**, incluido main.tscn e integration.tscn | R1 |
| res://scenes/world/**, buildings/**, crew/**, rockets/** | R2 |
| res://scenes/ui/** | R4 |
| res://assets/world/**, modelos, materiales, texturas y FX | R2 |
| res://assets/ui/**, assets/audio/**, icon.svg | R4 |
| res://data/balance.json | R1 |
| res://data/world/**, initial_layout.json | R2 |
| res://data/crew/**, profiles.json | R3 |
| res://data/tutorial.json, data/locales/**, data/nasa/** | R4 |
| res://tests/core/**, tests/integration/** y herramientas de validación/build | R1 |
| res://tests/world/** | R2 |
| res://tests/mission/** | R3 |
| res://tests/ui/** | R4 |
| Handoff, guía, plan maestro y contratos | R1, custodia documental tras entrega de Astra |
| Cada documento de rol | Su propio rol; cambios públicos coordinados con R1 |
| roles/dudas-y-supuestos.md | R1 recopila respuestas del usuario |

Regla de cierre: archivos nuevos fuera del inventario requieren asignación en esta tabla antes de editar; no hay carpeta de escritura compartida. Los archivos generados de Godot no se editan manualmente. Cada .tscn/.tres tiene el mismo propietario que su carpeta. R1 instancia world.tscn de R2 y hud.tscn de R4 dentro de main.tscn sin editar sus interiores.

## Dependencias y ruta crítica

R1 publica DTO, bus, reloj, estado y ledger → R2 conecta red/edificios/producción y R3 conecta tripulación → R1 resuelve energía/consumo → R3 calcula logística/apoyo → R4 presenta el estado real → integración de 42 soles → exportación y demo.

Ruta crítica: contratos/arranque (h2) → supervivencia integrada (h6) → cohete y economía (h11) → campaña completa (h16) → pruebas 42 soles y guardado (h20) → builds y ensayo (h24). El presupuesto del tutorial se fija en 32 placas (16 laboratorio + 10 panel + hasta 6 túneles nuevos); R2 debe validar un layout compatible. Siguen pendientes reglas de manifiesto/plataforma y kit nuclear inicial; ver dudas.

R2 y R3 usan ledger/reloj mock desde h0; R1 usa snapshots de edificios/tripulación mock; R4 usa snapshots y señales mock. Cada stub vive en tests/<propietario>, implementa el contrato real y no se usa en builds finales. R1 conmuta dependencias en integration.tscn. Reemplazar cada stub por su servicio al alcanzar su hito, con prueba de contrato.

## Fases paralelas e hitos

| Fase | R1 | R2 | R3 | R4 | Puerta de integración |
| --- | --- | --- | --- | --- | --- |
| 0–2 h | Boot, DTO, bus, seed, export mínimo, balance validable | Grid, cámara, proxies, layout y APIs mock | Ocho perfiles, tareas/eventos/cohetes mock | Wireframe, locales, HUD mock, auditoría NASA | H0: proyecto arranca, APIs consumibles, export mínimo ejecuta |
| 2–6 h | Reloj/ledger/potencia/consumo, fin de partida | Colocar/conectar/producir y estados visibles | Cuatro tripulantes, trabajo/sueño/necesidades | Menú/selección/HUD/control manual | H1: avanzar tres soles, un coste, consumo único y efecto visible |
| 6–11 h | Guardar/cargar, autonomía/informe | Investigación, mina/refinería/impresión, scan | Manifiesto/arribo/desguace/intercambio, micrometeorito | Construcción/lab/crew/energía/cohete, avisos | H2: llegada sol 7, transacción única, carga restaurable |
| 11–16 h | Apoyo integrado, registro causal, admin de servicios | Brecha/aislar/reparar, reactor/pad/FX | Tormenta/flare/aleatorios, dosis/moral y cuatro llegadas | Inspector/reporte/admin/tutorial/Codex/audio | H3: campaña funcional sin stubs de dominio |
| 16–20 h | Pruebas integradas/ajuste balance | Arte mínimo y bordes de mundo | Determinismo, límites y reemplazos | EN/ES, NASA verificada, accesibilidad | H4: victoria/derrota y save/load reproducibles, sin pausas automáticas |
| 20–24 h | Congelar, exports, integrar correcciones | Corregir bloqueantes | Corregir bloqueantes | Ensayar demo y corregir legibilidad | H5: Web/Windows probados y demo cronometrada |

Cada integración usa res://scenes/integration/integration.tscn con controles de escenarios y res://scenes/integration/main.tscn como entrada final. R1 integra; los otros corrigen exclusivamente su sección. Reuniones de interfaz de 10 minutos en h2/h6/h11/h16/h20, dentro del presupuesto, no al final de cada día.

## Cortes y aceptación

Origen: handoff §1 «Scope order». Cortar primero minijuego de soldadura (mantener reparación por tarea), animación avanzada, detalle no esencial de moral y mejoras no esenciales. No cortar victoria/derrota, energía, consumibles, cohetes ni guardado. Live NASA es post-MVP. Modelos proxy son aceptables; estados sin potencia/daño/riesgo deben seguir legibles. Los recortes adicionales de sistemas obligatorios se elevan al usuario, no se eliminan silenciosamente.

Aceptación global: cuatro roles y propietario único; ninguna acción de UI calcula reglas; todo coste visible; 42 soles a x4 reproducibles; EN/ES; cuatro perfiles incluso idénticos; save/load sin duplicación; sin sistema de decisiones ni cambios de velocidad por alertas; fuentes reales archivadas; Web/Windows funcionales. Matriz técnica completa en guía «Pruebas mínimas».

## Presentación de diez minutos

Una partida natural dura 42×60/4 = 630 segundos: 10:30, sin pausas. Se mantiene una demo guiada de exactamente diez minutos usando avance administrativo, sin alterar la campaña; es la interpretación de planificación de la última confirmación del usuario. No confundir demo con prueba completa de campaña.

| Minuto | Contenido |
| --- | --- |
| 0–1 | Objetivo, selección repetible y colonia inicial |
| 1–3 | Laboratorio/panel, conexión y consumo; precondición: validar layout con presupuesto de 32 placas |
| 3–5 | Noche/batería y llegada/cohete con coste de carga |
| 5–7 | Tormenta o flare, refugio/reparación directos sin pausa forzada |
| 7–9 | Última llegada, autonomía e informe; avance hacia final |
| 9–10 | Victoria, fuentes NASA/EN-ES y cierre |

Admin debe avanzar por simulación normal y no resucitar una colonia derrotada. Ensayar una semilla y secuencia viable, incluyendo tiempo de ejecución del avance. Si el usuario exige diez minutos para una partida completa sin admin, es necesario aprobar un cambio de duración/velocidad; no está aprobado.

## Riesgos y mitigación

| Riesgo | Mitigación / propietario |
| --- | --- |
| Carga alta para 24 h | Hitos cortos, stubs tempranos y proxies; congelación h20 / todos |
| R1 cuello de botella por JSON y bus | Solicitudes de claves/firmas en h0–2 y lotes por hito; no commits simultáneos al archivo / R1 |
| Conflictos de escenas | R1 solo composición; R2 mundo; R4 UI; escenas pequeñas / todos |
| Consumo, tarea o llegada duplicada | Coordinador único y IDs idempotentes, pruebas de frontera/restore / R1 y dueño de regla |
| Tutorial insolvente | Validar layout con máximo seis túneles nuevos y 32 placas iniciales / R2 propone, R1 balancea |
| Paquete NASA sin evento real | Auditar curated_donki_events vacío y verificar procedencia antes de demo / R4 |
| Export falla tarde | Export mínimo h2 y prueba repetida solo tras cambios relevantes / R1 |
| Faltan decisiones de diseño | Propuestas explícitas en dudas; no afirmar aprobación / R1 |
