import 'package:flutter/material.dart';
import '../services/project_organization_service.dart';
import '../models/project_model.dart';
import 'project_detail_screen.dart';
import 'search_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({Key? key}) : super(key: key);

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  final ProjectOrganizationService _projectService = ProjectOrganizationService();
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _projectService.getAllProjects();
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading projects: $e')),
      );
    }
  }

  Future<void> _createNewProject() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create New Folder', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "Folder name", labelText: "Name"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  hintText: "Location (optional)",
                  labelText: "Location",
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                  });
                }
              },
              child: Text('Create', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await _projectService.createProject(
          result['name']!,
          location: result['location']!.isEmpty ? null : result['location']
        );
        _loadProjects(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating folder: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // Format to show both date and time (e.g., "Jan 25, 2026 10:30 AM")
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Folders', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (String? value) {
              if (value != null) {
                _sortProjects(value);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'date_newest',
                child: Text('Date (Newest)', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              PopupMenuItem<String>(
                value: 'date_oldest',
                child: Text('Date (Oldest)', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              PopupMenuItem<String>(
                value: 'name_az',
                child: Text('Name (A-Z)', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
              PopupMenuItem<String>(
                value: 'name_za',
                child: Text('Name (Z-A)', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewProject,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const Center(
                  child: Text(
                    'No folders yet.\nTap the + button to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          leading: const Icon(Icons.folder, color: Colors.blue),
                          title: Text(project.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Created: ${_formatDateTime(project.createdAt)}'),
                              if (project.location != null && project.location!.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        project.location!,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              Text('Documents: ${project.documentCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProjectDetailScreen(projectName: project.name),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _sortProjects(String sortBy) {
    setState(() {
      switch (sortBy) {
        case 'date_newest':
          _projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'date_oldest':
          _projects.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'name_az':
          _projects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
        case 'name_za':
          _projects.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          break;
      }
    });
  }
}