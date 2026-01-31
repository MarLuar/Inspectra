#include <WiFi.h>
#include <WebServer.h>
#include <SPIFFS.h>
#include <SD.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#ifdef USE_QRCODE
  #include "qrcode.h"
#endif

// WiFi credentials - you can change these
const char* ssid = "PLDTHOMEFIBR21653";
const char* password = "Aloygwapo1234@";

// Static IP configuration
IPAddress local_IP(192, 168, 50, 245);  // ESP32's IP address
IPAddress gateway(192, 168, 50, 254);   // Router's IP address
IPAddress subnet(255, 255, 255, 0);     // Subnet mask
IPAddress primaryDNS(8, 8, 8, 8);       // Google DNS
IPAddress secondaryDNS(8, 8, 4, 4);     // Alternative Google DNS

// Supabase configuration - replace with your actual values
const char* SUPABASE_URL = "https://npnkrjhtmnzdlkfwumxv.supabase.co";  // Your Supabase URL
const char* SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wbmtyamh0bW56ZGxrZnd1bXh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3NjYwNTEsImV4cCI6MjA4NTM0MjA1MX0.aGoixuFAgROpvaWhnqfkNAag7SrYtiP4efWFa8Hqw6U";  // Your Supabase anon key
const char* SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wbmtyamh0bW56ZGxrZnd1bXh2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2OTc2NjA1MSwiZXhwIjoyMDg1MzQyMDUxfQ.STLZJtugDXsGOWs2hzd3X-qF_khfLVV5Wy9pJiosuzA";  // Your service role key
const char* SUPABASE_BUCKET_NAME = "documents";  // Your bucket name

// Web server on port 80
WebServer server(80);

// SD card CS pin (according to your wiring: GPIO 5)
const int SD_CS = 5;

// Structure to hold file information
struct FileInfo {
  String name;
  String category;
  String project;
  size_t size;
  unsigned long lastModified;
};

// Structure to hold project information including QR code
struct ProjectInfo {
  String name;
  String qrCodeData;  // Stores the QR code data for the project
  unsigned long lastUpdated;
};

// Global variables
bool sdInitialized = false;
String projectsDir = "/projects";
File uploadFile;
unsigned long lastSyncTime = 0;
const unsigned long SYNC_INTERVAL = 300000; // 5 minutes in milliseconds

// Flags for sync status
bool initialSyncComplete = false;
bool syncInProgress = false;

// Array to store project QR codes
#define MAX_PROJECTS 50
ProjectInfo projectQRs[MAX_PROJECTS];
int projectCount = 0;

// Forward declarations for recursive file collection
String getFileListFromEndpointWithPrefix(String prefix);
String getAllFilesFromStorage();
String getFileListFromEndpoint();
void cleanupEmptyProjectDirs();

void setup() {
  Serial.begin(115200);
  
  // Initialize SPI for SD card
  SPI.begin(18, 19, 23, 5); // SCK, MISO, MOSI, CS according to your wiring
  Serial.println("SPI initialized");

  // Initialize SD card with more detailed error reporting
  // Try different SPI frequency settings for better compatibility
  if (!SD.begin(SD_CS, SPI, 4000000U)) {  // Try lower frequency first (4MHz)
    Serial.println("SD Card initialization failed at 4MHz!");

    // Try with default settings
    if (!SD.begin(SD_CS)) {
      Serial.println("SD Card initialization failed with default settings!");
      Serial.println("Possible causes:");
      Serial.println("- SD card not properly inserted");
      Serial.println("- SD card not formatted as FAT32");
      Serial.println("- Wrong voltage (need 3.3V, NOT 5V)");
      Serial.println("- Wiring issues despite appearing correct");
      Serial.println("- Damaged SD card or slot");
      Serial.println("- SD card capacity too large (try 2GB-32GB)");
      Serial.println("- SD card is write-protected");
      sdInitialized = false;
    } else {
      Serial.println("SD Card initialized successfully with default settings!");
      sdInitialized = true;
    }
  } else {
    Serial.println("SD Card initialized successfully at 4MHz!");
    sdInitialized = true;
  }
  
  // Only proceed with directory creation if SD card is initialized
  if (sdInitialized) {
    // Create projects directory if it doesn't exist
    if (!SD.exists(projectsDir)) {
      if (SD.mkdir(projectsDir)) {
        Serial.println("Projects directory created");
      } else {
        Serial.println("Failed to create projects directory");
      }
    } else {
      Serial.println("Projects directory already exists");
    }
  }
  
  // Connect to WiFi with static IP
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  
  // Configure static IP
  if (!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) {
    Serial.println("Static IP configuration failed!");
  }
  
  WiFi.begin(ssid, password);
  
  // Wait for connection
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());

  // Define web server routes
  server.on("/", HTTP_GET, handleRoot);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/sd_diag", HTTP_GET, handleSDDiag);
  server.on("/list_projects", HTTP_GET, handleListProjects);
  server.on("/list_files", HTTP_GET, handleListFiles);
  server.on("/create_project_dir", HTTP_POST, handleCreateProjectDir);
  server.on("/upload_file", HTTP_POST, handleFileUpload);
  server.on("/preview_file", HTTP_GET, handlePreviewFile);
  server.on("/generate_qr", HTTP_GET, handleGenerateQR);
  server.on("/project_qr", HTTP_GET, handleProjectQR);  // NEW: Endpoint for project QR codes
  server.on("/fetch_from_supabase", HTTP_POST, handleFetchFromSupabase);
  server.on("/sync_supabase", HTTP_GET, handleSyncSupabase);
  server.on("/force_storage_sync", HTTP_GET, handleForceStorageSync); // NEW: Direct storage sync endpoint
  server.on("/force_qr_sync", HTTP_GET, handleForceQRCodesSync); // NEW: Direct QR code sync endpoint
  server.onNotFound(handleNotFound);

  server.begin();
  Serial.println("HTTP server started");
  
  // Start initial sync in background (non-blocking)
  Serial.println("Starting initial sync in background...");
  lastSyncTime = millis();
}

void loop() {
  server.handleClient();
  
  // Check if it's time to sync with Supabase and no sync is currently running
  if (sdInitialized && !syncInProgress && millis() - lastSyncTime > SYNC_INTERVAL) {
    Serial.println("Time to sync with Supabase storage...");
    // Start sync in background
    syncInProgress = true;
    syncSupabaseStorage();
    syncInProgress = false;
    lastSyncTime = millis();
  }
  
  // Allow other operations to continue during sync
  delay(1); // Small delay to prevent watchdog issues
  yield(); // Allow other tasks to run
}

// Function to get file list from Supabase storage with a specific prefix
String getFileListFromEndpointWithPrefix(String prefix) {
  HTTPClient http;

  // Supabase Storage API to list files in a bucket with a prefix
  String url = String(SUPABASE_URL) + "/storage/v1/object/list/" + String(SUPABASE_BUCKET_NAME);

  http.begin(url);
  http.setTimeout(10000); // 10 second timeout

  // Set headers for Supabase API
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  http.addHeader("Content-Type", "application/json");

  // Supabase Storage requires a POST request to list files with a prefix parameter
  String requestBody = "{\"prefix\":\"" + prefix + "\"}";
  int httpResponseCode = http.POST(requestBody);

  String response = "";
  if (httpResponseCode > 0) {
    response = http.getString();
    Serial.println("Successfully retrieved file list from Supabase with prefix: " + prefix);
    Serial.println("Response: " + response); // Print full response for debugging
  } else {
    Serial.println("Error getting file list from Supabase with prefix: " + prefix + ", HTTP Response code: " + String(httpResponseCode));
    Serial.println("Response: " + http.getString()); // Print error response for debugging
    response = "[]"; // Return empty array on error
  }

  http.end();
  return response;
}

// Iterative helper function to collect all files from all directories (avoiding recursion)
String getAllFilesFromStorage() {
  DynamicJsonDocument resultDoc(8192); // Larger document to hold all files
  JsonArray resultArray = resultDoc.to<JsonArray>();

  // Use a simple approach to get all files - just get the root level for now
  // This avoids deep recursion that could cause stack overflow
  String response = getFileListFromEndpointWithPrefix("");
  
  DynamicJsonDocument doc(4096);
  DeserializationError error = deserializeJson(doc, response);

  if (error) {
    Serial.println("JSON parsing failed: " + String(error.c_str()));
    return "[]";
  }

  JsonArray items = doc.as<JsonArray>();
  for (JsonObject item : items) {
    String name = item["name"] | "";
    String id = item["id"];
    bool isDirectory = item["id"].isNull();

    if (!isDirectory) {
      // If it's a file, add it to the result array with the full path
      JsonObject newItem = resultArray.createNestedObject();
      newItem["name"] = name;  // Full path
      newItem["id"] = id;
      newItem["updated_at"] = item["updated_at"];
      newItem["created_at"] = item["created_at"];
      newItem["last_accessed_at"] = item["last_accessed_at"];
      newItem["metadata"] = item["metadata"];
    }
  }

  String result;
  serializeJson(resultArray, result);
  Serial.println("Collected files, total count: " + String(resultArray.size()));
  return result;
}

// Function to get file list from Supabase storage (wrapper for iterative function)
String getFileListFromEndpoint() {
  Serial.println("Getting files from Supabase storage...");
  return getAllFilesFromStorage();
}

// Function to get document metadata from Supabase database
String getDocumentMetadata() {
  HTTPClient http;

  // Query the documents table to get metadata including QR codes
  // Join with projects table to get project names if needed
  String url = String(SUPABASE_URL) + "/rest/v1/documents?select=name,storage_path,project_id,category,qr_code&q=project_id.not.is.null";  // Adjust table name as needed

  http.begin(url);
  http.setTimeout(10000); // 10 second timeout

  // Set headers for Supabase API
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  http.addHeader("Content-Type", "application/json");

  int httpResponseCode = http.GET();

  String response = "";
  if (httpResponseCode > 0) {
    response = http.getString();
  } else {
    Serial.println("Error getting document metadata from Supabase, HTTP Response code: " + String(httpResponseCode));
    response = "[]"; // Return empty array on error
  }

  http.end();
  return response;
}

