@echo off
set PROJECTNAME="LostPartyIntro"

rem	Build ROM
python xmconv.py Demotune_New.xm Demotune.bin
echo Assembling...
rgbasm -o %PROJECTNAME%.obj -p 255 Main.asm
if errorlevel 1 goto :BuildError
rgbasm -DGBS -o %PROJECTNAME%_GBS.obj -p 255 Main.asm
if errorlevel 1 goto :BuildError
echo Linking...
rgblink -p 255 -o %PROJECTNAME%.gb -n %PROJECTNAME%.sym %PROJECTNAME%.obj
if errorlevel 1 goto :BuildError
rgblink -p 255 -o %PROJECTNAME%_GBS.gb %PROJECTNAME%_GBS.obj
if errorlevel 1 goto :BuildError
echo Fixing...
rgbfix -v -p 255 %PROJECTNAME%.gb
echo Cleaning up...
del %PROJECTNAME%.obj
echo Build complete.
del /f %PROJECTNAME%_GBS.obj %PROJECTNAME%_GBS.gb
goto :end

:BuildError
set PROJECTNAME=
echo Build failed, aborting...
goto:eof

:GBSMakeError
set PROJECTNAME=
echo GBS build failed, aborting...
goto:eof

:end
rem unset vars
set PROJECTNAME=
echo ** Build finished with no errors **
