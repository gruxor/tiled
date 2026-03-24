@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "CLEAN_BUILD=0"
set "FORCE_QMAKE=0"
set "KEEP_SYMBOLS=0"
set "NO_CLEANUP=0"
set "PS_ARGS="

rem Optional machine-specific defaults. Edit these if auto-detect fails.
set "DEFAULT_QT_PATH="
set "DEFAULT_VCVARS_PATH="
set "DEFAULT_JOBS=16"

if defined DEFAULT_QT_PATH set "PS_ARGS=%PS_ARGS% -QtPath "%DEFAULT_QT_PATH%""
if defined DEFAULT_VCVARS_PATH set "PS_ARGS=%PS_ARGS% -VcVarsPath "%DEFAULT_VCVARS_PATH%""
if defined DEFAULT_JOBS set "PS_ARGS=%PS_ARGS% -Jobs "%DEFAULT_JOBS%""

:parse_args
if "%~1"=="" goto :run

if /I "%~1"=="-clean" (
  set "CLEAN_BUILD=1"
  set "FORCE_QMAKE=1"
  shift
  goto :parse_args
)
if /I "%~1"=="clean" (
  set "CLEAN_BUILD=1"
  set "FORCE_QMAKE=1"
  shift
  goto :parse_args
)
if /I "%~1"=="-symbols" (
  set "KEEP_SYMBOLS=1"
  shift
  goto :parse_args
)
if /I "%~1"=="-verbose" (
  set "PS_ARGS=%PS_ARGS% -ShowCompileCommands"
  shift
  goto :parse_args
)
if /I "%~1"=="-nosummary" (
  set "PS_ARGS=%PS_ARGS% -NoSummary"
  shift
  goto :parse_args
)
if /I "%~1"=="-nocolor" (
  set "PS_ARGS=%PS_ARGS% -NoColor"
  shift
  goto :parse_args
)
if /I "%~1"=="-nocleanup" (
  set "NO_CLEANUP=1"
  set "KEEP_SYMBOLS=1"
  set "PS_ARGS=%PS_ARGS% -NoCleanup"
  shift
  goto :parse_args
)
if /I "%~1"=="-log" (
  if "%~2"=="" (
    echo ERROR: -log requires a path value
    exit /b 2
  )
  set "PS_ARGS=%PS_ARGS% -LogPath "%~2""
  shift
  shift
  goto :parse_args
)
if /I "%~1"=="-path" (
  if "%~2"=="" (
    echo ERROR: -path requires an absolute path value
    exit /b 2
  )
  set "PS_ARGS=%PS_ARGS% -OutputPath "%~2""
  shift
  shift
  goto :parse_args
)
if /I "%~1"=="-qt" (
  if "%~2"=="" (
    echo ERROR: -qt requires a path value
    exit /b 2
  )
  set "PS_ARGS=%PS_ARGS% -QtPath "%~2""
  shift
  shift
  goto :parse_args
)
if /I "%~1"=="-vcvars" (
  if "%~2"=="" (
    echo ERROR: -vcvars requires a path value
    exit /b 2
  )
  set "PS_ARGS=%PS_ARGS% -VcVarsPath "%~2""
  shift
  shift
  goto :parse_args
)
if /I "%~1"=="-help" goto :help
if /I "%~1"=="--help" goto :help
if /I "%~1"=="-h" goto :help
if /I "%~1"=="help" goto :help

set "PS_ARGS=%PS_ARGS% "%~1""
shift
goto :parse_args

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%tilezed-build.ps1" %PS_ARGS%
set "EC=%ERRORLEVEL%"
exit /b %EC%

:help
echo Usage:
echo   build.cmd [flags] [build-args]
echo.
echo Flags:
echo   -clean              Full rebuild ^(sets CLEAN_BUILD=1 FORCE_QMAKE=1^)
echo   -symbols            Keep .pdb files ^(sets KEEP_SYMBOLS=1^)
echo   -verbose            Show long compile/tool command lines
echo   -nosummary          Hide wrapper warning/error summary line
echo   -nocolor            Disable colored output in wrapper
echo   -log ^<path^>         Write full wrapper/build output to path
echo   -path ^<path^>        Absolute output path for build artifacts
echo   -qt ^<path^>          Absolute Qt kit path ^(folder containing bin\qmake.exe^)
echo   -vcvars ^<path^>      Absolute path to vcvarsall.bat
echo   -nocleanup          Skip cleanup stage and keep intermediate files ^(implies -symbols^)
echo.
echo Optional defaults can be edited at the top of build.cmd:
echo   DEFAULT_QT_PATH
echo   DEFAULT_VCVARS_PATH
echo   DEFAULT_JOBS ^(defaults to 16^)
echo.
echo Any other arguments are passed through to tilezed-build.bat.
exit /b 0
