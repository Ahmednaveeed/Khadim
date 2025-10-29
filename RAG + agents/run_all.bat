@echo off
title Khadim Multi-Agent System Launcher

echo ===================================================
echo  Khadim Restaurant - Multi-Agent System Launcher
echo ===================================================
echo.
echo Checking for virtual environment at '..\venv\'...
echo.

:: Check if the activation script exists at the relative path
IF NOT EXIST "..\venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found at '..\venv\Scripts\activate.bat'
    echo Please make sure your 'venv' folder is located in the main project directory,
    echo one level *above* the 'RAG + agents' folder where this script is.
    echo.
    echo Your current directory: %cd%
    echo Expected venv path: %cd%\..\venv
    echo.
    pause
    exit /b
)

echo Virtual environment found!
echo.
echo [1/3] Starting Cart Agent in a new window...
:: Use 'call' to run the activate.bat script, then '&&' to run python.
:: Use '/k' to keep the window open so you can see startup logs and any errors.
START "Cart Agent" cmd /k "call ..\venv\Scripts\activate.bat && python cart_agent.py"

echo [2/3] Starting Order Agent in a new window...
:: Use '/k' to keep the window open for logs/errors.
START "Order Agent" cmd /k "call ..\venv\Scripts\activate.bat && python order_agent.py"

echo [3/3] Starting Streamlit Orchestrator...
:: Use '/c' for streamlit as it runs its own server process.
START "Streamlit Orchestrator" cmd /c "call ..\venv\Scripts\activate.bat && streamlit run orchestrator.py"

echo.
echo All processes have been launched in separate windows.
echo This launcher window will close in 5 seconds...
timeout /t 5