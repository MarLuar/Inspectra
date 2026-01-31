# ESP32 Firmware Fixes Summary - Part 2

## Issues Fixed

### Issue 1: Download/Preview returning 404 errors
- **Problem**: When trying to download or preview files, the system returned {"statusCode":"404","error":"not_found","message":"Object not found"}
- **Root Cause**: The file paths being sent from the web interface didn't include the leading '/' that the SD card system expects
- **Solution**: Modified handlePreviewFile() to ensure file paths always start with '/' before checking SD card

### Issue 2: Files in "Photos" category not showing up
- **Problem**: Files in the "Photos" category were not appearing in the file listings
- **Potential Causes**: 
  1. Path construction inconsistencies during sync
  2. Category detection issues during sync
  3. File listing issues in UI functions
- **Solution**: Ensured consistent path handling throughout the sync and display process

## Specific Changes Made

1. **handlePreviewFile() function**: Added logic to ensure file paths start with '/' before accessing SD card
2. **downloadFileFromSupabase() function**: Improved filename extraction and added debug output
3. **Path handling**: Made consistent path handling throughout the code

## Result
- File downloads and previews should now work correctly
- Files in all categories (including "Photos") should be properly synced and displayed
- Better error reporting for debugging purposes