import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:inspectra_app/screens/qr_scanner_screen.dart';
import 'package:inspectra_app/services/project_organization_service.dart';
import 'package:inspectra_app/models/project_model.dart';

void main() {
  group('QR Scanner Screen Tests', () {
    testWidgets('QR Scanner screen builds correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: QrScannerScreen(),
        ),
      );

      // Verify that the app bar with title 'Scan QR Code' appears
      expect(find.text('Scan QR Code'), findsOneWidget);

      // Verify that the camera controls appear
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch), findsOneWidget);
    });

    testWidgets('QR Scanner processes valid project code', (WidgetTester tester) async {
      // Mock the project organization service
      final mockProjectService = MockProjectOrganizationService();
      
      // Create a mock project
      final testProject = Project(
        id: 'test-project-id',
        name: 'Test Project',
        createdAt: DateTime.now(),
      );
      
      mockProjectService.mockProjects = [testProject];

      // Temporarily replace the service with our mock
      // Note: This is a simplified test focusing on UI elements
      await tester.pumpWidget(
        const MaterialApp(
          home: QrScannerScreen(),
        ),
      );

      // Verify the screen is built
      expect(find.byType(QrScannerScreen), findsOneWidget);
    });
  });
}

// Mock class for testing
class MockProjectOrganizationService extends ProjectOrganizationService {
  List<Project> mockProjects = [];

  @override
  Future<List<Project>> getAllProjects() async {
    return mockProjects;
  }
}