@echo off
:: Build LangSwitcher as a standalone Windows .exe
setlocal EnableDelayedExpansion

echo Installing dependencies...
pip install -r requirements.txt

echo Building Windows .exe with PyInstaller...
python -m PyInstaller ^
  --noconfirm ^
  --windowed ^
  --onefile ^
  --name "LangSwitcher" ^
  langswitcher.py

echo.
echo Done! Executable is at: dist\LangSwitcher.exe
echo.
echo NOTE: Windows may require running as Administrator for global keyboard hook.
pause
