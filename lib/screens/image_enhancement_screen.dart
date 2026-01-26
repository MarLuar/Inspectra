import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../services/image_enhancement_service.dart';

class ImageEnhancementScreen extends StatefulWidget {
  final String imagePath;
  
  const ImageEnhancementScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<ImageEnhancementScreen> createState() => _ImageEnhancementScreenState();
}

class _ImageEnhancementScreenState extends State<ImageEnhancementScreen> {
  final ImageEnhancementService _enhancementService = ImageEnhancementService();
  
  double _brightnessValue = 0.0;
  double _contrastValue = 1.0;
  double _sharpnessValue = 0.0;
  int _rotationAngle = 0;
  bool _isCropping = false;
  Rect? _cropRect;
  
  String? _processedImagePath;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _processedImagePath = widget.imagePath;
  }

  Future<void> _applyEnhancements() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final enhancedBytes = await _enhancementService.enhanceImage(
        imagePath: widget.imagePath,
        brightness: _brightnessValue,
        contrast: _contrastValue,
        sharpness: _sharpnessValue,
        rotationDegrees: _rotationAngle,
        cropRect: _cropRect,
      );

      // Save the enhanced image to a temporary file
      final tempDir = await Directory.systemTemp.createTemp();
      final enhancedFile = File('${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await enhancedFile.writeAsBytes(enhancedBytes);
      
      setState(() {
        _processedImagePath = enhancedFile.path;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enhancing image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhance Image'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: () {
              setState(() {
                _rotationAngle = (_rotationAngle + 90) % 360;
              });
              _applyEnhancements();
            },
          ),
          IconButton(
            icon: const Icon(Icons.crop),
            onPressed: () {
              setState(() {
                _isCropping = !_isCropping;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // Return the processed image path to the previous screen
              Navigator.pop(context, _processedImagePath);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _processedImagePath != null
                ? InteractiveViewer(
                    child: Image.file(
                      File(_processedImagePath!),
                      fit: BoxFit.contain,
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text('No image to enhance'),
                    ),
                  ),
          ),
          if (_isProcessing)
            const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Brightness slider
                Row(
                  children: [
                    const Icon(Icons.brightness_medium),
                    Expanded(
                      child: Slider(
                        value: _brightnessValue,
                        min: -100,
                        max: 100,
                        onChanged: (value) {
                          setState(() {
                            _brightnessValue = value;
                          });
                        },
                        onChangeEnd: (_) => _applyEnhancements(),
                      ),
                    ),
                    Text('${_brightnessValue.toStringAsFixed(0)}%'),
                  ],
                ),
                
                // Contrast slider
                Row(
                  children: [
                    const Icon(Icons.linear_scale),
                    Expanded(
                      child: Slider(
                        value: _contrastValue,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        onChanged: (value) {
                          setState(() {
                            _contrastValue = value;
                          });
                        },
                        onChangeEnd: (_) => _applyEnhancements(),
                      ),
                    ),
                    Text('${(_contrastValue * 100).toStringAsFixed(0)}%'),
                  ],
                ),
                
                // Sharpness slider
                Row(
                  children: [
                    const Icon(Icons.blur_on),
                    Expanded(
                      child: Slider(
                        value: _sharpnessValue,
                        min: 0,
                        max: 5,
                        divisions: 5,
                        onChanged: (value) {
                          setState(() {
                            _sharpnessValue = value;
                          });
                        },
                        onChangeEnd: (_) => _applyEnhancements(),
                      ),
                    ),
                    Text('${_sharpnessValue.toStringAsFixed(0)}x'),
                  ],
                ),
                
                // Reset button
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _brightnessValue = 0.0;
                      _contrastValue = 1.0;
                      _sharpnessValue = 0.0;
                      _rotationAngle = 0;
                      _cropRect = null;
                    });
                    _applyEnhancements();
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}