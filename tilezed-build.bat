@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

rem ===== ENV OVERRIDES (set by build.cmd / wrapper) =====
if not defined QT_OVERRIDE set "QT_OVERRIDE="
if not defined VCVARS_OVERRIDE set "VCVARS_OVERRIDE="
if not defined KEEP_SYMBOLS set "KEEP_SYMBOLS=0"
if not defined CLEAN_BUILD set "CLEAN_BUILD=0"
if not defined FORCE_QMAKE set "FORCE_QMAKE=0"
if not defined STRIP_BUILD_TREE set "STRIP_BUILD_TREE=0"
if not defined NO_CLEANUP set "NO_CLEANUP=0"
if not defined JOBS set "JOBS="
if not defined ENABLE_CL_MP set "ENABLE_CL_MP=1"
rem ===================================================

set "SRC=%SCRIPT_DIR%"
if not defined BUILD_OUTPUT_PATH set "BUILD=%SCRIPT_DIR%\.build"
if defined BUILD_OUTPUT_PATH set "BUILD=%BUILD_OUTPUT_PATH%"
if defined BUILD_OUTPUT_PATH call :validate_absolute BUILD_OUTPUT_PATH || exit /b 1
set "SPEC=win32-msvc"
set "CFG=release"

echo [check] MSVC toolchain
call :find_msvc || exit /b 1

echo [check] Qt5
call :find_qt5 || exit /b 1

set "QMAKE=%QT%\bin\qmake.exe"
set "WINDEPLOYQT=%QT%\bin\windeployqt.exe"
set "CONFIG_STAMP=%BUILD%\.configure.stamp"

set "MAKE_TOOL=nmake"
where jom >nul 2>&1 && set "MAKE_TOOL=jom"
for %%I in ("%QT%\..\..\") do (
  if exist "%%~fITools\QtCreator\bin\jom\jom.exe" (
    set "MAKE_TOOL=%%~fITools\QtCreator\bin\jom\jom.exe"
  )
)

set "MAKE_ARGS="
if /I not "%MAKE_TOOL%"=="nmake" (
  if "%JOBS%"=="" set "JOBS=%NUMBER_OF_PROCESSORS%"
  if not "%JOBS%"=="" set "MAKE_ARGS=-j %JOBS%"
)

set "QMAKE_MP_ARGS="
if "%ENABLE_CL_MP%"=="1" set "QMAKE_MP_ARGS=QMAKE_CFLAGS+=/MP QMAKE_CXXFLAGS+=/MP"

echo [check] project files
if not exist "%SRC%\tiled.pro" (echo ERROR: tiled.pro not found at %SRC% & exit /b 1)
if not exist "%SRC%\src\tiled\luatiled.pkg" (echo ERROR: luatiled.pkg missing & exit /b 1)

echo [prep] build dir + configure
if "%CLEAN_BUILD%"=="1" (
  if exist "%SRC%\.qmake.cache" del /f /q "%SRC%\.qmake.cache"
  if exist "%SRC%\.qmake.stash" del /f /q "%SRC%\.qmake.stash"
  if exist "%BUILD%" rmdir /s /q "%BUILD%"
)
if not exist "%BUILD%" mkdir "%BUILD%" || (echo ERROR: failed to create build dir & exit /b 1)

cd /d "%BUILD%" || (echo ERROR: cd failed & exit /b 1)
set "NEED_QMAKE=0"
if "%FORCE_QMAKE%"=="1" set "NEED_QMAKE=1"
if not exist "%BUILD%\Makefile" set "NEED_QMAKE=1"
if not exist "%CONFIG_STAMP%" set "NEED_QMAKE=1"
if "%NEED_QMAKE%"=="0" (
  findstr /x /c:"SRC=%SRC%" "%CONFIG_STAMP%" >nul 2>&1 || set "NEED_QMAKE=1"
)
if "%NEED_QMAKE%"=="0" (
  findstr /x /c:"QMAKE=%QMAKE%" "%CONFIG_STAMP%" >nul 2>&1 || set "NEED_QMAKE=1"
)

if "%NEED_QMAKE%"=="1" (
  echo [prep] reconfiguring with qmake
  "%QMAKE%" "%SRC%\tiled.pro" -r -spec %SPEC% "CONFIG+=%CFG%" %QMAKE_MP_ARGS% || goto :fail
  > "%CONFIG_STAMP%" (
    echo SRC=%SRC%
    echo QMAKE=%QMAKE%
    echo SPEC=%SPEC%
    echo CFG=%CFG%
  )
)

echo [build] using %MAKE_TOOL% %MAKE_ARGS%

