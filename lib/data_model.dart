import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// 简单的ID生成器
String generateUuid() {
  return "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}";
}

class MaterialItem {
  String id;   // 唯一且不可变的主键
  String code; // 可修改，用于扫码
  String name; // 可修改
  String category;
  int stock;
  String remark; // 可修改

  MaterialItem({
    required this.id,
    required this.code,
    required this.name,
    this.category = '',
    this.stock = 0,
    this.remark = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'code': code, 'name': name, 'category': category, 'stock': stock, 'remark': remark
  };

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
    id: json['id'] ?? generateUuid(), // 兼容旧数据，如果没有ID则补一个
    code: json['code'],
    name: json['name'],
    category: json['category'] ?? '',
    stock: json['stock'] ?? 0,
    remark: json['remark'] ?? '',
  );
}

class RecordItem {
  String id;
  String materialId; // 关键：通过ID关联物资，而不是Code
  String type; 
  String subType;
  String code; // 仅作快照记录（当时的编码）
  String name; // 仅作快照记录（当时的名称）
  int count;
  String date;
  String operator;
  String target;
  String receiver;

  RecordItem({
    required this.id, 
    required this.materialId,
    required this.type, required this.subType,
    required this.code, required this.name, required this.count,
    required this.date, required this.operator, required this.target, required this.receiver
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'materialId': materialId, 
    'type': type, 'subType': subType, 'code': code, 'name': name,
    'count': count, 'date': date, 'operator': operator, 'target': target, 'receiver': receiver
  };

  factory RecordItem.fromJson(Map<String, dynamic> json) => RecordItem(
    id: json['id'], 
    materialId: json['materialId'] ?? '', // 兼容旧数据
    type: json['type'], subType: json['subType'],
    code: json['code'], name: json['name'], count: json['count'],
    date: json['date'], operator: json['operator'],
    target: json['target'] ?? '', receiver: json['receiver'] ?? '',
  );
}

class DataModel extends ChangeNotifier {
  List<MaterialItem> _materials = [];
  List<RecordItem> _records = [];
  String _currentUser = "管理员";
  int warnThreshold = 5;

  List<MaterialItem> get materials => _materials;
  List<RecordItem> get records => _records;
  String get currentUser => _currentUser;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final mStr = prefs.getString('materials');
    final rStr = prefs.getString('records');
    
    if (mStr != null) {
      _materials = (jsonDecode(mStr) as List).map((e) => MaterialItem.fromJson(e)).toList();
    }
    if (rStr != null) {
      _records = (jsonDecode(rStr) as List).map((e) => RecordItem.fromJson(e)).toList();
      // 数据迁移：如果旧数据没有 materialId，尝试通过 code 补全关联
      bool needSave = false;
      for (var r in _records) {
        if (r.materialId.isEmpty) {
           final m = _materials.where((e) => e.code == r.code).firstOrNull;
           if (m != null) {
             r.materialId = m.id;
             needSave = true;
           }
        }
      }
      if (needSave) _save();
    }
    notifyListeners();
  }

  void setCurrentUser(String user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('materials', jsonEncode(_materials.map((e) => e.toJson()).toList()));
    prefs.setString('records', jsonEncode(_records.map((e) => e.toJson()).toList()));
  }
  
  String exportData() {
    final data = {
      "materials": _materials.map((e) => e.toJson()).toList(),
      "records": _records.map((e) => e.toJson()).toList(),
      "version": "2.0" // 升级版本号
    };
    return jsonEncode(data);
  }
  
  Future<String?> importData(String jsonStr) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (data['materials'] != null) {
        _materials = (data['materials'] as List).map((e) => MaterialItem.fromJson(e)).toList();
      }
      if (data['records'] != null) {
        _records = (data['records'] as List).map((e) => RecordItem.fromJson(e)).toList();
      }
      await _save();
      notifyListeners();
      return null;
    } catch (e) {
      return "数据格式错误: $e";
    }
  }

  String? addMaterial(String code, String name, String category, String remark) {
    if (_materials.any((e) => e.code == code)) return "编码已存在";
    
    // 创建时生成唯一 ID
    final newItem = MaterialItem(
      id: generateUuid(), 
      code: code, name: name, category: category, remark: remark
    );
    _materials.add(newItem);
    _save();
    notifyListeners();
    return null;
  }

  // --- ID 模式下的更新逻辑：非常简单 ---
  String? updateMaterial(String id, String newCode, String newName, String newRemark) {
    final index = _materials.indexWhere((e) => e.id == id);
    if (index == -1) return "物资不存在";

    final currentItem = _materials[index];

    // 唯一性检查：如果修改了 Code，要检查新 Code 是否和其他人的冲突
    if (newCode != currentItem.code) {
      if (_materials.any((e) => e.code == newCode && e.id != id)) {
        return "编码 $newCode 已被其他物资占用";
      }
    }

    // 直接修改，无需关心历史记录（历史记录通过 ID 关联，稳如泰山）
    currentItem.code = newCode;
    currentItem.name = newName;
    currentItem.remark = newRemark;

    _save();
    notifyListeners();
    return null;
  }

  void inbound(String code, int count, String subType, String supplier, String remark) {
    final item = _materials.firstWhere((e) => e.code == code);
    item.stock += count;
    
    final record = RecordItem(
      id: "IN${generateUuid()}",
      materialId: item.id, // 记录 ID
      type: "in", subType: subType, 
      code: item.code, name: item.name, // 记录当时的快照
      count: count,
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      operator: _currentUser, target: supplier, receiver: "",
    );
    _records.insert(0, record);
    _save();
    notifyListeners();
  }

  String? outbound(String code, int count, String subType, String dept, String receiver) {
    final item = _materials.firstWhere((e) => e.code == code);
    if (item.stock < count) return "库存不足，当前仅剩 ${item.stock}";
    
    item.stock -= count;
    final record = RecordItem(
      id: "OUT${generateUuid()}",
      materialId: item.id, // 记录 ID
      type: "out", subType: subType, 
      code: item.code, name: item.name, // 快照
      count: count,
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      operator: _currentUser, target: dept, receiver: receiver,
    );
    _records.insert(0, record);
    _save();
    notifyListeners();
    return null;
  }

  MaterialItem? findByCode(String code) {
    try {
      return _materials.firstWhere((e) => e.code == code);
    } catch (e) {
      return null;
    }
  }
  
  // 通过 ID 查找（更可靠）
  MaterialItem? findById(String id) {
    try {
      return _materials.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
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

// Extension helper provided for list filtering nulls if needed
extension ListFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
