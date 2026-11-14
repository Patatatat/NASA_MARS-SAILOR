# MarSins · Base inicial de simulación

Base del carril de Rafael, verificable con Godot **4.7.2.stable.official.ed1daf0bf**. Abrir `project.godot` y ejecutar con F6/F5 la escena técnica. No es todavía la UI del juego ni una entrega web.

Incluye selección 4/6, mapa 6×6, presupuesto, construcción temporizada, potencia, aire/agua/comida, salud por déficits, tres finales, pausa/velocidad, registro y reinicio. Añade pronóstico por semilla, tormentas, partículas solares, dosis individual, refugio, enterramiento, dos ROBERTS con tres destinos y mejoras de nivel 1→2 en los cinco edificios. Los seis especialistas tienen efecto. Mantenimiento de reactor/oxígeno, inspector y resúmenes por sol están conectados. Balance provisional; minijuegos reales y UI final se integran desde los carriles de Luque/Andrés.

## Prueba manual

1. Ejecutar y mantener la selección inicial de cuatro. Probar tres o cinco y pulsar Reiniciar: debe rechazar sin borrar la partida.
2. Elegir reactor (45 masa) y colocarlo en (0,0), oxígeno (20) en (1,0), invernadero (25) en (3,0). Deben quedar 10 de masa; temporizadores detenidos en planificación.
3. Intentar solar adicional (15), reactor junto al hábitat o construir sobre una celda ocupada: rechazo sin cobro.
4. Iniciar. Oxígeno termina a los 5 s, reactor/invernadero a los 10 s. Revisar aire, agua y comida. Pausar y comprobar que cantidades y tiempo se detienen; continuar a ×4.
5. Pulsar reactor: la producción dependiente de potencia se detiene. Volver a encenderlo. Mirar las razones y la salud en el panel técnico.
6. Llegar al final o reiniciar. Verificar que recursos, edificios, tripulantes, reloj, eventos y misiones se restauran; repetir tres veces.

## Probar mantenimiento, inspector e informe

1. Para aislar el sistema, construir solo reactor (0,0), iniciar y esperar a 110 s simulados (en una crisis, el aviso se pospone). Seleccionar el reactor en Mantenimiento y pulsar Atender. En el banco técnico, **Prueba: éxito** aplica el resultado; estos botones no son los minijuegos finales.
2. Repetir con **Prueba: fallo**, Atender y luego éxito: hay un reintento. Cerrar mediante Abandonar deja el aviso pendiente, consume ese intento y permite continuar jugando.
3. Ignorar el aviso: 25 s después baja rendimiento al 70%; 50 s después del aviso se apaga. No se reactiva encendiendo el edificio. Esperar otros 50 s y pulsar Reactivar: cuesta 5 masa una sola vez.
4. Abrir una sesión y dejarla pasar: vence tras 15 segundos reales activos, también a x4/x0.5. Pausa detiene su reloj. Refugio o aviso/crisis suspenden la sesión sin gastar su tiempo ni aplicar abandono. Al salir se reanuda. El resto de la simulación continúa mientras se atiende.
5. Pulsar una celda ocupada para consultar su inspector (la pantalla técnica también conserva el gesto de encender/apagar al pulsar). Revisar potencia, tasas, condición y últimos hechos.
6. Al terminar un sol, revisar en el panel el cambio de reservas y los bloqueos medidos. Al perder antes de terminar un sol se conserva un informe parcial. Los datos completos quedan en `sol_reports` para la interfaz de Andrés.

Una estrategia que ignore todo el mantenimiento ya no tiene el mismo resultado que antes de esta función. Las tres sesiones automáticas de supervivencia atienden ahora sus avisos; las pruebas de degradación verifican por separado las consecuencias de ignorarlos.

## Probar eventos y ROBERTS

- Elegir semilla antes de Reiniciar. El pronóstico siempre muestra probabilidades reales; cambiar de tripulación con la misma semilla no vuelve a sortear el clima. Los eventos pueden no ocurrir. Las pruebas automáticas fuerzan probabilidades 0/1 en sus propios datos, sin trucos en la partida.
- Para expediciones: construir reactor en (0,0), laboratorio en (1,0) y oxígeno en (3,0); iniciar y esperar 10 s. Elegir ROBERT/destino y Enviar. Quedan 15 de masa y potencia suficiente para dos robots. Poner el cursor sobre el destino muestra carga/riesgo estimado.
- El regreso es a los 50 segundos de salida; la carga se aplica automáticamente una vez, o el robot se pierde según riesgo. Intentar reutilizar uno ocupado debe fallar. Apagar energía durante una misión muestra soporte sin potencia; el robot continúa autónomo.
- Tormenta posible: aviso a 55 s, inicio 75 s, fin 125 s. Comparar solar con reactor. Partículas posibles: aviso 155 s, inicio 175 s, fin 200 s. Observar dosis con/sin refugio; salir nunca borra la dosis.
- Visitar cantera para obtener regolito y pulsar Enterrar (10 masa + 20 regolito). La obra tarda 25 s y se pausa mientras hay refugio. Elegir geología mejora carga/riesgo; medicina reduce dosis.
- Un ROBERT que volvió puede salir otra vez. Si el panel dice «Salida bloqueada», revisar el motivo: laboratorio sin potencia, falta de potencia libre, refugio o partida terminada. Un robot perdido no puede reutilizarse. El panel distingue esos estados.

## Probar mejoras

1. Seleccionar un equipo con científico, reiniciar y construir solar en (0,0). Iniciar y esperar los 5 s de construcción.
2. Seleccionar `b2 · solar N1` en la lista de mejoras: debe indicar 10 masa y 15 s estimados. Sin científico serían 20 s.
3. Pulsar Mejorar: solar sigue produciendo como N1. Repetir la orden debe rechazar sin descontar más masa. Durante refugio o pausa no avanza el trabajo.
4. Al completar, ver N2 y potencia 9.6 con ingeniero (8 sin él). Intentar otra mejora del mismo solar debe indicar nivel máximo.
5. Probar los demás edificios. Oxígeno e invernadero aumentan producción y también consumo; laboratorio baja su demanda. El contrato detalla las cifras. La escena técnica tiene desplazamiento vertical para acceder a todos los controles.

## Verificación automática

Desde PowerShell en esta carpeta:

```powershell
./tests/run_checks.ps1 -GodotExe 'C:/Users/emili/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
```

El script importa, ejecuta pruebas GDScript y abre/cierra la escena en headless. Cada proceso tiene límite externo de 60 segundos. Detecta errores de Godot aunque el proceso devuelva 0; guarda logs en `local-only/test-results/` y aísla preferencias del motor allí. Ajustar la ruta del ejecutable en otros equipos.

`local-only/` guarda referencias personales, especificaciones antiguas y archivos locales excluidos de Git. `.agents/` también queda excluida; sus skills permanecen instaladas localmente. El código del juego, datos, escenas, tests y documentación de integración sí se comparten.

Contrato para Andrés/Luque y reglas exactas: [docs/SIMULATION_INTERFACE.md](docs/SIMULATION_INTERFACE.md). Verificación y pendientes: [docs/VALIDATION.md](docs/VALIDATION.md).
