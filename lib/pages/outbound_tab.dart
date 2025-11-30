import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data_model.dart';

class OutboundTab extends StatefulWidget {
  const OutboundTab({super.key});

  @override
  State<OutboundTab> createState() => _OutboundTabState();
}

class _OutboundTabState extends State<OutboundTab> {
  final _codeCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: "1");
  final _deptCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  String _subType = "领用";
  String? _itemNameDisplay;
  int _currentStock = 0;

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
                        Expanded(child: TextField(
                          controller: _codeCtrl, 
                          decoration: const InputDecoration(labelText: "物资编码", fillColor: Colors.white),
                          onChanged: (val) {
                            final item = model.findByCode(val);
                            setState(() {
                              if(item != null) {
                                _itemNameDisplay = item.name;
                                _currentStock = item.stock;
                              } else {
                                _itemNameDisplay = null;
                                _currentStock = 0;
                              }
                            });
                          },
                        )),
                        IconButton(
                          icon: const Icon(Icons.list),
                          onPressed: () {
                            // 简易选择器
                            showModalBottomSheet(context: context, builder: (ctx) => ListView.builder(
                              itemCount: model.materials.length,
                              itemBuilder: (c, i) {
                                final item = model.materials[i];
                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Text("剩余: ${item.stock}"),
                                  onTap: () {
                                    _codeCtrl.text = item.code;
                                    setState(() {
                                      _itemNameDisplay = item.name;
                                      _currentStock = item.stock;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ));
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_itemNameDisplay != null) 
                      Text("当前选择: $_itemNameDisplay (库存: $_currentStock)", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
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
                     setState(() { _currentStock -= (int.tryParse(_countCtrl.text) ?? 0); }); // 简单更新显示
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
