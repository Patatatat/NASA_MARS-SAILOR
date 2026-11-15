# Integración local con Andrés · 14 de noviembre de 2026

Fuentes: base de Rafael `73ff6e8`, rama de Andrés `c76d83d` (`Patatatat/NASA_MARS-SAILOR`, `andres/interfaz`). La base local previa quedó en commit y copia adicional ignorada en `local-only/antes-fusion-andres-20261114/`. La fusión queda local, sin push automático.

## Prioridad aplicada

| Coincidencia | Resolución |
| --- | --- |
| Datos y reglas | Los archivos `data/balance.json`, `domain/simulation.gd`, `simulation_config.gd`, `maintenance_system.gd`, `run_summary.gd` y `sol_report.gd` se verificaron por hash contra la base local; permanecen idénticos. |
| Recursos/duración/mapa | Se conservan cuatro existencias, energía almacenada/día-noche, 42 soles de 60 s y mapas variables. No se restauran masa/agua ni duración antigua. |
| HUD/cámara/resumen | Se conserva pantalla 3D completa, paneles desplegables, cámara con rueda pulsada, inspector sin apagado accidental y resumen final. |
| Selección de especialistas | Se conserva validación de cuatro distintos, pronóstico y seis especialidades activas; se agrega traducción sin recuperar mensajes antiguos de bonus pendientes. |
| Entrada del juego | Se añade el menú de Andrés; Jugar conduce a la selección propia en lugar de saltársela. |
| Tamaño de pantalla | Se mantiene base 1600×900, ventana inicial 1440×810 y disposición adaptable. El gestor nuevo no impone 1100×760 como valor inicial. |

## Funciones nuevas incorporadas

- Escenas de menú principal y ajustes de audio de Andrés, con sus IDs/UIDs originales.
- `SettingsManager` como autoload para preferencias persistentes. Solo conoce presentación/AudioServer, no cambia inventarios ni fórmulas de simulación.
- Volumen principal, música y efectos conectados a buses `Master`, `Music`, `SFX`. Se crean los dos buses secundarios si faltan, con envío al principal. No se añadieron archivos de audio.
- `preferences_panel.gd` adapta las tres categorías de ajustes (sonido/pantalla/idioma) al HUD conservado. Flechas cambian de categoría. Incluye resolución, pantalla completa e idioma ES/EN.
- Traducciones de Andrés conectadas a menú, selección y HUD; se agregan claves de las funciones propias. Esto no certifica traducción completa de toda la narrativa.
- Atajos Espacio, Esc/Tab y A/D/W/S/flechas, sin sustituir F11 ni los controles de ratón de Rafael. Los campos editables conservan el procesamiento normal del teclado antes de los atajos no manejados.
- Retorno explícito al menú desde Ajustes del HUD, indicando que termina la partida actual.
- Etiquetas de ROBERTS/enterramiento ajustadas al contrato local de alimento/regolito. Costos de enterramiento se leen del balance, no de cifras de la rama antigua.

Los botones Cómo jugar y Créditos ya estaban en el menú de Andrés sin callbacks; se conservan como pendientes. El sistema de crisis/decisiones y las otras fases del documento de bucle no se implementan incidentalmente por fusionar estas ramas.

## Verificación real

Ejecutado en Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
./tests/run_checks.ps1 -GodotExe 'C:/Users/emili/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
```

Resultado: **78 comprobaciones del contrato actual de simulación y 57 del recorrido de interfaz, 0 fallos**; regresión del historial, importación y arranque también correctos. Cada proceso tiene límite de 60 s y se comprueban logs, código de salida y marcadores.

La suite actual verifica reglamento preservado, transacciones sin doble cobro, mapa reproducible, consumo de alimento/aire, carga/descarga y noche, pausa/velocidad, retorno/reutilización de robots, mejoras, mantenimiento, radiación, eventos y resumen final. Ejemplos aritméticos: energía tras construir solar y avanzar 10 s = `160 − 5 + 5×(6−1) = 180`; retorno de alimento tras 130 s = `100000 − 16×130/60 + 45`; reactivación = `1000 − 45 − 5 = 950` regolito.

El recorrido de interfaz comprueba menú → selección → tablero, HUD adaptable, cámara/picking, expedición, mejora, mantenimiento, final/resumen, reinicio, retorno al menú/ajustes y cambio ES/EN. Un volumen de 62% se verifica en `AudioServer` y se restauran las preferencias previas de audio de la prueba.

Las suites históricas `test_simulation.gd` y `test_run_summary.gd` no validan el nuevo esquema (todavía acceden a masa/agua y ventanas antiguas). Se conservaron intactas y el runner las sustituye por `test_current_simulation.gd`, no por cambios de reglas para satisfacer pruebas obsoletas. No se reclaman las 407/168 comprobaciones antiguas para esta nueva base.

Pendiente: recorrido manual en ventana/navegador, sonido con assets reales, cobertura completa de todas las reglas de la migración y balance de estrategias. Una importación/ejecución headless no prueba legibilidad ni reproducción física de audio.
