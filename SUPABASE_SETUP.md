# Supabase Setup Instructions

To use Supabase storage with your InSpectra app, follow these steps:

## 1. Create a Supabase Account
- Go to https://supabase.com/
- Sign up for a new account
- Create a new project

## 2. Get Your Project Credentials
- Go to your project dashboard
- Navigate to "Project Settings" → "API"
- Copy the "Project URL" and "anon/public" key

## 3. Configure Your App
You need to set the Supabase credentials in your app. You can do this in several ways:

### Option A: Environment Variables (Recommended)
Create a `.env` file in your project root:
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Then run the app with:
```bash
flutter run --dart-define=SUPABASE_URL=your_supabase_project_url --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Option B: Direct Configuration
Update `lib/config/supabase_config.dart` with your credentials:
```dart
static const String url = 'your_supabase_project_url';
static const String anonKey = 'your_supabase_anon_key';
```

## 4. Configure Storage Bucket
- In your Supabase dashboard, go to "Storage"
- Create a bucket named "documents" (or update the constant in `SupabaseStorageService`)
- Set the bucket to public if you want public access to files, or private if you want to control access

## 5. Update Storage Policies
For the "documents" bucket, add the following policy to allow users to upload and read files:

```sql
-- Allow users to read files
CREATE POLICY "Allow public read access" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'documents');

-- Allow authenticated users to upload files
CREATE POLICY "Allow authenticated users to upload" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'documents');

-- Allow authenticated users to update their files
CREATE POLICY "Allow authenticated users to update" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'documents');

-- Allow authenticated users to delete their files
CREATE POLICY "Allow authenticated users to delete" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'documents');
```

## 6. Run the App
After configuring your credentials, run the app normally:
```bash
flutter run
```

Your documents will now be stored in Supabase instead of Firebase Storage!