// Function to get project QR codes from Supabase
String getProjectQRCodes() {
  HTTPClient http;

  // Query the documents table to get any QR code data that might be stored there
  // This assumes there might be a qr_code column in the documents table
  String url = String(SUPABASE_URL) + "/rest/v1/documents?select=project_id,qr_code&project_id.not.is.null&qr_code.not.is.null";

  http.begin(url);
  http.setTimeout(10000); // 10 second timeout

  // Set headers for Supabase API
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  http.addHeader("Content-Type", "application/json");

  int httpResponseCode = http.GET();

  String response = "";
  if (httpResponseCode > 0) {
    response = http.getString();
    Serial.println("Successfully retrieved project QR codes from Supabase documents table");
    Serial.println("Response: " + response); // Debug output
  } else {
    Serial.println("No QR code column found in documents table or error getting project QR codes from Supabase, HTTP Response code: " + String(httpResponseCode));
    Serial.println("Response: " + http.getString()); // Debug output

    // Try alternative table structure
    String altUrl = String(SUPABASE_URL) + "/rest/v1/project_qrcodes?select=project_name,qr_code_data";
    http.begin(altUrl);
    http.setTimeout(10000); // 10 second timeout
    http.addHeader("apikey", SUPABASE_ANON_KEY);
    http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
    http.addHeader("Content-Type", "application/json");

    int altHttpResponseCode = http.GET();
    if (altHttpResponseCode > 0) {
      response = http.getString();
      Serial.println("Successfully retrieved project QR codes from alternative table");
      Serial.println("Response: " + response); // Debug output
    } else {
      Serial.println("Alternative QR code table also not found, returning empty array");
      Serial.println("Alt Response: " + http.getString()); // Debug output
      response = "[]"; // Return empty array if no QR codes found
    }
    http.end();
    return response;
  }

  http.end();
  return response;
}

// Function to sync project QR codes from Supabase
void syncProjectQRCodes() {
  Serial.println("Starting sync of project QR codes from Supabase...");

  String qrCodesJson = getProjectQRCodes();
  Serial.println("Received project QR codes from Supabase: " + qrCodesJson);

  // Parse the QR codes JSON
  DynamicJsonDocument qrDoc(4096); // Adjust size as needed
  DeserializationError qrError = deserializeJson(qrDoc, qrCodesJson);

  if (qrError) {
    Serial.print("Project QR codes JSON parsing failed: ");
    Serial.println(qrError.c_str());
    return;
  }

  // Process the QR codes
  JsonArray qrCodes = qrDoc.as<JsonArray>();

  for (JsonObject qrCode : qrCodes) {
    // Try different possible field names for project name and QR code data
    String projectName = qrCode["project_name"] | qrCode["project_id"] | "unknown";
    String qrCodeData = qrCode["qr_code_data"] | qrCode["qr_code"] | "";

    if (qrCodeData != "") {
      storeProjectQRCode(projectName, qrCodeData);
      Serial.println("Stored QR code for project: " + projectName + " with data: " + qrCodeData);
    } else {
      Serial.println("Found record for project: " + projectName + " but no QR code data");
    }
  }

  Serial.println("Completed sync of project QR codes from Supabase.");
}

// Function to get all local files and their paths
void collectLocalFiles(String projectPath, JsonArray localFilesArray) {
  File projectDir = SD.open(projectPath);
  if (!projectDir.isDirectory()) {
    return;
  }

  File categoryDir = projectDir.openNextFile();
  while (categoryDir) {
    if (categoryDir.isDirectory()) {
      String categoryName = categoryDir.name();
      String categoryPath = projectPath + "/" + categoryName;

      File fileInCategory = SD.open(categoryPath);
      File innerFile = fileInCategory.openNextFile();

      while (innerFile) {
        JsonObject fileObj = localFilesArray.createNestedObject();
        String fileName = String(innerFile.name());
        String fullPath = categoryPath.substring(1) + "/" + fileName; // Remove leading '/'
        fileObj["path"] = fullPath;
        fileObj["name"] = fileName;
        fileObj["category"] = categoryName;
        fileObj["project"] = projectPath.substring(projectsDir.length() + 1); // Extract project name

        innerFile = fileInCategory.openNextFile();
        yield(); // Allow other tasks to run
      }
      fileInCategory.close();
    }
    categoryDir = projectDir.openNextFile();
    yield(); // Allow other tasks to run
  }
  projectDir.close();
}

// Function to sync all files from Supabase storage
void syncSupabaseStorage() {
  if (!sdInitialized) {
    Serial.println("SD card not initialized, skipping sync");
    return;
  }

  Serial.println("Starting sync with Supabase storage...");

  // Get document metadata from Supabase database FIRST (to get QR codes from documents table)
  String metadataJson = getDocumentMetadata();
  Serial.println("Received document metadata from Supabase: " + metadataJson);

  // Parse the metadata JSON
  DynamicJsonDocument metaDoc(4096); // Adjust size as needed
  DeserializationError metaError = deserializeJson(metaDoc, metadataJson);

  bool metadataValid = true;
  if (metaError) {
    Serial.print("Metadata JSON parsing failed: ");
    Serial.println(metaError.c_str());
    metadataValid = false;
  }

  // Collect all remote files from Supabase storage
  String fileListJson = getFileListFromEndpoint();
  Serial.println("Received file list from Supabase storage: " + fileListJson);

  DynamicJsonDocument remoteDoc(4096);
  DeserializationError remoteError = deserializeJson(remoteDoc, fileListJson);

  if (remoteError) {
    Serial.print("Remote file list JSON parsing failed: ");
    Serial.println(remoteError.c_str());
  }

  // Process the document metadata if valid
  if (metadataValid) {
    JsonArray documents = metaDoc.as<JsonArray>();

    for (JsonObject document : documents) {
      String documentName = document["name"] | "unnamed";
      String documentPath = document["path"] | documentName;  // Use path if available, otherwise name
      String project = document["project_id"] | "Default";  // Use project_id if available, otherwise default
      String category = document["category"] | "Documents";  // Use category if available, otherwise default
      String storagePath = document["storage_path"] | documentPath;  // Path in storage bucket
      String qrCodeData = document["qr_code"] | "";  // Get QR code data if available

      Serial.println("Processing document: " + documentName + " (Storage Path: " + storagePath +
                     ", Project: " + project + ", Category: " + category + ")");

      // Create project and category directories if they don't exist
      String projectPath = projectsDir + "/" + project;
      if (!SD.exists(projectPath)) {
        SD.mkdir(projectPath);
        Serial.println("Created project directory: " + projectPath);
      }

      String categoryPath = projectPath + "/" + category;
      if (!SD.exists(categoryPath)) {
        SD.mkdir(categoryPath);
        Serial.println("Created category directory: " + categoryPath);
      }

      // If QR code data exists for this project, store it
      if (qrCodeData != "") {
        storeProjectQRCode(project, qrCodeData);
        Serial.println("Stored QR code for project: " + project + " with data: " + qrCodeData);
      }

      // Check if file already exists locally
      String localFilePath = categoryPath + "/" + documentName;

      if (SD.exists(localFilePath)) {
        File existingFile = SD.open(localFilePath, FILE_READ);
        if (existingFile) {
          size_t existingSize = existingFile.size();
          existingFile.close();

          // In a real implementation, you might want to compare timestamps or checksums
          // For now, we'll just note that the file exists
          Serial.println("File already exists locally: " + localFilePath + " (" + String(existingSize) + " bytes)");
          continue;
        }
      }

      // Download the file from Supabase using the storage path
      downloadFileFromSupabase(storagePath, project, category);
    }
  }

  // Sync project QR codes from Supabase (this will get any QR codes that might be in a separate table)
  Serial.println("Syncing project QR codes from Supabase...");
  syncProjectQRCodes();

  // Regardless of metadata validity, also sync directly from storage and cleanup deleted files
  Serial.println("Performing direct storage sync and cleanup...");
  syncAndCleanupFromStorageOnly(remoteDoc);

  Serial.println("Sync with Supabase storage completed.");
}

