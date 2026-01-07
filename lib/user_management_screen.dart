import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _queryIdController = TextEditingController();
  final TextEditingController _addIdController = TextEditingController();
  final TextEditingController _addNameController = TextEditingController();

  Map<String, dynamic>? _queryResult;
  String _queryStatus = '';
  bool _isLoading = false;

  // Query user
  Future<void> _queryUserById(String id) async {
    if (id.isEmpty) {
      setState(() {
        _queryStatus = 'Please enter ID';
        _queryResult = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _queryStatus = 'Querying...';
    });

    try {
      final doc = await _firestore.collection('User').doc(id).get();
      
      if (doc.exists) {
        setState(() {
          _queryResult = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
          _queryStatus = 'Query successful';
          _isLoading = false;
        });
      } else {
        setState(() {
          _queryResult = null;
          _queryStatus = 'User with this ID not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _queryStatus = 'Query failed: $e';
        _queryResult = null;
        _isLoading = false;
      });
      print('Query error: $e');
    }
  }

  // Add user
  Future<void> _addUser() async {
    final id = _addIdController.text.trim();
    final name = _addNameController.text.trim();

    if (id.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID and Name cannot be empty')),
      );
      return;
    }

    try {
      // Check if already exists
      final existingDoc = await _firestore.collection('User').doc(id).get();
      if (existingDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This ID already exists')),
        );
        return;
      }

      // Add new user
      await _firestore.collection('User').doc(id).set({
        'ID': id,
        'name': name,
      });

      _addIdController.clear();
      _addNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully')),
      );
      print('User added successfully: ID=$id, name=$name');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add failed: $e')),
      );
      print('Add error: $e');
    }
  }

  // Delete user
  Future<void> _deleteUser(String id) async {
    try {
      await _firestore.collection('User').doc(id).delete();
      
      setState(() {
        _queryResult = null;
        _queryStatus = 'User deleted';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
      print('User deleted successfully: ID=$id');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
      print('Delete error: $e');
    }
  }

  @override
  void dispose() {
    _queryIdController.dispose();
    _addIdController.dispose();
    _addNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Query section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Query User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _queryIdController,
                      decoration: InputDecoration(
                        labelText: 'Enter User ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _queryUserById(_queryIdController.text),
                        child: Text(_isLoading ? 'Querying...' : 'Query'),
                      ),
                    ),
                    if (_queryStatus.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _queryStatus,
                        style: TextStyle(
                          color: _queryResult != null ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Query result
            if (_queryResult != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Query Result',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildResultRow('ID', _queryResult!['ID'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildResultRow('Name', _queryResult!['name'] ?? 'N/A'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _queryResult = null;
                                  _queryStatus = '';
                                  _queryIdController.clear();
                                });
                              },
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _showDeleteConfirmDialog(
                                  _queryResult!['ID'],
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Add user section
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addIdController,
                      decoration: InputDecoration(
                        labelText: 'Enter ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.person_add),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addNameController,
                      decoration: InputDecoration(
                        labelText: 'Enter Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Add User',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Result row widget
  Widget _buildResultRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Delete confirmation dialog
  void _showDeleteConfirmDialog(String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete the user with ID "$userId"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteUser(userId);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Confirm Delete'),
            ),
          ],
        );
      },
    );
  }
}
