import 'dart:io'; // 用于文件读写
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// PDF相关
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// 新增插件
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart'; // 用于生成文件名的时间戳

import '../data_model.dart';

class MineTab extends StatelessWidget {
  const MineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);
    final lowStock = model.materials.where((e) => e.stock <= 1).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("库存与设置")),
      body: ListView(
        children: [
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.account_circle, size: 60, color: Colors.white),
                Text(model.currentUser, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("仓库管理员", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          if (lowStock.isNotEmpty)
            ExpansionTile(
              title: const Text("库存预警 (<=1)", style: TextStyle(color: Colors.red)),
              leading: const Icon(Icons.warning, color: Colors.red),
              initiallyExpanded: true,
              children: lowStock.map((e) => ListTile(
                title: Text(e.name),
                trailing: Text("${e.stock}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text("库存严重不足"),
              )).toList(),
            ),

          const Divider(),
          ListTile(
            title: const Text("出入库记录 (点击导出PDF)"),
            leading: const Icon(Icons.history),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const RecordsPage()));
            },
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          
          // --- 需求优化：文件级数据迁移 ---
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("数据迁移 (文件备份)", style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.purple),
            title: const Text("导出备份文件 (.json)"),
            subtitle: const Text("推荐：生成文件发送到微信或保存"),
            onTap: () => _exportDataFile(context, model),
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.purple),
            title: const Text("导入备份文件"),
            subtitle: const Text("选择 .json 文件恢复数据"),
            onTap: () => _importDataFile(context, model),
          ),

          // --- 安全清空 ---
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("危险操作", style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("清空所有数据"),
            onTap: () {
              final confirmCtrl = TextEditingController();
              showDialog(context: context, builder: (c) => StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: const Text("警告"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("此操作将删除所有物资和记录，且不可恢复！", style: TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),
                      const Text("请输入 “清空数据” 确认操作："),
                      const SizedBox(height: 10),
                      TextField(
                        controller: confirmCtrl,
                        decoration: const InputDecoration(hintText: "清空数据"),
                        onChanged: (v) => setState((){}),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text("取消")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: confirmCtrl.text == "清空数据" ? () {
                        model.clearData();
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("数据已全部重置")));
                      } : null, 
                      child: const Text("确定删除"),
                    ),
                  ],
                ),
              ));
            },
          ),
        ],
      ),
    );
  }

  // --- 实现导出逻辑 ---
  Future<void> _exportDataFile(BuildContext context, DataModel model) async {
    try {
      // 1. 获取 JSON 字符串
      final jsonStr = model.exportData();
      
      // 2. 获取临时目录
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = "warehouse_backup_$dateStr.json";
      final file = File('${directory.path}/$fileName');
      
      // 3. 写入文件
      await file.writeAsString(jsonStr);
      
      // 4. 调用系统分享
      // Share.shareXFiles 需要 share_plus 插件
      if (context.mounted) {
        final result = await Share.shareXFiles(
          [XFile(file.path)], 
          text: '物资管理系统数据备份 ($dateStr)',
          subject: fileName
        );
        
        if (result.status == ShareResultStatus.success) {
           // 分享成功（部分系统可能不返回准确状态）
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("导出失败: $e")));
      }
    }
  }

  // --- 实现导入逻辑 ---
  Future<void> _importDataFile(BuildContext context, DataModel model) async {
    try {
      // 1. 调起文件选择器
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'], // 允许 .json 或 .txt
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // 2. 读取文件内容
        final jsonStr = await file.readAsString();
        
        // 3. 确认对话框
        if (context.mounted) {
           showDialog(context: context, builder: (c) => AlertDialog(
             title: const Text("确认恢复"),
             content: const Text("导入数据将覆盖或合并现有数据，是否继续？\n(建议先备份当前数据)"),
             actions: [
               TextButton(onPressed: () => Navigator.pop(c), child: const Text("取消")),
               ElevatedButton(
                 onPressed: () async {
                   Navigator.pop(c);
                   // 4. 执行导入
                   final err = await model.importData(jsonStr);
                   if (context.mounted) {
                     if (err == null) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("数据恢复成功！")));
                     } else {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("数据格式错误: $err")));
                     }
                   }
                 }, 
                 child: const Text("确定")
               ),
             ],
           ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("读取文件失败: $e")));
      }
    }
  }
}

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("操作记录")),
      body: ListView.builder(
        itemCount: model.records.length,
        itemBuilder: (c, i) {
          final r = model.records[i];
          final isIn = r.type == 'in';
          return ListTile(
            leading: Icon(isIn ? Icons.download : Icons.upload, color: isIn ? Colors.green : Colors.orange),
            title: Text(r.name),
            subtitle: Text("${r.date} | ${r.subType}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text((isIn ? "+" : "-") + r.count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.blue),
                  onPressed: () => _exportPdf(context, r),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, RecordItem r) async {
      try {
      final doc = pw.Document();
      pw.Font? font;
      try {
        final fontData = await rootBundle.load("assets/fonts/FangSong.ttf");
        font = pw.Font.ttf(fontData);
      } catch (e) {
        debugPrint("字体加载失败: $e");
      }
      final textStyle = font != null ? pw.TextStyle(font: font, fontSize: 14) : const pw.TextStyle(fontSize: 14);
      final titleStyle = font != null ? pw.TextStyle(font: font, fontSize: 24) : const pw.TextStyle(fontSize: 24);
      final labelStyle = font != null ? pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700) : const pw.TextStyle(fontSize: 12, color: PdfColors.grey700);

      doc.addPage(
        pw.Page(
          theme: font != null ? pw.ThemeData.withFont(base: font) : null,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, child: pw.Text(r.type == 'in' ? "物资入库单" : "物资出库单", style: titleStyle)),
                pw.SizedBox(height: 20),
                pw.Text("单号 ID: ${r.id}", style: textStyle),
                pw.Text("日期 Date: ${r.date}", style: textStyle),
                pw.Divider(),
                pw.SizedBox(height: 10),
                _buildPdfRow("物资名称:", r.name, labelStyle, textStyle),
                pw.SizedBox(height: 5),
                _buildPdfRow("物资编码:", r.code, labelStyle, textStyle),
                pw.SizedBox(height: 5),
                _buildPdfRow("数量:", r.count.toString(), labelStyle, textStyle),
                pw.SizedBox(height: 20),
                _buildPdfRow("操作员:", r.operator, labelStyle, textStyle),
                _buildPdfRow(r.type == 'in' ? "供应商/归还人:" : "领用部门:", r.target, labelStyle, textStyle),
                if(r.receiver.isNotEmpty) _buildPdfRow("经手/领用人:", r.receiver, labelStyle, textStyle),
                pw.SizedBox(height: 50),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.Text("签字确认: __________________", style: textStyle),
              ]
            );
          },
        ),
      );
      await Printing.sharePdf(bytes: await doc.save(), filename: "${r.name}_${r.id}.pdf");
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF导出失败: $e")));
    }
  }
  pw.Widget _buildPdfRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: labelStyle), pw.Text(value, style: valueStyle)]);
  }
}