// Function to sync from storage only and cleanup deleted files
void syncAndCleanupFromStorageOnly(DynamicJsonDocument& remoteDoc) {
  Serial.println("Starting direct storage sync with cleanup...");

  // Process the remote file list
  JsonArray remoteFiles = remoteDoc.as<JsonArray>();

  // Create a list of remote file paths for comparison
  String remotePaths[100]; // Assuming max 100 files
  int remoteCount = 0;

  for (JsonObject remoteFile : remoteFiles) {
    String fileName = remoteFile["name"] | "unknown";
    remotePaths[remoteCount] = fileName;
    remoteCount++;
    if (remoteCount >= 100) break; // Prevent overflow

    // Extract project and category from the file path
    String project = "Default"; // Default project if not specified in path
    String category = "Documents"; // Default category
    String actualFileName = fileName; // The actual filename to use

    // Try to parse project and category from the file path
    // Example: if path is "project1/blueprints/floor_plan.pdf",
    // project would be "project1" and category would be "blueprints", filename would be "floor_plan.pdf"
    int lastSlash = fileName.lastIndexOf('/');
    if (lastSlash >= 0) {
      // Extract the actual filename from the path
      actualFileName = fileName.substring(lastSlash + 1);

      // Extract project and category from the path
      int firstSlash = fileName.indexOf('/');
      if (firstSlash > 0) {
        project = fileName.substring(0, firstSlash);
        int secondSlash = fileName.indexOf('/', firstSlash + 1);
        if (secondSlash > 0) {
          category = fileName.substring(firstSlash + 1, secondSlash);
        } else {
          category = "Documents"; // Default if no category specified
        }
      }
    }

    Serial.println("File mapping - Name: " + actualFileName + ", Path: " + fileName + ", Project: " + project + ", Category: " + category + ")");

    // Create project and category directories if they don't exist
    String projectPath = projectsDir + "/" + project;
    if (!SD.exists(projectPath)) {
      SD.mkdir(projectPath);
      Serial.println("Created project directory: " + projectPath);
    }

    String categoryPath = projectPath + "/" + category;
    if (!SD.exists(categoryPath)) {
      SD.mkdir(categoryPath);
      Serial.println("Created category directory: " + categoryPath);
    }

    // Check if file already exists locally
    String localFilePath = categoryPath + "/" + actualFileName;

    if (SD.exists(localFilePath)) {
      File existingFile = SD.open(localFilePath, FILE_READ);
      if (existingFile) {
        size_t existingSize = existingFile.size();
        existingFile.close();

        // In a real implementation, you might want to compare timestamps or checksums
        // For now, we'll just note that the file exists
        Serial.println("File already exists locally: " + localFilePath + " (" + String(existingSize) + " bytes)");
        continue;
      }
    }

    // Download the file from Supabase using the fileName as the storage path
    downloadFileFromSupabase(fileName, project, category);
  }

  // Now check for local files that don't exist remotely (deleted files)
  // Get all local files
  DynamicJsonDocument localDoc(4096);
  JsonArray localFiles = localDoc.to<JsonArray>();

  // Collect all local files from all projects
  File root = SD.open(projectsDir);
  if (root) {
    File projectDir = root.openNextFile();
    while (projectDir) {
      if (projectDir.isDirectory()) {
        String projectPath = projectsDir + "/" + String(projectDir.name());
        collectLocalFiles(projectPath, localFiles);
      }
      projectDir = root.openNextFile();
      yield(); // Allow other tasks to run
    }
    root.close();
  }

  // Compare local files with remote files and delete those that don't exist remotely
  for (JsonObject localFile : localFiles) {
    String localPath = localFile["path"];
    bool foundInRemote = false;

    for (int i = 0; i < remoteCount; i++) {
      // Compare the local path with remote paths
      if (remotePaths[i] == localPath) {
        foundInRemote = true;
        break;
      }
    }

    if (!foundInRemote) {
      // This file exists locally but not remotely - it was deleted from Supabase
      String fullPath = "/" + localPath;
      Serial.println("Deleting local file that was removed from Supabase: " + fullPath);
      if (SD.remove(fullPath)) {
        Serial.println("Successfully deleted: " + fullPath);
      } else {
        Serial.println("Failed to delete: " + fullPath);
      }
    }
  }

  Serial.println("Completed direct storage sync with cleanup.");
  
  // Clean up empty project directories
  cleanupEmptyProjectDirs();
}

// Function to sync from storage only (improved version)
void syncFromStorageOnly() {
  Serial.println("Starting direct storage-only sync...");

  // Get the list of files from Supabase storage
  String fileListJson = getFileListFromEndpoint();
  Serial.println("Received file list from Supabase storage: " + fileListJson);

  // Parse the JSON response to get file paths
  DynamicJsonDocument doc(4096); // Adjust size as needed
  DeserializationError error = deserializeJson(doc, fileListJson);

  if (error) {
    Serial.print("Storage file list JSON parsing failed: ");
    Serial.println(error.c_str());
    return;
  }

  // Process the file list
  JsonArray files = doc.as<JsonArray>();

  // Create a list of remote file paths for comparison
  String remotePaths[100]; // Assuming max 100 files
  int remoteCount = 0;

  for (JsonObject fileInfo : files) {
    String fileName = fileInfo["name"] | "unknown";
    String fileId = fileInfo["id"] | fileName;  // Use id if available, otherwise name

    // Check if this is a directory by looking for null id and absence of file extensions
    bool isFolder = fileInfo["id"].isNull(); // If id is null, it's likely a folder
    bool hasExtension = fileName.indexOf('.') != -1; // Check if it has a file extension

    Serial.println("Processing item from storage: " + fileName + " (ID: " + String(fileId) + ", Is Folder: " + String(isFolder) + ", Has Extension: " + String(hasExtension) + ")");

    // Skip directories - only process actual files
    if (isFolder && !hasExtension) {
      Serial.println("Skipping directory: " + fileName);
      continue;
    }

    remotePaths[remoteCount] = fileName;
    remoteCount++;
    if (remoteCount >= 100) break; // Prevent overflow

    // Extract project and category from the file path
    String project = "Default"; // Default project if not specified in path
    String category = "Documents"; // Default category
    String actualFileName = fileName; // The actual filename to use

    // Try to parse project and category from the file path
    // Example: if path is "project1/blueprints/floor_plan.pdf",
    // project would be "project1" and category would be "blueprints", filename would be "floor_plan.pdf"
    int lastSlash = fileName.lastIndexOf('/');
    if (lastSlash >= 0) {
      // Extract the actual filename from the path
      actualFileName = fileName.substring(lastSlash + 1);

      // Extract project and category from the path
      int firstSlash = fileName.indexOf('/');
      if (firstSlash > 0) {
        project = fileName.substring(0, firstSlash);
        int secondSlash = fileName.indexOf('/', firstSlash + 1);
        if (secondSlash > 0) {
          category = fileName.substring(firstSlash + 1, secondSlash);
        } else {
          category = "Documents"; // Default if no category specified
        }
      }
    }

    Serial.println("File mapping - Name: " + actualFileName + ", Path: " + fileName + ", Project: " + project + ", Category: " + category + ")");

    // Create project and category directories if they don't exist
    String projectPath = projectsDir + "/" + project;
    if (!SD.exists(projectPath)) {
      SD.mkdir(projectPath);
      Serial.println("Created project directory: " + projectPath);
    }

    String categoryPath = projectPath + "/" + category;
    if (!SD.exists(categoryPath)) {
      SD.mkdir(categoryPath);
      Serial.println("Created category directory: " + categoryPath);
    }

    // Check if file already exists locally
    String localFilePath = categoryPath + "/" + actualFileName;

    if (SD.exists(localFilePath)) {
      File existingFile = SD.open(localFilePath, FILE_READ);
      if (existingFile) {
        size_t existingSize = existingFile.size();
        existingFile.close();

        // In a real implementation, you might want to compare timestamps or checksums
        // For now, we'll just note that the file exists
        Serial.println("File already exists locally: " + localFilePath + " (" + String(existingSize) + " bytes)");
        continue;
      }
    }

    // Download the file from Supabase using the fileName as the storage path
    downloadFileFromSupabase(fileName, project, category);
  }

  // Now check for local files that don't exist remotely (deleted files)
  // Get all local files
  DynamicJsonDocument localDoc(4096);
  JsonArray localFiles = localDoc.to<JsonArray>();

  // Collect all local files from all projects
  File root = SD.open(projectsDir);
  if (root) {
    File projectDir = root.openNextFile();
    while (projectDir) {
      if (projectDir.isDirectory()) {
        String projectPath = projectsDir + "/" + String(projectDir.name());
        collectLocalFiles(projectPath, localFiles);
      }
      projectDir = root.openNextFile();
      yield(); // Allow other tasks to run
    }
    root.close();
  }

  // Compare local files with remote files and delete those that don't exist remotely
  for (JsonObject localFile : localFiles) {
    String localPath = localFile["path"];
    bool foundInRemote = false;

    for (int i = 0; i < remoteCount; i++) {
      // Compare the local path with remote paths
      if (remotePaths[i] == localPath) {
        foundInRemote = true;
        break;
      }
    }

    if (!foundInRemote) {
      // This file exists locally but not remotely - it was deleted from Supabase
      String fullPath = "/" + localPath;
      Serial.println("Deleting local file that was removed from Supabase: " + fullPath);
      if (SD.remove(fullPath)) {
        Serial.println("Successfully deleted: " + fullPath);
      } else {
        Serial.println("Failed to delete: " + fullPath);
      }
    }
  }
}

// Function to download a specific file from Supabase
void downloadFileFromSupabase(String filePath, String project, String category) {
  HTTPClient http;

  // Construct the Supabase URL for the file
  String url = String(SUPABASE_URL) + "/storage/v1/object/" + String(SUPABASE_BUCKET_NAME) + "/" + filePath;

  http.begin(url);
  http.setTimeout(30000); // 30 second timeout for file downloads

  // Set headers for Supabase API
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));

  // Perform the GET request
  int httpResponseCode = http.GET();

  if (httpResponseCode > 0) {
    // Successfully received the file
    Serial.println("Successfully fetched file from Supabase: " + filePath);

    // Get the content length
    int contentLength = http.getSize();
    Serial.println("Content length: " + String(contentLength));

    // Create the project and category directories if they don't exist
    String projectPath = projectsDir + "/" + project;
    if (!SD.exists(projectPath)) {
      if (!SD.mkdir(projectPath)) {
        Serial.println("Failed to create project directory: " + projectPath);
        http.end();
        return;
      }
    }

    String categoryPath = projectPath + "/" + category;
    if (!SD.exists(categoryPath)) {
      if (!SD.mkdir(categoryPath)) {
        Serial.println("Failed to create category directory: " + categoryPath);
        http.end();
        return;
      }
    }

    // Extract filename from the path - FIXED LOGIC
    String fileName = filePath; // Start with the full path
    int lastSlash = filePath.lastIndexOf('/');
    if (lastSlash >= 0) {
      fileName = filePath.substring(lastSlash + 1); // Get just the filename part
    }
    // If no slash is found, the entire filePath is the filename

    // Create the local file path
    String localFilePath = categoryPath + "/" + fileName;

    Serial.println("Downloading file: " + fileName + " to local path: " + localFilePath);

    // Open the local file for writing
    File localFile = SD.open(localFilePath, FILE_WRITE);
    if (!localFile) {
      Serial.println("Failed to open local file for writing: " + localFilePath);
      Serial.println("Full path attempted: " + localFilePath);
      http.end();
      return;
    }

    // Stream the content from Supabase to the local file
    WiFiClient *stream = http.getStreamPtr();
    size_t totalBytesWritten = 0;

    while (http.connected() && (contentLength == 0 || totalBytesWritten < contentLength)) {
      size_t size = stream->available();

      if (size > 0) {
        // Limit buffer size to prevent memory issues
        if (size > 4096) size = 4096; // Max 4KB buffer
        
        uint8_t* buff = (uint8_t*)malloc(size);
        if (buff != NULL) {
          size_t bytesRead = stream->readBytes(buff, size);
          size_t bytesWritten = localFile.write(buff, bytesRead);

          if (bytesWritten != bytesRead) {
            Serial.println("Error writing to file");
            free(buff);
            localFile.close();
            http.end();
            return;
          }

          totalBytesWritten += bytesWritten;
          free(buff);
        } else {
          Serial.println("Memory allocation failed for buffer");
          localFile.close();
          http.end();
          return;
        }
      }
      
      // Small delay to prevent watchdog triggers and allow other tasks
      delay(1);
      yield();
    }

    localFile.close();
    http.end();

    Serial.println("Successfully saved file to local storage: " + localFilePath + " (" + String(totalBytesWritten) + " bytes)");
  } else {
    Serial.println("Error downloading file from Supabase: " + filePath + ", HTTP Response code: " + String(httpResponseCode));
    String response = http.getString();
    Serial.println("Supabase response: " + response);
    http.end();
  }
}

