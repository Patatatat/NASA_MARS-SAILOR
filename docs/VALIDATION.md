# Verificación de la base inicial

Fecha: 14 de noviembre de 2026. Motor real: `4.7.2.stable.official.ed1daf0bf` (comprobado con `--version`).

Resultado: **89 comprobaciones, 0 fallos**; importación y escena headless aprobadas.

Nota de alcance: ese resultado corresponde a la base 2D validada en esta fecha. Las actualizaciones posteriores crean una escena separada para elegir cuatro especialistas y una malla isométrica 3D de 32×32 con giro y zoom. La simulación recibe los mismos IDs de especialistas, por lo que conserva sus efectos. El tablero muestra un HUD de recursos, suministro/demanda de energía y soles transcurridos, y reserva huellas de 3×3 para hábitat/solar/invernadero, 4×4 para reactor y 2×2 para generador de oxígeno/laboratorio. La ocupación impide solapamientos y huellas fuera del tablero; las casillas reservadas se distinguen en la vista. La subvista 3D ahora renderiza a 2× el tamaño visible con MSAA 4×, y las etiquetas usan una textura de fuente de mayor resolución. Los 89 casos aún no se han vuelto a ejecutar sobre estas actualizaciones; el flujo de escenas y la presentación en ventana siguen pendientes de comprobación manual. En este entorno no se encontraron Godot ni PowerShell para ejecutar el runner.

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

Importación y arranque/cierre de escena headless: sin errores. La primera importación encontró permisos insuficientes para preferencias del editor; se resolvió aislando `APPDATA` y `LOCALAPPDATA` durante las pruebas, sin cambiar ajustes del usuario. El runner restaura ambas variables al terminar. Los `.gdignore` impiden importar especificaciones y fixtures de skills como parte del juego.

Pendiente de Rafael: interacción real en ventana, legibilidad del banco técnico y pruebas manuales del README. No se ha verificado exportación web, navegadores, móvil, rendimiento, equilibrio de estrategias ni el contenido del juego completo. Las tres sesiones automáticas no sustituyen tres partidas manuales de la futura versión integrada.
