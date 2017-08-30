@ECHO OFF

SETLOCAL enableExtensions enableDelayedExpansion

SET here=%~dp0

SET argCount=0

:: Based on Stack Overflow "Batch files - number of command line arguments"
:: https://stackoverflow.com/a/1292079/170990

:argLoop
IF NOT x%1x==xx (
    SET /A argCount+=1
    SET "argVec[!argCount!]=%1"
    SHIFT
    GOTO :argLoop
)

set argString=

FOR /L %%i IN (1,1,%argCount%) DO (
    :: Add space if needed
    if not "x!argString!"=="x" ( set argString=!argString! )

    :: Check for spaces and surround in double quotes if needed
    if not "x!argVec[%%i]: =!"=="x!argVec[%%i]!" (
        if "!argVec[%%i]:~0,1!!argVec[%%i]:~-1,1!"=="""" (
            set argString=!argString!\"!argVec[%%i]:~1,-1!\"
        ) else (
            set argString=!argString!\"!argVec[%%i]!\"
        )
    ) else (
        set argString=!argString!!argVec[%%i]!
    )
)

@powershell -NoProfile -ExecutionPolicy Bypass -Command "& '!here!\Accelerator.ps1' !argstring!"

ENDLOCAL
