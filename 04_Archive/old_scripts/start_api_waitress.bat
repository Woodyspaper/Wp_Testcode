@echo off
REM Start Contract Pricing API with Waitress
REM Use this for testing or if not using NSSM service

set PROJECT_PATH=C:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode
set PYTHON_PATH=C:\Program Files\Python314\python.exe
set PORT=5000
set THREADS=4

echo Starting Contract Pricing API with Waitress...
echo   Port: %PORT%
echo   Threads: %THREADS%
echo.

cd /d "%PROJECT_PATH%"
set PYTHONPATH=%PROJECT_PATH%

if not exist logs mkdir logs

echo Starting API...
"%PYTHON_PATH%" -m waitress-serve --host=0.0.0.0 --port=%PORT% --threads=%THREADS% api.contract_pricing_api_enhanced:app

pause
