# Verificación de la base inicial

Fecha: 14 de noviembre de 2026. Motor real: `4.7.2.stable.official.ed1daf0bf` (comprobado con `--version`).

Resultado histórico de la rama de simulación 2D, antes de esta integración: **387 comprobaciones, 0 fallos**; importación y escena headless aprobadas en Godot 4.7.2. No atribuir ese resultado al tablero 3D integrado descrito abajo.

Corrección posterior del historial: la regresión de escena reprodujo dos fallos antes del arreglo (actualizar contenido y refrescar estado reiniciaban scroll). `scenes/history_panel.gd` evita reemplazos innecesarios y conserva posición vertical/horizontal al actualizar. Los dos historiales tienen paneles de lectura con scroll independiente; el global conserva todos los hechos. El del inspector deja de ser una etiqueta truncada a dos entradas. La rueda no se propaga al contenedor exterior. La posición solo se reinicia al cambiar de partida/edificio. El runner incluye `tests/test_history_scroll.gd`; estas comprobaciones usan controles y layout reales en headless, sin probar físicamente la rueda en una ventana.

Estado de la integración: la escena de selección conserva los IDs de especialistas y la escena principal 3D consume eventos, ROBERTS, refugio/radiación, mejoras, mantenimiento, inspector e informes por sol sobre un mapa 32×32 con huellas. Los resultados de mantenimiento siguen siendo controles provisionales hasta integrar los minijuegos de Luque. El informe de referencia entregado para esta integración indica Godot 4.7.2, 407 comprobaciones de simulación, 20 comprobaciones del recorrido de interfaz, regresión de historial, arranque headless y una captura de Windows a 1100×760. Esos resultados pertenecen a esa validación externa; no se han reproducido sobre este árbol integrado. Aquí no se encontraron Godot ni PowerShell, así que el runner no pudo ejecutarse localmente.

Comando ejecutado desde la raíz:

```powershell
./tests/run_checks.ps1 -GodotExe 'C:/Users/emili/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
```

El runner ejecuta `--headless --path . --editor --import`, `--headless --path . --script res://tests/test_simulation.gd` y `--headless --path . --quit-after 10`. Límite externo de 60 segundos por proceso. Se prueban los scripts GDScript reales, sin modelo sustituto.

| Caso | Esperado | Observado | Resultado |
| --- | --- | --- | --- |
| Un sol sin producción | Aire 72, agua 152, comida 92 | 72, 152, 92 (tolerancia 0.000001) | OK |
| Solar + oxígeno, 30 s | Aire 82.4; potencia 6; demanda 4.2 | 82.4; 6; 4.2 | OK |
| Reactor + invernadero, 35 s | Comida 101.3; agua 144.8 | 101.3; 144.8 | OK |
| Invernadero sin agua, 25 s | Comida 92; déficit agua 8; salud 80 | 92; 8; 80 | OK |
| Frame largo con construcción y producción | 75 s iguales a 750 × 0.1 s | Snapshots y registros iguales | OK |
| Construcción inválida / repetida / sin masa | Ningún cambio | Estado anterior conservado | OK |
| Pausa y velocidad | Pausa no consume; 1 s a ×4 avanza 4 s | Coincide | OK |
| Snapshot modificado externamente | Dominio intacto | Copia profunda comprobada | OK |
| Relevo operativo / sin potencia / muertos | Tres finales excluyentes | Coincide, señal una vez por partida | OK |
| Muerte coincide con relevo | Derrota total | Derrota total | OK |
| Muerte del ingeniero | Solar pasa de 6 a 5 | 6 → 5 | OK |
| Tres sesiones con estrategia del README | Relevo logrado, sin estado residual | Tres relevos logrados | OK |
| Tormenta, aviso/inicio/fin | 55/75/125 s; solar 6 → 1.5, reactor 16.8 | Horarios y suministro coinciden; pérdida integrada 225 potencia·s | OK |
| Probabilidad 0 y 1 | Nunca / siempre ocurre | Coincide para ambos eventos | OK |
| Partículas sin médico, hasta 200 s | Dosis 43; salud 94 | 43; 94 | OK |
| Médico + refugio | Dosis .75 tras 25 s, .9375 tras otros 25 s | .75; .9375 | OK |
| Enterramiento | 10 masa + 20 regolito una vez, protección tras 25 s | Dosis .75 → 1.05 en dos soles | OK |
| Dos expediciones de 50 s | Potencia demandada 7; agua 1025.8, regolito 25 al regreso | Coincide; sin entrega anticipada/repetida | OK |
| Robot expuesto a tormenta con riesgo forzado 1 | Perdido sin carga, no reutilizable | Coincide | OK |
| Geólogo en hielo, riesgo forzado 0 | Carga 56.25, agua final 1037.05 | Coincide | OK |
| Retorno coincide con relevo | Aplicar carga una vez antes del final | Masa 955; no entrega después del final | OK |
| Eventos/misiones con frames distintos y misma semilla | Snapshots iguales, incluidas tiradas con probabilidades intermedias | Coincide | OK |
| Reutilización del mismo ROBERT | Tres salidas/retornos con IDs nuevos, 75 regolito | Coincide, comprobado antes de cambios funcionales | OK |
| Laboratorio solar en tormenta | Robot disponible, salida rechazada por laboratorio sin potencia; habilitada tras tormenta | Coincide; bloqueo condicional, no bloqueo permanente | OK |
| Mejora solar | Pagar 10 una vez; potencia 6 mientras obra, 9.6 al completar | Coincide | OK |
| Mejora oxígeno/invernadero/laboratorio/reactor | Producción, insumos y potencia de N2 según JSON | Coincide con aritmética independiente | OK |
| Científico | 20 de trabajo en 15 segundos, aporte extra 5 | Coincide | OK |
| Muerte del científico durante mejora | Tras 3 s quedan 16; al morir avanza 1 y quedan 15 | Coincide; estado sintético de salud para aislar una muerte individual | OK |
| Mejora inválida/repetida/nivel máximo/sin masa | Rechazo sin mutación ni doble cobro | Coincide | OK |
| Mejora pausada/refugio/apagada/final | Pausa/refugio detienen; apagado no detiene ni enciende; completa una vez al coincidir con relevo | Coincide | OK |
| Aviso/degradación/apagado de reactor construido a 10 s | Aviso a 110, potencia 11.76 a 135, apagado a 160 | Coincide | OK |
| Reactivación | Rechazo antes de 210; luego pagar 5 una vez y potencia 16.8 | Coincide; masa 930 tras reactor/lab/reactivación | OK |
| Resultado duplicado/antiguo/inválido | Ninguna mutación | Coincide, incluido callback de partida anterior | OK |
| Intentos/abandono/tiempo real | Dos intentos, abandono consume intento; timeout a 15 reales en x4 y x0.5 | Coincide; 14.9 aún activo, 15 cerrado | OK |
| Crisis durante minijuego | Suspender sin consumir tiempo/resultado; reanudar al terminar | Coincide | OK |
| Límite de avisos | Máximo 2 pendientes, separados por intervalo global | Coincide con 4 reactores candidatos | OK |
| Apoyo ROBERTS | ×0.8 si hay uno disponible; ×1 si ambos están fuera | Coincide | OK |
| Oxígeno degradado | Cambio de aire por paso: 12×.7/25 − 8/25 = .016 | .016 | OK |
| Informe con retorno de hielo | Variación de agua de ese sol: +45 − 8 = 37 | 37; contabilidad de tres recursos en tres soles consistente | OK |
| Inspector y causas | Copia profunda, hechos reales, invernadero sin agua 15 s | Coincide; informe parcial al morir y sin duplicados tras final | OK |