// Handle root request - serve the main web interface
void handleRoot() {
  String html = "<!DOCTYPE html><html>";
  html += "<head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<title>ESP32 Solar App Storage</title>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; margin: 20px; }";
  html += ".container { max-width: 800px; margin: 0 auto; }";
  html += ".card { border: 1px solid #ddd; border-radius: 8px; padding: 16px; margin-bottom: 16px; }";
  html += "button { background-color: #4CAF50; color: white; padding: 10px 16px; border: none; border-radius: 4px; cursor: pointer; margin-right: 8px; }";
  html += "button:hover { background-color: #45a049; }";
  html += "button.warning { background-color: #ff9800; }";
  html += "button.warning:hover { background-color: #e68900; }";
  html += "input[type='file'] { margin: 10px 0; }";
  html += "table { width: 100%; border-collapse: collapse; }";
  html += "th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }";
  html += "th { background-color: #f2f2f2; }";
  html += "</style>";
  html += "</head><body>";
  html += "<div class='container'>";
  html += "<h1>ESP32 Solar App Storage</h1>";
  
  // Status section
  html += "<div class='card'>";
  html += "<h2>Status</h2>";
  html += "<p>WiFi: ";
  html += WiFi.status() == WL_CONNECTED ? "Connected" : "Not Connected";
  html += "</p>";
  html += "<p>SSID: ";
  html += WiFi.SSID();
  html += "</p>";
  html += "<p>SD Card: ";
  html += sdInitialized ? "Mounted" : "Not Mounted";
  html += "</p>";
  html += "<p>IP Address: ";
  html += WiFi.localIP().toString();
  html += "</p>";
  html += "<p>Signal Strength: ";
  html += String(WiFi.RSSI());
  html += " dBm</p>";
  html += "<p>Last Sync: ";
  if (lastSyncTime == 0) {
    html += "Never";
  } else {
    unsigned long timeDiff = (millis() - lastSyncTime) / 1000;
    html += String(timeDiff) + " seconds ago";
  }
  html += "</p>";
  html += "<p>Sync Status: ";
  html += syncInProgress ? "In Progress" : "Idle";
  html += "</p>";
  html += "</div>";

  // Sync controls
  html += "<div class='card'>";
  html += "<h2>Sync Control</h2>";
  html += "<button onclick=\"syncNow()\">Sync with Supabase Now</button>";
  html += "<button class='warning' onclick=\"forceStorageSync()\">Force Storage-Only Sync</button>";
  html += "<button class='warning' onclick=\"forceQRCodesSync()\">Force QR Codes Sync</button>";
  html += "<p>Auto-sync interval: 5 minutes</p>";
  html += "</div>";

  // Projects section
  html += "<div class='card'>";
  html += "<h2>Projects</h2>";
  html += "<div id='projects-list'>";
  html += getProjectsHTML();
  html += "</div>";
  html += "</div>";

  // Files section - show files for the selected project
  String selectedProject = server.arg("project_name");
  if (selectedProject != "") {
    html += "<div class='card'>";
    html += "<h2>Files in " + selectedProject + "</h2>";
    html += "<div id='files-list'>";
    html += getFilesHTML(selectedProject);
    html += "</div>";
    html += "</div>";
  }

  // Upload section
  html += "<div class='card'>";
  html += "<h2>Upload File</h2>";
  html += "<form method='POST' action='/upload_file' enctype='multipart/form-data'>";
  html += "<label for='project_name'>Project:</label>";
  html += "<select name='project_name' id='project_name' required>";
  html += getProjectsOptionsHTML();
  html += "</select><br><br>";
  html += "<label for='category'>Category:</label>";
  html += "<select name='category' id='category'>";
  html += "<option value='Blueprints'>Blueprints</option>";
  html += "<option value='Site_Inspections'>Site Inspections</option>";
  html += "<option value='Reports'>Reports</option>";
  html += "<option value='Photos'>Photos</option>";
  html += "<option value='Safety_Documents'>Safety Documents</option>";
  html += "<option value='Progress_Reports'>Progress Reports</option>";
  html += "</select><br><br>";
  html += "<input type='file' name='file' required><br>";
  html += "<button type='submit'>Upload File</button>";
  html += "</form>";
  html += "</div>";

  html += "</div>"; // container
  html += "<div id='qrModal' style='display:none; position:fixed; z-index:1000; left:0; top:0; width:100%; height:100%; overflow:auto; background-color:rgba(0,0,0,0.4);'>";
  html += "  <div style='background-color:#fefefe; margin:15% auto; padding:20px; border:1px solid #888; width:400px; text-align:center;'>";
  html += "    <span onclick=\"closeQRModal()\" style='color:#aaa; float:right; font-size:28px; font-weight:bold; cursor:pointer;'>&times;</span>";
  html += "    <h3>Project QR Code</h3>";
  html += "    <div id='qrContainer'></div>";
  html += "    <p>Scan this QR code to open this project on your phone</p>";
  html += "  </div>";
  html += "</div>";
  html += "<script>";
  html += "function syncNow() {";
  html += "  fetch('/sync_supabase')";
  html += "    .then(response => response.text())";
  html += "    .then(data => {";
  html += "      alert('Sync initiated: ' + data);";
  html += "      location.reload();";
  html += "    })";
  html += "    .catch(error => {";
  html += "      alert('Sync failed: ' + error);";
  html += "    });";
  html += "}";
  html += "function forceStorageSync() {";
  html += "  fetch('/force_storage_sync')";
  html += "    .then(response => response.text())";
  html += "    .then(data => {";
  html += "      alert('Force storage sync initiated: ' + data);";
  html += "      location.reload();";
  html += "    })";
  html += "    .catch(error => {";
  html += "      alert('Force storage sync failed: ' + error);";
  html += "    });";
  html += "}";
  html += "function showProjectQR(projectName) {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  var qrContainer = document.getElementById('qrContainer');";
  html += "  qrContainer.innerHTML = '<img src=\"/project_qr?project=' + encodeURIComponent(projectName) + '\" alt=\"Project QR Code\" style=\"width:200px;height:200px;\">';";
  html += "  modal.style.display = 'block';";
  html += "}";
  html += "function forceQRCodesSync() {";
  html += "  fetch('/force_qr_sync')";
  html += "    .then(response => response.text())";
  html += "    .then(data => {";
  html += "      alert('Force QR codes sync initiated: ' + data);";
  html += "      location.reload();";
  html += "    })";
  html += "    .catch(error => {";
  html += "      alert('Force QR codes sync failed: ' + error);";
  html += "    });";
  html += "}";
  html += "function closeQRModal() {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  modal.style.display = 'none';";
  html += "}";
  html += "// Close modal if clicked outside content";
  html += "window.onclick = function(event) {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  if (event.target == modal) {";
  html += "    modal.style.display = 'none';";
  html += "  }";
  html += "}";
  html += "</script>";
  html += "</body></html>";
  
  server.send(200, "text/html", html);
}

// Handle sync request
void handleSyncSupabase() {
  Serial.println("Manual sync triggered via web interface");
  if (syncInProgress) {
    server.send(409, "text/plain", "Sync already in progress, please wait...");
    return;
  }
  
  syncInProgress = true;
  syncSupabaseStorage();
  syncInProgress = false;
  lastSyncTime = millis();
  server.send(200, "text/plain", "Sync with Supabase completed");
}

// NEW: Handle force storage sync request
void handleForceStorageSync() {
  Serial.println("Force storage-only sync triggered via web interface");
  if (syncInProgress) {
    server.send(409, "text/plain", "Sync already in progress, please wait...");
    return;
  }
  
  syncInProgress = true;
  syncFromStorageOnly();
  syncInProgress = false;
  server.send(200, "text/plain", "Force storage sync with Supabase completed");
}

// NEW: Handle force QR code sync request
void handleForceQRCodesSync() {
  Serial.println("Force project QR codes sync triggered via web interface");
  if (syncInProgress) {
    server.send(409, "text/plain", "Sync already in progress, please wait...");
    return;
  }
  
  syncInProgress = true;
  syncProjectQRCodes();
  syncInProgress = false;
  server.send(200, "text/plain", "Force project QR codes sync with Supabase completed");
}

// Handle status request
void handleStatus() {
  DynamicJsonDocument doc(1024);
  doc["wifi_status"] = WiFi.status() == WL_CONNECTED ? "connected" : "disconnected";
  doc["sd_mounted"] = sdInitialized;
  doc["ip_address"] = WiFi.localIP().toString();
  doc["ssid"] = WiFi.SSID();
  doc["rssi"] = WiFi.RSSI();
  doc["free_space_kb"] = sdInitialized ? SD.totalBytes()/1024 - SD.usedBytes()/1024 : 0;
  doc["total_space_kb"] = sdInitialized ? SD.totalBytes()/1024 : 0;
  doc["last_sync_time"] = lastSyncTime;
  doc["time_since_last_sync"] = millis() - lastSyncTime;
  doc["sync_in_progress"] = syncInProgress;
  
  String jsonString;
  serializeJson(doc, jsonString);
  server.send(200, "application/json", jsonString);
}

