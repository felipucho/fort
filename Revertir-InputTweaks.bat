@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Revertir-InputTweaks
color 0E

REM ===================================================================
REM  Revertir-InputTweaks.bat
REM  Restaura EXACTAMENTE desde un backup creado por
REM  Optimizar-InputTweaks.bat. No aplica valores "por defecto"
REM  supuestos: reimporta los .reg exportados y borra unicamente los
REM  valores que NO existian antes de aplicar.
REM ===================================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando privilegios de administrador...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "ROOTDIR=%USERPROFILE%\Documents\FortniteInputTweaks"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -Command"

if not exist "%ROOTDIR%" (
    echo No existe "%ROOTDIR%". No hay nada que revertir.
    pause
    exit /b 1
)

cls
echo ==========================================================
echo   REVERTIR INPUT TWEAKS
echo ==========================================================
echo.
echo Backups disponibles:
echo.
set "IDX=0"
for /f "delims=" %%d in ('dir /b /ad /o-n "%ROOTDIR%\backup_*" 2^>nul') do (
    set /a IDX+=1
    set "BK[!IDX!]=%%d"
    echo    [!IDX!] %%d
)
if "!IDX!"=="0" (
    echo    ninguno.
    pause
    exit /b 1
)
echo.
set "PICK="
set /p "PICK=Numero de backup a restaurar - Enter para el mas reciente [1]: "
if not defined PICK set "PICK=1"
set "SEL=!BK[%PICK%]!"
if not defined SEL (
    echo Seleccion invalida.
    pause
    exit /b 1
)
set "BKDIR=%ROOTDIR%\!SEL!"
set "LOGFILE=%BKDIR%\revert_log.txt"
>"%LOGFILE%" echo ==== Revertir-InputTweaks ====

echo.
echo Se va a restaurar desde: "%BKDIR%"
set "CONFIRM="
set /p "CONFIRM=Confirmas ? [S/N]: "
if /i not "!CONFIRM!"=="S" (
    echo Cancelado.
    pause
    exit /b 0
)

echo.
echo ===== RESTAURANDO =====
echo.

REM ---- 1. Reimportar las claves exportadas -------------------------
REM Devuelve a cada valor el dato exacto que tenia antes.
if exist "%BKDIR%\reg" (
    for %%f in ("%BKDIR%\reg\*.reg") do (
        reg import "%%~ff" >nul 2>&1
        if errorlevel 1 (
            call :LOG ERROR "Fallo import de %%~nxf"
        ) else (
            call :LOG OK "Importado %%~nxf"
        )
    )
) else (
    call :LOG ERROR "No hay carpeta reg en el backup"
)

REM ---- 2. Borrar los valores que NO existian antes ------------------
REM reg import no elimina valores creados despues del export, asi que
REM los valores que el optimizador creo de cero se borran aca.
if exist "%BKDIR%\valores_ausentes.txt" (
    for /f "usebackq tokens=1,2 delims=@" %%a in ("%BKDIR%\valores_ausentes.txt") do (
        reg delete "%%a" /v "%%b" /f >nul 2>&1
        if errorlevel 1 (
            call :LOG ERROR "No se pudo borrar %%b"
        ) else (
            call :LOG OK "Borrado valor creado por el script - %%b"
        )
    )
) else (
    call :LOG OK "No habia valores creados de cero"
)

REM ---- 3. Reactivar el esquema de energia ---------------------------
REM Las claves de PowerSchemes ya se reimportaron; setactive hace que
REM el subsistema de energia vuelva a leerlas.
if exist "%BKDIR%\scheme_guid.txt" (
    set "SCHEMEGUID="
    for /f "usebackq delims=" %%g in ("%BKDIR%\scheme_guid.txt") do set "SCHEMEGUID=%%g"
    if defined SCHEMEGUID (
        powercfg /setactive !SCHEMEGUID! >nul 2>&1
        if errorlevel 1 (
            call :LOG ERROR "No se pudo reactivar el esquema de energia"
        ) else (
            call :LOG OK "Esquema de energia reactivado"
        )
    )
) else (
    call :LOG OK "No se habia tocado el esquema de energia"
)

REM ---- 4. Restaurar GameUserSettings.ini ----------------------------
set "FNCFG=%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini"
if exist "%BKDIR%\GameUserSettings.ini.bak" (
    tasklist /fi "imagename eq FortniteClient-Win64-Shipping.exe" 2>nul | find /i "FortniteClient" >nul
    if not errorlevel 1 (
        call :LOG ERROR "Fortnite esta abierto - cerralo y volve a correr para restaurar el INI"
    ) else (
        copy /y "%BKDIR%\GameUserSettings.ini.bak" "%FNCFG%" >nul 2>&1
        if errorlevel 1 (
            call :LOG ERROR "No se pudo restaurar GameUserSettings.ini"
        ) else (
            call :LOG OK "GameUserSettings.ini restaurado"
        )
    )
) else (
    call :LOG OK "No habia backup de GameUserSettings.ini"
)

echo.
echo ===== REVERSION TERMINADA =====
echo Log: "%LOGFILE%"
echo.
echo Reinicia para que vuelvan a tomar efecto los cambios de HID,
echo MSI y HAGS.
echo.
pause
exit /b 0

:LOG
echo   [%~1] %~2
if defined LOGFILE >>"%LOGFILE%" echo [%~1] %~2
goto :eof
