# Dirección del bucle de juego para el hackathon

## Decisión de producto

El juego debe ser un simulador de supervivencia donde cada sol obliga a elegir qué sistema sostener, qué riesgo aceptar y qué recurso reservar. La presión mecánica guía el diseño; el arte y las animaciones hacen legibles sus efectos.

La partida responde **sí** a «¿varían las partidas?»: tripulación, semilla, eventos y decisiones deben producir situaciones y resultados distintos, sin depender de azar opaco.

## Auditoría del núcleo actual

La base ejecutable tiene construcción, asignación de potencia, producción y consumo de aire/agua/comida, salud individual, radiación, mantenimiento, eventos, ROBERTS, mejoras y tres finales. Ya hay consecuencias y azar por semilla, pero el bucle no está alineado con el handoff del hackathon:

- La base termina a los 12 soles de 25 segundos; el handoff define 42 soles de 60 segundos.
- «Energía» hoy es oferta y demanda instantáneas de potencia; no hay reserva, baterías ni noche.
- Hay cinco existencias (`mass`, `regolith`, `air`, `water`, `food`), además de potencia. La tripulación ya guarda salud individual.
- Los eventos tienen ventanas fijas y probabilidades; los destinos de ROBERT tienen riesgos distintos. Falta el sistema central de situaciones con opciones excluyentes y consecuencias diferidas.
- La selección de cuatro especialistas, la semilla y varias estrategias ya cambian la partida, pero no hay suficiente variedad estructural entre escenarios.

## Reglas de diseño que quedan fijadas

### 1. Cuatro medidores globales

El HUD principal muestra como máximo estos cuatro medidores:

1. **Regolito:** reserva de material para construcción y protección.
2. **Energía:** reserva eléctrica almacenada. Mostrar también, como texto de apoyo, generación y demanda actuales.
3. **Oxígeno:** reserva respirable.
4. **Alimento:** reserva combinada de agua y comida para la tripulación.
   
La salud permanece **por tripulante** en su ficha, no como quinto medidor de colonia. Cada persona conserva salud, estado vivo/fallecido y dosis acumulada; la salud baja por déficit o daño. No crear una barra global de salud.

Para cumplir el límite, retirar `mass` como inventario separado y convertir los costos de construcción a regolito. Unificar agua y comida en el inventario **Alimento**: el consumo de cada tripulante descuenta una sola cantidad que representa ambas necesidades, y la producción/restock añade a esa misma reserva. El balance debe asegurar que la cifra y su unidad se entiendan como raciones combinadas; no mantener agua como reserva, requisito de producción ni bloqueo oculto.

**Decisión de energía:** cambiar de potencia sin almacenamiento a una reserva con capacidad, carga/descarga y ciclo día/noche. La lectura de generación y demanda explica la variación de la reserva; no contar ambas como medidores adicionales. Sin noche y batería, «Energía» no genera una decisión de reserva y solo es un diagnóstico.

### 2. No existe una ruta completamente segura

Cada crisis debe ofrecer al menos dos opciones válidas, con costos y riesgos diferentes. La opción conservadora reduce un peligro, pero consume tiempo, energía, material o producción. La opción urgente protege la colonia ahora y aumenta una exposición, una deuda de mantenimiento o un riesgo futuro.

Ejemplos de situaciones para priorizar:

- **Tormenta de polvo:** proteger paneles reduce daño, pero corta generación durante la tormenta; dejarlos activos conserva energía y arriesga daño y reparación.
- **Llamarada solar:** refugiar a la tripulación reduce dosis, pero retrasa una reparación exterior; salir permite repararla y aumenta dosis.
- **Noche con reserva baja:** cortar un edificio no esencial conserva energía para soporte vital, pero pierde producción; mantenerlo acelera su objetivo y reduce la reserva de emergencia.
- **Invernadero sin energía suficiente:** reasignar energía conserva el cultivo, aceptar la pérdida libera energía inmediata y reduce alimento futuro.

Las situaciones salen del estado real (evento, edificio, reserva, tripulación). La inacción también tiene efecto: la crisis y sus temporizadores continúan. Cada decisión debe mostrar antes de confirmar: costo inmediato, efecto inmediato, riesgo u oportunidad posterior y explicación breve.

### 3. Toda acción importante tiene consecuencias legibles

