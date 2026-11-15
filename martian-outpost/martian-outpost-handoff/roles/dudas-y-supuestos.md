# Dudas, confirmaciones y supuestos — revisión de Astra

## Confirmado por el usuario

- Cuatro personas, cada una con un agente; cuatro secciones del juego. Se sobrescribió el reparto previo de cinco roles.
- Un único propietario por archivo, incluidas escenas, recursos, JSON y configuración.
- Godot 4.7.
- Eliminar el sistema dedicado de decisiones porque interrumpe el juego. Se retiraron Decision Maker, servicios/registros de decisiones, plantillas, textos exclusivos y pausas/ralentizaciones obligatorias. Se conservan acciones normales, peligros, costes y explicaciones basadas en hechos.
- Se puede repetir el mismo perfil de astronauta; cada instancia tiene ID y estado independientes.
- Plazo de desarrollo: 24 horas.
- Presentación: diez minutos.

No se ha implementado el juego. Los cuatro archivos de rol y contratos son planes. Tras la respuesta «Sí, mantén los 10 minutos», se ajustó el balance inicial de 24 a 32 placas para permitir laboratorio y panel antes del primer cohete. El valor 32 y el límite de seis túneles son decisiones de planificación para concretar el ajuste, no cifras dictadas por el usuario.

## Puntos resueltos y criterio de planificación

### D1. Tutorial y placas — resuelto con restricción de layout

El usuario aceptó que el inventario permita laboratorio y panel antes del primer cohete. Balance actualizado: 32 placas = 16 laboratorio + 10 panel + hasta 6 túneles nuevos. No se cambian los costes de edificios. R2 debe diseñar una ruta que requiera como máximo seis túneles nuevos; las conexiones de edificios iniciales vienen instaladas. R1 prueba que también alcanzan tiempo de trabajo/investigación antes del sol 7.

El layout todavía no existe: el presupuesto es verificable, pero su ejecución debe probarse. La batería queda para el siguiente paso; no se promete que estas mismas 32 placas cubran sus ocho placas adicionales. Origen: handoff §5, balance.json y aceptación del usuario.

### D2. Diez minutos — duración mantenida

Se mantienen diez minutos de presentación. Interpretación de planificación de la respuesta breve del usuario: recorrido guiado con avance administrativo, siguiendo la recomendación anterior. No se interpreta como autorización para modificar duración del sol o velocidad máxima. La campaña completa conserva 42×60/4 = 630 segundos (10:30). El guion de diez minutos se ensaya con admin que simula las reglas, sin omitir costes ni evitar derrota.

## Preguntas de diseño todavía abiertas

### D3. Kit inicial

Origen: handoff §2 y balance reactor.core_duration_sols/initial_inventory.
Faltan túneles iniciales, cultivos ya plantados, trajes disponibles, núcleo instalado y mapa válido. Propuesta: edificio inicial conectado, ISRU sobre acuífero, cultivos activos, combustible instalado y núcleo en inventario tratado como reserva, con cantidades registradas. **Pregunta:** ¿ese núcleo del inventario es reserva o el combustible que hay que instalar al empezar? ¿Se dispone de trajes desde el inicio?

### D4. Manifiesto, masa y llegada inválida

Origen: handoff §6; balance rockets.cargo_mass omite oxígeno, agua, comida, mineral, regolito y placas aunque permite recursos. Apoyo cambia cada sol pero no se especifica compromiso.
Propuesta: lista completa de carga/masa; congelar capacidad al confirmar. **Preguntas:** ¿se puede editar un manifiesto confirmado hasta la llegada? ¿Qué sucede al llegar sin zona válida o sin confirmación? Estas políticas afectan H2 y no se implementarán como envío gratuito o cancelación del programa por defecto.

### D5. Reemplazo y cohete

Origen: handoff §§1,6.
Propuesta: reemplazo reservado en manifiesto, un intercambio por cohete, exclusión definitiva con desguace. **Preguntas:** ¿se admite sustituir a un fallecido o solo intercambiar uno vivo? ¿Cuántas personas admite el cohete? ¿Cómo y cuándo se retira el cohete para liberar la zona? RocketService mantiene la transacción única; las respuestas completarán su política.

### D6. Plataforma y zona vacía

Origen: handoff §§2,6: pad 6×6 con túnel y zona vacía 8×8.
Propuesta: plataforma dentro de zona con excepción de ocupación explícita y acceso de túnel permitido. **Pregunta:** ¿confirmas esa relación o la plataforma mejora la carga desde una posición separada? No declarar válida una zona ocupada sin fijar primero las excepciones.

