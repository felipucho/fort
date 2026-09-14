@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Optimizar-InputTweaks - Latencia de entrada Fortnite
color 0B

REM ===================================================================
REM  Optimizar-InputTweaks.bat
REM  Objetivo unico: reducir latencia de ENTRADA en la cadena
REM  input -> frame -> pixel. Mouse, teclado, USB, GPU y monitor.
REM  NO toca: red, ping, servicios, telemetria, CPU/scheduler,
REM  almacenamiento ni BIOS. Ver checklist manual aparte.
REM
REM  Todo cambio se respalda ANTES de aplicarse en:
REM    %USERPROFILE%\Documents\FortniteInputTweaks\backup_AAAAMMDD_HHMM
REM  Revertir-InputTweaks.bat restaura EXACTAMENTE ese backup.
REM ===================================================================

REM ---------- Autoelevacion a administrador ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando privilegios de administrador...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "ROOTDIR=%USERPROFILE%\Documents\FortniteInputTweaks"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -Command"
set "REGIDX=0"
set "BKDIR="
set "LOGFILE=%ROOTDIR%\ultima_ejecucion.log"
if not exist "%ROOTDIR%" mkdir "%ROOTDIR%" >nul 2>&1

REM Claves de registro usadas -----------------------------------------
set "K_MOUSE=HKCU\Control Panel\Mouse"
set "K_KBD=HKCU\Control Panel\Keyboard"
set "K_DVR1=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
set "K_DVR2=HKCU\System\GameConfigStore"
set "K_DVR3=HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
set "K_GBAR=HKCU\Software\Microsoft\GameBar"
set "K_HAGS=HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
set "K_GPUPREF=HKCU\SOFTWARE\Microsoft\DirectX\UserGpuPreferences"

:MENU
cls
echo ==========================================================
echo   OPTIMIZAR INPUT LATENCY - FORTNITE
echo   Mouse / Teclado / USB / GPU / Monitor
echo ==========================================================
echo.
echo   AVISO HONESTO: con los dos monitores a 60 Hz, el monitor
echo   es el mayor cuello de botella de toda la cadena. A 60 Hz
echo   cada refresco dura 16.67 ms y la latencia media que
echo   agrega la cuantizacion del refresco es ~8.33 ms.
echo   A 144 Hz seria ~3.47 ms y a 240 Hz ~2.08 ms.
echo   Ningun tweak de este script compensa esa diferencia.
echo.
echo   [1] Aplicar Seguro     - cambios reversibles, riesgo bajo
echo   [2] Avanzado           - confirma S/N por cada tweak
echo   [D] Diagnostico        - detecta hardware, no cambia nada
echo   [R] Revertir           - abre Revertir-InputTweaks.bat
echo   [S] Salir
echo.
set "OPCION="
set /p "OPCION=Elegi una opcion: "
if /i "!OPCION!"=="1" goto APPLY_SAFE
if /i "!OPCION!"=="2" goto APPLY_ADV
if /i "!OPCION!"=="D" goto DIAG
if /i "!OPCION!"=="R" goto GO_REVERT
if /i "!OPCION!"=="S" exit /b 0
goto MENU

