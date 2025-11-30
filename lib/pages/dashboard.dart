import 'package:flutter/material.dart';
import 'catalog_tab.dart';
import 'outbound_tab.dart';
import 'mine_tab.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const CatalogTab(),
    const OutboundTab(),
    const MineTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 保持状态
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: '目录/入库'),
          NavigationDestination(icon: Icon(Icons.output), label: '出库'),
          NavigationDestination(icon: Icon(Icons.person), label: '设置/库存'),
        ],
      ),
    );
  }
}