### D7. Repetición de médicos

Repetir perfil ya está confirmado; apilar su ventaja no. Origen: handoff §4, +18% de moral global por médico. **Pregunta:** ¿se suman varias bonificaciones o se aplica una sola vez? Propuesta para evitar una combinación dominante: bonus global no acumulable, manteniendo habilidades individuales de cada astronauta. Sigue pendiente, no es requisito aprobado.

## Supuestos técnicos explícitos para hacer el plan utilizable

Se pueden revisar; no se presentan como decisiones del usuario.

| ID | Supuesto/propuesta | Motivo y referencia |
| --- | --- | --- |
| T1 | GDScript y proyecto existente en raíz del workspace como res:// | Firmas previas en GDScript y único project.godot encontrado; usuario confirmó versión, no explícitamente lenguaje/raíz |
| T2 | Archivos snake_case, clases/nodos PascalCase | Resolver discrepancia entre árbol PascalCase y regla escrita de guía |
| T3 | Llegadas al inicio de sol; economía y victoria al cierre | Respetar calendario explícito de handoff §§1,5 frente a agrupación imprecisa de guía antigua |
| T4 | SaveService emite state_restored; vistas reconstruyen | Una sola autoridad, en lugar de dos emisores de guía antigua |
| T5 | Global incluye noticias/ciencia/pensamientos; rutina de edificios local | Compatibilizar handoff §8 con separación de historial de edificios; quitar decisiones no elimina diálogo |
| T6 | Paso fijo configurable propuesto de 0.1 segundos; coordinador único | Determinismo y evitar doble consumo por señales |
| T7 | Potencia simplificada P y energía P·sol; trabajo en horas de sol con conversión configurada | Balance actual carece de unidades temporales completas; no llamar W a magnitudes arbitrarias |
| T8 | Prioridad 1 máxima; prohibición en flag aparte | Convención faltante en categorías 1–4 |
| T9 | Inputs y capas propuestos en contratos C7; R1 único editor del proyecto | Evitar conflicto y picking distinto entre UI/mundo |
| T10 | Objetivo UI 1280×720, comprobar 960×540; navegadores finales por confirmar | Falta resolución mínima en handoff/guía |
| T11 | Guía/reactivación conserva pasos completados; crítico visible mientras persista peligro | Evitar repetición y ocultación accidental, sin bloquear ni pausar |

No se da por validada la compatibilidad de exportar con el editor instalado; R1 debe probar Web/Windows en H0. Config/features declara 4.7, pero no prueba una build ejecutada.

## Datos y políticas que los propietarios deben completar

- R1/R2: métrica de radio/proximidad (borde o centro, Manhattan/Chebyshev/euclídea), reparto de potencia en empates, presión por módulo, unidades exactas y horas por sol. Publicar antes de H1.
- R1/R3: ocho ventajas/desventajas completas, costes/tiempos/prerrequisitos, límites de moral/recuperación/dosis, metas que afectan apoyo, reglas de cancelación y devolución de tareas. No convertir balance en afirmaciones NASA.
- R1: unificar multiplicador de tormenta y bono de plataforma hoy duplicados en balance; preservar una sola fuente de cada parámetro.
- R2/R3: calendario fijo completo en datos, límite de eventos activos y tratamiento de brechas persistentes frente a eventos atmosféricos; definir si el límite de uno se refiere a amenazas aleatorias o todas las condiciones.
- R4: sources.json contiene fuentes pero curated_donki_events está vacío. Falta obtener/verificar un evento real con ID y fecha, comprobar fechas declaradas y claves. Esta revisión no verificó URLs ni datos científicos externos.
- R4: corregir tutorial laboratory, cuya condición actual es edificio ya colocado aunque el texto pide construirlo; usar paso previo para la instrucción y colocación para completarlo. No introducir una pausa.
- R4/R1: definir Quit en Web y navegadores de aceptación. No prometer que el juego puede cerrar la pestaña.

## Estado de la revisión

El reparto y las rutas ya se pueden usar para preparar interfaces y stubs. D3–D7 condicionan balance y comportamientos concretos, no impiden escribir el plan. Se actualizaron handoff y guía para eliminar requisitos anteriores de cinco roles/36 horas/decisiones obligatorias. Los cuatro documentos de rol incluyen tareas, entradas/salidas, aceptación, propiedad, límites y dependencias. Resolver preguntas de diseño antes de cerrar los hitos afectados; no interpretar silencio como aprobación.
