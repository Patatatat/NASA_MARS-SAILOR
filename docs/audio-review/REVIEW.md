# Integración musical y efectos

Se usan los ocho WAV aportados en `assets/audio`, conservando los archivos originales.
Godot genera sus recursos de reproducción al importar el proyecto.

| Archivo | Uso |
| --- | --- |
| `Project_Mars_Menu_Theme.wav` | Menú principal, ajustes y créditos. |
| `Project_Mars_Character_Selection.wav` | Selección de astronautas. |
| `Project_Mars_Gameplay_1.wav` | Primera pista de la partida normal. |
| `Project_Mars_Gameplay_2.wav` | Segunda pista; al terminar vuelve a la primera. |
| `Project_Mars_Event.wav` | Tema durante eventos activos, incluidos los aleatorios. |
| `Project_Mars_Button-Notification.wav` | Botones y notificaciones; voces separadas para que una pulsación no corte una alerta. |
| `Project_Mars_FX_Upgrade.wav` | Investigación completada. |
| `Project_Mars_FX_Stage.wav` | Inicio de misión, llegada de cohete, sector descubierto y resultado final. |

## Comportamiento

- Una sola voz musical evita temas superpuestos. La playlist normal alterna 1→2→1
  usando la señal real `finished` de AudioStreamPlayer.
- El tema de eventos reemplaza temporalmente la música de gameplay. Al resolverse
  todos los eventos activos se recuperan la pista y posición interrumpidas.
  Un aviso previo emite notificación, sin cambiar todavía la música normal.
- Menú, selección y eventos repiten sus temas al terminar. Volver entre pantallas
  conserva la posición; iniciar una misión nueva reinicia la playlist normal.
- La música sigue sonando durante la pausa. Cambiar idioma o reconstruir controles
  no reinicia la pista.
- Música utiliza `Volumen × Música`; botones, avisos y efectos usan `Volumen × SFX`.
  Los cambios se aplican inmediatamente. El 0 % produce silencio real, sin el piso
  de volumen que tenía el generador de avisos anterior.
- Se sustituyen los avisos sintetizados anteriores por el WAV suministrado. La
  prioridad de avisos y mejoras evita que un efecto menor corte uno prioritario.
- La reproducción no escribe en el estado de la misión ni consume su RNG.

La implementación está en `autoload/audio_manager.gd`, registrado después de
SettingsService. Las pantallas comunican el contexto y los servicios existentes
aportan señales de eventos, investigación y cohetes. No se cambian sus reglas.

## Pruebas

```powershell
node tools/godot-mcp/check-playable.mjs res://tests/qa/run_audio_tests.tscn audio-result.json
```

La suite gráfica se ejecuta mediante el cliente MCP local, con preferencias y
guardados aislados. Sus **41 comprobaciones** cubren los ocho archivos, navegación,
pausa, persistencia del tema, eventos, efectos, volumen y reinicio de misión.

Para probar finales reales sin esperar cinco minutos, la suite posiciona el
reproductor a 0,12 segundos del final de cada pista y espera la señal del backend;
no emite `finished` manualmente. También prueba la repetición del tema de selección.

Un AudioEffectCapture observa la mezcla real del motor bajo WASAPI. `results.json`
registra una señal musical no nula y una señal exactamente cero al silenciar.
La captura descarta primero el bloque de audio anterior mientras el backend aplica
el cambio de ganancia. Esta comprobación valida la mezcla del motor, sin certificar
el dispositivo físico de salida ni la calidad subjetiva de escucha.

Se detectó y corrigió otro fallo durante esta integración: cerrar Ajustes e iniciar
una misión en el mismo frame dejaba al SettingsMenu retirado conectado a las señales
de idioma. Ahora se desconectan sus observadores antes de retirarlo. La prueba de
audio recorre esa secuencia.

Evidencias: `results.json` y `engine.log`, sin errores de ejecución. También pasan
las **909 comprobaciones de menús** (`menu-regression.json`) y las **37 de clima**
(`weather-regression.json`): **987 comprobaciones correctas en total**.
Exportaciones Web y otros sistemas
operativos quedan fuera de esta verificación local.
