-- Supabase Tables Setup Script
-- Run these commands in your Supabase SQL Editor to set up the required tables and columns

-- Create or alter the documents table to include the qr_code column
DO $$ 
BEGIN
    -- Check if qr_code column exists, if not create it
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'documents' AND column_name = 'qr_code') THEN
        ALTER TABLE documents ADD COLUMN qr_code TEXT;
        RAISE NOTICE 'Column qr_code added to documents table';
    ELSE
        RAISE NOTICE 'Column qr_code already exists in documents table';
    END IF;
END $$;

-- Create the qr_codes table if it doesn't exist
CREATE TABLE IF NOT EXISTS qr_codes (
    id BIGSERIAL PRIMARY KEY,
    project_id UUID,
    project_name TEXT NOT NULL,
    qr_code_data TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security on the qr_codes table
ALTER TABLE qr_codes ENABLE ROW LEVEL SECURITY;

-- Create policies for the qr_codes table
CREATE POLICY "Users can view their own QR codes" ON qr_codes
    FOR SELECT TO authenticated
    USING (auth.uid() = (SELECT owner_id FROM projects WHERE id = project_id));

CREATE POLICY "Users can insert their own QR codes" ON qr_codes
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = (SELECT owner_id FROM projects WHERE id = project_id));

CREATE POLICY "Users can update their own QR codes" ON qr_codes
    FOR UPDATE TO authenticated
    USING (auth.uid() = (SELECT owner_id FROM projects WHERE id = project_id));

CREATE POLICY "Users can delete their own QR codes" ON qr_codes
    FOR DELETE TO authenticated
    USING (auth.uid() = (SELECT owner_id FROM projects WHERE id = project_id));

-- Create updated_at trigger for qr_codes table
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_qr_codes_updated_at 
    BEFORE UPDATE ON qr_codes 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_qr_codes_project_id ON qr_codes(project_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_created_at ON qr_codes(created_at);

-- Also make sure the documents table has proper indexes
CREATE INDEX IF NOT EXISTS idx_documents_project_id ON documents(project_id);
CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);
CREATE INDEX IF NOT EXISTS idx_documents_owner_id ON documents(owner_id);