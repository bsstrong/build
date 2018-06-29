@echo off
@if defined _echo echo on

:main
setlocal enabledelayedexpansion
  set errorlevel=
  set BuildConfiguration=%~1
  if "%BuildConfiguration%"=="" set BuildConfiguration=Release

  set VersionSuffix=%~2
  if "%VersionSuffix%"=="" set VersionSuffix=release

  set OutputDirectory=%~dp0LocalPackages
  call :remove_directory "%OutputDirectory%" || exit /b 1

  rem Don't fall back to machine-installed versions of dotnet, only use repo-local version
  set DOTNET_MULTILEVEL_LOOKUP=0

  call "%~dp0.\dotnet-install.cmd" || exit /b 1

  echo DotNet CLI
  where.exe /R %~dp0 /F dotnet.exe

  echo NuGet CLI 
  where.exe /R %~dp0 /F nuget.exe

  set procedures=
  set procedures=%procedures% build
  set procedures=%procedures% build_test
  set procedures=%procedures% build_test_coverage
  set procedures=%procedures% build_myget

  for %%p in (%procedures%) do (
    call :%%p || (
      call :print_error_message Failed to run %%p
      exit /b 1
    )
  )
endlocal& exit /b %errorlevel%

:build
setlocal
  cd /d %~dp0\Build
  call :dotnet_pack
  exit /b %errorlevel%

:build_test
setlocal
  cd /d %~dp0\Build.Tests
  dotnet.exe restore --no-cache --packages "%~dp0packages"                                                                || exit /b 1
  echo/
  echo/  ==========
  echo/   Testing %cd%
  echo/  ==========
  call :remove_directory bin                                                                                              || exit /b 1
  call :remove_directory obj                                                                                              || exit /b 1
  dotnet.exe restore --no-cache --packages "%~dp0packages"                                                                || exit /b 1
  dotnet.exe build -c %BuildConfiguration%                                                                                || exit /b 1
  dotnet.exe test --no-build -c %BuildConfiguration%                                                                      || exit /b 1
  exit /b %errorlevel%

:build_test_coverage
setlocal
  cd /d %~dp0
  dotnet.exe restore --no-cache --packages "%~dp0packages"                                                                || exit /b 1
  call coverage                                                                                                           || exit /b 1
  exit /b %errorlevel%

:build_myget
setlocal
  cd /d %~dp0
  set /p BuildVersion=<BuildVersion.txt                                                                                   || exit /b 1
  nuget pack MyGet-Build.DependencyInjection.nuspec -Properties Configuration=Release;BuildVersion=%BuildVersion%         || exit /b 1
  for /f "tokens=* usebackq" %%f in (`dir /B *.nupkg`) do (
    set NuGetPackage=%%f
  )
  if "%MYGET_ACCESSTOKEN%" == "" (
    call :print_error_message Missing MyGet access token environment variable for MyGet feed API key
    exit /b 1
  )
  nuget push %NuGetPackage% %MYGET_ACCESSTOKEN% -Source https://www.myget.org/F/build-core/api/v2/package                 || exit /b 1
  rem del /f /q %NuGetPackage%
  exit /b %errorlevel%

:dotnet_build
  echo/
  echo/  ==========
  echo/   Building %cd%
  echo/  ==========
  call :remove_directory bin                                                                                              || exit /b 1
  call :remove_directory obj                                                                                              || exit /b 1

  for %%v in (net45 net451 net452 net46 net461 net462 net47 net471 netstandard2.0 netcoreapp2.1) do (
    dotnet.exe build --no-dependencies -c %BuildConfiguration% --version-suffix %VersionSuffix% --framework "%%v" || exit /b 1
  )
  exit /b 0

:dotnet_pack
setlocal
  dotnet.exe restore --no-cache --packages "%~dp0packages"                                                                || exit /b 1
  call :dotnet_build                                                                                                      || exit /b 1
  dotnet.exe publish -c %BuildConfiguration%                                                                              || exit /b 1
  rem if "%%v" == "net461" (
  rem   ".\simpleharness.exe"            --perf:collect default+gcapi --perf:outputdir "!cd!" || exit /b 1
  rem ) else (
  rem   dotnet.exe ".\simpleharness.dll" --perf:collect default+gcapi --perf:outputdir "!cd!" || exit /b 1
  rem )
   
  exit /b %errorlevel%

  echo/
  echo/  ==========
  echo/   Packing %cd%
  echo/  ==========
  set MsBuildArgs=
  set "MsBuildArgs=%MsBuildArgs% --no-build"
  set "MsBuildArgs=%MsBuildArgs% -c %BuildConfiguration%"
  set "MsBuildArgs=%MsBuildArgs% --version-suffix %VersionSuffix%"
  set "MsBuildArgs=%MsBuildArgs% --output "%OutputDirectory%""
  set "MsBuildArgs=%MsBuildArgs% --include-symbols --include-source"
  if defined LV_GIT_HEAD_SHA (
    set "MsBuildArgs=%MsBuildArgs% /p:GitHeadSha=%LV_GIT_HEAD_SHA%"
  )
  dotnet.exe pack %MsBuildArgs% || exit /b 1
  exit /b 0

:print_error_message
  echo/
  echo/  [ERROR] %*
  echo/
  exit /b %errorlevel%

:remove_directory
  if "%~1" == "" (
    call :print_error_message Directory name was not specified.
    exit /b 1
  )
  if exist "%~1" rmdir /s /q "%~1"
  if exist "%~1" (
    call :print_error_message Failed to remove directory "%~1".
    exit /b 1
  )
  exit /b 0
:exit