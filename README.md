# MarSins · 42 soles

Simulación de supervivencia para Godot 4.7.2. Abre `project.godot` y pulsa **F5**: menú → escenario y tripulación → planificación → misión → informe final.

## Primera misión

Elige **Contra el polvo**, semilla **1**, y conserva los cuatro especialistas seleccionados. Construye dos solares, un generador de oxígeno y un invernadero en celdas libres (75 de regolito). Inicia con ▶. La tormenta llega al sol 2: abre **Decisiones**, protege un panel y deja el otro desplegado. Observa batería, daño persistente y reparación al terminar. Usa pausa para leer y ×2/×4 para acelerar; el mantenimiento tiene 15 segundos reales.

Para aprender con energía más estable, **Horizonte rojo** permite reactor + oxígeno + cultivo por 90 de regolito. Tendrás que atender mantenimiento. **Cosecha quebrada** empieza con un cultivo al 45% y menos alimento: selecciona el cultivo y repáralo desde Base.

## Bucle

- Cuatro reservas: regolito, energía almacenada, oxígeno y alimento combinado. Salud y dosis por tripulante.
- 42 soles de 60 s, con día/noche, batería y prioridad de soporte vital.
- Crisis con opciones excluyentes, plazos y consecuencias: polvo, radiación, batería baja y cultivos. Máximo dos urgencias activas; resto en cola.
- Construcción, reparaciones, ROBERTS, cuadrilla exterior, mejoras, refugio y mantenimiento mediante dos intervenciones jugables.
- Ficha educativa LOTUS con fuentes y limitaciones; instalarla cuesta material, batería y tiempo. Su efecto solar es una simplificación ficticia.
- Informe final con supervivientes, reservas, tendencias y decisiones/consecuencias registradas. Reiniciar limpia la partida.

## Controles

Clic en terreno libre: construir. Clic en edificio: inspector. Rueda: zoom; botón derecho y arrastrar: girar; rueda pulsada y arrastrar: desplazar. F11: pantalla completa. Paneles en barra inferior; Ajustes incluye reinicio y semilla. La selección permite cambiar escenario y equipo.

## Desarrollo y verificación

`tests/run_checks.ps1 -GodotExe <ruta al ejecutable>` ejecuta importación, reglas actuales, supervivencia, historial, integración y arranque. Último resultado: **78 + 119 + 58 comprobaciones, cero fallos**, además de historial/importación/escena. Seis partidas automatizadas completaron los tres escenarios con cuatro supervivientes. Esto no sustituye las pruebas humanas de dificultad.

Ver [contrato vigente](docs/SIMULATION_INTERFACE.md), [validación y límites](docs/VALIDATION.md) y [propuesta de diseño](docs/PROPUESTA_BUCLE_HACKATHON.md). Las pruebas antiguas de masa/agua/12 soles son históricas. Sonido y ajustes de audio existentes se reservan al compañero responsable.

Capturas y archivos temporales quedan en `local-only/`; entregables en `exports/`, ambos ignorados por Git. Persisten tres avisos de inicialización de shaders en la captura OpenGL local; se renderiza la escena, pero no se ha validado una exportación web ni rendimiento de GPU.
