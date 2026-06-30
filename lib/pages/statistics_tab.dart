import 'package:flutter/material.dart';

import 'movement_tab.dart';

// 兼容旧路由/旧引用：统计功能已整合到 MovementTab 的“出入库统计”中。
class StatisticsTab extends StatelessWidget {
  const StatisticsTab({super.key});

  @override
  Widget build(BuildContext context) => const MovementTab();
}
