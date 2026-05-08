@echo off
:: Fintrak Setup Launcher for Windows
:: Tries Git Bash first, falls back to PowerShell.

echo.
echo Fintrak Setup Wizard
echo.

:: Try Git Bash (preferred - same as setup.sh on other platforms)
set GIT_BASH=
for %%G in (
    "C:\Program Files\Git\bin\bash.exe"
    "C:\Program Files (x86)\Git\bin\bash.exe"
) do (
    if exist %%G (
        set GIT_BASH=%%G
        goto :run_bash
    )
)

:: Try bash via PATH (covers Git Bash, WSL, MSYS2)
where bash >nul 2>&1
if %ERRORLEVEL%==0 (
    set GIT_BASH=bash
    goto :run_bash
)

:: Fallback: PowerShell
echo Git Bash not found. Running setup.ps1 via PowerShell...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
goto :end

:run_bash
echo Using bash: %GIT_BASH%
echo.
%GIT_BASH% "%~dp0setup.sh"

:end
