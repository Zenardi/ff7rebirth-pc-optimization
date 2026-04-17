@echo off
title SDE-Injector-Helper
rem by Sildur
rem https://www.nexusmods.com/finalfantasy7rebirth/mods/15
echo Setting up SDE..
timeout /t 10 /nobreak > NUL
echo Done! Launching Final Fantasy VII..
start /D "..\" /B ff7rebirth_.exe
echo Slowly leaving now, enjoy the game!
timeout /t 65 /nobreak