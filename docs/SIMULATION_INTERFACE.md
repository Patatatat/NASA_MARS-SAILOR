# Contrato inicial de simulación · v1

Esta guía corresponde al código ejecutable de la base inicial. El plan vigente y el diseño v0.4 orientan el alcance; `local-only/Especificaciones/00-main-handoff.md` y `01-interface-guide.md` son referencias históricas locales, no incluidas en el repositorio. No se cargan sus JSON. Este incremento no completa el juego del fin de semana.

## Uso por Andrés

Instanciar `preload("res://domain/simulation.gd").new()`; cargar `simulation_config.gd.load_file()`, comprobar `ok`, pasar `data` a `configure()`. Después llamar `reset_run(crew_ids, seed)` y construir durante planificación. `start_run()` comienza la simulación. Un único controlador llama `advance(delta)` por frame. No usar simultáneamente otro reloj o Timer para la economía.

No requiere autoloads. La instancia es un `RefCounted` independiente de escenas. Convención: los miembros con `_` son internos; GDScript no impone privacidad. Todas las lecturas públicas devuelven copias profundas. No editar miembros internos.

| API | Entrada / salida |
| --- | --- |
| `configure(data: Dictionary)` | Valida y copia datos; solo antes de inicializar la partida. Para otra configuración crear otra instancia. |
| `reset_run(crew_ids: Array, run_seed: int = 1)` | Exactamente 4 IDs únicos de los 6 disponibles. Reinicia reloj, edificios, registro, salud y final. Error conserva la partida anterior. |
| `get_catalog()` / `get_snapshot()` | Copias profundas de configuración / estado. |
| `preview_placement(kind: String, cell: Vector2i)` | Comprueba ocupación, tipo, distancia y presupuesto; devuelve costo y duración sin mutar. |
| `place_building(kind: String, cell: Vector2i)` | Revalida, cobra una sola vez y reserva la celda; retorna `result.building_id`. |
| `set_enabled(building_id: String, enabled: bool)` | Enciende/apaga; repetir mismo estado no duplica registro. Hábitat no apagable. |
| `start_run()` | Solo desde planificación. |
| `set_paused(paused: bool)` | Solo durante simulación. |
| `set_speed(speed: float)` | 0.5, 1, 2 o 4. |
| `advance(real_seconds: float)` | Delta real finito, no negativo. Pasos lógicos de 1 segundo. |

Los comandos retornan `{ok, error_code, cost, result}`. Un fallo no muta. Códigos principales: `select_four`, `invalid_crew`, `invalid_phase`, `invalid_building`, `outside_grid`, `occupied_cell`, `reactor_too_close`, `insufficient_mass`, `unknown_building`, `habitat_required`, `invalid_speed`, `invalid_delta`, `busy`.

Señales: `state_updated(snapshot)` después de una operación completa y `run_finished(result)` una sola vez por partida. No llamar comandos síncronos desde estas señales: se rechazan para evitar reentrada. Encolar la intención para el siguiente frame. No modificar el payload compartido entre suscriptores; obtener otra copia si se necesita manipularlo.

Snapshot: fase (`planning`, `running`, `finished`), semilla, segundos enteros, sol mostrado (1–12), soles completados (0–12), pausa, velocidad, recursos, tripulación, edificios, potencia, déficits acumulados, registro y resultado. Cada edificio tiene ID, tipo, x/y, nivel 1, habilitación, potencia, tiempo restante y aviso. Los IDs se reinician con la partida; descartar referencias de la sesión anterior.

## Reglas y unidades de esta base

- Masa/regolito/aire/agua/comida son cantidades de balance; potencia es tasa disponible, nunca inventario ni batería. Salud 0–100. No son cifras científicas ni parámetros médicos.
- Configuración nominal: 12 soles × 25 segundos. Datos numéricos provisionales en `data/balance.json`; validación estructural, tipos numéricos finitos y no negativos. Los valores de duración de sol y construcción son enteros. Grid fijo 6×6.
- Hábitat en (2,2), reactor a distancia Manhattan mínima 2. Un edificio ocupa una celda. Construir paga al ordenar; durante planificación los temporizadores están detenidos. Al iniciar, una obra de 5 segundos termina al final del tick 5 y produce desde el 6. No hay cancelación ni reembolso.
- Prioridad eléctrica provisional: hábitat → oxígeno → invernadero → laboratorio; empates por orden de construcción. Cada consumidor requiere toda su potencia. Las fuentes no necesitan potencia. No hay noche ni tormentas aún.
- Orden por segundo: resolver potencia → producción (riego antes del consumo de la tripulación) → consumos separados → registrar faltantes y daño → muerte → completar obras → actualizar soles → recalcular potencia/bonus → evaluar final.
- Conversión de tasas: `cantidad_por_sol / sol_seconds`. Invernadero sin agua suficiente para el paso no produce ni cobra riego. Falta de potencia detiene producción. Producción precede al consumo y puede cubrirlo en el mismo paso.
- Daño provisional por cada recurso: unidades faltantes × tasa de daño / vivos al comenzar el consumo. La salud se reduce por igual entre vivos. Muertos dejan de consumir y aportar bonus desde el próximo paso; potencia recalculada inmediatamente.
- Bonus implementados: ingeniería ×1.2 suministro, botánica ×1.25 aire/comida del invernadero, sistemas ×0.8 demanda del generador. Medicina, ciencia y geología son seleccionables **sin efecto todavía**; requieren sus sistemas posteriores.
- Final: cero vivos → `total_defeat` (prioridad incluso al coincidir con relevo); a 300 s, vivos + hábitat energizado + aire positivo → `relief_achieved`; en otro caso `partial_defeat`. Definición inicial explícita de soporte operativo: hábitat energizado. No calcula puntaje.
- El tiempo fraccionario se acumula internamente; `get_snapshot()` no es un formato de guardado/restauración. Semilla registrada, sin sorteos aún. No se promete reproducibilidad entre versiones del motor.

Registro causal: `id`, `seconds`, `reason`, `target`, `details`. Incluye pago, terminación, encendido, déficit medido, producción bloqueada por agua, muerte y final. No basta para calcular todavía todos los componentes del informe final. No inferir muertes hipotéticas o consecuencias no medidas.

## Próximos contratos / Luque

`start_upgrade`, `send_robert`, `bury_habitat` y `apply_maintenance_result` **no existen aún**. Tampoco hay pronóstico, eventos, dosis, refugio ni mantenimiento. No conectar botones de esos sistemas a descuentos locales.

El contrato de Luque del plan sigue como objetivo: escena Godot con `iniciar(building_id, dificultad)` y señal `resultado(success, elapsed_seconds)`. Antes de integrarlo se implementarán sesiones de mantenimiento con ID único, validación del objetivo y consumo del resultado una sola vez. Esta base no aplica premios ni penalizaciones falsos para simular esa integración.

## Integración en el repositorio del equipo

Este directorio no era un repositorio Git. No se creó uno ni se hizo commit/push. Al integrar, conservar los `.gd.uid` generados y copiar `domain/`, `data/balance.json`, `tests/` y esta guía. La escena técnica es opcional. Andrés debe combinar el `project.godot` con el suyo; no sobrescribir su escena principal. Ignorar `.godot/`, `test-results/` y archivos temporales.

Los directorios `skills-rafael/`, `skills-equipo/` y `Especificaciones/` se conservan dentro de `local-only/`, junto con planes personales y resultados de pruebas. Esta carpeta y `.agents/` están excluidas mediante `.gitignore`. No enviar logs, preferencias del motor ni cachés generados.
