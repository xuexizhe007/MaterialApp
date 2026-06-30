import 'package:flutter/material.dart';

import 'catalog_tab.dart';
import 'inbound_tab.dart';
import 'mine_tab.dart';
import 'movement_tab.dart';
import 'outbound_tab.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    CatalogTab(),
    InboundTab(),
    OutboundTab(),
    MovementTab(),
    MineTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: '目录'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), label: '入库'),
          NavigationDestination(icon: Icon(Icons.outbox_outlined), label: '出库'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '查询'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '设置'),
        ],
      ),
    );
  }
}
