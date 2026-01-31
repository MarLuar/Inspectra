# InSpectra - Document Management System

InSpectra is a Flutter-based mobile application for managing construction documents (blueprints, reports). The app enables users to scan documents, enhance images, convert them to PDFs, and organize them into local project folders.

## Features

### Document Scanning & Edge Detection
- Integrated `google_mlkit_document_scanner` for native-like scanning experience
- Automatic edge detection and perspective correction
- Manual cropping capabilities

### Image Enhancement Engine
- Adjust brightness, contrast, and sharpness of scanned images
- Rotate and crop functionality
- Real-time preview of enhancements

### File Conversion & PDF Generation
- JPEG to PDF conversion workflow
- High-resolution quality preservation (up to 1200 dpi equivalent)
- Optimized for readable blueprints and documents

### Local Project Organization
- Hierarchical local file system
- "Add Project" functionality with automatic QR code generation
- Automatic organization into sub-folders like `/Project_Name/Blueprints/` or `/Project_Name/Site_Inspections/`

### Cloud Storage with Supabase
- Documents are stored in Supabase Storage
- Project and document metadata stored in Firestore
- Secure user authentication and authorization

## Setup Instructions

### Prerequisites
- Flutter SDK
- Dart SDK
- Android Studio or VS Code with Flutter plugin

### Environment Configuration
1. Create a `.env` file in the project root with your Supabase credentials:
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

2. Make sure you have the correct Supabase configuration in `lib/config/supabase_config.dart`

### Running the Application
To run the app with environment variables:
```bash
flutter run --dart-define=SUPABASE_URL=$(grep SUPABASE_URL .env | cut -d '=' -f2) --dart-define=SUPABASE_ANON_KEY=$(grep SUPABASE_ANON_KEY .env | cut -d '=' -f2)
```

Or simply run:
```bash
flutter run
```

## Architecture

The app follows a clean architecture pattern with:
- Services layer for business logic
- Models for data representation
- Screens for UI components
- Utils for helper functions

## Dependencies

- `google_mlkit_document_scanner`: For document scanning
- `image`: For image processing
- `pdf` and `printing`: For PDF generation
- `path_provider`: For file system access
- `qr_flutter`: For QR code generation
- `sqflite`: For local database
- `provider`: For state management
- `supabase_flutter`: For cloud storage

## Getting Started

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Connect an Android device or start an emulator
4. Run `flutter run` to launch the app

## Cloud Storage Configuration

The app uses Supabase for document storage. To configure:

1. Create a Supabase project at https://supabase.com/
2. Get your Project URL and anon key from Project Settings → API
3. Add them to your `.env` file
4. Configure storage bucket policies in your Supabase dashboard:
   - Create a bucket named "documents"
   - Set appropriate RLS policies for user access