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
    final lowStock = model.materials.where((e) => e.stock <= model.warnThreshold).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("库存与设置")),
      body: ListView(
        children: [
          // 用户信息卡片
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
          
          // 库存预警
          if (lowStock.isNotEmpty)
            ExpansionTile(
              title: const Text("库存预警", style: TextStyle(color: Colors.red)),
              leading: const Icon(Icons.warning, color: Colors.red),
              initiallyExpanded: true,
              children: lowStock.map((e) => ListTile(
                title: Text(e.name),
                trailing: Text("${e.stock}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text("库存不足"),
              )).toList(),
            ),

          const Divider(),
          
          // 操作记录
          ListTile(
            title: const Text("出入库记录 (点击导出PDF)"),
            leading: const Icon(Icons.history),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const RecordsPage()));
            },
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          
          // 设置功能
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
                  icon: const Icon(Icons.print, color: Colors.blue),
                  onPressed: () => _printPdf(context, r),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 修复后的 PDF 生成逻辑 ---
  Future<void> _printPdf(BuildContext context, RecordItem r) async {
    try {
      final doc = pw.Document();
      pw.Font? font;

      // 1. 尝试加载中文字体
      try {
        final fontData = await rootBundle.load("assets/fonts/FangSong.ttf");
        font = pw.Font.ttf(fontData);
      } catch (e) {
        debugPrint("字体加载失败: $e");
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("警告：字体文件未找到，PDF中文将乱码。请确保 assets/fonts/FangSong.ttf 存在"),
             backgroundColor: Colors.orange,
           ));
        }
      }

      doc.addPage(
        pw.Page(
          // 2. 安全应用字体
          theme: font != null ? pw.ThemeData.withFont(base: font) : null,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, child: pw.Text(r.type == 'in' ? "物资入库单" : "物资出库单", style: const pw.TextStyle(fontSize: 24))),
                pw.SizedBox(height: 20),
                pw.Text("单号 ID: ${r.id}"),
                pw.Text("日期 Date: ${r.date}"),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("物资名称:"),
                  pw.Text(r.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ]),
                pw.SizedBox(height: 5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("编码 (Code):"),
                  pw.Text(r.code),
                ]),
                pw.SizedBox(height: 5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("数量 (Count):"),
                  pw.Text(r.count.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
                pw.SizedBox(height: 20),
                pw.Text("操作员 (Operator): ${r.operator}"),
                pw.Text(r.type == 'in' ? "供应商/归还人: ${r.target}" : "领用部门: ${r.target}"),
                if(r.receiver.isNotEmpty)
                  pw.Text("经手/领用人: ${r.receiver}"),
                  
                pw.SizedBox(height: 50),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.Text("签字确认: __________________", style: const pw.TextStyle(fontSize: 14)),
              ]
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: "${r.name}_单据.pdf"
      );
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF生成严重错误: $e")));
      }
    }
  }
}
