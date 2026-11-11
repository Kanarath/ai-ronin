@echo off
rem Abre el Dojo de AI RONIN directamente (sin el editor de Godot). Doble clic y a jugar.
rem Busca Godot 4.7.2 en la variable GODOT o junto a la carpeta del proyecto.
setlocal
set "AQUI=%~dp0"
if defined GODOT if exist "%GODOT%" goto :jugar
set "GODOT=%AQUI%..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto :jugar
set "GODOT=%AQUI%..\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto :jugar
echo No encuentro Godot 4.7.2. Pon su ruta en la variable GODOT, por ejemplo:
echo   set GODOT=C:\ruta\Godot_v4.7.2-stable_win64.exe
pause
exit /b 1
:jugar
start "" "%GODOT%" --path "%AQUI%game"
