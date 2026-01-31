#!/bin/bash
# Script to install required libraries for ESP32 Solar App

echo "Installing required libraries for ESP32 Solar App..."

# Check if platformio is installed
if command -v pio &> /dev/null; then
    echo "PlatformIO detected. Installing libraries..."
    
    # Change to the firmware directory
    cd esp32_firmware
    
    # Install libraries using platformio
    pio pkg install --library "bblanchon/ArduinoJson@^6.21.3"
    pio pkg install --library "ricmoo/QRCode"
    
    echo "Libraries installed successfully!"
    echo "You can now build and upload the firmware using:"
    echo "  cd esp32_firmware"
    echo "  pio run --target upload"
else
    echo "PlatformIO not found. Installing libraries for Arduino IDE..."
    echo ""
    echo "Please install the following libraries in Arduino IDE:"
    echo "  1. Open Arduino IDE"
    echo "  2. Go to Tools -> Manage Libraries"
    echo "  3. Search for and install:"
    echo "     - ArduinoJson by Benoit Blanchon"
    echo "     - QRCode by Richard Moore"
    echo ""
    echo "Note: When using the QRCode library, the correct include is #include \"qrcode.h\" (lowercase)"
    echo ""
    echo "After installing the libraries, open the esp32_wifi_server.ino file in Arduino IDE"
    echo "and upload it to your ESP32."
fi