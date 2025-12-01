import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data_model.dart';
import 'scanner_page.dart';
// 引用 CatalogTab 中的选择器
import 'catalog_tab.dart' show showSearchableSelectionSheet;

class OutboundTab extends StatefulWidget {
  const OutboundTab({super.key});

  @override
  State<OutboundTab> createState() => _OutboundTabState();
}

class _OutboundTabState extends State<OutboundTab> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: "1");
  final _deptCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  String _subType = "领用";
  int _currentStock = 0;
  
  // 需求1：防抖锁
  bool _isSubmitting = false;

  void _selectItem(DataModel model, String code) {
    final item = model.findByCode(code);
    if (item != null) {
      setState(() {
        _codeCtrl.text = item.code;
        _nameCtrl.text = item.name;
        _currentStock = item.stock;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("物资出库")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl, 
                            decoration: const InputDecoration(labelText: "物资编码", fillColor: Colors.white),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton(
                          icon: const Icon(Icons.list_alt, color: Colors.blue),
                          // --- 需求4 & 5：调用高级选择弹窗 ---
                          onPressed: () => showSearchableSelectionSheet(context, model, (code) {
                            _selectItem(model, code);
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.orange),
                          onPressed: () async {
                             final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
                             if (result != null) {
                               final item = model.findByCode(result);
                               if (item != null) {
                                 _selectItem(model, result);
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已识别: ${item.name}")));
                               } else {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("未找到该编码的物资")));
                               }
                             }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: "物品名称", fillColor: Colors.white, filled: true),
                      readOnly: true,
                    ),
                    if (_nameCtrl.text.isNotEmpty) 
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("当前库存: $_currentStock", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("出库详情", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: _countCtrl, decoration: const InputDecoration(labelText: "出库数量"), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
             DropdownButtonFormField(
              value: _subType,
              decoration: const InputDecoration(labelText: "业务类型"),
              items: const [DropdownMenuItem(value: "领用", child: Text("领用")), DropdownMenuItem(value: "借用", child: Text("借用"))],
              onChanged: (v) => setState(() => _subType = v.toString()),
            ),
            const SizedBox(height: 10),
            TextField(controller: _deptCtrl, decoration: const InputDecoration(labelText: "领用部门")),
            const SizedBox(height: 10),
            TextField(controller: _receiverCtrl, decoration: const InputDecoration(labelText: "领用人姓名")),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                // --- 需求1：防抖逻辑 ---
                onPressed: _isSubmitting ? null : () async {
                   if (_codeCtrl.text.isEmpty || _receiverCtrl.text.isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请完整填写信息")));
                     return;
                   }
                   
                   // 锁定
                   setState(() => _isSubmitting = true);
                   await Future.delayed(const Duration(seconds: 1));

                   final err = model.outbound(
                     _codeCtrl.text, 
                     int.tryParse(_countCtrl.text) ?? 1, 
                     _subType, 
                     _deptCtrl.text, 
                     _receiverCtrl.text
                   );

                   if (err != null) {
                     showDialog(context: context, builder: (_) => AlertDialog(title: const Text("错误"), content: Text(err)));
                     setState(() => _isSubmitting = false); // 解锁
                   } else {
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("出库成功")));
                       setState(() { 
                         _codeCtrl.clear();
                         _nameCtrl.clear();
                         _currentStock = 0;
                         _countCtrl.text = "1";
                         _isSubmitting = false; // 解锁
                       });
                     }
                   }
                },
                child: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("确认出库", style: TextStyle(fontSize: 18)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
