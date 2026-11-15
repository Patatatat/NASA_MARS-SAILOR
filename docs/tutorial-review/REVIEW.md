# Recorrido para principiantes y tutorial del robot

## Qué se probó antes de diseñar la guía

Cuatro rutas con servicios reales, la misma semilla y una tripulación seleccionable
desde el menú: ingeniería A, medicina, botánica A y ciencia A. Sin regalar recursos,
desbloquear tecnologías artificialmente ni cambiar el balance. Los avances de tiempo
del ensayo ejecutan los pasos normales de simulación y sus consecuencias.

| Ruta | Resultado observado | Decisión de diseño |
| --- | --- | --- |
| Laboratorio + una orden de investigación de 8 h | Tras 120 s, progreso 8/12 y panel todavía bloqueado. | Explicar órdenes de trabajo: una persona no investiga indefinidamente al terminar su tarea. |
| Laboratorio + dos órdenes de 8 h | Panel desbloqueado en unos 24,5 s a ×1, sol 1, con este equipo. | Enseñar dos asignaciones; después reanudar y observar la barra. El tiempo varía con el equipo y sus condiciones. |
| Esperar 90 s antes de investigar | Mismo trabajo y gasto, pero el panel se desbloquea en el sol 2. | Enseñar pausa y planificación antes de acelerar; esperar no sustituye la investigación. |
| Túnel → laboratorio → solar → reparar → primer cohete → batería | Cuatro personas vivas; 5 placas tras solar, 17 tras desguazar y 9 tras la batería. Capacidad de batería: 24. | No recomendar comprar una batería con las 5 placas restantes. Enlazar el aprendizaje con el cohete del sol 7. |

Resultados originales: `routes-before.json`; reproducción con la implementación
actual: `routes-after.json`. El equipo de ejemplo es una referencia para comparar,
no una composición obligatoria. No se afirma que sea una estrategia globalmente
óptima para ganar la campaña: se priorizan claridad, presupuesto y supervivencia
durante el aprendizaje inicial.

## Flujo integrado

El robot ofrece **Aprender conmigo**. El jugador decide si quiere la guía; no se
activa una pausa obligatoria solo por comenzar la partida.

1. Leer reservas, producción y consumo; conocer pausa y energía.
2. Construir un túnel y un laboratorio conectado.
3. Elegir Panel solar, asignar horas a dos personas y reanudar.
4. Construir el panel; distinguir día/noche, generación y almacenamiento.
5. Reservar 8×8 para el cohete y confirmar una carga útil: núcleo, repuesto y semilla.
6. Durante la espera, atender la primera fuga: enfocar, aislar, asignar reparación
   y reanudar para que se realice. Aislar no equivale a reparar.
7. Desguazar el primer cohete para recuperar materiales.
8. Investigar y construir la batería, conservando una reserva de placas.

Son 19 mensajes breves, con un solo objetivo activo y títulos/progreso visibles.
El sol 7 llega tras seis minutos de simulación a ×1, además del tiempo de lectura
pausada. La guía presenta ×2 como una opción durante la espera; no utiliza Demo.

Tras el recorrido, el robot también contextualiza tormentas/radiación, avisa cuando
quedan dos soles de combustible y explica el coste real del escaneo al desbloquearlo.
No intenta enseñar de golpe toda la industria avanzada ni todos los controles.

## Cómo funciona la ayuda

- Los mensajes usan lenguaje directo en español e inglés y la ventana del robot
  existente. El tutorial se coloca a la izquierda y deja el panel de herramientas
  utilizable. Las alertas críticas conservan una presentación central.
- Las acciones se validan leyendo edificios, tecnologías, horas pendientes, carga
  y cohetes reales. **Voy a hacerlo** cierra el mensaje; no completa el objetivo.
- **Mostrar objetivo** prepara controles y una casilla sugerida, sin construir ni
  gastar recursos. Si ya está ocupada, busca otra ubicación válida cercana.
- Tras construir en modo guiado se cierra la colocación y se confirma el éxito,
  evitando que «zona ocupada» parezca un fallo de la construcción recién hecha.
- El botón **Objetivo** recupera la explicación pendiente. **Ayuda** ofrece retomar
  o revisar la guía. Revisarla no borra la colonia ni exige duplicar edificios.
