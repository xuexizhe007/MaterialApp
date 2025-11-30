import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// 物资模型
class MaterialItem {
  String code;
  String name;
  String category;
  int stock;
  String remark;

  MaterialItem({
    required this.code,
    required this.name,
    this.category = '',
    this.stock = 0,
    this.remark = '',
  });

  Map<String, dynamic> toJson() => {
    'code': code, 'name': name, 'category': category, 'stock': stock, 'remark': remark
  };

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
    code: json['code'],
    name: json['name'],
    category: json['category'] ?? '',
    stock: json['stock'] ?? 0,
    remark: json['remark'] ?? '',
  );
}

// 记录模型
class RecordItem {
  String id;
  String type; // in, out
  String subType; // 进货, 领用等
  String code;
  String name;
  int count;
  String date;
  String operator;
  String target; // 供应商/部门
  String receiver; // 经手人

  RecordItem({
    required this.id, required this.type, required this.subType,
    required this.code, required this.name, required this.count,
    required this.date, required this.operator, required this.target, required this.receiver
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'subType': subType, 'code': code, 'name': name,
    'count': count, 'date': date, 'operator': operator, 'target': target, 'receiver': receiver
  };

  factory RecordItem.fromJson(Map<String, dynamic> json) => RecordItem(
    id: json['id'], type: json['type'], subType: json['subType'],
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

  // 新增物资
  String? addMaterial(String code, String name, String category, String remark) {
    if (_materials.any((e) => e.code == code)) return "编码已存在";
    _materials.add(MaterialItem(code: code, name: name, category: category, remark: remark));
    _save();
    notifyListeners();
    return null;
  }

  // 入库
  void inbound(String code, int count, String subType, String supplier, String remark) {
    final item = _materials.firstWhere((e) => e.code == code);
    item.stock += count;
    
    final record = RecordItem(
      id: "IN${DateTime.now().millisecondsSinceEpoch}",
      type: "in", subType: subType, code: code, name: item.name, count: count,
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      operator: _currentUser, target: supplier, receiver: "",
    );
    _records.insert(0, record);
    _save();
    notifyListeners();
  }

  // 出库
  String? outbound(String code, int count, String subType, String dept, String receiver) {
    final item = _materials.firstWhere((e) => e.code == code);
    if (item.stock < count) return "库存不足，当前仅剩 ${item.stock}";
    
    item.stock -= count;
    final record = RecordItem(
      id: "OUT${DateTime.now().millisecondsSinceEpoch}",
      type: "out", subType: subType, code: code, name: item.name, count: count,
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

  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _materials = [];
    _records = [];
    notifyListeners();
  }
}
