# Identificación de imágenes generadas con S.I.

Los seis retratos seleccionables y el robot del tutorial/alertas llevan una marca
**S.I.** discreta en la esquina inferior derecha del área de imagen. La selección
de tripulación y los créditos explican **S.I. = Super intelligence**.

La marca utiliza texto claro con fondo oscuro semitransparente. Sigue el tamaño
y el encuadre de cada imagen, incluido el espacio libre al ajustar la proporción
del robot. Se dibuja como parte de la interfaz, no altera las texturas originales
y no intercepta el ratón ni recibe foco.

La suite del menú comprueba las dos páginas de retratos, cambios de idioma y seis
resoluciones. Selecciona un personaje pulsando directamente sobre la marca para
comprobar que deja pasar el clic. La suite del tutorial recorre sus 19 objetivos
y verifica que las marcas del robot permanecen dentro del retrato en las capturas
de tutorial y alerta, desde 960×540 hasta 4K y formato ultrapanorámico.

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/ui/run_menu_regressions.tscn menu-result.json
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_tutorial_flow.tscn tutorial-result.json
```

Las pruebas utilizan el cliente MCP local y preferencias/guardados aislados.
Resultado: **1077 comprobaciones de menú y 213 del tutorial, sin fallos**.
Se generaron cinco capturas de menú y veintidós del tutorial. Los logs gráficos
no contienen errores de ejecución. Evidencias: [tripulación](crew.png),
[robot](robot.png), [robot con interfaz ampliada](robot-large-ui.png),
[resultado de menú](menu-result.json) y [resultado del tutorial](tutorial-result.json).

La identificación implementa la petición del equipo; no supone una auditoría
de requisitos del concurso, cuyo reglamento no se ha proporcionado.
