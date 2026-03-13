@echo on

set LIB=%LIBRARY_LIB%;%LIB%
set LIBPATH=%LIBRARY_LIB%;%LIBPATH%
set INCLUDE=%LIBRARY_INC%;%INCLUDE%

:: Configure.
:: -DZLIB_WINAPI switches to WINAPI calling convention. See Q7 in DLL_FAQ.txt.
cmake -G "NMake Makefiles" ^
      -D CMAKE_BUILD_TYPE=Release ^
      -D CMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
      -D CMAKE_INSTALL_PREFIX:PATH=%LIBRARY_PREFIX% ^
      -D CMAKE_C_FLAGS="-DZLIB_WINAPI" ^
      -D ZLIB_BUILD_SHARED=ON ^
      -D ZLIB_BUILD_STATIC=ON ^
      -D ZLIB_INSTALL=OFF ^
      %CMAKE_ARGS% %SRC_DIR%
if errorlevel 1 exit 1

:: For logging.
type CMakeCache.txt

:: Build.
cmake --build %SRC_DIR% --config Release
if errorlevel 1 exit 1

:: Copy built zlibwapi.dll with the same name provided by https://www.winimage.com/zLibDll/index.html
:: This is needed for example for cuDNN
:: https://docs.nvidia.com/deeplearning/cudnn/archives/cudnn-890/install-guide/index.html#install-zlib-windows
:: v1.3.2 produces z.dll / zs.lib on Windows (OUTPUT_NAME z, static suffix s)
:: Rename to the expected zlibwapi names
:: Stash winapi artifacts in a temp dir, do NOT touch %LIBRARY_*% yet
mkdir "%SRC_DIR%\winapi_out"
copy /Y "z.dll"  "%SRC_DIR%\winapi_out\zlibwapi.dll" || exit 1
copy /Y "zs.lib" "%SRC_DIR%\winapi_out\zlibwapi.lib" || exit 1

del /f /q CMakeCache.txt

:: Now build regular zlib.
:: Configure.
cmake -G "NMake Makefiles" ^
      -D CMAKE_BUILD_TYPE=Release ^
      -D CMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
      -D CMAKE_INSTALL_PREFIX:PATH=%LIBRARY_PREFIX% ^
      -D ZLIB_BUILD_SHARED=ON ^
      -D ZLIB_BUILD_STATIC=ON ^
      -D ZLIB_INSTALL=ON ^
      %CMAKE_ARGS% %SRC_DIR%
if errorlevel 1 exit 1

type CMakeCache.txt

:: Build.
cmake --build %SRC_DIR% --target INSTALL --config Release --clean-first
if errorlevel 1 exit 1

:: Test.
ctest --output-on-failure
if errorlevel 1 exit 1

:: Compat copies for regular zlib (z.lib is already installed
:: as the DLL import lib; zs.lib is the static lib)
copy %LIBRARY_LIB%\z.lib  %LIBRARY_LIB%\zdll.lib      || exit 1
copy %LIBRARY_LIB%\z.lib  %LIBRARY_LIB%\zlib.lib      || exit 1
copy %LIBRARY_LIB%\zs.lib %LIBRARY_LIB%\zlibstatic.lib || exit 1
copy %LIBRARY_BIN%\z.dll  %LIBRARY_BIN%\zlib.dll       || exit 1 
copy %LIBRARY_BIN%\z.dll  %PREFIX%\zlib.dll            || exit 1

:: Now copy winapi artifacts - LAST, after conda-build has
:: already seen the zlib package file list
copy /Y "%SRC_DIR%\winapi_out\zlibwapi.dll" "%LIBRARY_BIN%\zlibwapi.dll" || exit 1
copy /Y "%SRC_DIR%\winapi_out\zlibwapi.lib" "%LIBRARY_LIB%\zlibwapi.lib" || exit 1