Registrar una cadena causal corta: **decisión → cambio inmediato → resultado posterior**. Debe quedar en el mundo, el HUD y el informe del sol. Ejemplos: panel apagado → baja la carga → el hábitat pierde reserva; cuadrilla enviada → reparación avanza → sube su dosis; material gastado → edificio construido → ya no alcanza para blindar el hábitat.

Ningún botón importante puede limitarse a restar un número. Si una acción no cambia producción, tiempo, riesgo, capacidad, espacio o una alternativa disponible, se elimina o rediseña.

### 4. Las partidas varían de forma reproducible

Sistema de semilla aleatoria, que cree una malla con formas distintas y obstáculos que no dejen construir, además de que varían la forma de la malla, puede ser muy grande, mediana, pequeña o tener una forma irregular.

Cada partida usa una semilla visible y registrada. Mantener las mismas decisiones y la misma semilla debe repetir los mismos eventos y resultados. La variación procede de:

- Composición de tripulación y sus especialidades.
- Escenario inicial seleccionado o sorteado con semilla (por ejemplo, tormenta temprana, reserva energética corta o invernadero dañado).
- Ventanas y combinación de eventos, mostradas en el pronóstico sin revelar resultados no anunciados.
- Decisiones exclusivas y diferentes prioridades de construcción/energía.

No añadir azar que cambie resultados sin aviso, no volver a sortear después de una decisión y no depender solo de reordenar eventos. Primero terminar 3 escenarios con reglas claras; luego ampliar el conjunto.

### 5. Incorporar tecnologías patentadas por NASA con atribución

Seleccionar una o dos tecnologías del portal oficial NASA Technology Transfer que sirvan al bucle (por ejemplo, revitalización de atmósfera, tratamiento de aguas o monitoreo de polvo). Representarlas como **fichas de tecnología**: problema que resuelven, costo/limitación jugable, procedencia y enlace a la ficha oficial. Su beneficio debe crear una nueva elección, no una mejora gratuita.

Antes de integrar una tecnología, registrar título, número de patente si la ficha lo publica, titular, estado/licencia indicada, enlace y fecha de consulta. No afirmar que una patente está libre de licencia ni reproducir diseño técnico protegido. La página de NASA explica que su portafolio se ofrece mediante licenciamiento; confirmar las condiciones de cada ficha antes de cualquier uso comercial o reproducción técnica. La ficha educativa y la mecánica simplificada deben identificarse como tales.

