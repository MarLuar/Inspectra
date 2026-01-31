-- Supabase Setup Script - Complete
-- Run these commands in your Supabase SQL Editor to set up the required tables, columns, and RLS policies

-- First, make sure the documents table has the qr_code column
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
    
    -- Check if owner_id column exists, if not create it
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'documents' AND column_name = 'owner_id') THEN
        ALTER TABLE documents ADD COLUMN owner_id UUID;
        RAISE NOTICE 'Column owner_id added to documents table';
    ELSE
        RAISE NOTICE 'Column owner_id already exists in documents table';
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

-- Enable Row Level Security on the documents table if not already enabled
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Enable Row Level Security on the qr_codes table
ALTER TABLE qr_codes ENABLE ROW LEVEL SECURITY;

-- Create a function to check if a user owns a project
CREATE OR REPLACE FUNCTION is_project_owner(project_id_param UUID) 
RETURNS BOOLEAN 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM projects 
        WHERE id = project_id_param 
        AND owner_user_id = auth.uid()
    );
END;
$$;

-- Create policies for the documents table
-- Allow users to select documents they own or that are shared with them
CREATE POLICY "Users can view their own documents" ON documents
    FOR SELECT TO authenticated
    USING (
        owner_id = auth.uid() 
        OR is_project_owner(project_id)
    );

-- Allow users to insert documents for projects they own
CREATE POLICY "Users can insert documents for their projects" ON documents
    FOR INSERT TO authenticated
    WITH CHECK (
        project_id IN (
            SELECT id FROM projects 
            WHERE owner_user_id = auth.uid()
        )
        AND (owner_id = auth.uid() OR owner_id IS NULL)
    );

-- Allow users to update their own documents
CREATE POLICY "Users can update their own documents" ON documents
    FOR UPDATE TO authenticated
    USING (
        owner_id = auth.uid() 
        OR is_project_owner(project_id)
    );

-- Allow users to delete their own documents
CREATE POLICY "Users can delete their own documents" ON documents
    FOR DELETE TO authenticated
    USING (
        owner_id = auth.uid() 
        OR is_project_owner(project_id)
    );

-- Create policies for the qr_codes table
CREATE POLICY "Users can view their own QR codes" ON qr_codes
    FOR SELECT TO authenticated
    USING (is_project_owner(project_id));

CREATE POLICY "Users can insert their own QR codes" ON qr_codes
    FOR INSERT TO authenticated
    WITH CHECK (is_project_owner(project_id));

CREATE POLICY "Users can update their own QR codes" ON qr_codes
    FOR UPDATE TO authenticated
    USING (is_project_owner(project_id));

CREATE POLICY "Users can delete their own QR codes" ON qr_codes
    FOR DELETE TO authenticated
    USING (is_project_owner(project_id));

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
CREATE INDEX IF NOT EXISTS idx_documents_project_id ON documents(project_id);
CREATE INDEX IF NOT EXISTS idx_documents_category ON documents(category);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);
CREATE INDEX IF NOT EXISTS idx_documents_owner_id ON documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_project_id ON qr_codes(project_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_created_at ON qr_codes(created_at);

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON TABLE documents TO authenticated;
GRANT ALL PRIVILEGES ON TABLE qr_codes TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE qr_codes_id_seq TO authenticated;

-- Make sure the projects table also has proper policies
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own projects" ON projects
    FOR SELECT TO authenticated
    USING (owner_user_id = auth.uid());

CREATE POLICY "Users can insert their own projects" ON projects
    FOR INSERT TO authenticated
    WITH CHECK (owner_user_id = auth.uid());

CREATE POLICY "Users can update their own projects" ON projects
    FOR UPDATE TO authenticated
    USING (owner_user_id = auth.uid());

CREATE POLICY "Users can delete their own projects" ON projects
    FOR DELETE TO authenticated
    USING (owner_user_id = auth.uid());

GRANT ALL PRIVILEGES ON TABLE projects TO authenticated;