REM ===================================================================
REM  DIAGNOSTICO
REM ===================================================================
:DIAG
cls
echo ================= DIAGNOSTICO =================
echo.
echo --- GPU activas y modo de video actual ---
%PS% "Get-CimInstance Win32_VideoController | ForEach-Object { '  ' + $_.Name + ' | driver ' + $_.DriverVersion + ' | ' + $_.CurrentHorizontalResolution + 'x' + $_.CurrentVerticalResolution + ' @ ' + $_.CurrentRefreshRate + ' Hz' }"
echo.
echo --- Aviso de refresco ---
%PS% "$b=$false; Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentRefreshRate -gt 0 } | ForEach-Object { if ($_.CurrentRefreshRate -lt 75) { $b=$true; Write-Host ('  ATENCION: ' + $_.Name + ' esta a ' + $_.CurrentRefreshRate + ' Hz') -ForegroundColor Yellow } }; if (-not $b) { Write-Host '  OK: ningun adaptador por debajo de 75 Hz' -ForegroundColor Green }"
echo.
echo --- Mouse y cadena de dispositivos hasta el controlador PCI ---
%PS% "foreach($d in Get-CimInstance Win32_PointingDevice){ $id=$d.PNPDeviceID; if(-not $id){continue}; Write-Host ('  Mouse: ' + $d.Name); Write-Host ('    InstanceId: ' + $id); $p=$id; for($i=0;$i -lt 8;$i++){ try{ $par=(Get-PnpDeviceProperty -InstanceId $p -KeyName 'DEVPKEY_Device_Parent' -ErrorAction Stop).Data }catch{ break }; if(-not $par){ break }; Write-Host ('    padre: ' + $par); if($par -like 'PCI*'){ try{ $n=(Get-PnpDevice -InstanceId $par -ErrorAction Stop).FriendlyName; Write-Host ('    CONTROLADOR USB: ' + $n) -ForegroundColor Cyan }catch{}; break }; $p=$par } }"
echo.
echo --- Teclado ---
%PS% "foreach($d in Get-CimInstance Win32_Keyboard){ Write-Host ('  Teclado: ' + $d.Name + ' | ' + $d.PNPDeviceID) }"
echo.
echo --- HAGS - Hardware Accelerated GPU Scheduling ---
reg query "%K_HAGS%" /v HwSchMode >nul 2>&1
if errorlevel 1 (
    echo   HwSchMode: SIN VALOR en registro - se usa el default del driver
) else (
    reg query "%K_HAGS%" /v HwSchMode | findstr /i HwSchMode
    echo   Referencia: 2 = habilitado, 1 = deshabilitado
)
echo.
echo --- Aceleracion de mouse actual ---
reg query "%K_MOUSE%" /v MouseSpeed 2>nul | findstr /i MouseSpeed
echo   Referencia: MouseSpeed 0 = sin aceleracion
echo.
echo --- Fortnite ---
set "FNCFG=%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini"
if exist "%FNCFG%" (echo   INI: "%FNCFG%") else (echo   INI: NO ENCONTRADO - abri Fortnite una vez y volve a correr)
if exist "C:\Program Files\Epic Games\Fortnite" (echo   Instalacion: C:\Program Files\Epic Games\Fortnite) else (echo   Instalacion: no esta en la ruta por defecto)
call :FIND_FN_EXE
if defined FNEXE (echo   Binario: "!FNEXE!") else (echo   Binario FortniteClient-Win64-Shipping.exe: no encontrado)
echo.
echo --- Esquema de energia activo ---
%PS% "$o = (powercfg /getactivescheme | Out-String); if ($o -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { Write-Host ('  GUID activo: ' + $Matches[1]) }"
echo.
echo   NOTA: Windows no expone el Hz de reporte real del mouse.
echo   Medilo con MouseTester - ver protocolo de medicion.
echo.
pause
goto MENU

REM ===================================================================
REM  APLICAR - PERFIL SEGURO
REM ===================================================================
:APPLY_SAFE
call :PREP_BACKUP
if errorlevel 1 goto MENU
echo.
echo ===== APLICANDO PERFIL SEGURO =====
echo.
call :TW_MOUSE_ACCEL
call :TW_KEYBOARD
call :TW_USB_SELSUSP_PLAN
call :TW_HID_POWER
call :TW_GAMEDVR
call :TW_GAMEMODE
call :TW_FN_BACKUP
echo.
echo ===== PERFIL SEGURO APLICADO =====
echo Backup en: "%BKDIR%"
echo Log:       "%LOGFILE%"
echo.
echo Cerra sesion o reinicia para que tomen efecto los cambios de HID.
pause
goto MENU

REM ===================================================================
REM  APLICAR - PERFIL AVANZADO
REM ===================================================================
:APPLY_ADV
call :PREP_BACKUP
if errorlevel 1 goto MENU
echo.
echo ===== PERFIL AVANZADO - confirmacion por tweak =====
echo.

echo [A1] HAGS - Hardware Accelerated GPU Scheduling = ON
echo      Mueve la planificacion de la cola de trabajo de la GPU al
echo      hardware de la GPU y saca al scheduler de Windows del camino.
echo      Impacto: BAJO y NO garantizado. Evidencia: MEDIDO pero
echo      contradictorio segun sistema. Hay que medirlo, no asumirlo.
echo      Riesgo: MEDIO - requiere reinicio. En algunos drivers AMD
echo      genera stutter. Revertible.
call :ASK "Aplicar HAGS = ON"
if /i "!ANS!"=="S" call :SETREG "%K_HAGS%" "HwSchMode" "REG_DWORD" "2"
echo.

