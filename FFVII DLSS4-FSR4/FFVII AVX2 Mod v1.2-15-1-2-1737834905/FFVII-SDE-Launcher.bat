@echo off
TITLE Final Fantasy VII SDE Launcher
rem by Sildur
rem https://www.nexusmods.com/finalfantasy7rebirth/mods/15

:: BatchGotAdmin
::-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params = %*:"="
    echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
::--------------------------------------

rem Start injector helper
echo Launching injector helper..
start /min /D ".\SDE\" Injector-Helper.bat
timeout /t 3 /nobreak > nul
echo Injector helper started!

rem get PID of injector helper
echo Attaching SDE to injector helper..
for /F "tokens=2" %%G in ('tasklist /V /NH /FO table ^|find "cmd.exe" ^|find "SDE-Injector-Helper"') do set getPID=%%G
timeout /t 3 /nobreak > nul

rem Attach SDE to injector helper
echo SDE successfully attached!
start /D ".\SDE\" /B sde.exe -hsw -sync_avx512_state 0 -emu_xinuse 0 -xsave 0 -sde_skip_int3 1 -attach-pid %getPID%

echo Launching Final Fantasy VII..
:loop
Tasklist /FO csv /FI "IMAGENAME eq ff7rebirth_.exe" | find /I "ff7rebirth_.exe" > nul
if "%ERRORLEVEL%"=="0" (timeout /t 5 /nobreak > NUL && echo Final Fantasy VII successfully started! && echo Check Taskmanager because launch will take a while. && echo Slowly leaving now, enjoy the game! && timeout /t 60 /nobreak) else (timeout /t 5 /nobreak > NUL && goto :loop)