// Handle SD card diagnostics
void handleSDDiag() {
  String diagHtml = "<!DOCTYPE html><html>";
  diagHtml += "<head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  diagHtml += "<title>SD Card Diagnostics</title>";
  diagHtml += "<style>";
  diagHtml += "body { font-family: Arial, sans-serif; margin: 20px; }";
  diagHtml += ".container { max-width: 800px; margin: 0 auto; }";
  diagHtml += ".card { border: 1px solid #ddd; border-radius: 8px; padding: 16px; margin-bottom: 16px; }";
  diagHtml += "button { background-color: #4CAF50; color: white; padding: 10px 16px; border: none; border-radius: 4px; cursor: pointer; margin-right: 8px; }";
  diagHtml += "button:hover { background-color: #45a049; }";
  diagHtml += "button.warning { background-color: #ff9800; }";
  diagHtml += "button.warning:hover { background-color: #e68900; }";
  diagHtml += "</style>";
  diagHtml += "</head><body>";
  diagHtml += "<div class='container'>";
  diagHtml += "<h1>SD Card Diagnostics</h1>";
  
  diagHtml += "<div class='card'>";
  diagHtml += "<h2>SD Card Status</h2>";
  diagHtml += "<p>SD Card Initialized: ";
  diagHtml += sdInitialized ? "YES" : "NO";
  diagHtml += "</p>";
  
  if (sdInitialized) {
    uint64_t cardSize = SD.cardSize() / (1024 * 1024); // Size in MB
    uint64_t totalBytes = SD.totalBytes() / (1024 * 1024); // Total in MB
    uint64_t usedBytes = SD.usedBytes() / (1024 * 1024); // Used in MB
    
    diagHtml += "<p>Card Size: " + String(cardSize) + " MB</p>";
    diagHtml += "<p>Total Space: " + String(totalBytes) + " MB</p>";
    diagHtml += "<p>Used Space: " + String(usedBytes) + " MB</p>";
    diagHtml += "<p>Free Space: " + String(totalBytes - usedBytes) + " MB</p>";
    
    // List root directory contents
    diagHtml += "<h3>Root Directory Contents:</h3>";
    diagHtml += "<ul>";
    File root = SD.open("/");
    if (root) {
      File file = root.openNextFile();
      while (file) {
        if (file.isDirectory()) {
          diagHtml += "<li>[DIR] " + String(file.name()) + "</li>";
        } else {
          diagHtml += "<li>" + String(file.name()) + " (" + String(file.size()) + " bytes)</li>";
        }
        file = root.openNextFile();
        yield(); // Allow other tasks to run
      }
      root.close();
    }
    diagHtml += "</ul>";
  } else {
    diagHtml += "<p>No SD card detected or initialization failed.</p>";
    diagHtml += "<p>Please check:</p>";
    diagHtml += "<ul>";
    diagHtml += "<li>SD card is properly inserted</li>";
    diagHtml += "<li>SD card is formatted as FAT32</li>";
    diagHtml += "<li>All wires are connected correctly</li>";
    diagHtml += "<li>Using a known working SD card (4-32GB recommended)</li>";
    diagHtml += "<li>Power supply is stable and providing 3.3V</li>";
    diagHtml += "</ul>";
  }
  
  diagHtml += "<br><a href='/'>Back to Main Page</a>";
  diagHtml += "<br><br><button class='warning' onclick=\"forceStorageSync()\">Force Storage-Only Sync</button>";
  diagHtml += "</div>";
  diagHtml += "</div>";
  diagHtml += "<div id='qrModal' style='display:none; position:fixed; z-index:1000; left:0; top:0; width:100%; height:100%; overflow:auto; background-color:rgba(0,0,0,0.4);'>";
  diagHtml += "  <div style='background-color:#fefefe; margin:15% auto; padding:20px; border:1px solid #888; width:400px; text-align:center;'>";
  diagHtml += "    <span onclick=\"closeQRModal()\" style='color:#aaa; float:right; font-size:28px; font-weight:bold; cursor:pointer;'>&times;</span>";
  diagHtml += "    <h3>Project QR Code</h3>";
  diagHtml += "    <div id='qrContainer'></div>";
  diagHtml += "    <p>Scan this QR code to open this project on your phone</p>";
  diagHtml += "  </div>";
  diagHtml += "</div>";
  diagHtml += "<script>";
  diagHtml += "function forceStorageSync() {";
  diagHtml += "  fetch('/force_storage_sync')";
  diagHtml += "    .then(response => response.text())";
  diagHtml += "    .then(data => {";
  diagHtml += "      alert('Force storage sync initiated: ' + data);";
  diagHtml += "      location.reload();";
  diagHtml += "    })";
  diagHtml += "    .catch(error => {";
  diagHtml += "      alert('Force storage sync failed: ' + error);";
  diagHtml += "    });";
  diagHtml += "}";
  diagHtml += "function showProjectQR(projectName) {";
  diagHtml += "  var modal = document.getElementById('qrModal');";
  diagHtml += "  var qrContainer = document.getElementById('qrContainer');";
  diagHtml += "  qrContainer.innerHTML = '<img src=\"/project_qr?project=' + encodeURIComponent(projectName) + '\" alt=\"Project QR Code\" style=\"width:200px;height:200px;\">';";
  diagHtml += "  modal.style.display = 'block';";
  diagHtml += "}";
  diagHtml += "function forceQRCodesSync() {";
  diagHtml += "  fetch('/force_qr_sync')";
  diagHtml += "    .then(response => response.text())";
  diagHtml += "    .then(data => {";
  diagHtml += "      alert('Force QR codes sync initiated: ' + data);";
  diagHtml += "      location.reload();";
  diagHtml += "    })";
  diagHtml += "    .catch(error => {";
  diagHtml += "      alert('Force QR codes sync failed: ' + error);";
  diagHtml += "    });";
  diagHtml += "}";
  diagHtml += "function closeQRModal() {";
  diagHtml += "  var modal = document.getElementById('qrModal');";
  diagHtml += "  modal.style.display = 'none';";
  diagHtml += "}";
  diagHtml += "// Close modal if clicked outside content";
  diagHtml += "window.onclick = function(event) {";
  diagHtml += "  var modal = document.getElementById('qrModal');";
  diagHtml += "  if (event.target == modal) {";
  diagHtml += "    modal.style.display = 'none';";
  diagHtml += "  }";
  diagHtml += "}";
  diagHtml += "</script>";
  diagHtml += "</body></html>";

  server.send(200, "text/html", diagHtml);
}

// Handle list projects request
void handleListProjects() {
  if (!sdInitialized) {
    server.send(500, "text/plain", "SD card not initialized");
    return;
  }

  File root = SD.open(projectsDir);
  if (!root) {
    server.send(500, "text/plain", "Failed to open projects directory");
    return;
  }

  DynamicJsonDocument doc(2048);
  JsonArray projects = doc.to<JsonArray>();

  File projectDir = root.openNextFile();
  while (projectDir) {
    if (projectDir.isDirectory()) {
      JsonObject project = projects.createNestedObject();
      project["name"] = projectDir.name();
      
      // Count files in the project
      int fileCount = countFilesInDir(projectDir.name());
      project["file_count"] = fileCount;
    }
    projectDir = root.openNextFile();
    yield(); // Allow other tasks to run
  }

  String jsonString;
  serializeJson(doc, jsonString);
  server.send(200, "application/json", jsonString);
}

// Handle list files request - returns HTML UI instead of JSON
void handleListFiles() {
  if (!sdInitialized) {
    server.send(500, "text/plain", "SD card not initialized");
    return;
  }

  String projectName = server.arg("project_name");
  if (projectName == "") {
    server.send(400, "text/plain", "Project name required");
    return;
  }

  String projectPath = projectsDir + "/" + projectName;
  if (!SD.exists(projectPath)) {
    server.send(404, "text/plain", "Project not found");
    return;
  }

  File projectDir = SD.open(projectPath);
  if (!projectDir.isDirectory()) {
    server.send(500, "text/plain", "Invalid project directory");
    return;
  }

  String html = "<!DOCTYPE html><html>";
  html += "<head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<title>Files in " + projectName + " - ESP32 Solar App Storage</title>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; margin: 20px; }";
  html += ".container { max-width: 800px; margin: 0 auto; }";
  html += ".card { border: 1px solid #ddd; border-radius: 8px; padding: 16px; margin-bottom: 16px; }";
  html += "button { background-color: #4CAF50; color: white; padding: 10px 16px; border: none; border-radius: 4px; cursor: pointer; margin-right: 8px; }";
  html += "button:hover { background-color: #45a049; }";
  html += "input[type='file'] { margin: 10px 0; }";
  html += "table { width: 100%; border-collapse: collapse; }";
  html += "th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }";
  html += "th { background-color: #f2f2f2; }";
  html += "</style>";
  html += "</head><body>";
  html += "<div class='container'>";
  html += "<h1>Files in " + projectName + "</h1>";

  html += "<div class='card'>";
  html += "<h2>Project: " + projectName + "</h2>";
  html += "<a href='/'>Back to Main Page</a>";
  html += "</div>";

  // List categories and files
  html += "<div class='card'>";
  html += "<h2>Files</h2>";
  html += "<table><tr><th>File Name</th><th>Category</th><th>Size</th><th>Actions</th></tr>";

  File categoryDir = projectDir.openNextFile();
  int totalFiles = 0;
  while (categoryDir) {
    if (categoryDir.isDirectory()) {
      String categoryName = categoryDir.name();
      String categoryPath = projectPath + "/" + categoryName;

      File fileInCategory = SD.open(categoryPath);
      File innerFile = fileInCategory.openNextFile();

      while (innerFile) {
        html += "<tr>";
        String fileName = String(innerFile.name());
        html += "<td>" + fileName + "</td>";
        html += "<td>" + categoryName + "</td>";
        html += "<td>" + String(innerFile.size()) + " bytes</td>";
        html += "<td>";

        String filePath = categoryPath + "/" + fileName;
        // Create a relative path for the URL
        String relativePath = filePath.substring(1); // Remove leading '/'

        // Check file type to determine preview option
        String lowerFileName = fileName;
        lowerFileName.toLowerCase(); // Convert to lowercase in-place
        if (lowerFileName.endsWith(".jpg") || lowerFileName.endsWith(".jpeg") || lowerFileName.endsWith(".png") ||
            lowerFileName.endsWith(".gif") || lowerFileName.endsWith(".bmp") || lowerFileName.endsWith(".webp")) {
          html += "<button onclick=\"previewImage('" + relativePath + "')\">Preview Image</button>";
        } else if (lowerFileName.endsWith(".pdf")) {
          html += "<button onclick=\"previewPDF('" + relativePath + "')\">Preview PDF</button>";
        } else {
          html += "<button onclick=\"downloadFile('" + relativePath + "')\">Download</button>";
        }

        html += "</td>";
        html += "</tr>";

        innerFile = fileInCategory.openNextFile();
        totalFiles++;
        yield(); // Allow other tasks to run
      }
      fileInCategory.close();
    }
    categoryDir = projectDir.openNextFile();
    yield(); // Allow other tasks to run
  }

  if (totalFiles == 0) {
    html += "<tr><td colspan='4'>No files found in this project</td></tr>";
  }

  html += "</table>";
  html += "</div>";
  html += "</div>";
  html += "<div id='qrModal' style='display:none; position:fixed; z-index:1000; left:0; top:0; width:100%; height:100%; overflow:auto; background-color:rgba(0,0,0,0.4);'>";
  html += "  <div style='background-color:#fefefe; margin:15% auto; padding:20px; border:1px solid #888; width:400px; text-align:center;'>";
  html += "    <span onclick=\"closeQRModal()\" style='color:#aaa; float:right; font-size:28px; font-weight:bold; cursor:pointer;'>&times;</span>";
  html += "    <h3>Project QR Code</h3>";
  html += "    <div id='qrContainer'></div>";
  html += "    <p>Scan this QR code to open this project on your phone</p>";
  html += "  </div>";
  html += "</div>";
  html += "<script>";
  html += "function previewImage(path) { window.open('/preview_file?filepath=/' + encodeURIComponent(path), '_blank'); }";
  html += "function previewPDF(path) { window.open('/preview_file?filepath=/' + encodeURIComponent(path), '_blank'); }";
  html += "function downloadFile(path) { window.location.href = '/preview_file?filepath=/' + encodeURIComponent(path); }";
  html += "function showProjectQR(projectName) {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  var qrContainer = document.getElementById('qrContainer');";
  html += "  qrContainer.innerHTML = '<img src=\"/project_qr?project=' + encodeURIComponent(projectName) + '\" alt=\"Project QR Code\" style=\"width:200px;height:200px;\">';";
  html += "  modal.style.display = 'block';";
  html += "}";
  html += "function forceQRCodesSync() {";
  html += "  fetch('/force_qr_sync')";
  html += "    .then(response => response.text())";
  html += "    .then(data => {";
  html += "      alert('Force QR codes sync initiated: ' + data);";
  html += "      location.reload();";
  html += "    })";
  html += "    .catch(error => {";
  html += "      alert('Force QR codes sync failed: ' + error);";
  html += "    });";
  html += "}";
  html += "function closeQRModal() {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  modal.style.display = 'none';";
  html += "}";
  html += "// Close modal if clicked outside content";
  html += "window.onclick = function(event) {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  if (event.target == modal) {";
  html += "    modal.style.display = 'none';";
  html += "  }";
  html += "}";
  html += "</script>";
  html += "</body></html>";

  server.send(200, "text/html", html);
}

