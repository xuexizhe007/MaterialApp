import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 引入SP
import 'data_model.dart';
import 'pages/dashboard.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '物资管理系统 V1.4',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedUser();
  }

  // --- 需求3：加载保存的用户名 ---
  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_user') ?? "仓库管理员";
    setState(() {
      _userController.text = savedUser;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text("物资管理系统", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("V1.4 移动端", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "用户名",
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_userController.text.isEmpty) return;
                    
                    // --- 需求3：保存用户名 ---
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('saved_user', _userController.text);

                    // 初始化数据
                    if (context.mounted) {
                      final model = Provider.of<DataModel>(context, listen: false);
                      await model.init(); 
                      model.setCurrentUser(_userController.text);
                      
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const DashboardPage()),
                        );
                      }
                    }
                  },
                  child: const Text("登 录", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("默认无密码，直接点击登录", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
