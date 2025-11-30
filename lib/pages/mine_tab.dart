import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("数据管理", style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("清空所有数据"),
            onTap: () {
              showDialog(context: context, builder: (c) => AlertDialog(
                title: const Text("警告"),
                content: const Text("确定要删除所有数据吗？此操作不可恢复。"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("取消")),
                  TextButton(onPressed: () {
                    model.clearData();
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("数据已重置")));
                  }, child: const Text("确定删除", style: TextStyle(color: Colors.red))),
                ],
              ));
            },
          ),
        ],
      ),
    );
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
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("字体缺失，中文可能乱码"),
             backgroundColor: Colors.orange,
           ));
        }
      }

      // --- 需求4：修复乱码的关键逻辑 ---
      // 如果字体加载成功，创建一个强制使用该字体的 textStyle
      // 注意：我们移除了 fontWeight: bold，因为如果 ttf 文件本身不是粗体，
      // PDF库可能会回退到默认字体导致中文乱码。
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
                
                // 使用 Row 布局键值对
                _buildPdfRow("物资名称:", r.name, labelStyle, textStyle),
                pw.SizedBox(height: 5),
                _buildPdfRow("物资编码:", r.code, labelStyle, textStyle),
                pw.SizedBox(height: 5),
                _buildPdfRow("数量:", r.count.toString(), labelStyle, textStyle),
                pw.SizedBox(height: 20),
                
                _buildPdfRow("操作员:", r.operator, labelStyle, textStyle),
                _buildPdfRow(
                  r.type == 'in' ? "供应商/归还人:" : "领用部门:", 
                  r.target, 
                  labelStyle, 
                  textStyle
                ),
                if(r.receiver.isNotEmpty)
                  _buildPdfRow("经手/领用人:", r.receiver, labelStyle, textStyle),
                  
                pw.SizedBox(height: 50),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.Text("签字确认: __________________", style: textStyle),
              ]
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: "${r.name}_${r.id}.pdf"
      );
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF导出失败: $e")));
      }
    }
  }
  
  // 辅助方法构建 PDF 行
  pw.Widget _buildPdfRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
      children: [
        pw.Text(label, style: labelStyle),
        pw.Text(value, style: valueStyle), // 确保这里应用了中文字体
      ]
    );
  }
}
