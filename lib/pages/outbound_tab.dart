import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data_model.dart';
import 'scanner_page.dart';

class OutboundTab extends StatefulWidget {
  const OutboundTab({super.key});

  @override
  State<OutboundTab> createState() => _OutboundTabState();
}

class _OutboundTabState extends State<OutboundTab> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // 新增：名称只读
  final _countCtrl = TextEditingController(text: "1");
  final _deptCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  String _subType = "领用";
  int _currentStock = 0;

  // 统一处理选中逻辑
  void _selectItem(DataModel model, MaterialItem item) {
    setState(() {
      _codeCtrl.text = item.code;
      _nameCtrl.text = item.name;
      _currentStock = item.stock;
    });
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
                    // 编码选择行
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl, 
                            decoration: const InputDecoration(labelText: "物资编码", fillColor: Colors.white),
                            readOnly: true, // 只读
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton(
                          icon: const Icon(Icons.list_alt, color: Colors.blue),
                          tooltip: "选择列表",
                          onPressed: () {
                            // 丰富化的下拉列表
                            showModalBottomSheet(context: context, builder: (ctx) => Column(
                              children: [
                                const Padding(padding: EdgeInsets.all(16), child: Text("选择出库物资", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: model.materials.length,
                                    itemBuilder: (c, i) {
                                      final item = model.materials[i];
                                      return ListTile(
                                        title: Text(item.name),
                                        subtitle: Text("编码:${item.code} | 备注:${item.remark}"),
                                        trailing: Text("存:${item.stock}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        onTap: () {
                                          _selectItem(model, item);
                                          Navigator.pop(ctx);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.orange),
                          tooltip: "扫码出库",
                          onPressed: () async {
                             final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
                             if (result != null) {
                               final item = model.findByCode(result);
                               if (item != null) {
                                 _selectItem(model, item);
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
                    
                    // 物品名称 (只读联动)
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
                onPressed: () {
                   if (_codeCtrl.text.isEmpty || _receiverCtrl.text.isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请完整填写信息")));
                     return;
                   }
                   final err = model.outbound(
                     _codeCtrl.text, 
                     int.tryParse(_countCtrl.text) ?? 1, 
                     _subType, 
                     _deptCtrl.text, 
                     _receiverCtrl.text
                   );

                   if (err != null) {
                     showDialog(context: context, builder: (_) => AlertDialog(title: const Text("错误"), content: Text(err)));
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("出库成功")));
                     _countCtrl.text = "1";
                     _deptCtrl.clear();
                     _receiverCtrl.clear();
                     // 更新库存显示
                     setState(() { _currentStock -= (int.tryParse(_countCtrl.text) ?? 0); });
                   }
                },
                child: const Text("确认出库", style: TextStyle(fontSize: 18)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
