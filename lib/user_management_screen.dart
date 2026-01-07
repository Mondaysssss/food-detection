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

  // 查詢用戶
  Future<void> _queryUserById(String id) async {
    if (id.isEmpty) {
      setState(() {
        _queryStatus = '請輸入 ID';
        _queryResult = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _queryStatus = '查詢中...';
    });

    try {
      final doc = await _firestore.collection('User').doc(id).get();
      
      if (doc.exists) {
        setState(() {
          _queryResult = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
          _queryStatus = '查詢成功';
          _isLoading = false;
        });
      } else {
        setState(() {
          _queryResult = null;
          _queryStatus = '找不到此 ID 的用戶';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _queryStatus = '查詢失敗: $e';
        _queryResult = null;
        _isLoading = false;
      });
      print('查詢錯誤: $e');
    }
  }

  // 添加用戶
  Future<void> _addUser() async {
    final id = _addIdController.text.trim();
    final name = _addNameController.text.trim();

    if (id.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID 和名稱不能為空')),
      );
      return;
    }

    try {
      // 檢查是否已存在
      final existingDoc = await _firestore.collection('User').doc(id).get();
      if (existingDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此 ID 已存在')),
        );
        return;
      }

      // 新增用戶
      await _firestore.collection('User').doc(id).set({
        'ID': id,
        'name': name,
      });

      _addIdController.clear();
      _addNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用戶添加成功')),
      );
      print('用戶添加成功: ID=$id, name=$name');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失敗: $e')),
      );
      print('添加錯誤: $e');
    }
  }

  // 刪除用戶
  Future<void> _deleteUser(String id) async {
    try {
      await _firestore.collection('User').doc(id).delete();
      
      setState(() {
        _queryResult = null;
        _queryStatus = '用戶已刪除';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用戶刪除成功')),
      );
      print('用戶刪除成功: ID=$id');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗: $e')),
      );
      print('刪除錯誤: $e');
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
            // 查詢區段
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '查詢用戶',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _queryIdController,
                      decoration: InputDecoration(
                        labelText: '輸入用戶 ID',
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
                        child: Text(_isLoading ? '查詢中...' : '查詢'),
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

            // 查詢結果
            if (_queryResult != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '查詢結果',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildResultRow('ID', _queryResult!['ID'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildResultRow('名稱', _queryResult!['name'] ?? 'N/A'),
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
                              child: const Text('返回'),
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
                                '刪除',
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

            // 添加用戶區段
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '添加新用戶',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addIdController,
                      decoration: InputDecoration(
                        labelText: '輸入 ID',
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
                        labelText: '輸入名稱',
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
                          '添加用戶',
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

  // 結果行組件
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

  // 刪除確認對話框
  void _showDeleteConfirmDialog(String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除 ID 為 "$userId" 的用戶嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _deleteUser(userId);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );
  }
}
