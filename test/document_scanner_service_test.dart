import 'package:flutter_test/flutter_test.dart';
import 'package:inspectra_app/services/document_scanner_service.dart';

void main() {
  group('DocumentScannerService Tests', () {
    late DocumentScannerService service;

    setUp(() {
      service = DocumentScannerService();
    });

    test('Service initializes correctly', () {
      expect(service, isNotNull);
    });

    // Note: Actual scanning tests would require device/emulator
    // These are integration tests that would need to be run separately
    test('Methods exist and are callable', () {
      expect(service.scanDocument, isNotNull);
      expect(service.pickFromGallery, isNotNull);
    });
  });
}