@echo off

set TAGDIR=C:\Elbis
cd %TAGDIR%

if not "%4"=="" goto i'm_just_curious
if "%3"=="" goto at_most_two_args
perl %TAGDIR%\main.pl %1 %2 %3
goto end

:at_most_two_args
if "%2"=="" goto at_most_one_arg
perl %TAGDIR%\main.pl %1 %2
goto end

:at_most_one_arg
if "%1"=="" goto i'm_just_curious
perl %TAGDIR%\main.pl %1
goto end

:i'm_just_curious
echo Equally Long Binary Strings 0.8a
echo Usage: elbis [-p^|-t^|-c^|-pa^|-r^|-f^|-y] filein [fileout]
echo.

:end
