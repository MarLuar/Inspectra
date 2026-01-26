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

### UI/UX Design
- Capture & Enhance view
- Project Folder View
- File Details & Edit screen
- Search feature to retrieve files instantly by name or project

## Technical Specifications

### Platform
- Android (Target SDK 21+)

### Storage
- `sqflite` for metadata indexing (project names, dates, document types)
- Local storage for actual PDF/JPEG files using `path_provider` and `dart:io`

### Offline First
- All features work without an internet connection
- Files stored locally on the device

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

## Getting Started

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Connect an Android device or start an emulator
4. Run `flutter run` to launch the app

## Testing

The app is designed to work completely offline. All data is stored locally on the device, ensuring functionality without internet connectivity.# Inspectra