echo [A2] Forzar la RX 6800 XT para Fortnite
echo      Evita que el binario quede asignado a la iGPU. Si el juego
echo      renderiza en la iGPU y copia el frame a la dGPU, se agrega
echo      una copia entre adaptadores antes del scanout.
echo      Impacto: ALTO si hoy usa la iGPU, NULO si ya usa la dGPU.
echo      Riesgo: BAJO. Revertible.
call :ASK "Forzar GPU de alto rendimiento para Fortnite"
if /i "!ANS!"=="S" call :TW_GPU_PREF
echo.

echo [A3] Modo MSI en el controlador USB del mouse
echo      Interrupciones por mensaje en vez de por linea. Evita
echo      interrupciones compartidas, una causa habitual de latencia
echo      de interrupcion alta e inestable en el camino del HID.
echo      Impacto: MEDIO, depende del sistema. Evidencia: CONSENSO.
echo      Riesgo: ALTO - en controladores que no lo soportan bien
echo      puede dejar el mouse muerto al reiniciar. Tene un teclado
echo      PS/2 o el USB en otro controlador como plan B.
call :ASK "Habilitar modo MSI en el controlador USB del mouse"
if /i "!ANS!"=="S" call :TW_MSI_MODE
echo.

echo [A4] Fortnite - limite de FPS sin tope
echo      Mas FPS = frame mas fresco en el momento del scanout, aun
echo      con el monitor a 60 Hz. Con una 6800 XT a 1080p el limite
echo      no aporta nada y agrega espera.
echo      Impacto: MEDIO. Riesgo: BAJO. El juego reescribe el INI al
echo      cerrar, asi que aplicalo con Fortnite CERRADO.
call :ASK "Poner FrameRateLimit sin tope en GameUserSettings.ini"
if /i "!ANS!"=="S" call :TW_FN_FPSLIMIT
echo.

echo ===== PERFIL AVANZADO TERMINADO =====
echo Backup en: "%BKDIR%"
pause
goto MENU

REM ===================================================================
REM  TWEAKS
REM ===================================================================

:TW_MOUSE_ACCEL
REM QUE HACE: apaga la aceleracion de puntero de Windows, o sea
REM   "mejorar la precision del puntero" / pointer ballistics.
REM POR QUE BAJA LATENCIA DE ENTRADA: la aceleracion aplica una curva
REM   no lineal de conteos del sensor a pixeles, con historial de
REM   movimientos previos. El mapeo deja de ser determinista, por lo
REM   que el resultado en pantalla para un mismo movimiento fisico
REM   varia. No baja el tiempo en ms, baja la varianza de la
REM   respuesta y hace el apuntado repetible.
REM HONESTIDAD: Fortnite usa raw input, asi que esto NO afecta el
REM   apuntado dentro de la partida. Afecta menus y escritorio.
REM IMPACTO: BAJO para latencia medida en ms. Consistencia: ALTO.
REM RIESGO: BAJO - solo cambia sensacion del puntero en el escritorio.
REM EVIDENCIA: CONSENSO
REM URL: https://github.com/valleyofdoom/PC-Tuning
echo [Mouse] Desactivando aceleracion de puntero...
call :SETREG "%K_MOUSE%" "MouseSpeed" "REG_SZ" "0"
call :SETREG "%K_MOUSE%" "MouseThreshold1" "REG_SZ" "0"
call :SETREG "%K_MOUSE%" "MouseThreshold2" "REG_SZ" "0"
goto :eof

:TW_KEYBOARD
REM QUE HACE: pone la demora de repeticion en el minimo y la tasa de
REM   repeticion en el maximo.
REM POR QUE BAJA LATENCIA DE ENTRADA: solo afecta la AUTO-REPETICION,
REM   es decir mantener una tecla apretada. El primer evento de tecla
REM   NO se ve afectado por estos valores.
REM HONESTIDAD: esto NO reduce la latencia del primer keypress. Se
REM   incluye porque estaba en el alcance pedido, con su efecto real.
REM IMPACTO: BAJO. Nulo sobre el primer input.
REM RIESGO: BAJO - escribir texto se vuelve mas sensible al repetir.
REM EVIDENCIA: DOC_OFICIAL sobre el mecanismo de repeticion
REM URL: https://github.com/valleyofdoom/PC-Tuning
echo [Teclado] Demora minima y repeticion maxima...
call :SETREG "%K_KBD%" "KeyboardDelay" "REG_SZ" "0"
call :SETREG "%K_KBD%" "KeyboardSpeed" "REG_SZ" "31"
goto :eof

