import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data_model.dart';

class MineTab extends StatelessWidget {
  const MineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
        children: [
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.account_circle, size: 60, color: Colors.white),
                Text(model.currentUser, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('仓库管理员', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('数据迁移 (文件备份)', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.purple),
            title: const Text('导出备份文件 (.json)'),
            subtitle: const Text('生成文件发送到微信或保存'),
            onTap: () => _exportDataFile(context, model),
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.purple),
            title: const Text('导入备份文件'),
            subtitle: const Text('选择 .json 文件恢复数据'),
            onTap: () => _importDataFile(context, model),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('危险操作', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清空所有数据'),
            subtitle: const Text('删除所有物资和出入库记录'),
            onTap: () => _showClearConfirm(context, model),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _exportDataFile(BuildContext context, DataModel model) async {
    try {
      final jsonStr = model.exportData();
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'warehouse_backup_$dateStr.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonStr);
      if (context.mounted) {
        await Share.shareXFiles([XFile(file.path)], text: '物资管理系统数据备份 ($dateStr)', subject: fileName);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  Future<void> _importDataFile(BuildContext context, DataModel model) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'txt']);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('确认恢复'),
              content: const Text('导入数据将覆盖现有数据，是否继续？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(c);
                    final err = await model.importData(jsonStr);
                    if (context.mounted) {
                      if (err == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据恢复成功！')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('数据格式错误: $err')));
                      }
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('读取文件失败: $e')));
    }
  }

  void _showClearConfirm(BuildContext context, DataModel model) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('警告'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('此操作将删除所有物资和记录，且不可恢复！', style: TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              const Text('请输入 “清空数据” 确认操作：'),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                decoration: const InputDecoration(hintText: '清空数据'),
                onChanged: (v) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: confirmCtrl.text == '清空数据'
                  ? () {
                      model.clearData();
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据已全部重置')));
                    }
                  : null,
              child: const Text('确定删除'),
            ),
          ],
        ),
      ),
    );
  }
}