// Handle create project directory
void handleCreateProjectDir() {
  if (!sdInitialized) {
    server.send(500, "text/plain", "SD card not initialized");
    return;
  }

  String projectName = server.arg("project_name");
  if (projectName == "") {
    server.send(400, "text/plain", "Project name required");
    return;
  }

  String projectPath = projectsDir + "/" + projectName;
  Serial.println("Creating project directory: " + projectPath);

  if (SD.exists(projectPath)) {
    Serial.println("Project already exists: " + projectPath);
    server.send(409, "text/plain", "Project already exists");
    return;
  }

  if (SD.mkdir(projectPath)) {
    Serial.println("Main project directory created: " + projectPath);
    // Create standard category directories
    String categories[] = {"/Blueprints", "/Site_Inspections", "/Reports", "/Photos", "/Safety_Documents", "/Progress_Reports"};
    for (int i = 0; i < 6; i++) {
      String categoryPath = projectPath + categories[i];
      if (SD.mkdir(categoryPath)) {
        Serial.println("Created category directory: " + categoryPath);
      } else {
        Serial.println("Failed to create category directory: " + categoryPath);
      }
    }
    
    server.send(200, "text/plain", "Project directory created successfully");
  } else {
    Serial.println("Failed to create project directory: " + projectPath);
    server.send(500, "text/plain", "Failed to create project directory");
  }
}

// Handle file upload
void handleFileUpload() {
  if (!sdInitialized) {
    server.send(500, "text/plain", "SD card not initialized");
    return;
  }

  HTTPUpload& upload = server.upload();
  
  if (upload.status == UPLOAD_FILE_START) {
    String projectName = server.arg("project_name");
    String category = server.arg("category");
    
    Serial.println("Upload started - Project: " + projectName + ", Category: " + category);
    
    if (projectName == "" || category == "") {
      Serial.println("Missing project name or category");
      server.send(400, "text/plain", "Project name and category required");
      return;
    }
    
    String filename = upload.filename;
    String filepath = projectsDir + "/" + projectName + "/" + category + "/" + filename;
    
    Serial.println("Attempting to upload file: " + filepath);
    
    // Create category directory if it doesn't exist
    String categoryPath = projectsDir + "/" + projectName + "/" + category;
    if (!SD.exists(categoryPath)) {
      Serial.println("Creating category directory: " + categoryPath);
      if (SD.mkdir(categoryPath)) {
        Serial.println("Category directory created successfully");
      } else {
        Serial.println("Failed to create category directory");
        server.send(500, "text/plain", "Failed to create category directory");
        return;
      }
    }
    
    // Open file for writing
    uploadFile = SD.open(filepath, FILE_WRITE);
    if (!uploadFile) {
      Serial.println("Failed to open file for writing: " + filepath);
      server.send(500, "text/plain", "Failed to open file for writing");
      return;
    }
    Serial.println("File opened for writing: " + filepath);
  } else if (upload.status == UPLOAD_FILE_WRITE) {
    if (uploadFile) {
      uploadFile.write(upload.buf, upload.currentSize);
      Serial.printf("Writing %d bytes to file\n", upload.currentSize);
    } else {
      Serial.println("Upload file handle is invalid during write");
    }
  } else if (upload.status == UPLOAD_FILE_END) {
    if (uploadFile) {
      uploadFile.close();
      Serial.println("Upload finished and file closed");
      server.send(200, "text/plain", "File uploaded successfully");
    } else {
      Serial.println("Upload file handle was invalid during close");
      server.send(500, "text/plain", "Upload failed");
    }
  } else if (upload.status == UPLOAD_FILE_ABORTED) {
    Serial.println("Upload was aborted");
    if (uploadFile) {
      uploadFile.close();
    }
    server.send(500, "text/plain", "Upload was aborted");
  }
}

// Handle file preview
void handlePreviewFile() {
  String filepath = server.arg("filepath");
  if (filepath == "") {
    server.send(400, "text/plain", "File path required");
    return;
  }

  // Ensure the filepath starts with '/' for SD card access
  if (filepath.charAt(0) != '/') {
    filepath = "/" + filepath;
  }

  if (!SD.exists(filepath)) {
    Serial.println("File not found: " + filepath);  // Debug output
    server.send(404, "text/plain", "File not found");
    return;
  }

  File file = SD.open(filepath, FILE_READ);
  if (!file) {
    Serial.println("Could not open file: " + filepath);  // Debug output
    server.send(500, "text/plain", "Could not open file");
    return;
  }

  // Determine content type based on file extension
  String contentType = "application/octet-stream";
  if (filepath.endsWith(".jpg") || filepath.endsWith(".jpeg")) {
    contentType = "image/jpeg";
  } else if (filepath.endsWith(".png")) {
    contentType = "image/png";
  } else if (filepath.endsWith(".gif")) {
    contentType = "image/gif";
  } else if (filepath.endsWith(".bmp")) {
    contentType = "image/bmp";
  } else if (filepath.endsWith(".webp")) {
    contentType = "image/webp";
  } else if (filepath.endsWith(".pdf")) {
    contentType = "application/pdf";
  } else if (filepath.endsWith(".txt")) {
    contentType = "text/plain";
  } else if (filepath.endsWith(".html") || filepath.endsWith(".htm")) {
    contentType = "text/html";
  } else if (filepath.endsWith(".css")) {
    contentType = "text/css";
  } else if (filepath.endsWith(".js")) {
    contentType = "application/javascript";
  } else if (filepath.endsWith(".json")) {
    contentType = "application/json";
  }

  server.streamFile(file, contentType);
  file.close();
}

// Function to store QR code data for a project
void storeProjectQRCode(String projectName, String qrCodeData) {
  // Check if project already exists
  for (int i = 0; i < projectCount; i++) {
    if (projectQRs[i].name == projectName) {
      projectQRs[i].qrCodeData = qrCodeData;
      projectQRs[i].lastUpdated = millis();
      Serial.println("Updated QR code for project: " + projectName);
      return;
    }
  }

  // If project doesn't exist, add it
  if (projectCount < MAX_PROJECTS) {
    projectQRs[projectCount].name = projectName;
    projectQRs[projectCount].qrCodeData = qrCodeData;
    projectQRs[projectCount].lastUpdated = millis();
    projectCount++;
    Serial.println("Stored QR code for new project: " + projectName);
  } else {
    Serial.println("Maximum project count reached, cannot store QR code for: " + projectName);
  }
}

// Function to get QR code data for a project
String getProjectQRCode(String projectName) {
  for (int i = 0; i < projectCount; i++) {
    if (projectQRs[i].name == projectName) {
      String storedQR = projectQRs[i].qrCodeData;
      if (storedQR != "") {
        return storedQR;
      }
    }
  }

  // If no custom QR code is stored, generate one based on project name and ESP32 IP
  String ipAddress = WiFi.localIP().toString();

  // NEW: Look for QR code files in the new directory structure
  String projectPath = projectsDir + "/" + projectName;
  String qrCodePath = projectPath + "/qrcodes/qrcode(" + projectName + ").png";

  if (SD.exists(qrCodePath)) {
    // If QR code file exists in the new directory structure, return its path
    String qrCodeUrl = "http://" + ipAddress + "/preview_file?filepath=" + qrCodePath;
    Serial.println("Found QR code file for project " + projectName + ": " + qrCodeUrl);
    return qrCodeUrl;
  }

  // If no QR code file exists, generate the default URL
  String qrCodeUrl = "http://" + ipAddress + "/list_files?project_name=" + projectName;
  Serial.println("Generated QR code URL for project " + projectName + ": " + qrCodeUrl);
  return qrCodeUrl;
}

