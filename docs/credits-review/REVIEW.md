# Créditos y referencias de los edificios

Acceso: menú principal → **Créditos**. La primera sección muestra los cinco
integrantes y sus funciones, en el orden y con los nombres facilitados. La segunda
contiene once tarjetas, siguiendo el documento que utilizó el artista 3D.

Se mantienen Jura, el fondo de Marte, colores terrosos, contornos y estados de foco
del menú. Volver y Escape cierran la ventana y devuelven el foco a Créditos.
Las fuentes tienen desplazamiento, enlaces individuales y direcciones visibles.
Los textos están en español e inglés; consultar las tarjetas funciona sin conexión.

## Procedencia y verificación

Documento proporcionado por el usuario:
[tarjetas_colonia_marciana_nasa.md](tarjetas_colonia_marciana_nasa.md), copiado sin
modificaciones para conservar su procedencia. Se utilizó como referencia de
diseño; sus recomendaciones de presentación no se trataron como instrucciones
para modificar las reglas del juego.

El 15/11/2026 se revisaron los registros y artículos oficiales. Se incorporaron
**15 enlaces verificados en 11 tarjetas**, con títulos y URL en
[data/credits.json](../../data/credits.json). Los textos distinguen el estudio o
tecnología real de la adaptación del artista. No cambian edificios ni balance.

| Edificio | Fuente principal | Alcance mostrado |
| --- | --- | --- |
| Hábitat | [NTRS 19940021200](https://ntrs.nasa.gov/citations/19940021200) | Estudio universitario de seis módulos esféricos semienterrados; cuatro más uno es una adaptación. |
| Laboratorio | [NTRS 19930000364](https://ntrs.nasa.gov/citations/19930000364) | Propuesta cilíndrica; no acredita la distribución en Y ni su cubierta. |
| Solar | [NTRS 20190000437](https://ntrs.nasa.gov/citations/20190000437) | Concepto desplegable CTSA; no prescribe seis paneles ni protección absoluta ante tormentas. |
| Reactor | [Fission Surface Power](https://www.nasa.gov/exploration-systems-development-mission-directorate/fission-surface-power/) y [TDU](https://ntrs.nasa.gov/citations/20170000949) | Fisión y gestión térmica; el TDU usa un simulador de núcleo calentado eléctricamente, no demuestra un reactor desplegado en Marte. |
| ISRU | [NTRS 20240014064](https://ntrs.nasa.gov/citations/20240014064) y [panorama NASA](https://www.nasa.gov/overview-in-situ-resource-utilization/) | Modelo de planta de agua, metano y oxígeno; torre y producción simplificada pertenecen al juego. |
| Refinería | [NTRS 20050215331](https://ntrs.nasa.gov/citations/20050215331) | Procesamiento de simulantes e interés en materiales; no una fábrica operativa en Marte. |
| Mina | [RASSOR](https://technology.nasa.gov/patent/KSC-TOPS-7) y [recurso 3D](https://science.nasa.gov/3d-resources/regolith-advanced-surface-systems-operations-robot-rassor/) | Tambores contrarrotatorios; no confirma un yacimiento de hierro explotable. |
| Invernadero | [NTRS 19910008822](https://ntrs.nasa.gov/citations/19910008822) y [prototipos NASA](https://www.nasa.gov/science-research/lunar-martian-greenhouses-designed-to-mimic-those-on-earth/) | Tres módulos subterráneos propuestos; el óvalo exterior es artístico. |
| Baterías | [NTRS 20260006829](https://ntrs.nasa.gov/citations/20260006829) | Relación parcial: evacuación de calor; no especifica este contenedor de baterías. |
| Plataforma | [Landing Pads](https://www.nasa.gov/centers-and-facilities/kennedy/landing-pads-being-designed-for-extraterrestrial-missions/) | Preparación y estabilización del suelo; geometría y resistencia requieren ingeniería específica. |
| Túneles | [NTRS 20260004995](https://ntrs.nasa.gov/citations/20260004995) | Trabajo académico de University of Michigan; no una red construida ni arquitectura oficial aprobada. |

Los dos enlaces TechPort del documento (`93477` y `14795`) no se utilizaron como
respaldo en la ventana: la consulta disponible no permitió verificar su contenido;
TechPort requiere JavaScript. Los apartados correspondientes conservan las otras
fuentes verificadas del propio documento. No se añadieron afirmaciones supuestas.

Las referencias generales MOXIE/ECLSS/Veggie/Kilopower evaluadas antes de recibir
el documento no se presentan como procedencia artística. Las fuentes científicas
preexistentes del códice permanecen en su catálogo independiente.

## Pruebas reproducibles

La suite de créditos pasó **315 comprobaciones, sin fallos**, y generó 19 capturas
([resultado](results.json), [log](engine.log)). El log no contiene errores de
ejecución; mantiene avisos de análisis estático existentes. También pasó la suite
completa de menú y selección: **909 comprobaciones, sin fallos**
([resultado](menu-results.json), [log](menu-engine.log)).

Capturas: [equipo](credits-team-es.png), [referencias](credits-references-es.png),
[túneles](credits-references-last-es.png), [equipo en 960×540](credits-team-960x540-es.png)
y [referencias en inglés a 4K](credits-references-3840x2160-en.png).

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/ui/run_credits_tests.tscn credits-result.json
node tools/godot-mcp/check-playable.mjs res://tests/ui/run_menu_regressions.tscn menu-result.json
```

La prueba de créditos usa ratón/teclado dentro de Godot y comprueba nombres,
funciones, orden, procedencia, traducciones, URLs asociadas a botones,
desplazamiento por foco, apertura/cierre repetido y límites de pantalla en
960×540, 1920×1080, 3840×2160 y 3440×1440, en ambos idiomas. Los controles de
navegación mantienen al menos 44 píxeles de alto en la resolución menor.

El ensayo automático verifica la conexión de cada botón a su URL y el rechazo de
una dirección ajena al catálogo; no abre navegadores externos. Las publicaciones
se verificaron por separado mediante consulta web. Las pruebas no inician gameplay.

Se ejecutan mediante el cliente MCP local con preferencias y guardados aislados.
El servidor Godot no está expuesto como herramienta nativa en este chat; se usa
su cliente local ya configurado. No se cierra ningún editor existente.
