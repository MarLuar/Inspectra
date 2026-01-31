# Troubleshooting Supabase Sync Issues

## Problem Description
Files in Supabase storage are not syncing to the local ESP32 device when clicking "Sync with Supabase Now".

## Root Cause Analysis
The ESP32 sync functionality works in two ways:

1. **Primary Method**: Queries the `documents` table in Supabase database to get metadata about files
2. **Fallback Method**: Lists files directly from Supabase storage bucket

If your files exist in Supabase storage but are not registered in the `documents` table, the primary sync method will not find them.

## Solutions

### Solution 1: Ensure Files Are Registered in the Documents Table
The ESP32 expects each file to have a corresponding entry in the Supabase `documents` table with the following fields:
- `name`: The filename
- `storage_path`: Path in Supabase storage
- `project_id`: Associated project ID
- `category`: Category for organization

Make sure your files are properly registered in the Supabase database.

### Solution 2: Force Fallback to Storage-Only Sync
If files exist in storage but not in the database, the system should fall back to the storage-only sync. This happens when the metadata query fails. You can trigger this by temporarily modifying the query to fail.

### Solution 3: Manual Verification Steps

1. **Check Supabase Storage**:
   - Log into your Supabase dashboard
   - Navigate to Storage → `documents` bucket
   - Verify your files are present

2. **Check Supabase Database**:
   - Navigate to SQL Editor in Supabase dashboard
   - Run: `SELECT * FROM documents;`
   - Verify entries exist for your files

3. **Check ESP32 Serial Output**:
   - Open the serial monitor
   - Click "Sync with Supabase Now"
   - Look for error messages that might indicate why sync is failing

### Solution 4: API Endpoint Verification
The ESP32 queries these endpoints:
- Database: `https://npnkrjhtmnzdlkfwumxv.supabase.co/rest/v1/documents?select=name,storage_path,project_id,category&order=created_at.desc`
- Storage: `https://npnkrjhtmnzdlkfwumxv.supabase.co/storage/v1/object/list/documents`

You can test these endpoints manually with your Supabase API key to verify they return expected data.

## Recommended Action
1. First, verify that your files exist in both Supabase Storage and the documents table
2. If they exist in storage but not in the database, add the corresponding records to the documents table
3. If you want files to sync regardless of database records, consider modifying the sync logic to always check storage directly

## Additional Notes
- The sync function prioritizes database metadata over direct storage listing
- Files that exist locally are skipped during sync (unless implementing overwrite logic)
- Network connectivity issues could also prevent successful sync