# MarSins · Base inicial de simulación

Base del carril de Rafael, verificable con Godot **4.7.2.stable.official.ed1daf0bf**. F5 inicia en una escena independiente para seleccionar cuatro especialistas y después abre el tablero de simulación; F6 ejecuta la escena abierta. No es todavía la UI final del juego ni una entrega web.

Incluye selección 4/6 en escena separada, malla 3D isométrica 32×32 con giro y zoom, HUD de masa/aire/agua/comida/energía y soles transcurridos, presupuesto, construcción temporizada, potencia, salud por déficits, tres finales, pausa/velocidad, registro y reinicio. La selección conserva los mismos identificadores y efectos de especialistas. Balance provisional; no se ha validado equilibrio entre estrategias. Los efectos de tres especialistas y los sistemas de eventos, radiación, ROBERTS, mejoras y mantenimiento quedan pendientes.

## Prueba manual

1. Ejecutar con F5. La escena de selección inicia con cuatro especialistas elegidos; con tres o cinco, Continuar debe estar desactivado. Probar Cambiar tripulación desde el tablero y verificar que se conserva la selección.
2. Elegir reactor (45 masa) y colocarlo en (18,15), oxígeno (20) en (4,1), invernadero (25) en (7,1). Deben quedar 10 de masa; temporizadores detenidos en planificación.
3. Intentar un solar (15) en (10,1), colocar un reactor junto al hábitat (16,15) o elegir una casilla reservada del invernadero (6,1): debe rechazarse sin cobro.
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
