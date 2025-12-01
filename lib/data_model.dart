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
  String id;   // 唯一不可变
  String code; // 可修改
  String name; // 可修改
  String category;
  int stock;
  String remark;

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
    id: json['id'] ?? generateUuid(),
    code: json['code'],
    name: json['name'],
    category: json['category'] ?? '',
    stock: json['stock'] ?? 0,
    remark: json['remark'] ?? '',
  );
}

class RecordItem {
  String id;
  String materialId; // 关联ID
  String type; 
  String subType;
  String code; // 快照
  String name; // 快照
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
    materialId: json['materialId'] ?? '',
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
      // 简单的数据迁移兼容
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
      "version": "2.1"
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
    final newItem = MaterialItem(
      id: generateUuid(), 
      code: code, name: name, category: category, remark: remark
    );
    _materials.add(newItem);
    _save();
    notifyListeners();
    return null;
  }

  String? updateMaterial(String id, String newCode, String newName, String newRemark) {
    final index = _materials.indexWhere((e) => e.id == id);
    if (index == -1) return "物资不存在";
    final currentItem = _materials[index];
    if (newCode != currentItem.code) {
      if (_materials.any((e) => e.code == newCode && e.id != id)) {
        return "编码 $newCode 已被其他物资占用";
      }
    }
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
      materialId: item.id,
      type: "in", subType: subType, 
      code: item.code, name: item.name,
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
      materialId: item.id,
      type: "out", subType: subType, 
      code: item.code, name: item.name,
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
    try { return _materials.firstWhere((e) => e.code == code); } catch (e) { return null; }
  }
  
  MaterialItem? findById(String id) {
    try { return _materials.firstWhere((e) => e.id == id); } catch (e) { return null; }
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