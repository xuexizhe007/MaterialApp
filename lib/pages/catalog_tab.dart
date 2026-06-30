import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data_model.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  final _searchCtrl = TextEditingController();
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _stockAscending = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (_currentPage != 0) setState(() => _currentPage = 0);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);

    final filteredMaterials = model.materials.where((item) {
      final q = _searchCtrl.text.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.remark.toLowerCase().contains(q) ||
          item.code.toLowerCase().contains(q);
    }).toList();

    filteredMaterials.sort((a, b) {
      final stockCompare = _stockAscending ? a.stock.compareTo(b.stock) : b.stock.compareTo(a.stock);
      if (stockCompare != 0) return stockCompare;
      return a.name.compareTo(b.name);
    });

    final totalItems = filteredMaterials.length;
    final totalPages = (totalItems / _pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;
    if (totalItems == 0) _currentPage = 0;

    final pagedMaterials = filteredMaterials.skip(_currentPage * _pageSize).take(_pageSize).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜索名称 / 备注 / 旧编码',
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _currentPage = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: _stockAscending ? '库存升序' : '库存降序',
                      icon: Icon(_stockAscending ? Icons.arrow_upward : Icons.arrow_downward),
                      onPressed: () => setState(() {
                        _stockAscending = !_stockAscending;
                        _currentPage = 0;
                      }),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: pagedMaterials.isEmpty
                  ? const Center(child: Text('暂无物资'))
                  : ListView.builder(
                      itemCount: pagedMaterials.length + (totalPages > 1 ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == pagedMaterials.length) {
                          return _PaginationBar(
                            currentPage: _currentPage,
                            totalPages: totalPages,
                            onPrev: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                            onNext: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                          );
                        }

                        final item = pagedMaterials[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                item.name.isNotEmpty ? item.name[0] : '?',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: item.remark.isNotEmpty
                                ? Text('备注: ${item.remark}', style: const TextStyle(fontSize: 12, color: Colors.grey))
                                : const Text('无备注', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('库存 ', style: TextStyle(color: Colors.grey)),
                                Text(
                                  '${item.stock}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (c) => MaterialDetailPage(itemId: item.id)));
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新增物资',
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context, model),
      ),
    );
  }

  void _showAddDialog(BuildContext context, DataModel model) {
    final nameCtrl = TextEditingController();
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增物资'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 10),
            TextField(controller: remarkCtrl, decoration: const InputDecoration(labelText: '备注')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final err = model.addMaterial(nameCtrl.text, '', remarkCtrl.text);
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新增成功')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

void showSearchableSelectionSheet(BuildContext context, DataModel model, ValueChanged<MaterialItem> onSelected) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SearchableListSheet(model: model, onSelected: onSelected),
  );
}

class _SearchableListSheet extends StatefulWidget {
  final DataModel model;
  final ValueChanged<MaterialItem> onSelected;
  const _SearchableListSheet({required this.model, required this.onSelected});

  @override
  State<_SearchableListSheet> createState() => _SearchableListSheetState();
}

class _SearchableListSheetState extends State<_SearchableListSheet> {
  final _searchCtrl = TextEditingController();
  int _currentPage = 0;
  final int _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.model.materials.where((item) {
      final q = _searchCtrl.text.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.remark.toLowerCase().contains(q) ||
          item.code.toLowerCase().contains(q);
    }).toList();

    filtered.sort((a, b) {
      final nameCompare = a.name.compareTo(b.name);
      if (nameCompare != 0) return nameCompare;
      return b.stock.compareTo(a.stock);
    });

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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('选择物资', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索名称 / 备注 / 旧编码'),
              onChanged: (v) => setState(() => _currentPage = 0),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: paged.isEmpty
                ? const Center(child: Text('暂无匹配物资'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: paged.length + (totalPages > 1 ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i == paged.length) {
                        return _PaginationBar(
                          currentPage: _currentPage,
                          totalPages: totalPages,
                          onPrev: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                          onNext: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        );
                      }
                      final item = paged[i];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.remark.isEmpty ? '无备注' : '备注: ${item.remark}'),
                        trailing: Text('存: ${item.stock}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          widget.onSelected(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MaterialDetailPage extends StatefulWidget {
  final String itemId;
  const MaterialDetailPage({super.key, required this.itemId});

  @override
  State<MaterialDetailPage> createState() => _MaterialDetailPageState();
}

class _MaterialDetailPageState extends State<MaterialDetailPage> {
  int _currentPage = 0;
  final int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    return Consumer<DataModel>(
      builder: (context, model, child) {
        final currentItem = model.findById(widget.itemId);
        if (currentItem == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('物资已删除')));
        }

        final allHistory = model.records.where((r) => r.materialId == currentItem.id).toList();
        final totalItems = allHistory.length;
        final totalPages = (totalItems / _pageSize).ceil();
        if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;
        if (totalItems == 0) _currentPage = 0;
        final pagedHistory = allHistory.skip(_currentPage * _pageSize).take(_pageSize).toList();

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.blue[50],
                  child: Column(
                    children: [
                      Text(currentItem.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('当前库存', style: TextStyle(color: Colors.blue[800])),
                      Text('${currentItem.stock}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      const SizedBox(height: 10),
                      Text(currentItem.remark.isEmpty ? '无备注' : '备注: ${currentItem.remark}'),
                      TextButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('修改信息'),
                        onPressed: () => _showEditDialog(context, model, currentItem),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('出入库明细', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ),
                Expanded(
                  child: pagedHistory.isEmpty
                      ? const Center(child: Text('暂无记录'))
                      : ListView.builder(
                          itemCount: pagedHistory.length + (totalPages > 1 ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == pagedHistory.length) {
                              return _PaginationBar(
                                currentPage: _currentPage,
                                totalPages: totalPages,
                                onPrev: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                onNext: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                              );
                            }
                            final r = pagedHistory[i];
                            final isIn = r.type == 'in';
                            final detail = isIn ? '来源: ${r.target}' : '领用人: ${r.receiver} (${r.target})';
                            return ListTile(
                              leading: Icon(isIn ? Icons.download : Icons.upload, color: isIn ? Colors.green : Colors.orange),
                              title: Text(isIn ? '入库: ${r.subType}' : '出库: ${r.subType}'),
                              subtitle: Text('${r.date}\n$detail'),
                              isThreeLine: true,
                              trailing: Text(
                                '${isIn ? '+' : '-'}${r.count}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.red),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, DataModel model, MaterialItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final remarkCtrl = TextEditingController(text: item.remark);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改物资信息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
              const SizedBox(height: 15),
              TextField(controller: remarkCtrl, decoration: const InputDecoration(labelText: '备注')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final err = model.updateMaterial(item.id, nameCtrl.text, remarkCtrl.text);
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改成功')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text('第 ${currentPage + 1} / $totalPages 页'),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}
