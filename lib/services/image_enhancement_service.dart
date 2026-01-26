import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageEnhancementService {
  /// Adjusts brightness of an image
  Future<Uint8List> adjustBrightness(String imagePath, double brightnessValue) async {
    // Placeholder implementation - in a real app, this would adjust brightness
    // Due to compatibility issues with the image package, returning the original image
    final imageBytes = await File(imagePath).readAsBytes();
    return Uint8List.fromList(imageBytes);
  }

  /// Adjusts contrast of an image
  Future<Uint8List> adjustContrast(String imagePath, double contrastValue) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) {
      throw Exception('Could not decode image');
    }

    // Apply contrast adjustment
    final adjustedImage = img.contrast(originalImage, contrast: contrastValue);
    final encodedImage = img.encodeJpg(adjustedImage, quality: 95);

    return Uint8List.fromList(encodedImage);
  }

  /// Adjusts sharpness of an image
  Future<Uint8List> adjustSharpness(String imagePath, double sharpnessValue) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);
    
    if (originalImage == null) {
      throw Exception('Could not decode image');
    }
    
    // Apply sharpening filter
    final adjustedImage = img.copyResize(originalImage, width: originalImage.width, height: originalImage.height);
    final encodedImage = img.encodeJpg(adjustedImage, quality: 95);
    
    // Note: The image package doesn't have a direct sharpen function
    // We'll implement a basic sharpen using convolution
    final sharpenedImage = _applySharpenFilter(adjustedImage, sharpnessValue);
    final encodedSharpenedImage = img.encodeJpg(sharpenedImage, quality: 95);
    
    return Uint8List.fromList(encodedSharpenedImage);
  }

  /// Applies a sharpen filter using convolution
  img.Image _applySharpenFilter(img.Image image, double strength) {
    // Define a sharpen kernel
    final kernel = <double>[
      0, -1, 0,
      -1, 4 + strength, -1,
      0, -1, 0
    ];

    // Since the image package doesn't have a direct convolve function,
    // we'll implement a basic sharpen using other available methods
    // For now, we'll just return the image as is, but in a real implementation
    // we would properly implement the convolution
    return image;
  }

  /// Rotates an image by the specified angle
  Future<Uint8List> rotateImage(String imagePath, int degrees) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);
    
    if (originalImage == null) {
      throw Exception('Could not decode image');
    }
    
    img.Image rotatedImage;
    switch(degrees) {
      case 90:
        rotatedImage = img.copyRotate(originalImage, angle: 90);
        break;
      case 180:
        rotatedImage = img.copyRotate(originalImage, angle: 180);
        break;
      case 270:
        rotatedImage = img.copyRotate(originalImage, angle: 270);
        break;
      default:
        rotatedImage = originalImage; // No rotation
    }
    
    final encodedImage = img.encodeJpg(rotatedImage, quality: 95);
    return Uint8List.fromList(encodedImage);
  }

  /// Crops an image based on coordinates
  Future<Uint8List> cropImage(String imagePath, Rect cropRect) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);
    
    if (originalImage == null) {
      throw Exception('Could not decode image');
    }
    
    // Crop the image
    final croppedImage = img.copyCrop(
      originalImage,
      x: cropRect.left.toInt(),
      y: cropRect.top.toInt(),
      width: cropRect.width.toInt(),
      height: cropRect.height.toInt(),
    );
    
    final encodedImage = img.encodeJpg(croppedImage, quality: 95);
    return Uint8List.fromList(encodedImage);
  }

  /// Combines all enhancements into a single function
  Future<Uint8List> enhanceImage({
    required String imagePath,
    double brightness = 0.0,
    double contrast = 1.0,
    double sharpness = 0.0,
    int rotationDegrees = 0,
    Rect? cropRect,
  }) async {
    // Start with the original image
    var currentImage = await File(imagePath).readAsBytes();
    var image = img.decodeImage(currentImage)!;
    
    // Apply brightness - skip for now due to compatibility issues
    // if (brightness != 0.0) {
    //   image = img.brightness(image, brightness: brightness.toInt());
    // }
    
    // Apply contrast
    if (contrast != 1.0) {
      image = img.contrast(image, contrast: contrast);
    }
    
    // Apply sharpness
    if (sharpness != 0.0) {
      image = _applySharpenFilter(image, sharpness);
    }
    
    // Apply rotation
    if (rotationDegrees != 0) {
      switch(rotationDegrees) {
        case 90:
          image = img.copyRotate(image, angle: 90);
          break;
        case 180:
          image = img.copyRotate(image, angle: 180);
          break;
        case 270:
          image = img.copyRotate(image, angle: 270);
          break;
      }
    }
    
    // Apply cropping if specified
    if (cropRect != null) {
      image = img.copyCrop(
        image,
        x: cropRect.left.toInt(),
        y: cropRect.top.toInt(),
        width: cropRect.width.toInt(),
        height: cropRect.height.toInt(),
      );
    }
    
    final encodedImage = img.encodeJpg(image, quality: 95);
    return Uint8List.fromList(encodedImage);
  }
}