Fuentes: [Portal de patentes NASA](https://technology.nasa.gov/patents) · [Licenciamiento de tecnología NASA](https://technology.nasa.gov/license).

### 6. Priorizar presión mecánica sobre detalle visual

Orden de trabajo para cada sistema: decisión comprensible → consecuencia en reglas → respuesta visible simple → pulido visual. Primero hacer visibles los estados esenciales: encendido/apagado, reserva crítica, planta saludable/marchita, tripulación refugiada/expuesta, edificio dañado y material consumido. Posponer decoración, efectos avanzados y nuevas animaciones hasta tener decisiones y partidas completas.

## Camino de desarrollo

### Fase 1 — Congelar reglas y migrar datos

- Confirmar como objetivo de hackathon el handoff de 42 soles × 60 s; retirar la duración provisional de 12 × 25 s.
- Cambiar inventarios a regolito, energía almacenada, oxígeno y alimento; eliminar `mass` y el inventario de agua independiente.
- Definir capacidad de almacenamiento, generación solar, generación alternativa, consumo por edificio, noche y prioridades de corte.
- Conservar salud y dosis por tripulante; documentar las fuentes de daño y recuperación (si existe).
- Ajustar costos, producción y finales en `data/balance.json`; mantener una sola autoridad de reglas en `domain/simulation.gd`.

**Salida:** contrato de recursos y una hoja de balance con unidades de juego, sin tasas científicas presentadas como reales.

### Fase 2 — Cerrar el bucle de supervivencia

Implementar y conectar, en este orden:

1. Reloj de sol y estados de día/noche.
2. Generación, almacenamiento y demanda de energía; prioridades explícitas de edificios.
3. Producción y consumo de oxígeno y alimento combinado (agua + comida); bloqueos por energía.
4. Consecuencias de déficit sobre salud individual y supervivencia.
5. Recolección/uso de regolito para construcción y protección.
6. Final de victoria/derrota y reinicio completo.

**Salida:** partida completa con infraestructura mínima, una fuente de energía, una fuente de oxígeno y alimento, y un motivo entendible para cada final.

### Fase 3 — Hacer que la presión decida

- Añadir situaciones de crisis con dos o más opciones excluyentes.
- Empezar con los tres casos de mayor valor: tormenta/panel, llamarada/reparación exterior y noche/batería baja.
- Hacer que protegerse sacrifique producción o tiempo y que ignorar una crisis deteriore un estado existente.
- Limitar alertas urgentes simultáneas a dos; poner las restantes en cola y agrupar duplicados del mismo objetivo.
- Añadir una deuda persistente donde tenga sentido: daño, mantenimiento vencido, cultivo perdido o exposición acumulada.

**Salida:** al menos una decisión por sol relevante y registro causal de cada desenlace.

### Fase 4 — Asegurar variación y tecnologías NASA

- Crear tres escenarios iniciales jugables con diferencias mecánicas reales.
- Conectar eventos a ventanas variables determinadas por semilla y publicarlas en el pronóstico.
- Integrar fichas de una o dos tecnologías NASA que afecten decisiones reales.
- Añadir fuente, fecha, patente/licencia y simplificación a cada ficha.

**Salida:** misma semilla + mismas órdenes = mismos resultados; semillas o estrategias diferentes pueden producir desenlaces distintos.

### Fase 5 — Lectura visual y entrega

- Convertir cada estado mecánico importante en una señal visual clara y de bajo costo.
- Mantener el HUD dentro de cuatro medidores globales; detalle de edificios y salud individual en inspectores.
- Probar el recorrido completo y el reinicio; corregir primero bloqueos, decisiones dominantes y consecuencias que no se entiendan.
- Pulir arte, animación y sonido después de pasar los criterios mecánicos.

## Cambios concretos al núcleo actual

| Área | Estado actual | Cambio necesario |
|---|---|---|
| Recursos | `mass`, `regolith`, `air`, `water`, `food`; potencia instantánea | Unificar construcción en regolito; introducir reserva de energía; conservar oxígeno; fusionar agua y comida en Alimento |
| Tiempo | 12 soles × 25 s | Llevar a 42 × 60 s, con día/noche según handoff |
| Energía | Oferta/demanda sin almacenamiento | Añadir capacidad, carga, descarga, noche y consecuencias por baja reserva |
| Tripulación | Salud/dosis individual existentes | Mantener por persona; vincular cada pérdida a déficit, exposición u otro daño medido |
| Crisis | Eventos con aviso y horarios mayormente fijos | Añadir Decision Maker con opciones, costos, plazos y efectos diferidos |
| Variación | Semilla, equipo, eventos y misiones | Añadir escenarios y ventanas distintas por semilla; garantizar previsión y repetición |
| NASA | Plan local prioriza datos archivados DONKI/OSDR/Mars Trek | Añadir fichas verificables de tecnología patentada NASA; no confundir datos científicos con patentes |
| Prioridad | Sistemas y UI técnica ya amplios | Reducir/posponer extras; priorizar decisiones, consecuencias y legibilidad funcional |

## Criterios de aceptación

- El HUD tiene cuatro medidores globales como máximo; salud se consulta por tripulante.
- La energía cambia durante día/noche y una decisión de consumo puede reducir una reserva futura.
- Oxígeno y alimento combinado (agua + comida) tienen producción, consumo, bloqueo y déficit con causas claras; el agua no aparece como recurso o requisito independiente.
- Construir o proteger gasta regolito y excluye otro uso concreto del mismo material.
- Cada crisis importante presenta opciones con costo y ninguna evita todo riesgo.
- Una decisión produce efecto inmediato y al menos una consecuencia posterior registrada.
- Tres escenarios pueden completarse y se distinguen mecánicamente.
- La semilla permite repetir eventos; cambiar semilla o estrategia puede cambiar hechos y resultado.
- Al menos una ficha NASA enlaza a una tecnología patentada, distingue simplificación de juego y registra su licencia/estado según la ficha.
- Un jugador puede explicar por qué perdió o sobrevivió leyendo el estado y el informe, sin explicación oral del equipo.
