@ECHO OFF

SETLOCAL enableExtensions enableDelayedExpansion

SET argCount=0
FOR %%x IN (%*) DO (
   SET /A argCount+=1
   SET "argVec[!argCount!]=%%~x"
)

set argString=

FOR /L %%i IN (1,1,%argCount%) DO (
    :: Add space if needed
    if not "x!argString!"=="x" ( set argString=!argString! )

    :: Check for spaces and surround in double quotes if needed
    if not "x!argVec[%%i]: =!"=="x!argVec[%%i]!" (
        set argString=!argString!\"!argVec[%%i]!\"
    ) else (
        set argString=!argString!!argVec[%%i]!
    )
)

@powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\Accelerator.ps1' !argstring!"

ENDLOCAL
