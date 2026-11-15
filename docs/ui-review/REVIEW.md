# Revisión de interfaz y usabilidad

Se revisaron las pantallas mediante ejecuciones gráficas de Godot 4.7.2,
iniciadas con el cliente MCP local. La revisión combina inspección visual,
medición de controles y pruebas de interacción dentro del motor.

## Problemas encontrados y cambios

| Problema | Corrección aplicada |
| --- | --- |
| Dos paneles simultáneos ocupaban gran parte del mapa. | Un único panel contextual, con retorno a herramientas y cierre. La cámara se centra en el espacio libre. |
| Siete botones de navegación consumían tres filas. | Selector de actividad con las siete opciones y selección visible. |
| Tipografía pequeña y escalado sin control del usuario. | Texto de al menos 18 unidades de interfaz; controles de al menos 44 de alto; tamaños Normal, Grande y Muy grande. |
| Informe y administración dependían de símbolos ambiguos. | Botones con palabras: Informe, Historial, Ayuda y Demo. |
| Construcción comenzaba con coordenadas inválidas. | Elegir en el mapa es la acción principal; las coordenadas son opcionales. Costes legibles antes de construir. |
| La selección de perfiles era una lista larga y difícil de corregir. | Dos columnas y cuatro plazas explícitas; cada plaza se puede retirar; inicio habilitado al completar el equipo. |
| Reparar exigía buscar entre muchas acciones repetidas. | Método, astronauta y acción principal; reparación antes de retirada e historial. Retirada con confirmación. |
| Investigación repetía el mismo error para cada tecnología. | Selector de descubrimiento, explicación única, progreso y asignación de trabajo. |
| La guía empezaba hablando de paneles solares que todavía no existían. | Primero orienta a construir el laboratorio; la explicación de la noche aparece al colocar un panel solar. |
| Se mostraban IDs, nombres internos y diccionarios. | Nombres traducidos, costes y producción en lenguaje legible. |
| Cambiar valores podía destruir el campo activo. | Validación de coordenadas sin reconstruir el formulario; borradores de carga, escaneo y horas conservados. |
| Cambios rápidos de página e idioma notificaban páginas retiradas. | Desconexión de sus observadores antes de retirarlas. |
| La etiqueta de pausa podía quedarse desactualizada al iniciar otra misión. | Sincronización con el estado real del reloj; velocidad elegida visible. |
| El final era un mensaje dentro del HUD. | Pantalla de resultado centrada, fondo atenuado y retorno al menú. Mensaje de derrota orientado a volver a intentarlo. |

## Resolución y legibilidad

Se mantiene una base lógica de 1280×720 y se abre una ventana de 1600×900.
Godot escala el contenido al tamaño físico; la distribución usa el espacio
disponible, también en ultrapanorámica. No se agrandan individualmente paneles
con valores de píxeles fijos para cada monitor.

En 1920×1080, un texto base de 18 se presenta aproximadamente a 27 píxeles y
un botón de 44 a 66 píxeles. La opción Muy grande amplía el conjunto un 25 %.
Los formularios largos tienen desplazamiento vertical; los controles globales
y las alertas permanecen dentro de la pantalla. Cerrar el panel devuelve ese
espacio al mapa.

Contraste calculado entre texto y fondo de botones: normal **6,22:1**, al pasar
el puntero **5,84:1**, seleccionado **5,74:1** y acción principal **5,89:1**.
La selección combina fondo y estado del control; las fugas se anuncian con
texto y signo de advertencia. El foco de teclado tiene borde visible.

## Verificación

La auditoría genera **106 capturas** y comprueba estas resoluciones reales:

| Resolución | Uso |
| --- | --- |
| 960×540 | Ventana pequeña y escala Muy grande |
| 1280×720 | Base de comparación |
| 1920×1080 | Full HD, teclado y escala Muy grande |
| 2560×1440 | QHD |
| 3840×2160 | 4K |
| 3440×1440 | Ultrapanorámica |

Incluye menú, selección, ajustes, siete herramientas, inspector de brecha,
informe, historial, victoria y derrota. Comprueba EN/ES, controles dentro de
límites, botones de al menos 44 unidades, mapa con al menos el 50 % del ancho,
selección de edificios mediante eventos de ratón en todas las resoluciones,
pausa con Espacio, cierre con Esc, escritura sin mover la cámara y cancelación
de retirada. Las siete suites de regresión del proyecto también se ejecutaron.

Para repetir:

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/ui/run_layout_audit.tscn ui-audit-result.json
```

Los guardados de la prueba están aislados de la partida del jugador. Las
capturas de ejemplo son [HUD Full HD](hud-1920.png), [HUD ampliado en ventana
pequeña](hud-large-960.png), [selección](crew-1920.png), [reparación](repair-1920.png),
[investigación en inglés](research-en-1920.png) y [resultado](victory-1920.png).

## Siguiente validación con público joven

Esto es una revisión técnica y heurística; no sustituye sesiones con niños.
Conviene observar, sin dar instrucciones, si pueden formar un equipo, colocar
un edificio, encontrar la pausa y reparar una fuga. Registrar dónde dudan,
qué términos no entienden y cuándo necesitan ayuda. La interfaz facilita esas
tareas, pero su comprensión por edades todavía debe medirse con jugadores.
