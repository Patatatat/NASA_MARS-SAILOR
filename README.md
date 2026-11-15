# MarSins · Base inicial de simulación

Base del carril de Rafael, verificable con Godot **4.7.2.stable.official.ed1daf0bf**. F5 abre el menú principal de Andrés; Jugar conduce a la selección de cuatro especialistas y después al tablero. F6 ejecuta la escena abierta. No es todavía la UI final del juego ni una entrega web.

La fusión con `andres/interfaz` conserva las reglas/HUD de Rafael y añade menú principal, preferencias persistentes de audio/pantalla/idioma, traducciones y atajos. En Ajustes del HUD, las flechas recorren Sonido, Pantalla e Idioma. El volumen controla los buses Master/Music/SFX. Espacio inicia/pausa; Esc o Tab abre Ajustes; A/D o flechas laterales giran; W/S o flechas verticales cambian zoom. Se conservan rueda pulsada para desplazar y F11. Los botones Cómo jugar/Créditos del menú de Andrés todavía no tienen sus pantallas conectadas.

Incluye selección 4/6, mapa isométrico con tamaño de área sorteado por semilla (16×16, 24×24 o 32×32), formas irregulares y terreno bloqueado; giro y zoom; construcción con costo de regolito; cuatro reservas (regolito, energía almacenada, oxígeno y Alimento combinado de agua + comida); salud por tripulante; tormentas y partículas solares en ventanas reproducibles; dosis individual, refugio, enterramiento, dos ROBERTS, mejoras, mantenimiento y resúmenes. El ciclo nominal usa 42 soles de 60 segundos con 40 segundos de día y 20 de noche. Balance provisional; faltan el sistema de decisiones de crisis, escenarios iniciales adicionales, fichas de tecnologías NASA conectadas a mecánicas y la UI final.

La migración actual sigue [la propuesta del bucle para el hackathon](docs/PROPUESTA_BUCLE_HACKATHON.md). Las listas de pasos de prueba que siguen describen el balance previo y están pendientes de actualización para este contrato.

El runner actual usa `tests/test_current_simulation.gd` (cuatro recursos/42 soles), historial, recorrido de interfaz y arranque. `test_simulation.gd` y `test_run_summary.gd` se conservan como suites históricas del esquema de masa/agua; no se ejecutan automáticamente porque sus datos y resultados esperados corresponden a reglas sustituidas. Detalles de la fusión: [docs/INTEGRACION_ANDRES.md](docs/INTEGRACION_ANDRES.md).

## Prueba manual

Resolución base: **1600×900**, con ventana inicial de desarrollo de 1440×810 y HUD que se adapta al espacio. Usa **F11** o **Ajustes → Pantalla completa** para ampliar. La distribución se comprobó desde 1280×720 hasta 1920×1080; la futura página web debe dar al lienzo el área disponible. Falta verificar esa exportación en navegador real.

El resumen final ya está disponible: al concluir cualquier partida se abre **Resumen** en el HUD, con veredicto, cuatro indicadores, tripulación, tendencia de reservas y hechos registrados. Se puede cerrar y volver a abrir desde la barra inferior. Andrés puede obtener la misma copia mediante `get_run_summary().result` y conectarla a su futura pantalla; el contrato explica sus campos y los pesos de puntaje.

Para revisarlo rápidamente: continuar con los cuatro especialistas por defecto, iniciar sin construir y seleccionar ×4 hasta el relevo. Debe abrirse el resumen de derrota parcial, con supervivencia, salud, consumo de reservas y hechos medidos. Cerrar/reabrir Resumen debe conservar los datos; Reiniciar debe limpiar el resumen de la nueva partida. Esta secuencia sirve para verificar el informe, no como estrategia de supervivencia.

