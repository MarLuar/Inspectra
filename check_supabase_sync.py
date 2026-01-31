#!/usr/bin/env python3
"""
Diagnostic script to check Supabase sync functionality
"""

import requests
import json

# Supabase configuration - same as in the ESP32 firmware
SUPABASE_URL = "https://npnkrjhtmnzdlkfwumxv.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wbmtyamh0bW56ZGxrZnd1bXh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3NjYwNTEsImV4cCI6MjA4NTM0MjA1MX0.aGoixuFAgROpvaWhnqfkNAag7SrYtiP4efWFa8Hqw6U"
SUPABASE_BUCKET_NAME = "documents"

def check_documents_table():
    """Check the documents table in Supabase database"""
    print("Checking documents table in Supabase database...")
    
    url = f"{SUPABASE_URL}/rest/v1/documents"
    params = {
        'select': 'name,storage_path,project_id,category',
        'order': 'created_at.desc'
    }
    
    headers = {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.get(url, params=params, headers=headers)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Successfully retrieved {len(data)} documents from database:")
            for doc in data:
                print(f"  - Name: {doc.get('name', 'N/A')}, Path: {doc.get('storage_path', 'N/A')}, "
                      f"Project: {doc.get('project_id', 'N/A')}, Category: {doc.get('category', 'N/A')}")
            return True, data
        else:
            print(f"✗ Failed to retrieve documents. Status: {response.status_code}, Response: {response.text}")
            return False, None
    except Exception as e:
        print(f"✗ Error querying documents table: {str(e)}")
        return False, None

def check_storage_bucket():
    """Check the storage bucket in Supabase"""
    print("\nChecking storage bucket in Supabase...")
    
    url = f"{SUPABASE_URL}/storage/v1/object/list/{SUPABASE_BUCKET_NAME}"
    
    headers = {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
        'Content-Type': 'application/json'
    }
    
    # Supabase storage list requires a body
    body = {"prefix": ""}
    
    try:
        response = requests.post(url, headers=headers, json=body)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Successfully retrieved {len(data)} items from storage:")
            for item in data:
                print(f"  - Name: {item.get('name', 'N/A')}, ID: {item.get('id', 'N/A')}")
            return True, data
        else:
            print(f"✗ Failed to retrieve storage items. Status: {response.status_code}, Response: {response.text}")
            return False, None
    except Exception as e:
        print(f"✗ Error querying storage bucket: {str(e)}")
        return False, None

def compare_results(db_data, storage_data):
    """Compare results from database and storage"""
    print("\nComparing database and storage results...")
    
    if not db_data or not storage_data:
        print("Cannot compare - one or both queries failed")
        return
    
    db_files = {doc.get('storage_path', '') for doc in db_data if doc.get('storage_path')}
    storage_files = {item.get('id', '') for item in storage_data if item.get('id')}
    
    print(f"Files in database: {len(db_files)}")
    print(f"Files in storage: {len(storage_files)}")
    
    only_in_db = db_files - storage_files
    only_in_storage = storage_files - db_files
    
    if only_in_db:
        print(f"\nFiles only in database (missing from storage): {len(only_in_db)}")
        for f in only_in_db:
            print(f"  - {f}")
    
    if only_in_storage:
        print(f"\nFiles only in storage (missing from database): {len(only_in_storage)}")
        for f in only_in_storage:
            print(f"  - {f}")

def main():
    print("Supabase Sync Diagnostic Tool")
    print("="*50)
    
    # Check documents table
    db_success, db_data = check_documents_table()
    
    # Check storage bucket
    storage_success, storage_data = check_storage_bucket()
    
    # Compare results if both succeeded
    if db_success and storage_success:
        compare_results(db_data, storage_data)
    
    print("\nDiagnostic complete.")
    print("\nRecommendations:")
    print("- If files exist in storage but not in database, add them to the 'documents' table")
    print("- If sync still fails, check ESP32 serial output for specific error messages")
    print("- Verify network connectivity between ESP32 and Supabase")

if __name__ == "__main__":
    main()