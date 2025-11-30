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

  // 入库表单
  final _inCodeCtrl = TextEditingController();
  final _inNameCtrl = TextEditingController(); // 新增：物品名称（只读）
  final _inCountCtrl = TextEditingController(text: "1");
  final _inSupplierCtrl = TextEditingController();
  String _inSubType = "进货";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 监听 Tab 切换，解决 FAB 消失问题
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 统一处理选中物品逻辑
  void _onItemSelected(DataModel model, String code) {
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
                    
                    // 红色预警逻辑
                    final isLowStock = item.stock <= 1;
                    
                    return ListTile(
                      leading: CircleAvatar(child: Text(item.name.isNotEmpty ? item.name[0] : "?")),
                      title: Text(item.name),
                      subtitle: Text("编码:${item.code} | 备注:${item.remark}"), // 显示备注
                      trailing: Text(
                        "${item.stock}", 
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: isLowStock ? Colors.red : Colors.black // 红色变色
                        )
                      ),
                      onTap: () {
                         _onItemSelected(model, item.code);
                         _tabController.animateTo(1); 
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
                // 编码选择行
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inCodeCtrl, 
                        decoration: const InputDecoration(labelText: "物资编码", hintText: "请扫码或选择"),
                        readOnly: true, // 禁止手动输入
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(Icons.list_alt, color: Colors.blue),
                      onPressed: () => _showItemSelector(context, model),
                      tooltip: "选择列表",
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.green),
                      onPressed: () async {
                        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
                        if (result != null && result is String) {
                          final item = model.findByCode(result);
                          if (item != null) {
                            _onItemSelected(model, result);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已识别: ${item.name}")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("未录入的编码: $result")));
                            // 对于新编码，允许填入，但提示需要新增
                            setState(() {
                              _inCodeCtrl.text = result;
                              _inNameCtrl.text = "未录入物资";
                            });
                          }
                        }
                      },
                      tooltip: "扫码",
                    )
                  ],
                ),
                const SizedBox(height: 10),
                
                // 物品名称行 (新增，只读)
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
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("该物资未在目录中，请先新增")));
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
                      _inCountCtrl.text = "1";
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

  // 下拉选择列表
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
                  subtitle: Text("编码:${item.code} | 备注:${item.remark}"),
                  trailing: Text("存:${item.stock}"),
                  onTap: () {
                    _onItemSelected(model, item.code);
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
    final remarkCtrl = TextEditingController(); // 改为备注
    
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
          TextField(controller: remarkCtrl, decoration: const InputDecoration(labelText: "备注")), // 分类改为备注
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
        ElevatedButton(onPressed: () {
          if(codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
          // 注意：DataModel addMaterial 第三个参数是 category，第四个是 remark。
          // 这里我们将 UI 的 "备注" 存入 remark，category 留空或存入 "通用"
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