1. Ejecutar con F5. La escena de selección inicia con cuatro especialistas elegidos; con tres o cinco, Continuar debe estar desactivado. Probar Cambiar tripulación desde el tablero y verificar que se conserva la selección.
2. Elegir reactor (45 masa) y colocarlo en (18,15), oxígeno (20) en (4,1), invernadero (25) en (7,1). Deben quedar 10 de masa; temporizadores detenidos en planificación.
3. Intentar un solar (15) en (10,1), colocar un reactor junto al hábitat (16,15) o elegir una casilla reservada del invernadero (6,1): debe rechazarse sin cobro.
4. Iniciar. Oxígeno termina a los 5 s, reactor/invernadero a los 10 s. Revisar aire, agua y comida. Pausar y comprobar que cantidades y tiempo se detienen; continuar a ×4.
5. Pulsar reactor: la producción dependiente de potencia se detiene. Volver a encenderlo. Mirar las razones y la salud en el panel técnico.
6. Llegar al final o reiniciar. Verificar que recursos, edificios, tripulantes, reloj, eventos y misiones se restauran; repetir tres veces.

## Probar mantenimiento, inspector e informe

1. Para aislar el sistema, construir solo reactor (18,15), iniciar y esperar a 110 s simulados (en una crisis, el aviso se pospone). Seleccionar el reactor en Mantenimiento y pulsar Atender. En el banco técnico, **Prueba: éxito** aplica el resultado; estos botones no son los minijuegos finales.
2. Repetir con **Prueba: fallo**, Atender y luego éxito: hay un reintento. Cerrar mediante Abandonar deja el aviso pendiente, consume ese intento y permite continuar jugando.
3. Ignorar el aviso: 25 s después baja rendimiento al 70%; 50 s después del aviso se apaga. No se reactiva encendiendo el edificio. Esperar otros 50 s y pulsar Reactivar: cuesta 5 masa una sola vez.
4. Abrir una sesión y dejarla pasar: vence tras 15 segundos reales activos, también a x4/x0.5. Pausa detiene su reloj. Refugio o aviso/crisis suspenden la sesión sin gastar su tiempo ni aplicar abandono. Al salir se reanuda. El resto de la simulación continúa mientras se atiende.
5. Pulsar una celda ocupada para consultar su inspector (la pantalla técnica también conserva el gesto de encender/apagar al pulsar). Revisar potencia, tasas, condición y últimos hechos.
6. Al terminar un sol, revisar en el panel el cambio de reservas y los bloqueos medidos. Al perder antes de terminar un sol se conserva un informe parcial. Los datos completos quedan en `sol_reports` para la interfaz de Andrés.

Una estrategia que ignore todo el mantenimiento ya no tiene el mismo resultado que antes de esta función. Las tres sesiones automáticas de supervivencia atienden ahora sus avisos; las pruebas de degradación verifican por separado las consecuencias de ignorarlos.

## Probar eventos y ROBERTS

- Elegir semilla antes de Reiniciar. El pronóstico siempre muestra probabilidades reales; cambiar de tripulación con la misma semilla no vuelve a sortear el clima. Los eventos pueden no ocurrir. Las pruebas automáticas fuerzan probabilidades 0/1 en sus propios datos, sin trucos en la partida.
- Para expediciones: construir reactor en (18,15), laboratorio en (4,1) y oxígeno en (7,1); iniciar y esperar 10 s. Elegir ROBERT/destino y Enviar. Quedan 15 de masa y potencia suficiente para dos robots. Poner el cursor sobre el destino muestra carga/riesgo estimado.
- El regreso es a los 50 segundos de salida; la carga se aplica automáticamente una vez, o el robot se pierde según riesgo. Intentar reutilizar uno ocupado debe fallar. Apagar energía durante una misión muestra soporte sin potencia; el robot continúa autónomo.
- Tormenta posible: aviso a 55 s, inicio 75 s, fin 125 s. Comparar solar con reactor. Partículas posibles: aviso 155 s, inicio 175 s, fin 200 s. Observar dosis con/sin refugio; salir nunca borra la dosis.
- Visitar cantera para obtener regolito y pulsar Enterrar (10 masa + 20 regolito). La obra tarda 25 s y se pausa mientras hay refugio. Elegir geología mejora carga/riesgo; medicina reduce dosis.
- Un ROBERT que volvió puede salir otra vez. Si el panel dice «Salida bloqueada», revisar el motivo: laboratorio sin potencia, falta de potencia libre, refugio o partida terminada. Un robot perdido no puede reutilizarse. El panel distingue esos estados.

## Probar mejoras

1. Seleccionar un equipo con científico, reiniciar y construir solar en (1,1). Iniciar y esperar los 5 s de construcción.
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