:TW_USB_SELSUSP_PLAN
REM QUE HACE: desactiva la suspension selectiva de USB en el esquema
REM   de energia activo, en CA y en CC.
REM POR QUE BAJA LATENCIA DE ENTRADA: con la suspension activa, un
REM   dispositivo USB ocioso puede pasar a estado suspendido. El
REM   primer input despues de ese estado paga la latencia de reanudar
REM   el enlace antes de entregar el dato.
REM HONESTIDAD: un mouse gamer en partida nunca esta ocioso, asi que
REM   esto casi no actua durante el juego. Sirve para el primer
REM   movimiento despues de un rato quieto, por ejemplo en el lobby.
REM IMPACTO: BAJO en partida. MEDIO en el primer input tras inactividad.
REM RIESGO: BAJO - solo mas consumo en reposo.
REM EVIDENCIA: DOC_OFICIAL
REM URL: https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/selective-suspend-for-hid-over-usb-devices
echo [USB] Desactivando suspension selectiva en el plan de energia...
set "SCHEMEGUID="
for /f "delims=" %%g in ('%PS% "$o=(powercfg /getactivescheme ^| Out-String); if($o -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'){ $Matches[1] }"') do set "SCHEMEGUID=%%g"
if not defined SCHEMEGUID (
    call :LOG ERROR "No se pudo determinar el esquema de energia activo"
    goto :eof
)
>"%BKDIR%\scheme_guid.txt" echo !SCHEMEGUID!
set "K_PWR=HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\!SCHEMEGUID!\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
call :BK_VALUE "!K_PWR!" "ACSettingIndex"
call :BK_VALUE "!K_PWR!" "DCSettingIndex"
powercfg /setacvalueindex !SCHEMEGUID! 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 >nul 2>&1
if errorlevel 1 (call :LOG ERROR "powercfg CA fallo") else (call :LOG OK "USB selective suspend CA = 0")
powercfg /setdcvalueindex !SCHEMEGUID! 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 >nul 2>&1
if errorlevel 1 (call :LOG ERROR "powercfg CC fallo") else (call :LOG OK "USB selective suspend CC = 0")
powercfg /setactive !SCHEMEGUID! >nul 2>&1
goto :eof

:TW_HID_POWER
REM QUE HACE: desactiva el ahorro de energia por dispositivo en los
REM   devnodes del mouse y del teclado y en sus padres USB.
REM   EnhancedPowerManagementEnabled = 0 y SelectiveSuspendEnabled = 0.
REM POR QUE BAJA LATENCIA DE ENTRADA: es el equivalente por
REM   dispositivo de la opcion "permitir que el equipo apague este
REM   dispositivo para ahorrar energia". Evita que el enlace del HID
REM   entre en bajo consumo y que el primer reporte pague la
REM   reanudacion.
REM HONESTIDAD: los nombres exactos de los valores en runtime no
REM   estan documentados por Microsoft en la pagina de HID selective
REM   suspend, que describe el mecanismo via INF. Son CONSENSO.
REM   Se escriben ambos valores en cada devnode listado; donde no
REM   aplican son ignorados por el driver.
REM IMPACTO: BAJO en partida, MEDIO tras inactividad.
REM RIESGO: BAJO. Se revierte exacto desde el backup.
REM EVIDENCIA: CONSENSO - mecanismo DOC_OFICIAL
REM URL: https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/selective-suspend-for-hid-over-usb-devices
echo [HID] Desactivando ahorro de energia en mouse y teclado...
set "HIDLIST=%BKDIR%\hid_devnodes.txt"
%PS% "$ids=@(); $ids+=(Get-CimInstance Win32_PointingDevice).PNPDeviceID; $ids+=(Get-CimInstance Win32_Keyboard).PNPDeviceID; $out=@(); foreach($i in $ids){ if(-not $i){continue}; $out+=$i; try{ $p=(Get-PnpDeviceProperty -InstanceId $i -KeyName 'DEVPKEY_Device_Parent' -ErrorAction Stop).Data; if($p -and $p -like 'USB*'){ $out+=$p } }catch{} }; $out | Sort-Object -Unique | ForEach-Object { 'HKLM\SYSTEM\CurrentControlSet\Enum\' + $_ + '\Device Parameters' } | Set-Content -Encoding ASCII '%BKDIR%\hid_devnodes.txt'"
if not exist "!HIDLIST!" (
    call :LOG ERROR "No se pudo enumerar devnodes HID"
    goto :eof
)
for /f "usebackq delims=" %%K in ("!HIDLIST!") do (
    call :SETREG "%%K" "EnhancedPowerManagementEnabled" "REG_DWORD" "0"
    call :SETREG "%%K" "SelectiveSuspendEnabled" "REG_DWORD" "0"
)
goto :eof