// Handle QR code generation
void handleGenerateQR() {
  String text = server.arg("text");
  String project = server.arg("project"); // Optional project parameter

  if (text == "") {
    server.send(400, "text/plain", "Text parameter required");
    return;
  }

  // If project parameter is provided, store the QR code for that project
  if (project != "") {
    storeProjectQRCode(project, text);
  }

#ifdef USE_QRCODE
  // Create QR code
  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(10)];
  qrcode_initText(&qrcode, qrcodeData, 10, ECC_LOW, text.c_str());

  // Create SVG representation of QR code
  String svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 " +
               String(qrcode.size) + " " + String(qrcode.size) + "'>";

  // Background
  svg += "<rect width='100%' height='100%' fill='#ffffff'/>";

  // QR code modules
  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        svg += "<rect x='" + String(x) + "' y='" + String(y) +
               "' width='1' height='1' fill='#000000'/>";
      }
    }
  }
  svg += "</svg>";

  server.send(200, "image/svg+xml", svg);
#else
  // If QR code library is not available, return a simple placeholder
  String placeholderSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' fill='#ffffff'/><rect x='10' y='10' width='80' height='80' fill='#cccccc'/><text x='50' y='55' font-size='12' text-anchor='middle' fill='#000000'>QR: " + text + "</text></svg>";
  server.send(200, "image/svg+xml", placeholderSvg);
#endif
}

// Handle project QR code request
void handleProjectQR() {
  String projectName = server.arg("project");
  if (projectName == "") {
    server.send(400, "text/plain", "Project name required");
    return;
  }

  String qrCodeData = getProjectQRCode(projectName);
  if (qrCodeData == "") {
    server.send(404, "text/plain", "No QR code found for project: " + projectName);
    return;
  }

#ifdef USE_QRCODE
  // Create QR code from the data
  QRCode qrcode;
  uint8_t qrcodeDataBuffer[qrcode_getBufferSize(10)];
  qrcode_initText(&qrcode, qrcodeDataBuffer, 10, ECC_LOW, qrCodeData.c_str());

  // Create SVG representation of QR code
  String svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 " +
               String(qrcode.size) + " " + String(qrcode.size) + "'>";

  // Background
  svg += "<rect width='100%' height='100%' fill='#ffffff'/>";

  // QR code modules
  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        svg += "<rect x='" + String(x) + "' y='" + String(y) +
               "' width='1' height='1' fill='#000000'/>";
      }
    }
  }
  svg += "</svg>";

  server.send(200, "image/svg+xml", svg);
#else
  // If QR code library is not available, return a simple placeholder
  String placeholderSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' fill='#ffffff'/><rect x='10' y='10' width='80' height='80' fill='#cccccc'/><text x='50' y='55' font-size='12' text-anchor='middle' fill='#000000'>Project: " + projectName + "</text></svg>";
  server.send(200, "image/svg+xml", placeholderSvg);
#endif
}

// Function to fetch files from Supabase storage
void handleFetchFromSupabase() {
  if (!sdInitialized) {
    server.send(500, "text/plain", "SD card not initialized");
    return;
  }

  // Get parameters from the request
  String bucketName = server.arg("bucket");
  String filePath = server.arg("file_path");
  String projectName = server.arg("project_name");
  String category = server.arg("category");

  if (bucketName == "" || filePath == "" || projectName == "" || category == "") {
    server.send(400, "text/plain", "Missing required parameters: bucket, file_path, project_name, category");
    return;
  }

  Serial.println("Fetching file from Supabase: " + filePath + " from bucket: " + bucketName);
  
  HTTPClient http;
  
  // Construct the Supabase URL for the file
  String url = String(SUPABASE_URL) + "/storage/v1/object/" + bucketName + "/" + filePath;
  
  http.begin(url);
  http.setTimeout(30000); // 30 second timeout
  
  // Set headers for Supabase API
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  
  // Perform the GET request
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    // Successfully received the file
    Serial.println("Successfully fetched file from Supabase, HTTP Response code: " + String(httpResponseCode));
    
    // Get the content length
    int contentLength = http.getSize();
    Serial.println("Content length: " + String(contentLength));
    
    // Create the project and category directories if they don't exist
    String projectPath = projectsDir + "/" + projectName;
    if (!SD.exists(projectPath)) {
      if (!SD.mkdir(projectPath)) {
        Serial.println("Failed to create project directory: " + projectPath);
        http.end();
        server.send(500, "text/plain", "Failed to create project directory");
        return;
      }
    }
    
    String categoryPath = projectPath + "/" + category;
    if (!SD.exists(categoryPath)) {
      if (!SD.mkdir(categoryPath)) {
        Serial.println("Failed to create category directory: " + categoryPath);
        http.end();
        server.send(500, "text/plain", "Failed to create category directory");
        return;
      }
    }
    
    // Extract filename from the path
    int lastSlash = filePath.lastIndexOf('/');
    String fileName = filePath;
    if (lastSlash >= 0) {
      fileName = filePath.substring(lastSlash + 1);
    } else {
      // If there's no slash, use the whole path as filename
      fileName = filePath;
    }

    // Create the local file path
    String localFilePath = categoryPath + "/" + fileName;

    Serial.println("Downloading file: " + fileName + " to local path: " + localFilePath);
    
    // Open the local file for writing
    File localFile = SD.open(localFilePath, FILE_WRITE);
    if (!localFile) {
      Serial.println("Failed to open local file for writing: " + localFilePath);
      http.end();
      server.send(500, "text/plain", "Failed to open local file for writing");
      return;
    }
    
    // Stream the content from Supabase to the local file
    WiFiClient *stream = http.getStreamPtr();
    size_t totalBytesWritten = 0;
    
    while (http.connected() && (contentLength == 0 || totalBytesWritten < contentLength)) {
      size_t size = stream->available();
      
      if (size > 0) {
        // Limit buffer size to prevent memory issues
        if (size > 4096) size = 4096; // Max 4KB buffer
        
        uint8_t* buff = (uint8_t*)malloc(size);
        if (buff != NULL) {
          size_t bytesRead = stream->readBytes(buff, size);
          size_t bytesWritten = localFile.write(buff, bytesRead);
          
          if (bytesWritten != bytesRead) {
            Serial.println("Error writing to file");
            free(buff);
            localFile.close();
            http.end();
            server.send(500, "text/plain", "Error writing to local file");
            return;
          }
          
          totalBytesWritten += bytesWritten;
          free(buff);
        } else {
          Serial.println("Memory allocation failed for buffer");
          localFile.close();
          http.end();
          server.send(500, "text/plain", "Memory allocation failed");
          return;
        }
      }
      
      // Small delay to prevent watchdog triggers and allow other tasks
      delay(1);
      yield();
    }
    
    localFile.close();
    http.end();
    
    Serial.println("Successfully saved file to local storage: " + localFilePath + " (" + String(totalBytesWritten) + " bytes)");
    
    server.send(200, "text/plain", "File successfully fetched from Supabase and saved locally: " + String(totalBytesWritten) + " bytes");
  } else {
    Serial.println("Error fetching file from Supabase, HTTP Response code: " + String(httpResponseCode));
    
    // Get response payload for more details
    String response = http.getString();
    Serial.println("Supabase response: " + response);
    
    http.end();
    server.send(httpResponseCode, "text/plain", "Error fetching file from Supabase: " + response);
  }
}

// Handle not found
void handleNotFound() {
  String message = "File Not Found\n\n";
  message += "URI: ";
  message += server.uri();
  message += "\nMethod: ";
  message += (server.method() == HTTP_GET) ? "GET" : "POST";
  message += "\nArguments: ";
  message += server.args();
  message += "\n";
  for (uint8_t i = 0; i < server.args(); i++) {
    message += " " + server.argName(i) + ": " + server.arg(i) + "\n";
  }
  server.send(404, "text/plain", message);
}

// Helper function to get projects as HTML options
String getProjectsOptionsHTML() {
  String html = "";
  
  if (!sdInitialized) {
    return html;
  }

  File root = SD.open(projectsDir);
  if (!root) {
    return html;
  }

  File projectDir = root.openNextFile();
  while (projectDir) {
    if (projectDir.isDirectory()) {
      html += "<option value='" + String(projectDir.name()) + "'>" + 
              String(projectDir.name()) + "</option>";
    }
    projectDir = root.openNextFile();
    yield(); // Allow other tasks to run
  }
  
  root.close();
  return html;
}