- Se reconocen acciones realizadas antes de recibir su mensaje. Si faltan horas
  o materiales, se ofrece una vía de recuperación; no se regalan recursos.
- La guía pausa ante nuevos objetivos/emergencias después de aceptarla. Reanudar
  sigue siendo una decisión del jugador para trabajar o esperar. Omitir libera una
  pausa creada por la guía, pero respeta una pausa manual del jugador.
- La simulación descarta el resto de un frame cuando el tutorial pausa: no acumula
  tiempo que se ejecute de golpe después de leer.
- El avance queda en el guardado, con campos opcionales validados; los guardados
  anteriores siguen admitidos. No se cambia la duración de los soles, costes,
  inventario inicial, producción, daño ni condiciones de victoria.

## Bugs corregidos durante el trabajo

| ID | Problema | Corrección y comprobación |
| --- | --- | --- |
| TUTORIAL-001 | La guía pedía construir sin enseñar asignación suficiente de horas. | Dos órdenes de 8 h, detección de horas pendientes y ayuda si se cancela trabajo. |
| TUTORIAL-002 | Los disparadores podían crear consejos desconectados del progreso; cerrar y completar se confundían. | Secuencia por estado real, con confirmación explícita solo en explicaciones. |
| TUTORIAL-003 | Una alerta crítica reconocida podía ocultar todos los mensajes siguientes. | Separar la alerta activa conservada en historial del aviso que debe mostrar el robot. |
| TUTORIAL-004 | Construir mientras estaba pausado no actualizaba de inmediato la energía del laboratorio. | Recalcular la vista de energía con delta cero al cambiar un edificio. |
| TUTORIAL-005 | La tarjeta podía crecer fuera de pantalla al cambiar un texto autoajustado. | Limitar el encabezado, desplazar el cuerpo si hace falta y ajustar tras el layout del contenedor. |
| TUTORIAL-006 | Una pausa emitida dentro de un tick podía dejar tiempo acumulado por ejecutar. | Detener el update en ese tick y descartar el remanente del frame. |
| TUTORIAL-007 | Retomar una guía ya terminada podía dejar una pausa sin objetivo. | Reiniciar explicaciones sin reiniciar la colonia y reconocer lo ya construido. |

## Pruebas reproducibles

Resultado final: **169 comprobaciones, 19 objetivos recorridos y cero fallos**
en la prueba guiada ([results.json](results.json)). Se generaron 22 capturas,
incluida la interfaz a escala 1,25 en 960×540. El log gráfico no contiene errores
de ejecución; conserva avisos de análisis estático ([engine.log](engine.log)).

Las siete suites de regresión terminaron con código 0: núcleo, mundo, misión,
flujo completo, victoria, pruebas adversas (32 comprobaciones) y estrés
(1000 acciones, 9795 comprobaciones). Sus logs están en esta carpeta.

Capturas representativas: [bienvenida](tutorial-welcome.png),
[asignar investigación](tutorial-research-workers.png),
[primera emergencia](tutorial-first-emergency.png),
[final de la guía](tutorial-finish.png),
[interfaz ampliada en 960×540](tutorial-large-ui-960x540.png) y
[tarjeta en 3840×2160](tutorial-layout-3840x2160-es.png).

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_beginner_routes.tscn beginner-routes-result.json
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_tutorial_flow.tscn tutorial-result.json
```

La prueba guiada usa clics dentro del viewport real para robot, construcción,
investigación, cohete, aislamiento y reparación. Selecciona opciones mediante las
señales públicas de OptionButton y acelera la simulación normal entre interacciones.
Comprueba guardado/carga, cancelación, recuperación de presupuesto, alertas,
revisión de la guía, pausa manual y automática y reabastecimiento posterior.

Se revisa la tarjeta en 960×540, 1920×1080, 3840×2160 y 3440×1440, en ambos idiomas,
incluidas las alertas centrales. Los resultados, logs y capturas representativas se
conservan junto a este informe. Los tests usan preferencias/guardados aislados vía
cliente MCP local; no sobrescriben partidas del jugador.

La evaluación es técnica y editorial. No se realizaron sesiones con jóvenes reales
ni se certifican exportaciones u otros sistemas operativos. Las suites headless
existentes pueden conservar avisos de objetos/recursos al cerrar, documentados en
sus logs; no se presentan como fugas de memoria resueltas del juego.