:TW_GAMEDVR
REM QUE HACE: apaga la grabacion en segundo plano de Game DVR y la
REM   captura de Xbox Game Bar.
REM POR QUE BAJA LATENCIA DE ENTRADA: la captura engancha la cadena
REM   de presentacion. Con el hook activo el frame terminado puede
REM   pasar por composicion adicional antes de llegar al scanout, en
REM   vez de ir por el camino directo. Sacar el hook devuelve el
REM   camino de presentacion mas corto.
REM IMPACTO: MEDIO.
REM RIESGO: BAJO - perdes la grabacion con Win+G. Revertible.
REM EVIDENCIA: CONSENSO
REM URL: https://github.com/valleyofdoom/PC-Tuning
echo [Windows] Desactivando Game DVR y captura en segundo plano...
call :SETREG "%K_DVR1%" "AppCaptureEnabled" "REG_DWORD" "0"
call :SETREG "%K_DVR2%" "GameDVR_Enabled" "REG_DWORD" "0"
reg query "%K_DVR3%" >nul 2>&1 || reg add "%K_DVR3%" /f >nul 2>&1
call :SETREG "%K_DVR3%" "AllowGameDVR" "REG_DWORD" "0"
goto :eof

:TW_GAMEMODE
REM QUE HACE: deja Game Mode habilitado.
REM POR QUE BAJA LATENCIA DE ENTRADA: evita que Windows Update y
REM   ciertas notificaciones interrumpan al juego. Una interrupcion
REM   que roba tiempo al hilo de render se ve como un pico de
REM   latencia, no como perdida de FPS promedio.
REM HONESTIDAD: no hay medicion publicada de reduccion de latencia
REM   en ms atribuible a Game Mode. Ademas puede interferir con los
REM   boosts de prioridad de hilos. Se deja ON por ser el default y
REM   porque el efecto documentado es evitar interrupciones.
REM IMPACTO: BAJO.
REM RIESGO: BAJO.
REM EVIDENCIA: DOC_OFICIAL sobre que hace - INFERENCIA sobre latencia
REM URL: https://support.xbox.com/en-GB/help/games-apps/game-setup-and-play/use-game-mode-gaming-on-pc
echo [Windows] Asegurando Game Mode habilitado...
call :SETREG "%K_GBAR%" "AutoGameModeEnabled" "REG_DWORD" "1"
call :SETREG "%K_GBAR%" "AllowAutoGameMode" "REG_DWORD" "1"
goto :eof

:TW_FN_BACKUP
REM QUE HACE: copia GameUserSettings.ini al backup. No lo modifica.
echo [Fortnite] Respaldando GameUserSettings.ini...
set "FNCFG=%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini"
if not exist "%FNCFG%" (
    call :LOG ERROR "GameUserSettings.ini no encontrado - abri Fortnite una vez"
    goto :eof
)
copy /y "%FNCFG%" "%BKDIR%\GameUserSettings.ini.bak" >nul 2>&1
if errorlevel 1 (call :LOG ERROR "No se pudo copiar el INI") else (call :LOG OK "INI respaldado")
goto :eof

:TW_GPU_PREF
REM QUE HACE: registra el binario de Fortnite en las preferencias de
REM   GPU de DirectX con GpuPreference=2, alto rendimiento.
REM POR QUE BAJA LATENCIA DE ENTRADA: si el juego se asigna a la iGPU
REM   el frame se renderiza ahi y despues se copia al adaptador que
REM   maneja la salida de video. Esa copia entre adaptadores se paga
REM   entre el fin del render y el scanout. Fijar la dGPU la elimina.
REM IMPACTO: ALTO si hoy corre en la iGPU. NULO si ya corre en la dGPU.
REM RIESGO: BAJO. Revertible.
REM EVIDENCIA: DOC_OFICIAL - preferencia de GPU de Windows
REM URL: https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/multi-gpu-system
call :FIND_FN_EXE
if not defined FNEXE (
    call :LOG ERROR "No se encontro FortniteClient-Win64-Shipping.exe"
    goto :eof
)
reg query "%K_GPUPREF%" >nul 2>&1 || reg add "%K_GPUPREF%" /f >nul 2>&1
call :SETREG "%K_GPUPREF%" "!FNEXE!" "REG_SZ" "GpuPreference=2;"
goto :eof

