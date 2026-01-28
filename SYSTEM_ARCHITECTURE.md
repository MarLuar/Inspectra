# InSpectra System Architecture

## Overview

InSpectra is a Flutter-based mobile application designed for managing construction documents (blueprints, reports). The app enables users to scan documents, enhance images, convert them to PDFs, and organize them into local project folders. The system follows a clean architecture pattern with separation of concerns between UI, business logic, and data layers.

## Architecture Layers

### 1. Presentation Layer (UI)
The presentation layer consists of Flutter widgets organized into screens that provide the user interface for the application.

#### Key Components:
- **Main Application Entry Point (`main.dart`)**: Initializes Firebase and sets up the main MaterialApp with routing
- **Authentication Screen (`auth_screen.dart`)**: Handles user authentication flows
- **Home Screen (`home_screen.dart`)**: Main dashboard with navigation to core features
- **Document Scanner Screen (`document_scanner_screen.dart`)**: Interface for document scanning and capture
- **Project Management Screens**: Various screens for project creation and management
- **Enhancement Screens**: For image processing and editing

#### Navigation Flow:
```
Auth Screen → Home Screen → Document Scanner / Projects List / QR Scanner
```

### 2. Business Logic Layer (Services)
The services layer contains the core business logic and handles operations like document scanning, image enhancement, PDF generation, and data management.

#### Key Services:
- **Document Scanner Service (`document_scanner_service.dart`)**: Handles document scanning using Google ML Kit
- **Image Enhancement Service (`image_enhancement_service.dart`)**: Provides image processing capabilities
- **PDF Generator Service (`pdf_generator_service.dart`)**: Converts images to PDF format
- **Database Service (`database_service.dart`)**: Manages SQLite database operations
- **QR Code Generator Service (`qr_code_generator_service.dart`)**: Creates and manages QR codes
- **Cloud Sync Service (`cloud_sync_service.dart`)**: Handles synchronization with Firebase
- **Project Organization Service (`project_organization_service.dart`)**: Manages project structure and document organization
- **Search Service (`search_service.dart`)**: Implements search functionality across projects and documents

### 3. Data Layer
The data layer manages both local and remote data persistence.

#### Local Data:
- **SQLite Database**: Using `sqflite` package for storing project metadata and document information
- **File System**: Using `path_provider` for storing actual document files locally
- **Models**: `Project` and `Document` classes define the data structures

#### Remote Data:
- **Firebase**: Authentication, Firestore for remote data synchronization, and Firebase Storage for document storage

### 4. External Dependencies
- **Google ML Kit Document Scanner**: For document scanning and edge detection
- **Image Package**: For image processing operations
- **PDF Package**: For PDF generation
- **Provider**: For state management (though not currently implemented in providers directory)
- **Firebase Core/Auth/Storage/Firestore**: For cloud services

## Core Features Architecture

### Document Scanning Workflow
1. User initiates scan from Document Scanner Screen
2. Document Scanner Service uses Google ML Kit to capture document
3. Scanned image is saved to local storage
4. User can enhance, name, and categorize the document
5. Document is added to selected project via Project Organization Service
6. Metadata is stored in SQLite database

### Project Organization
- Projects are stored in SQLite with associated metadata
- Documents are organized by category (Blueprints, Site Inspections, Reports, etc.)
- Each project can have multiple documents
- QR codes are generated for project identification and sharing

### Data Synchronization
- Local SQLite database stores all project and document metadata
- Cloud Sync Service handles synchronization with Firebase
- Offline-first approach ensures functionality without internet connectivity
- Manual sync option available for users

## System Components

### Authentication System
- Firebase Authentication handles user accounts
- Email/password authentication
- Session management through StreamBuilder in main app

### Document Processing Pipeline
```
Capture → Scan/Enhance → Categorize → Store → Index
```

### File Management
- Local file storage using application documents directory
- Organized by project structure
- Support for both image and PDF formats
- QR code generation for document identification

### Search Functionality
- Local search across project names and document titles
- Implemented through database queries
- Fast retrieval using SQLite indexing

## Technology Stack

### Frontend
- **Framework**: Flutter (Dart)
- **UI Components**: Material Design widgets
- **Navigation**: Built-in routing system
- **State Management**: Provider pattern (planned)

### Backend
- **Authentication**: Firebase Authentication
- **Database**: Firestore (remote), SQLite (local)
- **Storage**: Firebase Storage (remote), Local file system (local)
- **ML Services**: Google ML Kit for document scanning

### Third-party Libraries
- `google_mlkit_document_scanner`: Document scanning
- `image`: Image processing
- `pdf`: PDF generation
- `sqflite`: Local database
- `path_provider`: File system access
- `qr_flutter`: QR code generation
- `firebase_core/auth/storage/firestore`: Firebase integration

## Security Considerations

### Data Protection
- Local data stored on-device only
- No sensitive data transmitted unnecessarily
- Firebase authentication for cloud sync
- Secure file storage using application directories

### Permissions
- Storage permissions requested for document access
- Camera permissions for document scanning
- Proper handling of denied permissions

## Scalability and Performance

### Performance Optimization
- Local-first approach minimizes network dependencies
- Efficient image processing algorithms
- SQLite database for fast local queries
- Cached network images where applicable

### Scalability Features
- Modular architecture allows for feature additions
- Separate services for different functionalities
- Clean separation of concerns
- Database schema designed to accommodate growth

## Deployment Architecture

### Mobile Platforms
- Android (primary platform)
- Cross-platform compatibility maintained for potential iOS expansion

### Build Process
- Standard Flutter build process
- Version management through pubspec.yaml
- Asset bundling for images and resources

## Error Handling and Resilience

### Fallback Mechanisms
- Camera fallback when ML Kit fails
- Offline functionality when network unavailable
- Graceful degradation of features

### Error Recovery
- Proper exception handling in all services
- User-friendly error messages
- Retry mechanisms where appropriate

## Future Architecture Considerations

### Potential Enhancements
- Advanced image enhancement algorithms
- More sophisticated document classification
- Enhanced collaboration features
- Integration with CAD software
- Bluetooth printer support for document output

### Architecture Evolution
- Introduction of proper state management (Provider/MobX)
- Implementation of repository pattern
- Advanced caching strategies
- Background synchronization services

## Conclusion

The InSpectra system architecture follows modern mobile application design principles with a focus on offline functionality, user experience, and scalability. The clean separation of concerns allows for maintainable code and easy feature additions. The architecture balances local performance with cloud synchronization capabilities to provide a robust document management solution for construction professionals.