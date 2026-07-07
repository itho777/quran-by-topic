@echo off
title Quran Embeddings Backfill
color 0A
echo ============================================
echo   Quran Semantic Embeddings Backfill Tool
echo ============================================
echo.

echo [1/2] Installing required Python packages...
pip install sentence-transformers requests --quiet
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: pip install failed. Make sure Python is installed.
    pause
    exit /b 1
)
echo Done!
echo.

echo [2/2] Running embedding backfill...
echo This will download the AI model (~120MB) on first run, then process all verses.
echo.
python "C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\scripts\backfill_embeddings.py"

echo.
echo ============================================
echo   Backfill complete!
echo ============================================
pause