// Helper function to get projects as HTML list
String getProjectsHTML() {
  String html = "<table><tr><th>Project Name</th><th>Files</th><th>Actions</th></tr>";

  if (!sdInitialized) {
    html += "<tr><td colspan='3'>SD card not initialized</td></tr>";
    return html;
  }

  File root = SD.open(projectsDir);
  if (!root) {
    html += "<tr><td colspan='3'>Could not open projects directory</td></tr>";
    return html;
  }

  File projectDir = root.openNextFile();
  while (projectDir) {
    if (projectDir.isDirectory()) {
      int fileCount = countFilesInDir(projectDir.name());
      html += "<tr>";
      html += "<td>" + String(projectDir.name()) + "</td>";
      html += "<td>" + String(fileCount) + "</td>";
      html += "<td>";
      html += "<button onclick=\"viewFiles('" + String(projectDir.name()) + "')\">View Files</button>";
      html += "<button onclick=\"showProjectQR('" + String(projectDir.name()) + "')\">Show QR</button>";
      html += "<button onclick=\"window.location.href='/sd_diag'\">SD Diag</button>";
      html += "</td>";
      html += "</tr>";
    }
    projectDir = root.openNextFile();
    yield(); // Allow other tasks to run
  }

  root.close();
  html += "</table>";
  html += "<div id='qrModal' style='display:none; position:fixed; z-index:1000; left:0; top:0; width:100%; height:100%; overflow:auto; background-color:rgba(0,0,0,0.4);'>";
  html += "  <div style='background-color:#fefefe; margin:15% auto; padding:20px; border:1px solid #888; width:400px; text-align:center;'>";
  html += "    <span onclick=\"closeQRModal()\" style='color:#aaa; float:right; font-size:28px; font-weight:bold; cursor:pointer;'>&times;</span>";
  html += "    <h3>Project QR Code</h3>";
  html += "    <div id='qrContainer'></div>";
  html += "    <p>Scan this QR code to open this project on your phone</p>";
  html += "  </div>";
  html += "</div>";
  html += "<script>";
  html += "function viewFiles(projectName) { window.location.href = '/list_files?project_name=' + encodeURIComponent(projectName); }";
  html += "function showProjectQR(projectName) {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  var qrContainer = document.getElementById('qrContainer');";
  html += "  qrContainer.innerHTML = '<img src=\"/project_qr?project=' + encodeURIComponent(projectName) + '\" alt=\"Project QR Code\" style=\"width:200px;height:200px;\">';";
  html += "  modal.style.display = 'block';";
  html += "}";
  html += "function forceQRCodesSync() {";
  html += "  fetch('/force_qr_sync')";
  html += "    .then(response => response.text())";
  html += "    .then(data => {";
  html += "      alert('Force QR codes sync initiated: ' + data);";
  html += "      location.reload();";
  html += "    })";
  html += "    .catch(error => {";
  html += "      alert('Force QR codes sync failed: ' + error);";
  html += "    });";
  html += "}";
  html += "function closeQRModal() {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  modal.style.display = 'none';";
  html += "}";
  html += "// Close modal if clicked outside content";
  html += "window.onclick = function(event) {";
  html += "  var modal = document.getElementById('qrModal');";
  html += "  if (event.target == modal) {";
  html += "    modal.style.display = 'none';";
  html += "  }";
  html += "}";
  html += "</script>";

  return html;
}

// Helper function to get files as HTML list for a specific project
String getFilesHTML(String projectName) {
  String html = "<table><tr><th>File Name</th><th>Category</th><th>Size</th><th>Actions</th></tr>";

  if (!sdInitialized) {
    html += "<tr><td colspan='4'>SD card not initialized</td></tr>";
    return html;
  }

  String projectPath = projectsDir + "/" + projectName;
  File projectDir = SD.open(projectPath);
  if (!projectDir.isDirectory()) {
    html += "<tr><td colspan='4'>Project directory not found</td></tr>";
    return html;
  }

  // List categories first
  File categoryDir = projectDir.openNextFile();
  int totalFiles = 0;
  while (categoryDir) {
    if (categoryDir.isDirectory()) {
      String categoryName = categoryDir.name();
      String categoryPath = projectPath + "/" + categoryName;

      File fileInCategory = SD.open(categoryPath);
      File innerFile = fileInCategory.openNextFile();

      while (innerFile) {
        html += "<tr>";
        String fileName = String(innerFile.name());
        html += "<td>" + fileName + "</td>";
        html += "<td>" + categoryName + "</td>";
        html += "<td>" + String(innerFile.size()) + " bytes</td>";
        html += "<td>";

        String filePath = categoryPath + "/" + fileName;
        // Create a relative path for the URL
        String relativePath = filePath.substring(1); // Remove leading '/'

        // Check file type to determine preview option
        String lowerFileName = fileName;
        lowerFileName.toLowerCase(); // Convert to lowercase in-place
        if (lowerFileName.endsWith(".jpg") || lowerFileName.endsWith(".jpeg") || lowerFileName.endsWith(".png") ||
            lowerFileName.endsWith(".gif") || lowerFileName.endsWith(".bmp") || lowerFileName.endsWith(".webp")) {
          html += "<button onclick=\"previewImage('" + relativePath + "')\">Preview Image</button>";
        } else if (lowerFileName.endsWith(".pdf")) {
          html += "<button onclick=\"previewPDF('" + relativePath + "')\">Preview PDF</button>";
        } else {
          html += "<button onclick=\"downloadFile('" + relativePath + "')\">Download</button>";
        }

        html += "</td>";
        html += "</tr>";

        innerFile = fileInCategory.openNextFile();
        totalFiles++;
        yield(); // Allow other tasks to run
      }
      fileInCategory.close();
    }
    categoryDir = projectDir.openNextFile();
    yield(); // Allow other tasks to run
  }

  if (totalFiles == 0) {
    html += "<tr><td colspan='4'>No files found in this project</td></tr>";
  }

  html += "</table>";
  html += "<script>";
  html += "function previewImage(path) { window.open('/preview_file?filepath=/' + encodeURIComponent(path), '_blank'); }";
  html += "function previewPDF(path) { window.open('/preview_file?filepath=/' + encodeURIComponent(path), '_blank'); }";
  html += "function downloadFile(path) { window.location.href = '/preview_file?filepath=/' + encodeURIComponent(path); }";
  html += "</script>";

  return html;
}

// Helper function to count files in a project directory
int countFilesInDir(const char* dirName) {
  String projectPath = projectsDir + "/" + String(dirName);
  File projectDir = SD.open(projectPath);
  
  if (!projectDir.isDirectory()) {
    return 0;
  }

  int count = 0;
  File categoryDir = projectDir.openNextFile();
  
  while (categoryDir) {
    if (categoryDir.isDirectory()) {
      String categoryPath = projectPath + "/" + categoryDir.name();
      File fileInCategory = SD.open(categoryPath);
      File innerFile = fileInCategory.openNextFile();
      
      while (innerFile) {
        count++;
        innerFile = fileInCategory.openNextFile();
        yield(); // Allow other tasks to run
      }
      fileInCategory.close();
    }
    categoryDir = projectDir.openNextFile();
    yield(); // Allow other tasks to run
  }
  
  projectDir.close();
  return count;
}

// Helper function to recursively remove a directory and all its contents (safer version)
bool removeDirectory(String dirPath) {
  Serial.println("Attempting to remove directory: " + dirPath);
  
  File dir = SD.open(dirPath.c_str());
  if (!dir.isDirectory()) {
    Serial.println("Path is not a directory: " + dirPath);
    dir.close();
    return false;
  }

  // First, collect all file paths to be deleted
  File file = dir.openNextFile();
  String filePaths[50]; // Reduced size to save memory
  int fileCount = 0;
  
  while (file && fileCount < 50) {
    if (!file.isDirectory()) {
      filePaths[fileCount] = String(file.name());
      fileCount++;
    }
    file = dir.openNextFile();
    yield(); // Allow other tasks to run
  }
  dir.close();
  
  // Now delete the files one by one
  for (int i = 0; i < fileCount; i++) {
    if (SD.remove(filePaths[i])) {
      Serial.println("Removed file: " + filePaths[i]);
    } else {
      Serial.println("Failed to remove file: " + filePaths[i]);
      // Continue with other files even if one fails
    }
    delay(10); // Small delay to prevent overwhelming the SD card
    yield(); // Allow other tasks to run
  }
  
  // Now remove the directory itself
  return SD.rmdir(dirPath.c_str());
}

// Function to clean up empty project directories
void cleanupEmptyProjectDirs() {
  Serial.println("Starting cleanup of empty project directories...");

  // Get list of all files from Supabase to know which projects have files
  String fileListJson = getFileListFromEndpoint();
  DynamicJsonDocument remoteDoc(4096);
  DeserializationError error = deserializeJson(remoteDoc, fileListJson);

  if (error) {
    Serial.print("Remote file list JSON parsing failed during cleanup: ");
    Serial.println(error.c_str());
    return;
  }

  // Create a list of projects that exist in Supabase (have files in them)
  JsonArray remoteFiles = remoteDoc.as<JsonArray>();
  String remoteProjects[50]; // Assuming max 50 projects
  int remoteProjectCount = 0;

  for (JsonObject remoteFile : remoteFiles) {
    String fileName = remoteFile["name"] | "unknown";
    String fileId = remoteFile["id"]; // If id is null, it's a directory

    // Skip if this is actually a directory entry (id will be null for directories)
    if (remoteFile["id"].isNull()) {
      Serial.println("Skipping directory entry: " + fileName);
      continue;
    }

    // Extract project from the file path
    String project = "Default"; // Default project if not specified in path
    int firstSlash = fileName.indexOf('/');
    if (firstSlash > 0) {
      project = fileName.substring(0, firstSlash);
    }

    // Add to remote projects list if not already there
    bool alreadyExists = false;
    for (int i = 0; i < remoteProjectCount; i++) {
      if (remoteProjects[i] == project) {
        alreadyExists = true;
        break;
      }
    }
    if (!alreadyExists && remoteProjectCount < 50) {
      remoteProjects[remoteProjectCount] = project;
      remoteProjectCount++;
    }
  }

  // Now check local project directories against the remote list
  File root = SD.open(projectsDir);
  if (root) {
    File projectDir = root.openNextFile();
    while (projectDir) {
      if (projectDir.isDirectory()) {
        String localProjectName = String(projectDir.name());

        // Skip if it's not an actual project directory (e.g., system directories)
        if (localProjectName != "." && localProjectName != "..") {
          bool projectExistsRemotely = false;

          // Check if this local project exists in the remote list
          for (int i = 0; i < remoteProjectCount; i++) {
            if (remoteProjects[i] == localProjectName) {
              projectExistsRemotely = true;
              break;
            }
          }

          if (!projectExistsRemotely) {
            // This project directory doesn't exist in Supabase, so remove it
            String projectPath = projectsDir + "/" + localProjectName;
            Serial.println("Removing project directory that no longer exists in Supabase: " + projectPath);
            if (removeDirectory(projectPath)) {
              Serial.println("Successfully removed project directory: " + projectPath);
            } else {
              Serial.println("Failed to remove project directory: " + projectPath);
            }
          }
        }
      }
      projectDir = root.openNextFile();
      yield(); // Allow other tasks to run
    }
    root.close();
  }

  Serial.println("Completed cleanup of empty project directories.");
}