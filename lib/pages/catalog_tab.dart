import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data_model.dart';
import 'scanner_page.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  // 入库表单控制器
  final _inCodeCtrl = TextEditingController();
  final _inNameCtrl = TextEditingController();
  final _inCountCtrl = TextEditingController(text: "1");
  final _inSupplierCtrl = TextEditingController();
  String _inSubType = "进货";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 选中物资（仅用于入库页的手动选择）
  void _onItemSelectedForInbound(DataModel model, String code) {
    final item = model.findByCode(code);
    if (item != null) {
      setState(() {
        _inCodeCtrl.text = item.code;
        _inNameCtrl.text = item.name;
      });
    }
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
          // --- 1. 物资目录 (含搜索与历史跳转) ---
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), 
                    hintText: "搜索名称 / 编码 / 备注",
                    filled: true,
                    fillColor: Colors.white
                  ),
                  onChanged: (v) => setState((){}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: model.materials.length,
                  itemBuilder: (ctx, i) {
                    final item = model.materials[i];
                    final query = _searchCtrl.text.toLowerCase();
                    
                    // --- 需求1：多维搜索 (名称、编码、备注) ---
                    bool match = item.name.toLowerCase().contains(query) || 
                                 item.code.toLowerCase().contains(query) ||
                                 item.remark.toLowerCase().contains(query);
                                 
                    if (_searchCtrl.text.isNotEmpty && !match) {
                      return const SizedBox.shrink();
                    }
                    
                    final isLowStock = item.stock <= 1;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock ? Colors.red[100] : Colors.blue[100],
                          child: Text(item.name.isNotEmpty ? item.name[0] : "?", style: TextStyle(color: isLowStock ? Colors.red : Colors.blue)),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("编码: ${item.code}"),
                            if(item.remark.isNotEmpty) Text("备注: ${item.remark}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("${item.stock}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLowStock ? Colors.red : Colors.black)),
                            const Icon(Icons.chevron_right, color: Colors.grey)
                          ],
                        ),
                        // --- 需求2：点击跳转出入库记录详情页 ---
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (c) => MaterialDetailPage(item: item)));
                        },
                      ),
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
                    Expanded(
                      child: TextField(
                        controller: _inCodeCtrl, 
                        decoration: const InputDecoration(labelText: "物资编码", hintText: "请扫码或选择"),
                        readOnly: true, 
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.list_alt, color: Colors.blue),
                      onPressed: () => _showItemSelector(context, model),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.green),
                      onPressed: () async {
                        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
                        if (result != null && result is String) {
                          final item = model.findByCode(result);
                          if (item != null) {
                            _onItemSelectedForInbound(model, result);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已识别: ${item.name}")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("未录入的编码，请手动新增")));
                            setState(() {
                              _inCodeCtrl.text = result;
                              _inNameCtrl.text = "未录入物资";
                            });
                          }
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _inNameCtrl,
                  decoration: const InputDecoration(labelText: "物品名称", filled: true),
                  readOnly: true,
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先扫码或选择物资")));
                        return;
                      }
                      final item = model.findByCode(_inCodeCtrl.text);
                      if (item == null) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("物资不存在，请先新增")));
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
                      
                      // --- 需求3：清空表单，避免重复提交 ---
                      setState(() {
                        _inCodeCtrl.clear();
                        _inNameCtrl.clear();
                        _inCountCtrl.text = "1";
                        // 供应商可选清空，这里不清空方便连续录入
                      });
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

  void _showItemSelector(BuildContext context, DataModel model) {
    showModalBottomSheet(context: context, builder: (ctx) {
      return Column(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text("选择物资", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          Expanded(
            child: ListView.builder(
              itemCount: model.materials.length,
              itemBuilder: (c, i) {
                final item = model.materials[i];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text("编码:${item.code}"),
                  trailing: Text("存:${item.stock}"),
                  onTap: () {
                    _onItemSelectedForInbound(model, item.code);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }

  void _showAddDialog(BuildContext context, DataModel model) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final remarkCtrl = TextEditingController();
    
    if (_inCodeCtrl.text.isNotEmpty && model.findByCode(_inCodeCtrl.text) == null) {
      codeCtrl.text = _inCodeCtrl.text;
    }

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("新增物资"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "条码/编码"))),
              IconButton(
                icon: const Icon(Icons.qr_code),
                onPressed: () async {
                   final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
                   if(result != null) codeCtrl.text = result;
                },
              )
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "名称")),
          const SizedBox(height: 10),
          TextField(controller: remarkCtrl, decoration: const InputDecoration(labelText: "备注")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
        ElevatedButton(onPressed: () {
          if(codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
          final err = model.addMaterial(codeCtrl.text, nameCtrl.text, "", remarkCtrl.text);
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

// --- 新增：物资详情与历史记录页 ---
class MaterialDetailPage extends StatelessWidget {
  final MaterialItem item;
  const MaterialDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);
    // 筛选出该物资的记录
    final history = model.records.where((r) => r.code == item.code).toList();

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text("当前库存", style: TextStyle(color: Colors.blue[800])),
                Text("${item.stock}", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                const SizedBox(height: 10),
                Text("编码: ${item.code}"),
                Text("备注: ${item.remark}"),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Align(alignment: Alignment.centerLeft, child: Text("出入库明细", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          ),
          Expanded(
            child: history.isEmpty 
              ? const Center(child: Text("暂无记录"))
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (ctx, i) {
                    final r = history[i];
                    final isIn = r.type == 'in';
                    return ListTile(
                      leading: Icon(isIn ? Icons.download : Icons.upload, color: isIn ? Colors.green : Colors.orange),
                      title: Text(isIn ? "入库: ${r.subType}" : "出库: ${r.subType}"),
                      // --- 需求2：显示领用人姓名 ---
                      subtitle: Text("${r.date}\n${isIn ? '供应商: ' + r.target : '领用人: ' + r.receiver + ' (' + r.target + ')'}"),
                      isThreeLine: true,
                      trailing: Text(
                        (isIn ? "+" : "-") + r.count.toString(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.red),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