Importación y arranque/cierre de escena headless: sin errores. La primera importación encontró permisos insuficientes para preferencias del editor; se resolvió aislando `APPDATA` y `LOCALAPPDATA` durante las pruebas, sin cambiar ajustes del usuario. El runner restaura ambas variables al terminar. Los `.gdignore` impiden importar especificaciones y fixtures de skills como parte del juego.

Datos añadidos: `events`, `radiation`, `roberts` en el JSON. No se alteraron costos, reservas ni tasas económicas originales. Efectos nuevos: penalización solar por tormenta, demanda continua de soporte de expediciones, carga de retorno y dosis con protección. Contratos nuevos documentados en `SIMULATION_INTERFACE.md`; la escena técnica ya los consume. Las pruebas fuerzan probabilidad/recursos solo en copias de configuración, nunca mediante controles ocultos de la partida.

Datos añadidos para mejoras: `upgrades` y `scientist_upgrade_duration_multiplier`; nivel 1 conserva sus valores. La escena consume preview/comando de mejora y explica errores de ROBERTS. Las pruebas del motor no verifican visualmente esos textos ni la interacción del nuevo selector.

Reporte manual de ROBERTS: mensaje posiblemente «inválido», sin semilla ni configuración. No se reprodujo ese caso exacto. Se verificaron tres usos y el rechazo legítimo durante tormenta. No se modificó la lógica ni el balance de expediciones para esconder el reporte.

Datos añadidos para este incremento: `balance.json.maintenance` (cadencia, límites, producción degradada, enfriamiento, precio de reactivación, reloj real e influencia de ROBERTS). Nuevos módulos: `maintenance_system.gd` y `sol_report.gd`. No hay gastos ni reglas duplicados en botones; el banco técnico solo envía resultados de prueba. Los resúmenes miden producción/consumo/importación/faltantes/bloqueos; no inventan explicaciones ni calculan el puntaje de Andrés.

Cambio observado en regresión: las tres sesiones anteriores fallaron inicialmente al introducir mantenimiento porque la estrategia ignoraba todos los avisos. Se adaptó esa estrategia para atender solicitudes; las pruebas independientes de degradación/apagado conservan la consecuencia nueva. No se cambió el balance para disimular el fallo. El límite del minijuego usa tiempo real separado de la economía, incluida la fracción de paso a x0.5.

Pendiente de Rafael: interacción real en ventana, legibilidad del banco técnico y pruebas manuales del README. No se ha verificado exportación web, navegadores, móvil, rendimiento, equilibrio de estrategias ni el contenido del juego completo. Las tres sesiones automáticas no sustituyen tres partidas manuales de la futura versión integrada. Luque debe aportar sus dos minijuegos y Andrés conectar el adaptador de sesiones, inspector e informe.
