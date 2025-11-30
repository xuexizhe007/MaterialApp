import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // 引入资源加载器
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
                  onPressed: () => _printPdf(context, r), // 传入 context 用于报错提示
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // 生成 PDF (已修改：支持中文字体)
  Future<void> _printPdf(BuildContext context, RecordItem r) async {
    try {
      final doc = pw.Document();

      // 1. 加载中文字体文件
      final fontData = await rootBundle.load("assets/fonts/FangSong.ttf");
      final ttf = pw.Font.ttf(fontData);

      // 2. 定义使用该字体的样式
      final titleStyle = pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold);
      final contentStyle = pw.TextStyle(font: ttf, fontSize: 14);
      final labelStyle = pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold);

      // 3. 构建页面
      doc.addPage(
        pw.Page(
          // 设置默认字体，防止某些遗漏的地方乱码
          theme: pw.ThemeData.withFont(base: ttf),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(r.type == 'in' ? "物资入库单" : "物资出库单", style: titleStyle)
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                
                _buildRow("单据编号", r.id, labelStyle, contentStyle),
                _buildRow("日期时间", r.date, labelStyle, contentStyle),
                _buildRow("物资名称", r.name, labelStyle, contentStyle),
                _buildRow("物资编码", r.code, labelStyle, contentStyle),
                _buildRow("数量", "${r.count}", labelStyle, contentStyle),
                _buildRow("业务类型", r.subType, labelStyle, contentStyle),
                
                if (r.type == 'in')
                  _buildRow("供应商/来源", r.target, labelStyle, contentStyle),
                if (r.type == 'out') ...[
                  _buildRow("领用/借用部门", r.target, labelStyle, contentStyle),
                  _buildRow("领用人姓名", r.receiver, labelStyle, contentStyle),
                ],
                
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                  children: [
                    pw.Text("经办人：${r.operator}", style: contentStyle),
                    pw.Text("签字确认：______________", style: contentStyle),
                  ]
                ),
              ]
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
      
    } catch (e) {
      // 如果字体加载失败，会在屏幕下方提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("生成失败，请检查字体文件: $e"))
      );
    }
  }

  // 辅助方法：生成 PDF 行
  pw.Widget _buildRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("$label：", style: labelStyle),
          pw.Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
