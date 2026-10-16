#!/bin/bash
set -e

# امسح أي حاجة قديمة
rm -rf apps/customer
mkdir -p apps/customer/lib/models
mkdir -p apps/customer/lib/providers
mkdir -p apps/customer/lib/screens

# إنشاء supabase_config.dart
cat > apps/customer/lib/supabase_config.dart << 'FILE_END'
class SupabaseConfig {
  static const String url = 'https://pqovaolgcjrgjoeqkdlf.supabase.co';
  static const String anonKey = 'المفتاح_الكامل_هنا';
}
FILE_END
mkdir -p apps/customer/lib/models
mkdir -p apps/customer/lib/providers
mkdir -p apps/customer/lib/screens

# ============ pubspec.yaml ============
cat > apps/customer/pubspec.yaml << 'FILE_END'
name: customer_app
description: Handmade marketplace customer app
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.6
  supabase_flutter: ^2.5.6
  cached_network_image: ^3.3.1
  provider: ^6.1.2
  permission_handler: ^11.3.0

flutter:
  uses-material-design: true
FILE_END

# ============ main.dart ============
cat > apps/customer/lib/main.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'supabase_config.dart';
import 'providers/cart_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Handmade',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFFB07D62),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAF7F2),
        ),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
FILE_END

# ============ models/product.dart ============
cat > apps/customer/lib/models/product.dart << 'FILE_END'
class Product {
  final String id;
  final String title;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? storeId;
  final String? categoryId;
  final String? warranty;

  Product({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.imageUrl,
    this.storeId,
    this.categoryId,
    this.warranty,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        price: (m['price'] as num).toDouble(),
        imageUrl: m['image_url'] as String?,
        storeId: m['store_id'] as String?,
        categoryId: m['category_id'] as String?,
        warranty: m['warranty'] as String?,
      );
}
FILE_END

# ============ models/category.dart ============
cat > apps/customer/lib/models/category.dart << 'FILE_END'
class Category {
  final String id;
  final String name;
  final String? icon;

  Category({required this.id, required this.name, this.icon});

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: m['icon'] as String?,
      );
}
FILE_END

# ============ models/ad.dart ============
cat > apps/customer/lib/models/ad.dart << 'FILE_END'
class Ad {
  final String id;
  final String? title;
  final String? imageUrl;
  final String? linkUrl;
  final String? position;

  Ad({required this.id, this.title, this.imageUrl, this.linkUrl, this.position});

  factory Ad.fromMap(Map<String, dynamic> m) => Ad(
        id: m['id'] as String,
        title: m['title'] as String?,
        imageUrl: m['image_url'] as String?,
        linkUrl: m['link_url'] as String?,
        position: m['position'] as String?,
      );
}
FILE_END

# ============ models/cart_item.dart ============
cat > apps/customer/lib/models/cart_item.dart << 'FILE_END'
import 'product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}
FILE_END

# ============ providers/cart_provider.dart ============
cat > apps/customer/lib/providers/cart_provider.dart << 'FILE_END'
import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;
  int get count => _items.values.fold(0, (s, i) => s + i.quantity);
  double get total => _items.values.fold(0, (s, i) => s + i.total);

  void add(Product p) {
    if (_items.containsKey(p.id)) {
      _items[p.id]!.quantity++;
    } else {
      _items[p.id] = CartItem(product: p);
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.remove(id);
    notifyListeners();
  }

  void increment(String id) {
    _items[id]?.quantity++;
    notifyListeners();
  }

  void decrement(String id) {
    final item = _items[id];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(id);
    } else {
      item.quantity--;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
FILE_END

# ============ screens/splash_screen.dart ============
cat > apps/customer/lib/screens/splash_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Permission.location.request();
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            session == null ? const LoginScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB07D62),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.handyman,
                size: 80,
                color: Color(0xFFB07D62),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Handmade',
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'CRAFTS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
FILE_END

# ============ screens/login_screen.dart ============
cat > apps/customer/lib/screens/login_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _isSignUp = false;

  Future<void> _submit() async {
    if (_email.text.isEmpty || _password.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_isSignUp) {
        await auth.signUp(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFB07D62),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.handyman, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Handmade',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1810),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB07D62),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isSignUp ? 'إنشاء الحساب' : 'تسجيل الدخول',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'عندك حساب؟ سجّل دخول'
                      : 'معندكش حساب؟ اعمل واحد',
                  style: const TextStyle(color: Color(0xFFB07D62)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
FILE_END

echo "✅ setup-phase1a.sh done"
