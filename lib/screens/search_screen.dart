import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../models/project_model.dart';
import 'project_detail_screen.dart';
import 'document_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String _searchType = 'all'; // 'all', 'projects', 'documents'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      if (_searchType == 'projects') {
        final results = await _searchService.searchProjects(query);
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } else if (_searchType == 'documents') {
        final results = await _searchService.searchDocumentsGlobally(query);
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } else { // 'all'
        // Search both projects and documents
        final projectResults = await _searchService.searchProjects(query);
        final documentResults = await _searchService.searchDocumentsGlobally(query);
        
        // Combine results
        setState(() {
          _searchResults = [...projectResults.cast(), ...documentResults.cast()];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search projects or documents...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12.0),
                ),
                onChanged: _performSearch,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search type selector
          Container(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'projects', label: Text('Projects')),
                ButtonSegment(value: 'documents', label: Text('Documents')),
              ],
              selected: {_searchType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _searchType = newSelection.first;
                });
                _performSearch(_searchController.text);
              },
            ),
          ),
          
          // Results count
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    '${_searchResults.length} results for "${_searchController.text}"',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Results list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(
                        child: Text(
                          'No results found',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Enter a search term',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              final isProject = result is Project;
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isProject ? Colors.blue : Colors.green,
                                    child: Text(
                                      isProject ? 'P' : 'D',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(isProject ? (result as Project).name : (result as Document).name),
                                  subtitle: Text(isProject ? 'Project' : 'Document (${(result as Document).category})'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    // Handle tap based on result type
                                    if (isProject) {
                                      // Navigate to project details
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProjectDetailScreen(projectName: (result as Project).name),
                                        ),
                                      );
                                    } else {
                                      // Navigate to document details
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DocumentDetailScreen(document: result as Document),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}