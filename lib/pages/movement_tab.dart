import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../data_model.dart';

class MovementTab extends StatefulWidget {
  const MovementTab({super.key});

  @override
  State<MovementTab> createState() => _MovementTabState();
}

class _MovementTabState extends State<MovementTab> with SingleTickerProviderStateMixin {
  late TabController _mainController;

  @override
  void initState() {
    super.initState();
    _mainController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _mainController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: '出入库记录'),
                  Tab(text: '出入库统计'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _mainController,
                children: const [
                  _MovementRecordsView(),
                  _MovementStatisticsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordBatch {
  final String batchId;
  final List<RecordItem> items;

  _RecordBatch({required this.batchId, required this.items});

  RecordItem get first => items.first;
  bool get isInbound => first.type == 'in';
  int get totalCount => items.fold(0, (sum, e) => sum + e.count);
  String get typeName => isInbound ? '入库' : '出库';
  String get itemNames => items.map((e) => e.name).toSet().join('、');
}

class _MovementRecordsView extends StatefulWidget {
  const _MovementRecordsView();

  @override
  State<_MovementRecordsView> createState() => _MovementRecordsViewState();
}

class _MovementRecordsViewState extends State<_MovementRecordsView> with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final int _pageSize = 10;
  int _outPage = 0;
  int _inPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _outPage = 0;
        _inPage = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final model = Provider.of<DataModel>(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索物资、类型、部门或人员',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: '出库'),
              Tab(text: '入库'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRecordList(model, 'out', Colors.orange, _outPage, (page) => setState(() => _outPage = page)),
                _buildRecordList(model, 'in', Colors.green, _inPage, (page) => setState(() => _inPage = page)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordList(DataModel model, String type, Color color, int page, ValueChanged<int> setPage) {
    final batches = _filteredBatches(model, type);
    final totalItems = batches.length;
    final totalPages = (totalItems / _pageSize).ceil();
    var safePage = page;
    if (safePage >= totalPages && totalPages > 0) safePage = totalPages - 1;
    if (totalItems == 0) safePage = 0;
    if (safePage != page) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setPage(safePage));
    }

    final paged = batches.skip(safePage * _pageSize).take(_pageSize).toList();
    final emptyText = type == 'out' ? '暂无出库记录' : '暂无入库记录';

    return paged.isEmpty
        ? Center(child: Text(emptyText))
        : ListView.builder(
            itemCount: paged.length + (totalPages > 1 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == paged.length) {
                return _PaginationBar(
                  currentPage: safePage,
                  totalPages: totalPages,
                  onPrev: safePage > 0 ? () => setPage(safePage - 1) : null,
                  onNext: safePage < totalPages - 1 ? () => setPage(safePage + 1) : null,
                );
              }
              final batch = paged[index];
              final first = batch.first;
              final isIn = batch.isInbound;
              final partyText = isIn
                  ? '供应商/归还人: ${first.target.isEmpty ? '未填写' : first.target}'
                  : '领用部门: ${first.target.isEmpty ? '未填写' : first.target}  领用人: ${first.receiver.isEmpty ? '未填写' : first.receiver}';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(isIn ? Icons.download : Icons.upload, color: color),
                  title: Text('${batch.typeName}单: ${first.subType}（${batch.items.length}项）'),
                  subtitle: Text('${first.date}\n${batch.itemNames}\n$partyText'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isIn ? '+' : '-'}${batch.totalCount}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                      ),
                      IconButton(
                        tooltip: '导出单据',
                        icon: const Icon(Icons.share, color: Colors.blue),
                        onPressed: () => _exportPdf(context, batch),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  List<_RecordBatch> _filteredBatches(DataModel model, String type) {
    final groups = <String, List<RecordItem>>{};
    for (final r in model.records.where((r) => r.type == type)) {
      final key = r.batchId.isNotEmpty ? r.batchId : r.id;
      groups.putIfAbsent(key, () => []).add(r);
    }

    var batches = groups.entries.map((e) => _RecordBatch(batchId: e.key, items: e.value)).toList();
    batches.sort((a, b) {
      final ad = model.parseRecordDate(a.first.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = model.parseRecordDate(b.first.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      batches = batches.where((b) {
        return b.items.any((r) =>
            r.name.toLowerCase().contains(q) ||
            r.subType.toLowerCase().contains(q) ||
            r.target.toLowerCase().contains(q) ||
            r.receiver.toLowerCase().contains(q));
      }).toList();
    }
    return batches;
  }

  Future<void> _exportPdf(BuildContext context, _RecordBatch batch) async {
    try {
      final doc = pw.Document();
      pw.Font? font;
      try {
        final fontData = await rootBundle.load('assets/fonts/FangSong.ttf');
        font = pw.Font.ttf(fontData);
      } catch (e) {
        debugPrint('字体加载失败: $e');
      }
      final textStyle = font != null ? pw.TextStyle(font: font, fontSize: 14) : const pw.TextStyle(fontSize: 14);
      final titleStyle = font != null ? pw.TextStyle(font: font, fontSize: 24) : const pw.TextStyle(fontSize: 24);
      final labelStyle = font != null ? pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700) : const pw.TextStyle(fontSize: 12, color: PdfColors.grey700);
      final first = batch.first;

      doc.addPage(
        pw.Page(
          theme: font != null ? pw.ThemeData.withFont(base: font) : null,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, child: pw.Text(batch.isInbound ? '物资入库单' : '物资出库单', style: titleStyle)),
                pw.SizedBox(height: 20),
                pw.Text('单号 ID: ${batch.batchId}', style: textStyle),
                pw.Text('日期 Date: ${first.date}', style: textStyle),
                pw.Text('业务类型: ${first.subType}', style: textStyle),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  headers: ['序号', '物资名称', '数量'],
                  data: batch.items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    return [index.toString(), item.name, item.count.toString()];
                  }).toList(),
                  headerStyle: textStyle.copyWith(fontWeight: pw.FontWeight.bold),
                  cellStyle: textStyle,
                  cellAlignment: pw.Alignment.centerLeft,
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                ),
                pw.SizedBox(height: 12),
                pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('合计数量: ${batch.totalCount}', style: textStyle)),
                pw.SizedBox(height: 20),
                _buildPdfRow('操作员:', first.operator, labelStyle, textStyle),
                _buildPdfRow(batch.isInbound ? '供应商/归还人:' : '领用部门:', first.target, labelStyle, textStyle),
                if (!batch.isInbound) _buildPdfRow('领用人:', first.receiver, labelStyle, textStyle),
                pw.SizedBox(height: 50),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.Text('签字确认: __________________', style: textStyle),
              ],
            );
          },
        ),
      );
      final safeName = batch.batchId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      await Printing.sharePdf(bytes: await doc.save(), filename: '${batch.typeName}单_$safeName.pdf');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF导出失败: $e')));
    }
  }

  pw.Widget _buildPdfRow(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: labelStyle), pw.Text(value, style: valueStyle)],
      ),
    );
  }
}

