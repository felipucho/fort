# Latencia de entrada en Fortnite — RX 6800 XT / Ryzen 9 9950X / Win11 25H2

Alcance: **solo** la cadena `input -> frame -> pixel` (mouse, teclado, USB, GPU, monitor).
Fuera de alcance por pedido: red/ping, servicios, telemetria, CPU/scheduler, almacenamiento, BIOS.

## Lo primero, y lo mas importante

Los dos monitores (Samsung S22F350 y S19B150) corren a **60 Hz**. Ese es el mayor
cuello de botella de toda la cadena, por encima de cualquier tweak de software.

| Refresco | Intervalo de frame | Latencia media agregada por cuantizacion de refresco |
|---|---|---|
| 60 Hz  | 16.67 ms | ~8.33 ms |
| 75 Hz  | 13.33 ms | ~6.67 ms |
| 144 Hz | 6.94 ms  | ~3.47 ms |
| 240 Hz | 4.17 ms  | ~2.08 ms |

Esos numeros son **aritmetica** (mitad del intervalo de refresco), no un benchmark.
Para la latencia total click-to-photon 60 Hz vs 240 Hz: **sin dato medido** verificado.
Blur Busters documenta que el **mejor caso** de latencia es identico entre 60 y 144 Hz,
pero el **peor caso siempre es peor a 60 Hz**.

Conclusion honesta: la suma de todos los tweaks de este repo esta en el orden de
**1-3 ms**. Pasar de 60 Hz a 144/240 Hz esta en el orden de **6+ ms solo en
cuantizacion**. El upgrade de monitor le gana a todo el software junto.

## Archivos

- `Optimizar-InputTweaks.bat` — menu: Seguro / Avanzado / Diagnostico / Revertir.
- `Revertir-InputTweaks.bat` — restaura exactamente desde el backup elegido.

