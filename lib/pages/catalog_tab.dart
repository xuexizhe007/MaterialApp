import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data_model.dart';
import 'scanner_page.dart'; // 确保此文件已创建

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  // 入库表单
  final _inCodeCtrl = TextEditingController();
  final _inCountCtrl = TextEditingController(text: "1");
  final _inSupplierCtrl = TextEditingController();
  String _inSubType = "进货";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("物资管理"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "物资目录"), Tab(text: "入库操作")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- 1. 目录列表页 ---
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "搜索物资..."),
                  onChanged: (v) => setState((){}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: model.materials.length,
                  itemBuilder: (ctx, i) {
                    final item = model.materials[i];
                    if (_searchCtrl.text.isNotEmpty && !item.name.contains(_searchCtrl.text)) return const SizedBox.shrink();
                    return ListTile(
                      leading: CircleAvatar(child: Text(item.name.isNotEmpty ? item.name[0] : "?")),
                      title: Text(item.name),
                      subtitle: Text("编码:${item.code} | 库存:${item.stock}"),
                      trailing: Text(item.category),
                      onTap: () {
                         // 点击列表项，自动填充到入库表单
                         _inCodeCtrl.text = item.code;
                         _tabController.animateTo(1); // 切换到入库Tab
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已选中，请填写入库数量")));
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // --- 2. 入库操作页 ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _inCodeCtrl, decoration: const InputDecoration(labelText: "物资编码"))),
                    const SizedBox(width: 10),
                    
                    // --- 真实扫码按钮 ---
                    ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text("扫码"),
                      onPressed: () async {
                        // 跳转到扫码页
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ScannerPage()),
                        );

                        if (result != null && result is String) {
                          setState(() {
                            _inCodeCtrl.text = result;
                          });
                          // 检查该码是否已存在
                          final item = model.findByCode(result);
                          if (item != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已识别: ${item.name}")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("新物资: $result，请录入信息")));
                          }
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: _inCountCtrl, decoration: const InputDecoration(labelText: "数量"), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: _inSubType,
                  decoration: const InputDecoration(labelText: "入库类型"),
                  items: const [DropdownMenuItem(value: "进货", child: Text("进货")), DropdownMenuItem(value: "归还", child: Text("归还"))],
                  onChanged: (v) => setState(() => _inSubType = v.toString()),
                ),
                const SizedBox(height: 10),
                TextField(controller: _inSupplierCtrl, decoration: const InputDecoration(labelText: "供应商/归还人")),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    onPressed: () {
                      if (_inCodeCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入或扫码获取编码")));
                        return;
                      }
                      // 如果编码不存在，询问是否直接新增
                      final item = model.findByCode(_inCodeCtrl.text);
                      if (item == null) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("编码不存在，请先点击右下角+号新增物资")));
                         return;
                      }
                      model.inbound(
                        _inCodeCtrl.text, 
                        int.tryParse(_inCountCtrl.text) ?? 1, 
                        _inSubType, 
                        _inSupplierCtrl.text, 
                        ""
                      );
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("入库成功")));
                      _inCountCtrl.text = "1"; // 重置数量
                    }, 
                    child: const Text("确认入库")
                  ),
                )
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0 ? FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context, model),
      ) : null,
    );
  }

  void _showAddDialog(BuildContext context, DataModel model) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    
    // 如果刚才扫了码但不存在，自动填入
    if (_inCodeCtrl.text.isNotEmpty) {
      codeCtrl.text = _inCodeCtrl.text;
    }

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("新增物资"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "条码/编码")),
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "名称")),
          const SizedBox(height: 10),
          TextField(controller: catCtrl, decoration: const InputDecoration(labelText: "分类")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
        ElevatedButton(onPressed: () {
          if(codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
          final err = model.addMaterial(codeCtrl.text, nameCtrl.text, catCtrl.text, "");
          if (err != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          } else {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("新增成功")));
          }
        }, child: const Text("保存")),
      ],
    ));
  }
}