echo [1/4] build lua first (produces lua.lib)
cd /d "%BUILD%\src\lua" || (echo ERROR: missing %BUILD%\src\lua & goto :fail)
"%MAKE_TOOL%" %MAKE_ARGS% || goto :fail
if not exist "%BUILD%\lib\lua.lib" (
  echo ERROR: %BUILD%\lib\lua.lib not produced
  goto :fail
)

echo [2/4] build tolua (produces tolua.lib + tolua.exe)
cd /d "%BUILD%\src\tolua\src" || (echo ERROR: missing %BUILD%\src\tolua\src & goto :fail)
"%MAKE_TOOL%" %MAKE_ARGS% || goto :fail
if not exist "%BUILD%\lib\tolua.lib" (
  echo ERROR: %BUILD%\lib\tolua.lib not produced
  goto :fail
)
if not exist "%BUILD%\tolua.exe" (
  echo ERROR: %BUILD%\tolua.exe not produced
  goto :fail
)

echo [3/4] generate luatiled.tolua.cpp
cd /d "%BUILD%\src\tiled" || (echo ERROR: missing %BUILD%\src\tiled & goto :fail)
"%BUILD%\tolua.exe" -n tiled -o luatiled.tolua.cpp "%SRC%\src\tiled\luatiled.pkg" || goto :fail
if not exist "%BUILD%\src\tiled\luatiled.tolua.cpp" (
  echo ERROR: luatiled.tolua.cpp was not generated
  goto :fail
)

echo [4/4] build everything
cd /d "%BUILD%" || goto :fail
"%MAKE_TOOL%" %MAKE_ARGS% || goto :fail
if not exist "%BUILD%\TileZed.exe" (
  echo ERROR: %BUILD%\TileZed.exe not produced
  goto :fail
)

echo [deploy] runtime + assets
call :copy_file "%SRC%\dist\win\qt.conf" "%BUILD%\qt.conf" || goto :fail

call :copy_file "%SRC%\AUTHORS" "%BUILD%\AUTHORS.txt" || goto :fail
call :copy_file "%SRC%\COPYING" "%BUILD%\COPYING.txt" || goto :fail
call :copy_file "%SRC%\LICENSE.APACHE" "%BUILD%\LICENSE.APACHE.txt" || goto :fail
call :copy_file "%SRC%\LICENSE.BSD" "%BUILD%\LICENSE.BSD.txt" || goto :fail
call :copy_file "%SRC%\LICENSE.GPL" "%BUILD%\LICENSE.GPL.txt" || goto :fail
call :copy_file "%SRC%\LICENSE.QT5" "%BUILD%\LICENSE.QT5.txt" || goto :fail
call :copy_file "%SRC%\NEWS" "%BUILD%\NEWS.txt" || goto :fail
call :copy_file "%SRC%\README.md" "%BUILD%\README.txt" || goto :fail

for %%F in (
  LuaTools.txt
  Rearrange.txt
  RearrangeGrid.txt
  RoomNames.txt
  RoomTone.txt
  TileProperties.txt
  Tilesets.txt
  Curbs.txt
  Edges.txt
  Fences.txt
  Textures.txt
  TileShapes.txt
) do (
  call :copy_file "%SRC%\%%F" "%BUILD%\%%F" || goto :fail
)

for %%F in (
  BuildingFurniture.txt
  BuildingTemplates.txt
  BuildingTiles.txt
  TMXConfig.txt
) do (
  call :copy_file "%SRC%\src\tiled\BuildingEditor\%%F" "%BUILD%\%%F" || goto :fail
)

call :copy_dir "%SRC%\lua" "%BUILD%\lua" || goto :fail
call :copy_dir "%SRC%\examples" "%BUILD%\examples" || goto :fail
call :copy_dir "%SRC%\docs\TileProperties" "%BUILD%\docs\TileProperties" || goto :fail
call :copy_dir "%SRC%\docs\TileZed" "%BUILD%\docs\TileZed" || goto :fail
call :copy_dir "%SRC%\src\tiled\BuildingEditor\manual" "%BUILD%\docs\BuildingEd" || goto :fail
call :copy_file "%SRC%\docs\map.dtd" "%BUILD%\docs\map.dtd" || goto :fail
call :copy_file "%SRC%\docs\map.xsd" "%BUILD%\docs\map.xsd" || goto :fail

if not exist "%BUILD%\translations" mkdir "%BUILD%\translations" || goto :fail
for %%F in (qt_*.qm qtbase_*.qm) do (
  for %%G in ("%QT%\translations\%%F") do (
    if exist "%%~fG" call :copy_file "%%~fG" "%BUILD%\translations\%%~nxG" || goto :fail
  )
)

