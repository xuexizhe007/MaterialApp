import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
          
          // --- 需求2：数据迁移 ---
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("数据迁移 (更换手机时使用)", style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.purple),
            title: const Text("数据备份 (导出)"),
            subtitle: const Text("复制数据码到剪贴板"),
            onTap: () {
              final jsonStr = model.exportData();
              Clipboard.setData(ClipboardData(text: jsonStr));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("数据已复制到剪贴板，请发送到新手机")));
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.purple),
            title: const Text("数据恢复 (导入)"),
            onTap: () {
              final ctrl = TextEditingController();
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text("恢复数据"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("请粘贴旧手机生成的备份数据码：", style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 10),
                    TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder())),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
                  ElevatedButton(onPressed: () async {
                    if(ctrl.text.isEmpty) return;
                    final err = await model.importData(ctrl.text);
                    if(context.mounted) {
                      Navigator.pop(ctx);
                      if(err == null) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("数据恢复成功！")));
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("恢复失败: $err")));
                      }
                    }
                  }, child: const Text("确定导入")),
                ],
              ));
            },
          ),

          // --- 需求6：安全清空 ---
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
              // 使用 StatefulBuilder 来更新 Dialog 内部按钮状态
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
                        onChanged: (v) => setState((){}), // 刷新按钮状态
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text("取消")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      // 只有输入正确才启用按钮
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
}

// RecordsPage 代码与之前相同，但为了文件完整性，这里再次列出（省略部分重复代码以节省空间，逻辑不变）
class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);
    // 记录列表也应该分页，这里简单起见保持长列表，因为历史记录通常是流式查看
    // 如果需要分页，逻辑同 CatalogTab
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
