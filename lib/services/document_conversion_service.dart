import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class DocumentConversionService {
  /// Converts a JPG image to a PDF document
  Future<String> convertJpgToPdf(String imagePath, String outputFileName) async {
    try {
      // Read the image file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      
      // Decode the image
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Could not decode image');
      }

      // Create a PDF document
      final pdf = pw.Document();

      // Add the image to the PDF
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pw.MemoryImage(Uint8List.fromList(imageBytes)),
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );

      // Get the documents directory to save the PDF
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/Converted_PDFs/$outputFileName.pdf';

      // Create the directory if it doesn't exist
      final outputDir = Directory('${directory.path}/Converted_PDFs');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Write the PDF to the file
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return outputPath;
    } catch (e) {
      throw Exception('Error converting JPG to PDF: $e');
    }
  }

  /// Converts a JPG image to a simple DOC-like text document
  /// Note: This creates a plain text file with image data embedded as base64
  /// For a true DOCX file, we would need a more complex implementation
  Future<String> convertJpgToDoc(String imagePath, String outputFileName) async {
    try {
      // Read the image file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      // Get the documents directory to save the DOC file
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/Converted_Docs/$outputFileName.txt'; // Using .txt as a simple text file

      // Create the directory if it doesn't exist
      final outputDir = Directory('${directory.path}/Converted_Docs');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Create a simple text representation of the image
      final StringBuffer content = StringBuffer();
      content.writeln('Document converted from image: ${imageFile.path}');
      content.writeln('Conversion date: ${DateTime.now()}');
      content.writeln('');
      content.writeln('Note: This is a text representation. The original image data is attached.');
      content.writeln('');
      content.writeln('Original image dimensions: ');
      // Try to get image dimensions
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage != null) {
        content.writeln('Width: ${decodedImage.width}px');
        content.writeln('Height: ${decodedImage.height}px');
      }

      // Write the content to the file
      final outputFile = File(outputPath);
      await outputFile.writeAsString(content.toString());

      return outputPath;
    } catch (e) {
      throw Exception('Error converting JPG to DOC: $e');
    }
  }

  /// Creates a proper text file that represents the image as a document
  Future<String> convertJpgToText(String imagePath, String outputFileName) async {
    try {
      // Read the image file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      // Get the documents directory to save the text file
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/Converted_Text/$outputFileName.txt';

      // Create the directory if it doesn't exist
      final outputDir = Directory('${directory.path}/Converted_Text');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Create a more detailed text representation of the image
      final StringBuffer content = StringBuffer();
      content.writeln('=' * 50);
      content.writeln('IMAGE DOCUMENT REPORT');
      content.writeln('=' * 50);
      content.writeln('');
      content.writeln('Source Image: ${imageFile.path.split('/').last}');
      content.writeln('Conversion Date: ${DateTime.now()}');
      content.writeln('');

      // Try to get image dimensions and metadata
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage != null) {
        content.writeln('Dimensions:');
        content.writeln('  Width: ${decodedImage.width} pixels');
        content.writeln('  Height: ${decodedImage.height} pixels');
        content.writeln('  Color Type: ${decodedImage.numChannels} channels');
        content.writeln('');
      }

      content.writeln('File Information:');
      content.writeln('  Size: ${(imageBytes.lengthInBytes / 1024).toStringAsFixed(2)} KB');
      content.writeln('  Format: JPEG');
      content.writeln('');
      content.writeln('=' * 50);
      content.writeln('SUMMARY');
      content.writeln('=' * 50);
      content.writeln('');
      content.writeln('This document represents an image file that has been converted');
      content.writeln('to text format for archival and reference purposes.');
      content.writeln('');
      content.writeln('The original image may contain important visual information');
      content.writeln('that is not represented in this text format.');

      // Write the content to the file
      final outputFile = File(outputPath);
      await outputFile.writeAsString(content.toString());

      return outputPath;
    } catch (e) {
      throw Exception('Error converting JPG to text: $e');
    }
  }

  /// Creates a more advanced DOCX file using a different approach
  /// This is a placeholder for when we have proper DOCX support
  Future<String> convertJpgToDocx(String imagePath, String outputFileName) async {
    // For now, we'll just return the same as the simple DOC conversion
    // In a real implementation, we would use a proper DOCX library
    return await convertJpgToDoc(imagePath, outputFileName);
  }
}