class _MovementStatisticsView extends StatefulWidget {
  const _MovementStatisticsView();

  @override
  State<_MovementStatisticsView> createState() => _MovementStatisticsViewState();
}

class _MovementStatisticsViewState extends State<_MovementStatisticsView> with AutomaticKeepAliveClientMixin {
  late DateTime _startDate;
  late DateTime _endDate;
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final int _pageSize = 10;
  int _outPage = 0;
  int _inPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _applyPresetSilently(7);
  }

  void _applyPresetSilently(int days) {
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _startDate = _endDate.subtract(Duration(days: days - 1));
  }

  void _applyPreset(int days) {
    setState(() {
      _applyPresetSilently(days);
      _outPage = 0;
      _inPage = 0;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      }
      _outPage = 0;
      _inPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final model = Provider.of<DataModel>(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildDateCard(),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: '出库'),
              Tab(text: '入库'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStatList(model, 'out', Colors.orange, _outPage, (page) => setState(() => _outPage = page)),
                _buildStatList(model, 'in', Colors.green, _inPage, (page) => setState(() => _inPage = page)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    final compactButtonStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12),
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                const Text('统计时间', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: compactButtonStyle,
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_dateFmt.format(_startDate), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('-'),
                ),
                Expanded(
                  child: OutlinedButton(
                    style: compactButtonStyle,
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_dateFmt.format(_endDate), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _PresetButton(label: '近7天', onPressed: () => _applyPreset(7))),
                const SizedBox(width: 6),
                Expanded(child: _PresetButton(label: '近1个月', onPressed: () => _applyPreset(30))),
                const SizedBox(width: 6),
                Expanded(child: _PresetButton(label: '近3个月', onPressed: () => _applyPreset(90))),
                const SizedBox(width: 6),
                Expanded(child: _PresetButton(label: '近1年', onPressed: () => _applyPreset(365))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatList(DataModel model, String type, Color color, int page, ValueChanged<int> setPage) {
    final stats = model.movementStatistics(type, _startDate, _endDate);
    final totalCount = stats.fold<int>(0, (sum, item) => sum + item.totalCount);
    final totalItems = stats.length;
    final totalPages = (totalItems / _pageSize).ceil();

    var safePage = page;
    if (safePage >= totalPages && totalPages > 0) safePage = totalPages - 1;
    if (totalItems == 0) safePage = 0;
    if (safePage != page) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setPage(safePage));
    }

    final paged = stats.skip(safePage * _pageSize).take(_pageSize).toList();
    final title = type == 'out' ? '出库统计' : '入库统计';
    final emptyText = type == 'out' ? '该时间段暂无出库记录' : '该时间段暂无入库记录';

    return ListView.builder(
      itemCount: paged.isEmpty ? 2 : paged.length + 1 + (totalPages > 1 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$title：物资种类 $totalItems，合计数量 $totalCount', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          );
        }

        if (paged.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(child: Text(emptyText)),
          );
        }

        final itemIndex = index - 1;
        if (itemIndex == paged.length) {
          return _PaginationBar(
            currentPage: safePage,
            totalPages: totalPages,
            onPrev: safePage > 0 ? () => setPage(safePage - 1) : null,
            onNext: safePage < totalPages - 1 ? () => setPage(safePage + 1) : null,
          );
        }

        final globalIndex = safePage * _pageSize + itemIndex + 1;
        final stat = paged[itemIndex];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(child: Text('$globalIndex')),
            title: Text(stat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('记录次数: ${stat.recordCount}  |  最近: ${stat.lastDate}'),
            trailing: Text(
              '${stat.totalCount}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        );
      },
    );
  }
}


class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PresetButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      onPressed: onPressed,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