for %%F in (TileZed.exe config.exe tmxviewer.exe automappingconverter.exe) do (
  if exist "%BUILD%\%%F" (
    "%WINDEPLOYQT%" --release --force --compiler-runtime --dir "%BUILD%" "%BUILD%\%%F" || goto :fail
  )
)

if "%NO_CLEANUP%"=="1" (
  echo [cleanup] skipped ^(NO_CLEANUP=1^)
) else (
  echo [cleanup] build artifacts
  if "%STRIP_BUILD_TREE%"=="1" (
    call :remove_file "%BUILD%\.qmake.cache"
    call :remove_file "%BUILD%\.qmake.stash"
    call :remove_file "%BUILD%\Makefile"
    call :remove_file "%BUILD%\Makefile.initvars"
    call :remove_file "%BUILD%\tolua.exe"
    call :remove_dir  "%BUILD%\src"
    call :remove_dir  "%BUILD%\lib"
  )
  if "%KEEP_SYMBOLS%"=="0" del /f /q "%BUILD%\*.pdb" >nul 2>&1
)

echo.
echo SUCCESS
for %%F in (TileZed.exe config.exe tmxviewer.exe automappingconverter.exe) do (
  if exist "%BUILD%\%%F" echo FOUND: %BUILD%\%%F
)
if exist "%BUILD%\lua\tool-edge.png" echo FOUND: %BUILD%\lua\tool-edge.png
if exist "%BUILD%\docs\TileZed\index.html" echo FOUND: %BUILD%\docs\TileZed\index.html
if exist "%BUILD%\translations" echo FOUND: %BUILD%\translations
if exist "%BUILD%\platforms\qwindows.dll" echo FOUND: %BUILD%\platforms\qwindows.dll
exit /b 0

:copy_file
copy /y "%~1" "%~2" >nul || exit /b 1
exit /b 0

:copy_dir
if not exist "%~2" mkdir "%~2" >nul || exit /b 1
xcopy "%~1\*" "%~2\" /e /i /y >nul || exit /b 1
exit /b 0

:remove_file
if exist "%~1" del /f /q "%~1" >nul
exit /b 0

:remove_dir
if exist "%~1" rmdir /s /q "%~1"
exit /b 0

:validate_absolute
call set "_P=%%%~1%%"
if "%_P%"=="" exit /b 0
if "%_P:~1,1%"==":" exit /b 0
if "%_P:~0,2%"=="\\" exit /b 0
echo ERROR: %~1 must be an absolute path. Got: %_P%
exit /b 1

:find_msvc
if not "%VCVARS_OVERRIDE%"=="" (
  if exist "%VCVARS_OVERRIDE%" (
    call "%VCVARS_OVERRIDE%" x64 || exit /b 1
    exit /b 0
  )
  echo ERROR: VCVARS_OVERRIDE set but not found at %VCVARS_OVERRIDE%
  exit /b 1
)
where cl >nul 2>&1
if "%errorlevel%"=="0" (
  if /I "%VSCMD_ARG_TGT_ARCH%"=="x64" exit /b 0
  if /I "%Platform%"=="X64" exit /b 0
  if /I "%Platform%"=="x64" exit /b 0
)
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo ERROR: vswhere.exe not found. Run from a VS developer prompt or set VCVARS_OVERRIDE.
  exit /b 1
)
set "VCPATH="
for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VCPATH=%%I"
if "%VCPATH%"=="" (
  echo ERROR: No Visual Studio with C++ tools found via vswhere.
  exit /b 1
)
call "%VCPATH%\VC\Auxiliary\Build\vcvarsall.bat" x64 || exit /b 1
exit /b 0

:find_qt5
if not "%QT_OVERRIDE%"=="" (
  if exist "%QT_OVERRIDE%\bin\qmake.exe" (
    set "QT=%QT_OVERRIDE%"
    exit /b 0
  )
  echo ERROR: QT_OVERRIDE set but qmake.exe not found at %QT_OVERRIDE%
  exit /b 1
)
for %%D in ("C:\Qt" "D:\Qt") do (
  for %%V in (5.15.2 5.15.1 5.15.0 5.14.2 5.12.12 5.12.11 5.12.10) do (
    for %%P in (msvc2019_64 msvc2017_64 msvc2015_64) do (
      if exist "%%~D\%%V\%%P\bin\qmake.exe" (
        set "QT=%%~D\%%V\%%P"
        exit /b 0
      )
    )
  )
)
echo ERROR: Qt5 not found. Set QT_OVERRIDE at the top of this script.
exit /b 1

:fail
echo.
echo BUILD FAILED (errorlevel=%errorlevel%)
exit /b %errorlevel%