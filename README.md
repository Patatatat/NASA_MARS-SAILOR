# BEYOND OUR HOME — prueba local

Registro de bugs corregidos, reproducciones y pruebas adversariales:
[docs/qa/BUGS.md](docs/qa/BUGS.md). Incluye la barra de investigación, el ciclo
día/noche y comprobaciones de guardado, producción, tareas y cohetes.

Abre `project.godot` con Godot 4.7.2 y pulsa **F5**. La escena de entrada es
`scenes/integration/main.tscn`. Elige Nueva partida y cuatro astronautas; puedes
repetir perfiles. Los servicios reales de simulación, mundo, misión e interfaz
están conectados; los dobles de pruebas no forman parte del juego.

## Primer recorrido

1. Construir: coloca un túnel en **14,17** y un laboratorio en **14,18**.
2. Laboratorio: inicia Panel solar y asigna **8 horas** a dos astronautas.
3. Cuando se desbloquee, construye el panel en **10,18**.
4. Cohete: reserva una zona **8×8** con origen **22,22**, añade carga y confirma.
   El primer cohete llega al inicio del sol 7. Si preparas tarde el manifiesto,
   usa Procesar llegada en esa misma pestaña.
5. Selecciona un edificio en el mapa para abrir su inspector. Desde allí puedes
   encender/apagar, plantar, imprimir, proteger/limpiar paneles, reparar brechas,
   aislar túneles, reabastecer el reactor y retirar edificios no protegidos.
6. Tras la llegada, el panel Cohete permite desguazar o intercambiar tripulación
   si incluiste un reemplazo. Ambas acciones son excluyentes.

El selector del panel derecho permite cambiar entre las siete herramientas.
Construir ofrece colocación con el ratón; activa **Usar coordenadas (opcional)**
si quieres seguir las posiciones de este recorrido. Seleccionar un edificio
abre su inspector en el mismo panel; **Paneles** vuelve a las herramientas.

WASD/flechas desplazan la cámara; rueda acerca/aleja; clic izquierdo selecciona
o coloca; clic derecho cancela la colocación. **Espacio** pausa o continúa y
**Esc** cierra el panel y cancela la colocación. Escribir en un campo no mueve
la cámara. Las alertas no pausan el juego.

Los botones **Informe**, **Historial** y **Ayuda** tienen etiquetas explícitas.
**Demo** abre controles de demostración que ejecutan la simulación normal y no
evitan una derrota. En **Ajustes → Tamaño de la interfaz** puedes elegir Normal,
Grande o Muy grande. La escala se conserva con la partida guardada.

La ventana inicial es de 1600×900; el contenido escala proporcionalmente y se
redistribuye al cambiar resolución. El informe de revisión y sus capturas están
en [docs/ui-review/REVIEW.md](docs/ui-review/REVIEW.md).

La campaña dura 42 soles de 60 segundos a ×1. La prueba de victoria muestra
una estrategia viable con reparación y recargas del reactor. Los modelos 3D
son proxies. Las exportaciones Web/Windows y las reglas pendientes del handoff
(por ejemplo, relación plataforma/zona y mejoras de blindaje) no se consideran
validadas por estas pruebas locales.

## MCP y verificación

Para instalar el servidor tras clonar el repositorio, sigue
[tools/godot-mcp/README.md](tools/godot-mcp/README.md).
La configuración local está en `.codex/config.toml` y se excluye de Git.
Para comprobar el servidor:

```powershell
node tools/godot-mcp/verify.mjs
node tools/godot-mcp/check-playable.mjs
node tools/godot-mcp/check-playable.mjs res://tests/ui/run_layout_audit.tscn ui-audit-result.json
```

La segunda orden abre una ejecución gráfica de prueba mediante MCP, comprueba
interacciones y guarda capturas de 1280×720 y 960×540 en `.test_playable/`.
Usa guardados aislados y deja que su propia ejecución termine. No abre editores
ni detiene sesiones existentes. Un chat ya iniciado puede necesitar una sesión
nueva del proyecto para disponer de las herramientas MCP de forma nativa.

La tercera orden audita menús, selección, ajustes, las siete herramientas,
inspector, informe, historial y resultados en seis resoluciones, incluyendo
1920×1080, 2560×1440, 3840×2160 y 3440×1440. Comprueba escala ampliada, EN/ES,
límites, tamaños de botones, clics de mapa y navegación con teclado.

Las suites ejecutables están en `tests/{core,world,mission,ui,integration}`.
La nueva `run_playable_flow.tscn` cubre reiniciar investigación, falta de energía,
autoguardado semanal, plantar desde UI, protección, llegada tardía, entidades
visuales, edición de coordenadas, límites del HUD y selección con clic real.
