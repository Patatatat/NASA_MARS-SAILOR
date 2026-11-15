# Revisión del menú principal y selección de personajes

Base revisada: `350643c` de `andres/interfaz-nueva`.
Alcance: menú principal, ajustes, selección y preferencias de ventana/sonido.
No se modifica MissionMain, HUD, mundo, simulación ni reglas de la partida.
La suite monta únicamente MainMenu y sus pantallas: no crea una misión,
comprueba que GameState siga vacío y captura la señal de inicio sin ejecutar gameplay.

## Fallos reproducidos y correcciones

| ID | Reproducción / causa | Corrección y verificación |
| --- | --- | --- |
| MENU-001 | Abrir Sonido: se ve el tirador, pero la pista tiene altura mínima cero y no hay medición numérica. | Pista con grosor, relleno de color y porcentaje actualizado en los tres canales. Ratón y flechas cambian el valor y las preferencias se guardan. Captura: `sound.png`. |
| MENU-002 | Cambiar resolución: también se sustituye el viewport lógico 1280×720 por el tamaño elegido, alterando las coordenadas y escala interna. | La resolución modifica la ventana nativa y mantiene el viewport del proyecto. Se comprueban 1280×720, 1600×900 y 1920×1080, entrada/salida de pantalla completa y restauración del tamaño elegido. |
| MENU-003 | Seleccionar una tarjeta: se destruye y reconstruye el botón enfocado. La navegación con teclado pierde el foco. | Identificadores estables y recuperación del foco en la tarjeta o paginación. Probado con clic y selección/deselección consecutiva mediante Enter, sin reenfocar. |
| MENU-004 | Cargar settings.cfg con NaN, escala negativa, resolución inválida o fullscreen de tipo texto: los valores se aceptan sin validación. | Se reutiliza la validación al leer el archivo. Se rechazan tipos incorrectos y volúmenes no finitos; las operaciones inválidas no alteran preferencias válidas. |
| MENU-005 | El botón principal «Volver» cierra la aplicación; Escape también la cierra desde el menú raíz. | Etiqueta explícita «Salir / Quit». Escape vuelve desde selección y ajustes, sin cerrar inesperadamente el menú principal. |
| MENU-006 | En 960×540 hay botones de 33–40 px de alto, incluidos Inicio, Volver y paginación. | Se amplían los destinos de clic a un mínimo de 44 px. Se comprueban límites y tamaños en ambas páginas de selección, menú y cuatro pantallas de ajustes, en seis resoluciones y dos idiomas. |

## Pantalla completa incrustada en Godot

El modo nativo de pantalla completa **ya funcionaba en la prueba inicial con una
ventana independiente**. No se atribuye ese comportamiento a una corrección nueva.
Godot no permite cambiar el modo de ventana cuando el juego está incrustado en el
editor: [documentación oficial de Godot](https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html).

Ahora se detecta `Engine.is_embedded_in_editor()`, se rechaza el cambio sin guardar
una preferencia ficticia y se explica cómo abrir una ventana independiente.
Desactiva **Embed Game on Next Play / Incrustar juego en la próxima ejecución**
para probar los cambios nativos. Esta rama de detección no se probó dentro de un
editor incrustado; las pruebas gráficas se ejecutan en procesos independientes.

En pantalla completa se utiliza el tamaño del monitor. El selector conserva el
tamaño que se aplicará al volver a ventana; la interfaz explica esta distinción.
No se implementa un selector de resolución de renderizado del gameplay.

## Prevenciones adicionales

- Se conserva el OptionButton mientras termina de cerrar su popup nativo, evitando
  reconstruir toda la página en su callback y perder el foco.
- Abrir Ajustes repetidamente no crea capas duplicadas.
- Ajustes solo consume Escape como atajo propio; deja pasar otras teclas.
- El texto de créditos se redistribuye debajo del botón Salir.

## Evidencia y ejecución

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/ui/run_menu_regressions.tscn menu-result.json
```

El cliente local MCP inicia una ejecución gráfica aislada, consulta su salida de
depuración y permite que termine por sí misma. No se abren editores ni se detienen
sesiones ajenas. Cada ejecución utiliza su propio directorio de preferencias y
guardados bajo `.test_playable/`.

`before.json` recoge la primera batería de 34 comprobaciones: 14 fallos antes de
corregir. `after.json` recoge la batería ampliada final: **909 comprobaciones,
cero fallos**. `engine.log` no contiene errores de ejecución. El número
de comprobaciones aumenta porque se añadieron navegación, ratón, teclado,
persistencia, límites, tamaños y una matriz de seis resoluciones en EN/ES.

Las resoluciones solicitadas y efectivamente observadas se guardan en `after.json`:
960×540, 1280×720, 1920×1080, 2560×1440, 3440×1440 y 3840×2160.
Las tres opciones del selector de resolución se prueban aparte. La suite abre el
desplegable con ratón y activa su señal pública `index_pressed` para recorrer las
opciones; no simula un clic físico sobre cada fila de la ventana popup del sistema.

Capturas reales del motor: `main.png`, `sound.png`, `screen.png`,
`fullscreen.png` y `crew.png`. Se revisaron visualmente Sonido, Pantalla y Selección.
Las advertencias previas de GDScript sobre nombres/señales no forman parte de estas
correcciones. Esta revisión no certifica exportaciones Web ni otros sistemas operativos.
