# Supabase Storage Troubleshooting Guide

This guide addresses the common "row-level security policy" error you might encounter when using Supabase storage with the InSpectra app.

## Understanding the Error

The error "new row violates row-level security policy" occurs when:
1. The storage bucket doesn't exist
2. The RLS (Row Level Security) policies are not properly configured
3. The user doesn't have sufficient permissions to perform the operation

## Step-by-Step Solution

### 1. Verify Your Supabase Project Setup

Make sure you have:
- A Supabase project created
- The correct URL and ANON key in your config
- Storage enabled for your project

### 2. Create the Storage Bucket

1. Go to your Supabase dashboard
2. Navigate to "Storage" in the sidebar
3. Click "New Bucket"
4. Name it exactly "documents" (lowercase)
5. Set public access as needed (public or private)
6. Click "Create Bucket"

### 3. Configure Row Level Security (RLS) Policies

**Important:** The RLS policy setup requires admin privileges. If you get a "must be owner of table objects" error, this means you need to have the appropriate permissions or ask your project owner to run these commands.

1. Go to your Supabase dashboard
2. Navigate to "SQL Editor"
3. Run the following SQL commands:

```sql
-- Policy to allow authenticated users to read files in the 'documents' bucket
CREATE POLICY "Allow authenticated read access" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'documents');

-- Policy to allow authenticated users to insert files in the 'documents' bucket
CREATE POLICY "Allow authenticated users to upload" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'documents');

-- Policy to allow authenticated users to update files in the 'documents' bucket
CREATE POLICY "Allow authenticated users to update" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'documents');

-- Policy to allow authenticated users to delete files in the 'documents' bucket
CREATE POLICY "Allow authenticated users to delete" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'documents');
```

**Note:** If you get a "duplicate policy" error, it means the policies already exist. That's fine - you can skip this step.

### 4. Verify Authentication

Make sure your users are properly authenticated with Supabase Auth before attempting to use storage. The policies require users to be authenticated.

### 5. Test the Setup

After applying the policies:
1. Restart your app
2. Log in with a user account
3. Try uploading a document
4. Check the app logs for any remaining errors

## Alternative: Using Service Role Key (Advanced)

If you need programmatic bucket creation, you can use the service role key, but this should only be done in secure environments (not in client apps):

1. Get your service role key from Project Settings → API
2. Create a backend function or use the Supabase CLI to create buckets
3. Never expose the service role key in client-side code

## Common Issues and Solutions

### Issue: "Bucket does not exist"
**Solution:** Manually create the bucket in the Supabase dashboard as described above.

### Issue: "Unauthorized" or "Forbidden"
**Solution:** Verify that:
- The user is authenticated
- The RLS policies are correctly applied
- The bucket name matches exactly ("documents")

### Issue: "must be owner of table objects" error
**Solution:** This error occurs when you don't have sufficient privileges to create RLS policies. Either:
- Ask your project owner/administrator to run the SQL commands
- Make sure you're logged in as a project owner in the Supabase dashboard

### Issue: Still getting RLS errors after following all steps
**Solution:**
1. Double-check that the bucket name in your code matches the one in Supabase
2. Ensure the user is authenticated before attempting storage operations
3. Verify that the policies are active in the Supabase dashboard
4. Check that your Supabase URL and ANON key are correct

## Testing Your Setup

You can test your storage setup directly in the Supabase SQL Editor:

```sql
-- Check if policies are applied
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'storage';

-- Check if bucket exists
SELECT * FROM storage.buckets WHERE name = 'documents';
```

## Additional Notes

- The storage bucket name is case-sensitive
- Make sure to use the same bucket name in both your Supabase dashboard and code
- If you change the bucket name in the code, update it everywhere it's referenced
- Remember that RLS policies apply to all operations (select, insert, update, delete)
- The RLS policy setup often requires project owner/administrator privileges