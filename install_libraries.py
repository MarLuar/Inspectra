#!/usr/bin/env python3
"""
Script to install required libraries for ESP32 Solar App
"""

import os
import subprocess
import sys

def install_platformio_libraries():
    """Install required libraries using PlatformIO"""
    print("Installing required libraries for ESP32 Solar App...")
    
    libraries = [
        "bblanchon/ArduinoJson@^6.21.3",
        "ricmoo/QRCode"
    ]
    
    for lib in libraries:
        print(f"Installing {lib}...")
        try:
            result = subprocess.run([
                "pio", "pkg", "install", 
                "--library", f"{lib}"
            ], capture_output=True, text=True, cwd=".")
            
            if result.returncode == 0:
                print(f"✓ Successfully installed {lib}")
            else:
                print(f"✗ Failed to install {lib}: {result.stderr}")
        except FileNotFoundError:
            print("PlatformIO not found. Installing via Arduino IDE...")
            return False
    
    return True

def main():
    # Change to the ESP32 firmware directory
    firmware_dir = "esp32_firmware"
    if not os.path.exists(firmware_dir):
        print(f"Firmware directory {firmware_dir} not found!")
        return 1
    
    os.chdir(firmware_dir)
    
    # Try installing with PlatformIO first
    if install_platformio_libraries():
        print("\nAll libraries installed successfully with PlatformIO!")
        print("You can now build and upload the firmware using:")
        print("  pio run --target upload")
        return 0
    else:
        # Fallback to Arduino IDE library installation
        print("\nPlatformIO not available. Installing libraries for Arduino IDE...")
        print("Please install the following libraries in Arduino IDE:")
        print("  1. ArduinoJson by Benoit Blanchon")
        print("  2. QRCode by Richard Moore")
        print("\nYou can install them via: Tools -> Manage Libraries")
        return 0

if __name__ == "__main__":
    sys.exit(main())