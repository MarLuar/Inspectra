// Supabase configuration
class SupabaseConfig {
  // Replace these with your actual Supabase project details
  static const String url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://npnkrjhtmnzdlkfwumxv.supabase.co');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wbmtyamh0bW56ZGxrZnd1bXh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3NjYwNTEsImV4cCI6MjA4NTM0MjA1MX0.aGoixuFAgROpvaWhnqfkNAag7SrYtiP4efWFa8Hqw6U');
}