# Sustitución de modelos y revisión de túneles

Origen: [Patatatat/NASA_MARS-SAILOR, commit 7aad6b7](https://github.com/Patatatat/NASA_MARS-SAILOR/commit/7aad6b76be9dcad102025bae13f847588ff6b794),
rama `andres/interfaz-nueva`.

Se retiró `assets/3D assests/3D_assets` y se incorporó únicamente
`assets/3D assests/nuevosmodelos3d`, con sus texturas y configuración de importación.
Los **15 GLB coinciden byte por byte con los blobs del commit de origen**;
`assets.json` recoge sus hashes. No se fusionó el resto de la rama sobre los
cambios locales de menús, clima o audio.

## Tamaños comprobados

Se midió la geometría transformada, incluyendo las transformaciones internas del
GLB. Los 11 edificios se probaron a 0°, 90°, 180° y 270°: escala uniforme, centrado,
apoyo y límites dentro de las casillas ocupadas. Se mantiene el margen visual del
10 % de los edificios; las piezas de túnel utilizan una calibración propia para
que sus puertos coincidan entre celdas.

| Edificio | Huella de juego |
| --- | --- |
| Base, invernadero, panel solar, refinería | 3×3 |
| ISRU, batería, laboratorio, impresora 3D | 2×2 |
| Reactor | 4×4 |
| Mina, plataforma | 6×6 |
| Pieza de túnel | 1×1 |

También se colocó cada edificio mediante BuildingService, usando terreno,
investigación y recursos preparados explícitamente en la prueba. Se verifican
ocupación, coste, selección por casilla, rechazo de solapamientos sin segundo
cobro y uso del GLB nuevo, sin cubos de sustitución.

Las proporciones y la composición del reactor y la mina se conservan tal como
están modeladas en el origen: son conjuntos bajos y distribuidos dentro de su huella.
No se inventan alturas ni se modifica el archivo de arte para hacerlos más altos.

## Bugs corregidos

| ID | Fallo / causa | Corrección |
| --- | --- | --- |
| MODEL-001 | Se suponía que la recta estaba orientada este-oeste y la esquina norte-este. Los GLB nuevos usan norte-sur y norte-oeste. | Calibrar las direcciones originales y probar las 16 máscaras de vecinos. |
| MODEL-002 | La búsqueda de giro exigía tantos puertos como vecinos. Una recta con un solo vecino nunca giraba. | Permitir el puerto adicional de una recta terminal y cerrar los extremos sin vecino con tapas visuales. |
| MODEL-003 | Escala al 90 % y centrado por AABB dejaban huecos y desplazaban el centro de esquinas y uniones T. | Todos los túneles comparten escala 0,5 y el origen de unión del modelo. Los puertos en coordenadas ±1 llegan a los bordes de sus celdas. |
| MODEL-004 | Un túnel no reconocía visualmente al laboratorio u otros edificios con conexión. | Resolver vecinos compatibles por cara de casilla, usando los mismos tipos que la red. |
| MODEL-005 | La plataforma se elevaba para apoyar el punto más bajo de una roca decorativa. | Apoyar la superficie estructural de la plataforma, conservando la decoración original que se prolonga bajo el terreno. |
| TUNNEL-001 | Un tramo sano pero desconectado figuraba como conectado. | Construir el grafo ortogonal y recorrerlo desde las bases operativas. Las diagonales no conectan. |
| TUNNEL-002 | Una rotura separada físicamente de la colonia seguía descontando oxígeno. | Solo contabilizar fugas que tengan una cara comunicada con la red de la base. No se cambia la tasa de fuga configurada. |
| TUNNEL-003 | Tramos aislados, desactivados o sin salud podían satisfacer conexiones de construcción o actuar como conductos eléctricos. | Reutilizar una comprobación de tramo operativo en red, colocación y enlace eléctrico. |

La prueba recorre daños, fugas, aislamiento, reparación, retirada del puente,
reconstrucción y restauración del estado. Las tapas de aislamiento cierran los
puertos; las tapas terminales desaparecen al construir un vecino.

La conectividad sigue siendo una regla por casillas, sin simular físicamente
puertas individuales ni navegación 3D por el interior. Se conserva la alimentación
global del reactor definida por las reglas existentes: aislamiento de túneles y
alimentación del reactor son sistemas distintos.

## Pruebas y evidencias

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_model_tests.tscn models-result.json
```

La escena gráfica se ejecuta con el cliente MCP local y guardados aislados. La
primera batería tenía 209 comprobaciones y detectó 17 fallos de calibración y vecinos
(`before.json`). La batería ampliada final pasa **369 comprobaciones** (`after.json`).
Sus capturas revisadas son `initial.png`, `tunnel-atlas.png` y `building-gallery.png`.
Las medidas quedan dentro del resultado final.

Pasaron además siete suites headless: core, mundo, misión, integración completa,
campaña de victoria, regresiones adversariales y estrés de 1.000 acciones / 9.795
comprobaciones. Los logs se guardan junto al informe. Algunas suites todavía emiten
avisos de objetos/recursos pendientes al salir; no se presentan como fugas de memoria
resueltas del juego. La nueva prueba gráfica no registra errores de ejecución.

También pasan las **23 regresiones gráficas de investigación y día/noche**,
conservadas en `daylight-regression.json`.

Esta revisión utiliza Godot 4.7.2 y GL Compatibility en Windows. No certifica
exportaciones ni otros sistemas operativos.
