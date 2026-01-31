# ESP32 Project QR Code Feature

## Overview
I've implemented a feature that allows storing and displaying QR codes for projects on your ESP32. This enables you to scan QR codes from the ESP32 UI to open projects on your phone.

## Features Added

### 1. Project QR Code Storage
- Added a ProjectInfo structure to store project names and associated QR code data
- Created an array to store up to 50 projects with their QR codes
- Functions to store and retrieve QR code data for projects

### 2. New API Endpoints
- `/project_qr?project=PROJECT_NAME` - Returns the QR code for a specific project
- Updated `/generate_qr` to accept an optional project parameter to store QR codes

### 3. UI Integration
- Added "Show QR" buttons to project listings on all pages
- Created a modal popup to display project QR codes
- QR codes are displayed in a user-friendly modal that can be easily scanned

### 4. How to Use

#### Storing QR Codes from Your Mobile App:
When your mobile app sends a QR code to the ESP32, use this endpoint:
`/generate_qr?text=QR_CODE_DATA&project=PROJECT_NAME`

This will store the QR code data associated with the project name.

#### Viewing QR Codes on ESP32:
1. Access the ESP32 web interface
2. Go to the main page or SD diagnostics page
3. Find a project in the list
4. Click the "Show QR" button next to the project
5. A modal will appear with the QR code that can be scanned with your phone

## Technical Details

### Data Storage
- Project QR codes are stored in memory (will reset on ESP32 restart)
- Maximum of 50 projects supported
- Each project stores its name, QR code data, and last updated timestamp

### API Endpoints
- `/generate_qr?text=DATA&project=NAME` - Store QR code for a project
- `/project_qr?project=NAME` - Retrieve QR code for a project

### UI Components
- Modal dialog for displaying QR codes
- Responsive design that works on mobile devices
- Easy scanning interface

## Integration with Mobile App
Your mobile app can send QR codes to the ESP32 using the generate_qr endpoint with the project parameter. The ESP32 will then store and display these QR codes for easy access and scanning.