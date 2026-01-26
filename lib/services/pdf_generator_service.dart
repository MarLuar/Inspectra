import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  /// Converts a JPEG image to a high-quality PDF
  Future<Uint8List> imageToPdf({
    required String imagePath,
    String? title,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    // Load the image
    final imageBytes = await File(imagePath).readAsBytes();
    final pdfImage = pw.MemoryImage(imageBytes);
    
    // Create PDF document
    final pdf = pw.Document();
    
    // Add page with the image
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Expanded(
              child: pw.Image(
                pdfImage,
                fit: pw.BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
    
    // Return the PDF as bytes
    return pdf.save();
  }

  /// Converts multiple images to a single PDF document
  Future<Uint8List> imagesToPdf({
    required List<String> imagePaths,
    String? title,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document();
    
    for (final imagePath in imagePaths) {
      final imageBytes = await File(imagePath).readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);
      
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Expanded(
                child: pw.Image(
                  pdfImage,
                  fit: pw.BoxFit.contain,
                ),
              ),
            );
          },
        ),
      );
    }
    
    return pdf.save();
  }

  /// Creates a high-resolution PDF from an image (simulating 1200 DPI)
  Future<Uint8List> imageToHighResPdf({
    required String imagePath,
    String? title,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    // Load the image
    final imageBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(imageBytes)!;
    
    // Calculate dimensions for high DPI (1200 DPI equivalent)
    // Standard A4 is 8.27 x 11.69 inches
    // At 1200 DPI that would be 9924 x 14028 pixels
    // We'll scale the image proportionally to maintain quality
    const targetDpi = 1200.0;
    const standardDpi = 72.0; // Standard PDF DPI
    
    // Calculate scaling factor
    final scaleFactor = targetDpi / standardDpi;
    
    // Resize image to simulate high DPI
    final resizedImage = img.copyResize(
      originalImage,
      width: (originalImage.width * scaleFactor).toInt(),
      height: (originalImage.height * scaleFactor).toInt(),
    );
    
    // Encode the resized image
    final resizedImageBytes = img.encodePng(resizedImage);
    final pdfImage = pw.MemoryImage(Uint8List.fromList(resizedImageBytes));
    
    // Create PDF document
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.FittedBox(
              child: pw.Image(
                pdfImage,
                fit: pw.BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
    
    return pdf.save();
  }

  /// Saves PDF to a file
  Future<String> savePdfToFile(Uint8List pdfData, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(pdfData);
    return filePath;
  }
}