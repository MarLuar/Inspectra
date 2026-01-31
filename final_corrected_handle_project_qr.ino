void handleProjectQR() {
  String projectName = server.arg("project");
  if (projectName == "") {
    server.send(400, "text/plain", "Project name required");
    return;
  }

  // First, try to get the QR code URL from stored project QR codes
  String qrCodeUrl = getProjectQRCode(projectName);
  Serial.println("Retrieved QR code URL for project " + projectName + ": " + qrCodeUrl);

  // If the stored QR code is a URL (not the raw data), redirect to it
  if (qrCodeUrl.startsWith("http")) {
    // Redirect to the stored QR code URL (could be a Supabase URL or local file path)
    if (qrCodeUrl.startsWith("http://" + WiFi.localIP().toString())) {
      // If it's a local file path, serve it directly
      String filePath = qrCodeUrl.substring(7 + WiFi.localIP().toString().length() + 1); // Remove "http://[IP]/" part
      if (SD.exists(filePath)) {
        File qrFile = SD.open(filePath, FILE_READ);
        if (qrFile) {
          server.streamFile(qrFile, "image/png");
          qrFile.close();
          return;
        } else {
          Serial.println("Could not open QR code file: " + filePath);
        }
      } else {
        Serial.println("QR code file does not exist: " + filePath);
      }
    } else {
      // If it's a remote URL (like Supabase), redirect to it
      server.sendHeader("Location", qrCodeUrl);
      server.send(302, "text/plain", "");
      return;
    }
  }

  // If no stored QR code URL exists or it's not a URL, try to construct the Supabase URL
  String supabaseQRUrl = String(SUPABASE_URL) + "/storage/v1/object/public/documents/" + projectName + "/qrcodes/qrcode(" + projectName + ").png";
  Serial.println("Constructed Supabase QR code URL: " + supabaseQRUrl);

  // Try to fetch the QR code from Supabase
  HTTPClient httpClient;
  httpClient.begin(supabaseQRUrl);
  httpClient.addHeader("apikey", SUPABASE_ANON_KEY);
  httpClient.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));

  int httpResponseCode = httpClient.GET();
  if (httpResponseCode == 200) {
    // Successfully fetched QR code from Supabase, redirect to it
    server.sendHeader("Location", supabaseQRUrl);
    server.send(302, "text/plain", "");
  } else {
    Serial.println("Failed to fetch QR code from Supabase for project " + projectName + ", HTTP: " + String(httpResponseCode));
    // If we can't fetch from Supabase, generate a simple placeholder QR code with the project info
    String placeholderSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' fill='#ffffff'/><rect x='10' y='10' width='80' height='80' fill='#cccccc'/><text x='50' y='55' font-size='12' text-anchor='middle' fill='#000000'>Project: " + projectName + "</text><text x='50' y='70' font-size='8' text-anchor='middle' fill='#000000'>QR code not found</text></svg>";
    server.send(200, "image/svg+xml", placeholderSvg);
  }
  httpClient.end();
}