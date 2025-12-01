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
  
  // 目录页状态
  final _searchCtrl = TextEditingController();
  int _currentPage = 0;
  final int _pageSize = 10;

  // 入库表单
  final _inCodeCtrl = TextEditingController();
  final _inNameCtrl = TextEditingController();
  final _inCountCtrl = TextEditingController(text: "1");
  final _inSupplierCtrl = TextEditingController();
  String _inSubType = "进货";
  
  // 防抖锁
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _searchCtrl.addListener(() {
       if(_currentPage != 0) setState(() => _currentPage = 0);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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

    // --- 目录页列表逻辑 ---
    // 1. 筛选
    final filteredMaterials = model.materials.where((item) {
      final q = _searchCtrl.text.toLowerCase();
      return item.name.toLowerCase().contains(q) || 
             item.code.toLowerCase().contains(q) ||
             item.remark.toLowerCase().contains(q);
    }).toList();
    
    // --- 需求：库存降序排序 ---
    filteredMaterials.sort((a, b) => b.stock.compareTo(a.stock));

    // 2. 分页计算
    final totalItems = filteredMaterials.length;
    final totalPages = (totalItems / _pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;
    if (totalItems == 0) _currentPage = 0;

    // 3. 截取当前页数据
    final pagedMaterials = filteredMaterials.skip(_currentPage * _pageSize).take(_pageSize).toList();

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
          // --- 1. 物资目录 ---
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), 
                    hintText: "搜索名称 / 编码 / 备注",
                    filled: true, fillColor: Colors.white
                  ),
                  onChanged: (v) => setState((){}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: pagedMaterials.length,
                  itemBuilder: (ctx, i) {
                    final item = pagedMaterials[i];
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
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (c) => MaterialDetailPage(item: item)));
                        },
                      ),
                    );
                  },
                ),
              ),
              // 分页控制条
              if (totalPages > 1)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.grey[200],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                      ),
                      Text("第 ${_currentPage + 1} / $totalPages 页 (共 $totalItems 条)"),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                      ),
                    ],
                  ),
                )
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
                      onPressed: () => showSearchableSelectionSheet(context, model, (code) {
                        _onItemSelectedForInbound(model, code);
                      }),
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
                    onPressed: _isSubmitting ? null : () async {
                      if (_inCodeCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先扫码或选择物资")));
                        return;
                      }
                      setState(() => _isSubmitting = true);
                      await Future.delayed(const Duration(seconds: 1));

                      final item = model.findByCode(_inCodeCtrl.text);
                      if (item == null) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("物资不存在，请先新增")));
                         setState(() => _isSubmitting = false);
                         return;
                      }
                      model.inbound(
                        _inCodeCtrl.text, 
                        int.tryParse(_inCountCtrl.text) ?? 1, 
                        _inSubType, 
                        _inSupplierCtrl.text, 
                        ""
                      );
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("入库成功")));
                        setState(() {
                          _inCodeCtrl.clear();
                          _inNameCtrl.clear();
                          _inCountCtrl.text = "1";
                          _isSubmitting = false;
                        });
                      }
                    }, 
                    child: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("确认入库"),
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

// --- 选择器逻辑 ---
void showSearchableSelectionSheet(BuildContext context, DataModel model, Function(String) onSelected) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, 
    useSafeArea: true,
    builder: (ctx) => _SearchableListSheet(model: model, onSelected: onSelected),
  );
}

class _SearchableListSheet extends StatefulWidget {
  final DataModel model;
  final Function(String) onSelected;
  const _SearchableListSheet({required this.model, required this.onSelected});

  @override
  State<_SearchableListSheet> createState() => _SearchableListSheetState();
}

class _SearchableListSheetState extends State<_SearchableListSheet> {
  final _searchCtrl = TextEditingController();
  int _currentPage = 0;
  final int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.model.materials.where((item) {
      final q = _searchCtrl.text.toLowerCase();
      return item.name.toLowerCase().contains(q) || 
             item.code.toLowerCase().contains(q) ||
             item.remark.toLowerCase().contains(q);
    }).toList();
    
    // 弹窗中也按库存降序
    filtered.sort((a, b) => b.stock.compareTo(a.stock));

    final totalItems = filtered.length;
    final totalPages = (totalItems / _pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;
    if (totalItems == 0) _currentPage = 0;
    final paged = filtered.skip(_currentPage * _pageSize).take(_pageSize).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text("选择物资", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "搜索 名称/编码/备注"),
              onChanged: (v) => setState(() => _currentPage = 0),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: paged.length,
              itemBuilder: (c, i) {
                final item = paged[i];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text("编码:${item.code} | 备注:${item.remark}"),
                  trailing: Text("存:${item.stock}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    widget.onSelected(item.code);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  ),
                  Text("${_currentPage + 1} / $totalPages 页"),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}

// --- 详情页：增加编辑功能 ---
class MaterialDetailPage extends StatelessWidget {
  final MaterialItem item;
  const MaterialDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // 使用 Consumer 监听 Model 变化，确保修改后页面刷新
    return Consumer<DataModel>(
      builder: (context, model, child) {
        // 重新获取 item 引用，防止失效
        final currentItem = model.findByCode(item.code) ?? item;
        final history = model.records.where((r) => r.code == currentItem.code).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(currentItem.name),
            actions: [
              // --- 需求：编辑按钮 ---
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: "修改信息",
                onPressed: () => _showEditDialog(context, model, currentItem),
              )
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.blue[50],
                child: Column(
                  children: [
                    Text("当前库存", style: TextStyle(color: Colors.blue[800])),
                    Text("${currentItem.stock}", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                    const SizedBox(height: 10),
                    Text("编码: ${currentItem.code}"),
                    Text("备注: ${currentItem.remark}"),
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
                          subtitle: Text("${r.date}\n${isIn ? '供应商: ' + r.target : '领用人: ' + r.receiver + ' (' + r.target + ')'}"),
                          isThreeLine: true,
                          trailing: Text((isIn ? "+" : "-") + r.count.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.red)),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      }
    );
  }

  // --- 需求：编辑对话框 ---
  void _showEditDialog(BuildContext context, DataModel model, MaterialItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final remarkCtrl = TextEditingController(text: item.remark);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("修改物资信息"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 编码只读
            TextField(
              controller: TextEditingController(text: item.code),
              decoration: const InputDecoration(labelText: "编码 (不可修改)", filled: true, fillColor: Colors.black12),
              readOnly: true,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "名称"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: remarkCtrl,
              decoration: const InputDecoration(labelText: "备注"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("名称不能为空")));
                 return;
              }
              // 调用 Model 更新方法
              model.updateMaterial(item.code, nameCtrl.text, remarkCtrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("修改成功")));
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }
}
