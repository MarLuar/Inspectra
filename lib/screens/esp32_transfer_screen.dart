import 'package:flutter/material.dart';
import 'dart:io';
import '../services/esp32_communication_service.dart';
import '../services/project_organization_service.dart';
import '../models/project_model.dart';

class Esp32TransferScreen extends StatefulWidget {
  final String? projectName;

  const Esp32TransferScreen({Key? key, this.projectName}) : super(key: key);

  @override
  State<Esp32TransferScreen> createState() => _Esp32TransferScreenState();
}

class _Esp32TransferScreenState extends State<Esp32TransferScreen> {
  final Esp32CommunicationService _esp32Service = Esp32CommunicationService();
  final ProjectOrganizationService _projectService = ProjectOrganizationService();
  
  String _esp32Ip = '192.168.4.1';
  bool _isConnected = false;
  bool _isTestingConnection = false;
  bool _isSending = false;
  String _connectionStatus = 'Not connected';
  String _transferStatus = '';
  double _transferProgress = 0.0;
  Project? _selectedProject;
  List<Document> _projectDocuments = [];

  @override
  void initState() {
    super.initState();
    _initializeProject();
  }

  Future<void> _initializeProject() async {
    if (widget.projectName != null) {
      try {
        final allProjects = await _projectService.getAllProjects();
        _selectedProject = allProjects.firstWhere((p) => p.name == widget.projectName);
        
        if (_selectedProject != null) {
          _projectDocuments = await _projectService.getDocumentsForProject(_selectedProject!.id);
        }
        
        setState(() {});
      } catch (e) {
        print('Error initializing project: $e');
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
    });

    final isConnected = await _esp32Service.testConnection();
    
    setState(() {
      _isConnected = isConnected;
      _isTestingConnection = false;
      _connectionStatus = isConnected ? 'Connected to ESP32' : 'Connection failed';
    });

    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to ESP32. Please check the IP address and ensure ESP32 is powered on.')),
      );
    }
  }

  Future<void> _updateEsp32Ip() async {
    final TextEditingController ipController = TextEditingController(text: _esp32Ip);

    final result = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update ESP32 IP Address'),
          content: TextField(
            controller: ipController,
            decoration: const InputDecoration(hintText: 'Enter ESP32 IP address'),
            keyboardType: TextInputType.text,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(ipController.text);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _esp32Ip = result;
      });
      _esp32Service.updateEsp32Ip(result);
    }
  }

  Future<void> _sendProjectToEsp32() async {
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No project selected')),
      );
      return;
    }

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to ESP32')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _transferStatus = 'Starting transfer...';
      _transferProgress = 0.0;
    });

    try {
      bool success = await _esp32Service.sendProjectToEsp32(_selectedProject!, _projectDocuments);
      
      if (success) {
        setState(() {
          _transferStatus = 'Transfer completed successfully!';
          _transferProgress = 100.0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project sent to ESP32 successfully!')),
        );
      } else {
        setState(() {
          _transferStatus = 'Transfer failed';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send project to ESP32')),
        );
      }
    } catch (e) {
      setState(() {
        _transferStatus = 'Transfer failed: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending project to ESP32: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 File Transfer', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ESP32 Connection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ESP32 Connection',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: _updateEsp32Ip,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('IP Address: $_esp32Ip'),
                    const SizedBox(height: 8),
                    Text(
                      _connectionStatus,
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTestingConnection ? null : _testConnection,
                            icon: _isTestingConnection 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.wifi),
                            label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected ? Colors.green : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Project Information Section
            if (_selectedProject != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Project Name: ${_selectedProject!.name}'),
                      Text('Documents Count: ${_projectDocuments.length}'),
                      Text('Created: ${_formatDateTime(_selectedProject!.createdAt)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Transfer Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transfer Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_transferStatus.isNotEmpty) Text(_transferStatus),
                    if (_isSending) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _transferProgress / 100.0),
                      const SizedBox(height: 4),
                      Text('${_transferProgress.toStringAsFixed(1)}%'),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSending || !_isConnected || _selectedProject == null
                                ? null
                                : _sendProjectToEsp32,
                            icon: const Icon(Icons.upload),
                            label: const Text('Send to ESP32'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Project Documents Preview
            if (_projectDocuments.isNotEmpty) ...[
              const Text(
                'Documents to Transfer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _projectDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = _projectDocuments[index];
                    final fileName = doc.path.split('/').last;
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            _getFileIcon(doc.path),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    fileName,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Category: ${doc.category}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_selectedProject != null) ...[
              const Text(
                'Documents to Transfer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('No documents in this project'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getFileIcon(String filePath) {
    final fileName = filePath.toLowerCase();
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.gif')) {
      return const Icon(Icons.image, color: Colors.blue);
    } else if (fileName.endsWith('.pdf')) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    String month = _getMonthName(dateTime.month);
    String ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    int hour = dateTime.hour % 12;
    if (hour == 0) hour = 12; // 12-hour format

    return '$month ${dateTime.day}, ${dateTime.year} ${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  String _getMonthName(int monthIndex) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[monthIndex - 1];
  }
}