:TW_MSI_MODE
REM QUE HACE: habilita MSI en el controlador PCI xHCI del que cuelga
REM   el mouse, escribiendo MSISupported = 1.
REM POR QUE BAJA LATENCIA DE ENTRADA: las interrupciones por mensaje
REM   no comparten linea. Las interrupciones compartidas son una causa
REM   habitual de latencia de interrupcion alta e inestable, y cada
REM   reporte del mouse llega justamente por una interrupcion.
REM IMPACTO: MEDIO. Depende del sistema, hay que medirlo.
REM RIESGO: ALTO. Si el controlador no lo soporta bien el mouse puede
REM   no responder al reiniciar. Revertible desde el backup, pero
REM   necesitas otro dispositivo de entrada para llegar a revertirlo.
REM EVIDENCIA: CONSENSO
REM URL: https://github.com/valleyofdoom/PC-Tuning
set "USBCTRL="
for /f "delims=" %%c in ('%PS% "foreach($d in Get-CimInstance Win32_PointingDevice){ $p=$d.PNPDeviceID; if(-not $p){continue}; for($i=0;$i -lt 8;$i++){ try{ $par=(Get-PnpDeviceProperty -InstanceId $p -KeyName 'DEVPKEY_Device_Parent' -ErrorAction Stop).Data }catch{ break }; if(-not $par){ break }; if($par -like 'PCI*'){ $par; exit }; $p=$par } }"') do set "USBCTRL=%%c"
if not defined USBCTRL (
    call :LOG ERROR "No se identifico el controlador PCI del mouse"
    goto :eof
)
echo   Controlador detectado: !USBCTRL!
set "K_MSI=HKLM\SYSTEM\CurrentControlSet\Enum\!USBCTRL!\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
reg query "!K_MSI!" >nul 2>&1
if errorlevel 1 (
    call :LOG ERROR "El controlador no expone MessageSignaledInterruptProperties - no soporta MSI"
    goto :eof
)
call :SETREG "!K_MSI!" "MSISupported" "REG_DWORD" "1"
echo   Requiere reinicio.
goto :eof

:TW_FN_FPSLIMIT
REM QUE HACE: pone FrameRateLimit en 0.000000, sin tope, en
REM   GameUserSettings.ini.
REM POR QUE BAJA LATENCIA DE ENTRADA: mas FPS significa que el frame
REM   que agarra el scanout fue generado hace menos tiempo, o sea
REM   contiene input mas reciente. Esto vale aunque el monitor este a
REM   60 Hz, porque el monitor muestra el ultimo frame completo.
REM HONESTIDAD: sin VSync esto produce tearing. Es el intercambio
REM   clasico entre latencia e imagen entera.
REM IMPACTO: MEDIO.
REM RIESGO: BAJO. Fortnite reescribe el INI al cerrar, hay que
REM   aplicarlo con el juego cerrado.
REM EVIDENCIA: CONSENSO
REM URL: https://github.com/valleyofdoom/PC-Tuning
set "FNCFG=%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini"
if not exist "%FNCFG%" (
    call :LOG ERROR "GameUserSettings.ini no encontrado"
    goto :eof
)
tasklist /fi "imagename eq FortniteClient-Win64-Shipping.exe" 2>nul | find /i "FortniteClient" >nul
if not errorlevel 1 (
    call :LOG ERROR "Fortnite esta abierto - cerralo y volve a intentar"
    goto :eof
)
if not exist "%BKDIR%\GameUserSettings.ini.bak" copy /y "%FNCFG%" "%BKDIR%\GameUserSettings.ini.bak" >nul 2>&1
%PS% "$f='%FNCFG%'; $c=Get-Content -LiteralPath $f; if($c -match 'FrameRateLimit'){ $c = $c -replace '^FrameRateLimit=.*','FrameRateLimit=0.000000' } else { $c += 'FrameRateLimit=0.000000' }; Set-Content -LiteralPath $f -Value $c -Encoding ASCII"
if errorlevel 1 (call :LOG ERROR "No se pudo editar el INI") else (call :LOG OK "FrameRateLimit sin tope")
goto :eof

