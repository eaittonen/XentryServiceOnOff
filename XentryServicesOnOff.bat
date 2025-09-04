@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==== ASETUKSET ====
set "VERBOSE=1"
set "TIMEOUT_SECS=45"
set "PAUSE_AT_END=1"

rem ==== ADMIN-TARKISTUS ====
net session >nul 2>&1
if errorlevel 1 (
  echo [VIRHE] Aja skripti jarjestelmanvalvojana.
  if "%PAUSE_AT_END%"=="1" pause
  goto :EOF
)

rem ==== PALVELULISTA ====
set "SERVICES=ConfigAssistService DiagnosisPlatformApiRestService UC1MonitoringService NovaPrinterReinstallationService SupportPackageCreator.SystemContextService SupportTool.LogLevel.Service SupportToolService DaimlerVCIIdentService WorkshopChannelMonitoring WorkshopNotificationClient LegacyVCIService XentryUpdateServiceLightService XentryUpdateServiceFileService XentryUpdateServiceWatcherService XentryUpdateServiceWCFService XentryUpdateServiceWebAPIService XentryUpdateServiceCCAPIService XentryUpdateServiceManager"

echo(
echo Haluatko SAMMUTTAA vai KAYNNISTAA naiden palveluiden?
choice /c SK /m "Paina S = sammuta, K = kaynnista"
if errorlevel 2 (set "MODE=2") else (set "MODE=1")
echo Valinta MODE=%MODE%

if "%MODE%"=="1" goto DO_STOP
goto DO_START

rem ============================================================
rem ================ SAMMUTUS (net stop /y) ====================
rem ============================================================
:DO_STOP
echo === Sammutetaan kaynnissa olevat : net stop /y ===
for %%S in (%SERVICES%) do (
  echo.
  echo --- %%S ---
  sc query "%%~S" >nul 2>&1
  if errorlevel 1060 (
    echo [SKIP] %%S ei ole asennettu ^(1060^).
  ) else (
    sc query "%%~S" | find /I "RUNNING" >nul
    if errorlevel 1 (
      echo [SKIP] %%S ei ole kaynnissa.
    ) else (
      if "%VERBOSE%"=="1" (net stop "%%~S" /y) else (net stop "%%~S" /y >nul 2>&1)
      set "RC=!ERRORLEVEL!"
      echo     net stop RC=!RC!
      call :WAIT_FOR_STATE "%%~S" 1 %TIMEOUT_SECS%
      if errorlevel 1 (
        echo [VAROITUS] %%S ei pysahtynyt %TIMEOUT_SECS%s kuluessa.
        sc query "%%~S"
      ) else (
        echo [OK] %%S pysaytetty.
      )
    )
  )
)
goto SUMMARY

rem ============================================================
rem ============== KAYNNISTYS (sc start) =======================
rem ============================================================
:DO_START
echo === Kaynnistetaan pysahtyneet : sc start ===
for %%S in (%SERVICES%) do (
  echo.
  echo --- %%S ---
  sc query "%%~S" >nul 2>&1
  if errorlevel 1060 (
    echo [SKIP] %%S ei ole asennettu ^(1060^).
  ) else (
    sc query "%%~S" | find /I "RUNNING" >nul
    if not errorlevel 1 (
      echo [SKIP] %%S on jo kaynnissa.
    ) else (
      if "%VERBOSE%"=="1" (sc start "%%~S") else (sc start "%%~S" >nul 2>&1)
      set "RC=!ERRORLEVEL!"
      echo     sc start RC=!RC!
      call :WAIT_FOR_STATE "%%~S" 4 %TIMEOUT_SECS%
      if errorlevel 1 (
        echo [VAROITUS] %%S ei kaynnistynyt %TIMEOUT_SECS%s kuluessa.
        sc query "%%~S"
      ) else (
        echo [OK] %%S kaynnistetty.
      )
    )
  )
)
goto SUMMARY

rem ============================================================
rem ====== Odota haluttuun tilaan (1=STOPPED, 4=RUNNING) ======
rem ============================================================
:WAIT_FOR_STATE
set "SVC=%~1"
set "TARGET=%~2"
set /a "LIMIT=%~3", "elapsed=0"

:WLOOP
if "%TARGET%"=="1" (
  sc query "%SVC%" | find /I "STOPPED" >nul
) else (
  sc query "%SVC%" | find /I "RUNNING" >nul
)
if not errorlevel 1 exit /b 0

if %elapsed% GEQ %LIMIT% exit /b 1
if "%VERBOSE%"=="1" ( sc query "%SVC%" | findstr /B /C:"STATE" ) else ( <nul set /p ="." )
powershell -nop -c "Start-Sleep -Seconds 1" >nul 2>&1
set /a elapsed+=1
goto :WLOOP

rem ============================================================
rem ===================== YHTEENVETO ===========================
rem ============================================================
:SUMMARY
echo.
echo === Yhteenveto: kaynnissa olevat palvelut ===
set "ANYRUN="
for %%S in (%SERVICES%) do (
  sc query "%%~S" | findstr /R /C:"STATE *: *4" >nul && (
    echo RUNNING: %%S
    set "ANYRUN=1"
  )
)
if not defined ANYRUN echo [OK] Kaikki listan palvelut eivat ole kaynnissa.

:END
echo(
echo Valmista!
if "%PAUSE_AT_END%"=="1" pause
goto :EOF
