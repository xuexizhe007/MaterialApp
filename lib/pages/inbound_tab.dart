import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data_model.dart';
import 'catalog_tab.dart' show showSearchableSelectionSheet;

class InboundTab extends StatefulWidget {
  const InboundTab({super.key});

  @override
  State<InboundTab> createState() => _InboundTabState();
}

class _InboundLineController {
  String? materialId;
  int currentStock = 0;
  final nameCtrl = TextEditingController();
  final countCtrl = TextEditingController(text: '1');

  void dispose() {
    nameCtrl.dispose();
    countCtrl.dispose();
  }
}

class _InboundTabState extends State<InboundTab> {
  final List<_InboundLineController> _lines = [];
  final _supplierCtrl = TextEditingController();
  String _subType = '进货';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _lines.add(_InboundLineController());
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _selectItem(int index, MaterialItem item) {
    setState(() {
      final line = _lines[index];
      line.materialId = item.id;
      line.nameCtrl.text = item.name;
      line.currentStock = item.stock;
    });
  }

  void _addLine() {
    setState(() => _lines.insert(0, _InboundLineController()));
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _resetLines() {
    for (final line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..add(_InboundLineController());
    _supplierCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<DataModel>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            ..._lines.asMap().entries.map((entry) => _buildLineCard(model, entry.key, entry.value)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _subType,
              decoration: const InputDecoration(labelText: '入库类型'),
              items: const [
                DropdownMenuItem(value: '进货', child: Text('进货')),
                DropdownMenuItem(value: '归还', child: Text('归还')),
              ],
              onChanged: (v) => setState(() => _subType = v ?? '进货'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _supplierCtrl, decoration: const InputDecoration(labelText: '供应商/归还人')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: _isSubmitting ? null : () => _submitInbound(model),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('确认入库', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('入库物资', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        OutlinedButton.icon(
          onPressed: _addLine,
          icon: const Icon(Icons.add),
          label: const Text('新增一项'),
        ),
      ],
    );
  }

  Widget _buildLineCard(DataModel model, int index, _InboundLineController line) {
    return Card(
      color: Colors.green[50],
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('物资 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_lines.length > 1)
                  IconButton(
                    tooltip: '删除此项',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeLine(index),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.nameCtrl,
                    decoration: const InputDecoration(labelText: '物品名称', hintText: '请选择物资', fillColor: Colors.white),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 5),
                IconButton(
                  tooltip: '从列表选择',
                  icon: const Icon(Icons.list_alt, color: Colors.blue),
                  onPressed: () => showSearchableSelectionSheet(context, model, (item) => _selectItem(index, item)),
                ),
              ],
            ),
            if (line.materialId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('当前库存: ${line.currentStock}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: line.countCtrl,
              decoration: const InputDecoration(labelText: '入库数量'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitInbound(DataModel model) async {
    final movementLines = <MovementLineInput>[];
    for (final line in _lines) {
      if (line.materialId == null || line.materialId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请完整选择入库物资')));
        return;
      }
      final count = int.tryParse(line.countCtrl.text.trim()) ?? 0;
      if (count <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('入库数量必须大于 0')));
        return;
      }
      movementLines.add(MovementLineInput(materialId: line.materialId!, count: count));
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final err = model.inboundBatch(movementLines, _subType, _supplierCtrl.text, '');
    if (!mounted) return;
    if (err != null) {
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('错误'), content: Text(err)));
      setState(() => _isSubmitting = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('入库成功，共 ${movementLines.length} 项')));
      setState(() {
        _resetLines();
        _isSubmitting = false;
      });
    }
  }
}
