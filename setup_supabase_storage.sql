-- Supabase Storage Setup Script
-- Run these commands in your Supabase SQL Editor to set up proper storage policies
-- NOTE: These commands must be run by a user with superuser privileges (typically the project owner)

-- Enable Row Level Security on the storage schema (usually already enabled by default)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

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

-- Create a bucket named 'documents' if it doesn't exist (this needs to be done via API or dashboard)
-- You can create it in the Supabase dashboard under Storage -> New Bucket
-- Name: documents
-- Public: false (or true based on your needs)

-- If you want to add custom columns for ownership tracking, uncomment the following:
/*
-- Add owner_id column to track file ownership
ALTER TABLE storage.objects ADD COLUMN IF NOT EXISTS owner_id UUID;

-- Update the RLS policies to include ownership checks
DROP POLICY IF EXISTS "Allow authenticated users to upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to update" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete" ON storage.objects;

-- Policy to allow authenticated users to insert files in the 'documents' bucket with ownership
CREATE POLICY "Allow authenticated users to upload" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  (storage.check_permissions('bucket_id', 'objects', 'insert') OR auth.role() = 'authenticated')
);

-- Policy to allow authenticated users to update their own files
CREATE POLICY "Allow authenticated users to update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  (SELECT auth.uid()) = owner_id AND
  bucket_id = 'documents'
);

-- Policy to allow authenticated users to delete their own files
CREATE POLICY "Allow authenticated users to delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  (SELECT auth.uid()) = owner_id AND
  bucket_id = 'documents'
);
*/