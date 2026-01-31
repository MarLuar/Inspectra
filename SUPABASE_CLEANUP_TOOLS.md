# Supabase Storage Cleanup Tools

This directory contains tools to help you manage and clean up your Supabase storage when local files have been deleted but cloud storage files remain.

## Available Tools

### 1. cleanup_supabase_storage.dart
A utility to list and delete files from your Supabase storage bucket.

### 2. check_supabase_sync.dart
A utility to identify "orphaned" files in Supabase storage that are no longer referenced in your local database, and optionally delete them.

## Prerequisites

Before using these tools, ensure you have:

1. Updated Supabase credentials in `lib/config/supabase_config.dart`
2. The following dependencies in your `pubspec.yaml`:
   - `supabase_flutter: ^2.5.5`
   - `path_provider: ^2.1.4`
   - `sqflite: ^2.3.3`
   - `path: ^1.9.0`

## How to Use

### Option 1: Check for Orphaned Files (Recommended)
This is the safer option that identifies files in Supabase that are no longer referenced in your local database:

```bash
dart check_supabase_sync.dart
```

This will:
1. Connect to your Supabase storage
2. Scan your local database for document references
3. Identify files in Supabase that are no longer referenced
4. Prompt you to delete the orphaned files

### Option 2: Manual Cleanup
Use the manual cleanup tool to list or delete files:

```bash
dart cleanup_supabase_storage.dart
```

Follow the prompts to either list files or delete all files from your Supabase storage.

## Important Notes

⚠️ **Warning**: These tools can permanently delete files from your Supabase storage. Please be careful when using them.

- Always backup important data before running these tools
- The "orphaned files" detection relies on your local database being accurate
- Files deleted through these tools cannot be recovered
- Make sure your Supabase credentials are correctly configured

## Troubleshooting

If you encounter authentication errors:
1. Verify your Supabase URL and ANON key in `lib/config/supabase_config.dart`
2. Ensure your Supabase storage bucket policies allow the operations
3. Check that your account has the necessary permissions

For other errors, check that all required dependencies are properly installed and that your Supabase project is accessible.