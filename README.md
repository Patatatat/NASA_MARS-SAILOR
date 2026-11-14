# MarSins · Base inicial de simulación

Base del carril de Rafael, verificable con Godot **4.7.2.stable.official.ed1daf0bf**. Abrir `project.godot` y ejecutar con F6/F5 la escena técnica. No es todavía la UI del juego ni una entrega web.

Incluye selección 4/6, mapa 6×6, presupuesto, construcción temporizada, potencia, aire/agua/comida, salud por déficits, tres finales, pausa/velocidad, registro y reinicio. Balance provisional; no se ha validado equilibrio entre estrategias. Los efectos de tres especialistas y los sistemas de eventos, radiación, ROBERTS, mejoras y mantenimiento quedan pendientes.

## Prueba manual

1. Ejecutar y mantener la selección inicial de cuatro. Probar tres o cinco y pulsar Reiniciar: debe rechazar sin borrar la partida.
2. Elegir reactor (45 masa) y colocarlo en (0,0), oxígeno (20) en (1,0), invernadero (25) en (3,0). Deben quedar 10 de masa; temporizadores detenidos en planificación.
3. Intentar solar adicional (15), reactor junto al hábitat o construir sobre una celda ocupada: rechazo sin cobro.
4. Iniciar. Oxígeno termina a los 5 s, reactor/invernadero a los 10 s. Revisar aire, agua y comida. Pausar y comprobar que cantidades y tiempo se detienen; continuar a ×4.
5. Pulsar reactor: la producción dependiente de potencia se detiene. Volver a encenderlo. Mirar las razones y la salud en el panel técnico.
6. Llegar al final o reiniciar. Verificar que recursos, edificios, tripulantes y reloj se restauran; repetir tres veces. Medicina/ciencia/geología aún no tienen bonus.

## Verificación automática

Desde PowerShell en esta carpeta:

```powershell
./tests/run_checks.ps1 -GodotExe 'C:/Users/emili/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
```

El script importa, ejecuta pruebas GDScript y abre/cierra la escena en headless. Cada proceso tiene límite externo de 60 segundos. Detecta errores de Godot aunque el proceso devuelva 0; guarda logs en `local-only/test-results/` y aísla preferencias del motor allí. Ajustar la ruta del ejecutable en otros equipos.

`local-only/` guarda referencias personales, especificaciones antiguas y archivos locales excluidos de Git. `.agents/` también queda excluida; sus skills permanecen instaladas localmente. El código del juego, datos, escenas, tests y documentación de integración sí se comparten.

Contrato para Andrés/Luque y reglas exactas: [docs/SIMULATION_INTERFACE.md](docs/SIMULATION_INTERFACE.md). Verificación y pendientes: [docs/VALIDATION.md](docs/VALIDATION.md).