Backups en `%USERPROFILE%\Documents\FortniteInputTweaks\backup_AAAAMMDD_HHMM\`:
`reg\*.reg` (export previo), `reg_index.txt`, `valores_ausentes.txt` (valores que
NO existian y por lo tanto se borran al revertir), `GameUserSettings.ini.bak`,
`hags_antes.txt`, `scheme_guid.txt`, `log.txt`.

## Checklist manual — no entra en un .bat

### BIOS (ASRock X870 Riptide WiFi)
- **Resizable BAR: ON**. Afecta el throughput CPU->VRAM, no el input directamente.
  Etiqueta: INFERENCIA para latencia de entrada.
- **IOMMU: OFF** si no usas virtualizacion. Quita traduccion DMA del camino.
  INFERENCIA. No tocar si usas WSL2/Hyper-V.
- **NO tocar** VBS ni Secure Boot: Vanguard y BattlEye los requieren.
- **Puerto USB**: en esta placa van directo al CPU los 2x USB4 Type-C, 1x USB 3.2
  Gen2 Type-A y 1x USB 3.2 Gen1 Type-A traseros. El resto cuelga del chipset X870.
  Enchufa el mouse en un puerto CPU-directo y **solo** (sin hub, sin compartir con
  audio USB ni webcam). El beneficio real es evitar contencion de interrupciones
  en el mismo controlador, no el largo del camino electrico. INFERENCIA.

### Adrenalin (no se puede scriptear de forma confiable)
- **Radeon Anti-Lag: ON** para Fortnite. Limita la cola de render. Es la version
  de driver, no inyecta codigo. Segura con EAC/BattlEye.
- **Anti-Lag+: NO EXISTE mas** — AMD lo retiro tras causar bans de VAC en CS2 por
  detourear funciones del juego. **Anti-Lag 2** requiere integracion por juego;
  no hay confirmacion de que Fortnite la tenga. Si aparece en el juego, usala.
- **VSync: OFF**. VSync retiene el frame terminado hasta el proximo refresco y,
  si la cola se llena, el juego se bloquea en Present. Es latencia pura agregada.
- **Enhanced Sync**: alternativa a VSync sin la espera. Evaluar, no asumir.
- **FreeSync**: estos dos monitores no lo soportan. No aplica.
- **Radeon Boost / Image Sharpening / Chill: OFF**. Chill limita FPS = mas latencia.

### Mouse y teclado (software del fabricante)
- Polling: **1000 Hz** es el punto razonable. 8000 Hz baja el intervalo de reporte
  de 1 ms a 0.125 ms — una mejora media de ~0.44 ms — a cambio de 8x interrupciones.
  Las cifras de costo de CPU que circulan (1-10%) vienen de blogs de fabricantes de
  mouse, no de benchmarks rigurosos: tratalas como no verificadas.
- DPI alto + sensibilidad baja in-game: satura los polls con datos de movimiento.
- Apagar angle snapping, smoothing y DPI downshift.
- **NO usar hidusbf**: driver sin firmar, incompatible con Vanguard/EAC/BattlEye.

### Monitor
- CRU a 75 Hz: el EDID no anuncia mas de 75 Hz, asi que 75 Hz es el techo realista.
  Verificar frame skipping en testufo.com/frameskipping despues. Si saltea frames,
  volver a 60 Hz. Ganancia esperada: ~1.67 ms de cuantizacion media.
- Activar Overdrive/AMA del monitor: reduce tiempo de respuesta del pixel a costa
  de overshoot.

## Protocolo de medicion antes/despues

1. **Linea base**: antes de tocar nada, correr `[D] Diagnostico` y guardar la salida.
2. **Polling real del mouse**: [MouseTester](https://github.com/valleyofdoom/MouseTester).
   Mira el intervalo entre polls. A 1000 Hz debe ser 1 ms plano. Si pica a 2 ms o
   mas, hay un problema (cable, puerto, contencion en el controlador).
3. **Click-to-photon**: celular en camara lenta (240 fps o mas) apuntando al mouse
   y a la pantalla a la vez. Contar frames entre el click y el fogonazo del disparo.
   A 240 fps cada frame son 4.17 ms — esa es tu resolucion de medicion.
   Repetir 20 veces y promediar; una sola muestra no dice nada.
4. **Latencia de sistema en juego**: [Frame Latency Meter](https://github.com/GPUOpen-Tools/frame_latency_meter)
   (AMD, funciona en Radeon) o PresentMon para frame pacing.
5. **Regla**: cambiar **un** tweak por vez y volver a medir. Si no medis, no sabes.

## Descartados

| Tweak | Motivo |
|---|---|
| Desactivar MPO (`OverlayTestMode=5`) | Al reves de lo que dicen las guias: quita `Hardware Composed: Independent Flip`, que es el camino de presentacion de **menor** latencia. Solo sirve para escapar de el, no para mejorarlo. |
| XHCI Interrupt Moderation (IMOD) | Requiere el driver RWEverything, que esta en la blocklist de drivers vulnerables. Incompatible con Vanguard/EAC/BattlEye y con el pedido de no usar drivers sin firmar. |
| Timer resolution global | Desde Win10 2004 es por proceso. Ademas el intervalo de polling USB lo fija el `bInterval` del endpoint HID y lo atiende el hardware xHCI, **no** el timer del kernel. Sin evidencia de que afecte el polling. |
| `hidusbf` | Driver sin firmar. Ban asegurado con los anticheats instalados. |
| Anti-Lag+ | Retirado por AMD tras causar bans de VAC. No existe mas. |
| VSync ON | Agrega latencia por diseno. |
| Desactivar optimizaciones de pantalla completa | Empuja a `Hardware: Legacy Flip`, que no es necesariamente mas rapido que Independent Flip. Medir antes, no aplicar a ciegas. |
| Tweaks de CPU/scheduler/afinidad/red/servicios | Fuera de alcance por pedido explicito. |

## Fuentes

- valleyofdoom/PC-Tuning — https://github.com/valleyofdoom/PC-Tuning
- Microsoft, Selective Suspend for HID Over USB Devices — https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/selective-suspend-for-hid-over-usb-devices
- Blur Busters Forums, input lag vs refresh rate — https://forums.blurbusters.com/viewtopic.php?f=10&t=3419
- Tom's Hardware, Anti-Lag+ y bans de VAC — https://www.tomshardware.com/news/amds-anti-lag-triggers-anti-cheat-protection-in-multiple-games
- AMD AntiLag2 SDK — https://github.com/GPUOpen-LibrariesAndSDKs/AntiLag2-SDK
- ASRock X870 Riptide WiFi, especificaciones — https://pg.asrock.com/mb/AMD/X870%20Riptide%20WiFi/index.asp
- BoringBoredom, PC Optimization Hub — https://github.com/BoringBoredom/PC-Optimization-Hub
