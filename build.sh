#!/bin/sh
PROJECTNAME="LostPartyIntro"

BuildError () {
    PROJECTNAME=
    echo Build failed, aborting...
    exit 1
}

# Build ROM
# python xmconv.py Demotune.xm Demotune.bin
echo Assembling...
rgbasm -o $PROJECTNAME.obj -p 255 Main.asm
if test $? -eq 1; then
    BuildError
fi
# rgbasm -DGBS -o $PROJECTNAME_GBS.obj -p 255 Main.asm
# if errorlevel 1 goto :BuildError
echo Linking...
rgblink -p 255 -o $PROJECTNAME.gb -n $PROJECTNAME.sym $PROJECTNAME.obj
if test $? -eq 1; then
    BuildError
fi
# rgblink -p 255 -o $PROJECTNAME_GBS.gb $PROJECTNAME_GBS.obj
# if errorlevel 1 goto :BuildError
echo Fixing...
rgbfix -v -p 255 $PROJECTNAME.gb
echo Cleaning up...
rm $PROJECTNAME.obj
echo Build complete.

# unset vars
PROJECTNAME=
echo "** Build finished with no errors **"
