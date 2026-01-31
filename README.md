Inspectra v1.05 - QR-Linked Web-Based Documentation and Site Inspection Management System

  Comprehensive Inspection Management Platform with ESP32 Hardware Integration

  Inspectra is a cutting-edge web-based application designed for site inspection professionals, featuring seamless
  integration with ESP32 hardware devices and Supabase cloud storage for efficient project management and document
  synchronization.

  What's New in v1.05:
   - Fixed QR Code Display Issue: Resolved the critical ESP32 QR code generation problem where QR codes weren't displaying
     properly in the web interface
   - Enhanced Supabase Integration: Improved handling of Supabase-stored QR code files with proper URL redirection
   - Improved File Sync: Enhanced synchronization between ESP32 and Supabase storage systems
   - Better Error Handling: Added robust error handling for missing QR codes and network issues
   - Stable ESP32 Firmware: Fixed memory allocation and watchdog timer issues in the ESP32 firmware

  Key Features:

  Web Application
   - Intuitive interface for site inspection documentation
   - Real-time project management and documentation
   - Document scanning and categorization tools
   - Offline capability with automatic sync when online
   - Photo capture and annotation tools for inspection reports

  ESP32 Hardware Integration
   - Local file storage and management
   - WiFi connectivity for direct device access
   - Automatic synchronization with Supabase cloud storage
   - QR code generation for quick project access
   - Web-based file management interface

  Cloud Storage & Sync
   - Supabase-powered backend for secure document storage
   - Real-time synchronization between devices
   - Automatic backup and recovery
   - Secure authentication and authorization
   - Project-based file organization

  Cross-Platform Access
   - Web interface accessible via ESP32's local server
   - QR code integration for instant project access
   - File preview and download capabilities
   - Multi-device synchronization

  Technical Architecture:

  Web Application Stack:
   - Framework: Flutter Web (Dart)
   - State Management: Built-in Flutter patterns
   - UI Components: Responsive design for mobile and desktop
   - Connectivity: WiFi-based communication with ESP32 devices

  ESP32 Firmware:
   - Platform: ESP-IDF / Arduino Framework
   - Storage: SD card integration for local file storage
   - Networking: WiFi with static IP configuration
   - Protocols: HTTP server for web interface, Supabase API integration
   - Features: File synchronization, QR code generation, project management

  Backend Services:
   - Database: Supabase (PostgreSQL)
   - Storage: Supabase Storage for document management
   - Authentication: Supabase Auth
   - Real-time: Supabase Realtime for live synchronization
   - Security: Row Level Security (RLS) policies

  Use Cases:
   - Construction companies managing multiple project sites
   - Field inspectors documenting site conditions
   - Project managers tracking progress across multiple locations
   - Quality assurance teams performing compliance checks
   - Maintenance crews accessing historical project data

  Access Methods:
   1. Web Interface: Access via WiFi connection to ESP32 device
   2. QR Code Access: Scan project QR codes for instant access
   3. Cloud Dashboard: Supabase-based management interface

  Project Organization:
   - Projects: Top-level containers for each inspection site
   - Categories: Organized file types (Blueprints, Photos, Reports, etc.)
   - Sync Status: Real-time indication of cloud synchronization status
   - Access Control: Role-based permissions for team collaboration

  Development Focus:
   - Reliability: Stable ESP32 firmware with proper error handling
   - Performance: Optimized file transfer and sync mechanisms
   - Scalability: Designed to handle multiple projects and users
   - Security: End-to-end encryption and secure authentication
   - Usability: Intuitive interfaces for both technical and non-technical users

  Synchronization Flow:
   1. Field data captured and stored locally on ESP32
   2. ESP32 periodically syncs with Supabase cloud storage
   3. Team members access synchronized files via web interface
   4. QR codes enable quick access to project-specific data

  Data Management:
   - Local Storage: SD card on ESP32 for offline access
   - Cloud Storage: Supabase for centralized management
   - File Types: Support for images, PDFs, documents, and technical drawings
   - Metadata: Automatic tagging and categorization of files
   - Retention: Configurable retention policies for different file types

  Security Features:
   - Encrypted communication between all components
   - Secure authentication with Supabase Auth
   - Role-based access control
   - Audit trails for file access and modifications
   - Protected local storage on ESP32 devices
