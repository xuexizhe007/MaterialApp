import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 简单的ID生成器
String generateUuid() {
  return "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}";
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _toStr(dynamic value) => value == null ? '' : value.toString();

class MaterialItem {
  String id; // 唯一不可变，后续出入库均以此关联
  String code; // 历史兼容字段：新版本不再要求填写，也不作为主键使用
  String name;
  String category;
  int stock;
  String remark;

  MaterialItem({
    required this.id,
    this.code = '',
    required this.name,
    this.category = '',
    this.stock = 0,
    this.remark = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'category': category,
        'stock': stock,
        'remark': remark,
      };

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
        id: _toStr(json['id']).isEmpty ? generateUuid() : _toStr(json['id']),
        code: _toStr(json['code']),
        name: _toStr(json['name']).isEmpty ? '未命名物资' : _toStr(json['name']),
        category: _toStr(json['category']),
        stock: _toInt(json['stock']),
        remark: _toStr(json['remark']),
      );
}

class RecordItem {
  String id;
  String batchId; // 同一次出/入库单号，多物资时多条记录共用同一 batchId
  String materialId;
  String type; // in / out
  String subType;
  String code; // 历史快照字段，仅用于兼容旧数据/旧扫码
  String name;
  int count;
  String date;
  String operator;
  String target;
  String receiver;

  RecordItem({
    required this.id,
    required this.batchId,
    required this.materialId,
    required this.type,
    required this.subType,
    required this.code,
    required this.name,
    required this.count,
    required this.date,
    required this.operator,
    required this.target,
    required this.receiver,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'materialId': materialId,
        'type': type,
        'subType': subType,
        'code': code,
        'name': name,
        'count': count,
        'date': date,
        'operator': operator,
        'target': target,
        'receiver': receiver,
      };

  factory RecordItem.fromJson(Map<String, dynamic> json) {
    final id = _toStr(json['id']).isEmpty ? generateUuid() : _toStr(json['id']);
    return RecordItem(
      id: id,
      batchId: _toStr(json['batchId']).isEmpty ? id : _toStr(json['batchId']),
      materialId: _toStr(json['materialId']),
      type: _toStr(json['type']).isEmpty ? 'out' : _toStr(json['type']),
      subType: _toStr(json['subType']),
      code: _toStr(json['code']),
      name: _toStr(json['name']).isEmpty ? '未知物资' : _toStr(json['name']),
      count: _toInt(json['count'], fallback: 1),
      date: _toStr(json['date']).isEmpty
          ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())
          : _toStr(json['date']),
      operator: _toStr(json['operator']),
      target: _toStr(json['target']),
      receiver: _toStr(json['receiver']),
    );
  }
}

class MovementLineInput {
  final String materialId;
  final int count;

  const MovementLineInput({required this.materialId, required this.count});
}

class MovementStat {
  final String materialId;
  final String code;
  final String name;
  int totalCount;
  int recordCount;
  String lastDate;

  MovementStat({
    required this.materialId,
    required this.code,
    required this.name,
    required this.totalCount,
    required this.recordCount,
    required this.lastDate,
  });
}

class DataModel extends ChangeNotifier {
  List<MaterialItem> _materials = [];
  List<RecordItem> _records = [];
  String _currentUser = "管理员";

  List<MaterialItem> get materials => _materials;
  List<RecordItem> get records => _records;
  String get currentUser => _currentUser;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final mStr = prefs.getString('materials');
    final rStr = prefs.getString('records');

    if (mStr != null) {
      _materials = (jsonDecode(mStr) as List)
          .map((e) => MaterialItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (rStr != null) {
      _records = (jsonDecode(rStr) as List)
          .map((e) => RecordItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final changed = _migrateLegacyRecords();
    if (changed) await _save();
    notifyListeners();
  }

  bool _migrateLegacyRecords() {
    bool changed = false;
    for (final r in _records) {
      if (r.batchId.isEmpty) {
        r.batchId = r.id;
        changed = true;
      }
      if (r.materialId.isEmpty && r.code.isNotEmpty) {
        final m = _materials.where((e) => e.code == r.code).firstOrNull;
        if (m != null) {
          r.materialId = m.id;
          changed = true;
        }
      }
      if (r.name.isEmpty && r.materialId.isNotEmpty) {
        final m = findById(r.materialId);
        if (m != null) {
          r.name = m.name;
          changed = true;
        }
      }
    }
    return changed;
  }

  void setCurrentUser(String user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('materials', jsonEncode(_materials.map((e) => e.toJson()).toList()));
    await prefs.setString('records', jsonEncode(_records.map((e) => e.toJson()).toList()));
  }

  String exportData() {
    final data = {
      'materials': _materials.map((e) => e.toJson()).toList(),
      'records': _records.map((e) => e.toJson()).toList(),
      'version': '3.0',
    };
    return jsonEncode(data);
  }

  Future<String?> importData(String jsonStr) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (data['materials'] != null) {
        _materials = (data['materials'] as List)
            .map((e) => MaterialItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data['records'] != null) {
        _records = (data['records'] as List)
            .map((e) => RecordItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      _migrateLegacyRecords();
      await _save();
      notifyListeners();
      return null;
    } catch (e) {
      return "数据格式错误: $e";
    }
  }

  String? addMaterial(String name, String category, String remark, {String code = ''}) {
    final fixedName = name.trim();
    final fixedCode = code.trim();
    if (fixedName.isEmpty) return '物资名称不能为空';
    if (fixedCode.isNotEmpty && _materials.any((e) => e.code == fixedCode)) {
      return '兼容编码已存在';
    }
    final newItem = MaterialItem(
      id: generateUuid(),
      code: fixedCode,
      name: fixedName,
      category: category.trim(),
      remark: remark.trim(),
    );
    _materials.add(newItem);
    _save();
    notifyListeners();
    return null;
  }

  String? updateMaterial(String id, String newName, String newRemark, {String? newCode, String? category}) {
    final index = _materials.indexWhere((e) => e.id == id);
    if (index == -1) return '物资不存在';
    final currentItem = _materials[index];
    final fixedName = newName.trim();
    if (fixedName.isEmpty) return '物资名称不能为空';

    if (newCode != null) {
      final fixedCode = newCode.trim();
      if (fixedCode.isNotEmpty && fixedCode != currentItem.code) {
        if (_materials.any((e) => e.code == fixedCode && e.id != id)) {
          return '兼容编码 $fixedCode 已被其他物资占用';
        }
      }
      currentItem.code = fixedCode;
    }

    currentItem.name = fixedName;
    currentItem.remark = newRemark.trim();
    if (category != null) currentItem.category = category.trim();
    _save();
    notifyListeners();
    return null;
  }

  String? inboundById(String materialId, int count, String subType, String supplier, String remark) {
    return inboundBatch([
      MovementLineInput(materialId: materialId, count: count),
    ], subType, supplier, remark);
  }

  String? outboundById(String materialId, int count, String subType, String dept, String receiver) {
    return outboundBatch([
      MovementLineInput(materialId: materialId, count: count),
    ], subType, dept, receiver);
  }

  // 兼容旧代码入口：仍可通过旧编码进行扫码查找，但新版本不再要求物资编码。
  void inbound(String code, int count, String subType, String supplier, String remark) {
    final item = findByCode(code);
    if (item == null) return;
    inboundById(item.id, count, subType, supplier, remark);
  }

  String? outbound(String code, int count, String subType, String dept, String receiver) {
    final item = findByCode(code);
    if (item == null) return '未找到该物资';
    return outboundById(item.id, count, subType, dept, receiver);
  }

  String? inboundBatch(List<MovementLineInput> lines, String subType, String supplier, String remark) {
    final err = _validateLines(lines);
    if (err != null) return err;

    final batchId = 'IN${generateUuid()}';
    final date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final newRecords = <RecordItem>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final item = findById(line.materialId)!;
      item.stock += line.count;
      newRecords.add(RecordItem(
        id: '${batchId}_${i + 1}',
        batchId: batchId,
        materialId: item.id,
        type: 'in',
        subType: subType,
        code: item.code,
        name: item.name,
        count: line.count,
        date: date,
        operator: _currentUser,
        target: supplier.trim(),
        receiver: '',
      ));
    }

    _records.insertAll(0, newRecords);
    _save();
    notifyListeners();
    return null;
  }

  String? outboundBatch(List<MovementLineInput> lines, String subType, String dept, String receiver) {
    final err = _validateLines(lines);
    if (err != null) return err;

    final totals = <String, int>{};
    for (final line in lines) {
      totals[line.materialId] = (totals[line.materialId] ?? 0) + line.count;
    }
    for (final entry in totals.entries) {
      final item = findById(entry.key);
      if (item == null) return '物资不存在';
      if (item.stock < entry.value) {
        return '${item.name} 库存不足，当前仅剩 ${item.stock}';
      }
    }

    final batchId = 'OUT${generateUuid()}';
    final date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final newRecords = <RecordItem>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final item = findById(line.materialId)!;
      item.stock -= line.count;
      newRecords.add(RecordItem(
        id: '${batchId}_${i + 1}',
        batchId: batchId,
        materialId: item.id,
        type: 'out',
        subType: subType,
        code: item.code,
        name: item.name,
        count: line.count,
        date: date,
        operator: _currentUser,
        target: dept.trim(),
        receiver: receiver.trim(),
      ));
    }

    _records.insertAll(0, newRecords);
    _save();
    notifyListeners();
    return null;
  }

  String? _validateLines(List<MovementLineInput> lines) {
    if (lines.isEmpty) return '请至少选择一项物资';
    for (final line in lines) {
      if (line.materialId.trim().isEmpty) return '请完整选择物资';
      if (line.count <= 0) return '数量必须大于 0';
      if (findById(line.materialId) == null) return '物资不存在';
    }
    return null;
  }

  MaterialItem? findByCode(String code) {
    final fixedCode = code.trim();
    if (fixedCode.isEmpty) return null;
    try {
      return _materials.firstWhere((e) => e.code == fixedCode);
    } catch (e) {
      return null;
    }
  }

  MaterialItem? findById(String id) {
    try {
      return _materials.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  List<RecordItem> recordsForBatch(String batchId) {
    final fixedBatchId = batchId.trim();
    if (fixedBatchId.isEmpty) return [];
    return _records.where((e) => e.batchId == fixedBatchId).toList();
  }

  List<MovementStat> movementStatistics(String type, DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final endExclusive = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));
    final map = <String, MovementStat>{};

    for (final r in _records) {
      if (r.type != type) continue;
      final dt = parseRecordDate(r.date);
      if (dt == null || dt.isBefore(start) || !dt.isBefore(endExclusive)) continue;

      final key = r.materialId.isNotEmpty ? r.materialId : '${r.code}_${r.name}';
      final old = map[key];
      if (old == null) {
        map[key] = MovementStat(
          materialId: r.materialId,
          code: r.code,
          name: r.name,
          totalCount: r.count,
          recordCount: 1,
          lastDate: r.date,
        );
      } else {
        old.totalCount += r.count;
        old.recordCount += 1;
        final oldDate = parseRecordDate(old.lastDate);
        if (oldDate == null || dt.isAfter(oldDate)) old.lastDate = r.date;
      }
    }

    final result = map.values.where((e) => e.totalCount > 0).toList();
    result.sort((a, b) {
      final countCompare = b.totalCount.compareTo(a.totalCount);
      if (countCompare != 0) return countCompare;
      return a.name.compareTo(b.name);
    });
    return result;
  }

  DateTime? parseRecordDate(String value) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm').parseStrict(value);
    } catch (_) {
      return DateTime.tryParse(value);
    }
  }

  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('materials');
    await prefs.remove('records');
    _materials = [];
    _records = [];
    notifyListeners();
  }
}

extension ListFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
