import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../services/pdf_generator_service.dart';

class PdfGenerationScreen extends StatefulWidget {
  final String imagePath;
  
  const PdfGenerationScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<PdfGenerationScreen> createState() => _PdfGenerationScreenState();
}

class _PdfGenerationScreenState extends State<PdfGenerationScreen> {
  final PdfGeneratorService _pdfService = PdfGeneratorService();
  String? _pdfPath;
  bool _isGenerating = false;

  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final pdfData = await _pdfService.imageToHighResPdf(
        imagePath: widget.imagePath,
      );
      
      final fileName = 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await _pdfService.savePdfToFile(pdfData, fileName);
      
      setState(() {
        _pdfPath = path;
        _isGenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generated successfully!')),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  Future<Uint8List> _generatePdfData() async {
    return await _pdfService.imageToPdf(
      imagePath: widget.imagePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate PDF'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _pdfPath != null
                ? PdfPreview(
                    build: (context) => _generatePdfData(),
                    allowPrinting: true,
                    allowSharing: true,
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text('Generate PDF from your image'),
                    ),
                  ),
          ),
          if (_isGenerating)
            const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _generatePdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}