REM ===================================================================
REM  UTILIDADES
REM ===================================================================

:FIND_FN_EXE
set "FNEXE="
for %%P in (
 "C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe"
) do if exist "%%~P" set "FNEXE=%%~P"
goto :eof

:PREP_BACKUP
set "STAMP="
for /f "delims=" %%i in ('%PS% "Get-Date -Format yyyyMMdd_HHmm"') do set "STAMP=%%i"
if not defined STAMP (
    echo ERROR: no se pudo generar la marca de tiempo.
    pause
    exit /b 1
)
set "BKDIR=%ROOTDIR%\backup_!STAMP!"
set "LOGFILE=!BKDIR!\log.txt"
if not exist "!BKDIR!\reg" mkdir "!BKDIR!\reg" >nul 2>&1
if not exist "!BKDIR!" (
    echo ERROR: no se pudo crear el directorio de backup.
    pause
    exit /b 1
)
set "REGIDX=0"
>"!LOGFILE!" echo ==== Optimizar-InputTweaks ====
call :LOG OK "Backup iniciado en !BKDIR!"
REM Estado de HAGS antes de tocar nada
reg query "%K_HAGS%" /v HwSchMode >"!BKDIR!\hags_antes.txt" 2>&1
exit /b 0

:BK_VALUE
REM %1 = clave, %2 = nombre de valor
set "BK_K=%~1"
set "BK_V=%~2"
reg query "%BK_K%" /v "%BK_V%" >nul 2>&1
if errorlevel 1 (
    >>"%BKDIR%\valores_ausentes.txt" echo %BK_K%@@%BK_V%
    call :LOG OK "Backup - valor inexistente, se borrara al revertir"
    goto :eof
)
if not exist "%BKDIR%\reg_index.txt" goto BK_DOEXPORT
findstr /i /c:"@@%BK_K%" "%BKDIR%\reg_index.txt" >nul 2>&1
if not errorlevel 1 goto :eof
:BK_DOEXPORT
set /a REGIDX+=1
reg export "%BK_K%" "%BKDIR%\reg\key_!REGIDX!.reg" /y >nul 2>&1
if errorlevel 1 (
    call :LOG ERROR "Fallo reg export de %BK_K%"
    goto :eof
)
>>"%BKDIR%\reg_index.txt" echo key_!REGIDX!.reg@@%BK_K%
call :LOG OK "Backup reg export de %BK_K%"
goto :eof

:SETREG
REM %1=clave %2=valor %3=tipo %4=dato
set "SR_K=%~1"
set "SR_V=%~2"
set "SR_T=%~3"
set "SR_D=%~4"
if /i "%SR_T%"=="REG_DWORD" (set "SR_EXP=0x%SR_D%") else (set "SR_EXP=%SR_D%")
set "SR_CUR="
for /f "tokens=2,*" %%a in ('reg query "%SR_K%" /v "%SR_V%" 2^>nul ^| findstr /i /c:"%SR_V%"') do set "SR_CUR=%%b"
if /i "!SR_CUR!"=="%SR_EXP%" (
    call :LOG OK "Ya aplicado - %SR_V%"
    goto :eof
)
call :BK_VALUE "%SR_K%" "%SR_V%"
reg add "%SR_K%" /v "%SR_V%" /t %SR_T% /d "%SR_D%" /f >nul 2>&1
if errorlevel 1 (
    call :LOG ERROR "No se pudo escribir %SR_V% en %SR_K%"
) else (
    call :LOG OK "Aplicado %SR_V% = %SR_D%"
)
goto :eof

:ASK
set "ANS="
set /p "ANS=     %~1 ? [S/N]: "
goto :eof

:LOG
echo   [%~1] %~2
if defined LOGFILE >>"%LOGFILE%" echo [%~1] %~2
goto :eof

:GO_REVERT
if exist "%~dp0Revertir-InputTweaks.bat" (
    start "" "%~dp0Revertir-InputTweaks.bat"
    exit /b 0
)
echo No se encontro Revertir-InputTweaks.bat junto a este script.
pause
goto MENU
