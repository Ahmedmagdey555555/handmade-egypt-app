#!/bin/bash
set -e

echo "🔨 Building project from scratch..."

rm -rf apps/customer
mkdir -p apps/customer/lib/models
mkdir -p apps/customer/lib/screens

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
  cupertino_icons: ^1.0.6
  supabase_flutter: ^2.5.6
  cached_network_image: ^3.3.1

flutter:
  uses-material-design: true
FILE_END

cat > apps/customer/lib/supabase_config.dart << 'FILE_END'
class SupabaseConfig {
  static const String url = 'https://pqovaolgcjrgjoeqkdlf.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxb3Zhb2xnY2pyZ2pvZXFrZGxmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwOTM1NTYsImV4cCI6MjEwNzY2OTU1Nn0.PWA4foPpi15pWl-Hviutu_9stJctjFJor4xx0ghU90Y';
}
FILE_END

cat > apps/customer/lib/main.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

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
    final session = Supabase.instance.client.auth.currentSession;
    return MaterialApp(
      title: 'Handmade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFB07D62),
        useMaterial3: true,
      ),
      home: session == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
FILE_END

cat > apps/customer/lib/models/product.dart << 'FILE_END'
class Product {
  final String id;
  final String title;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? storeId;

  Product({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.imageUrl,
    this.storeId,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        price: (m['price'] as num).toDouble(),
        imageUrl: m['image_url'] as String?,
        storeId: m['store_id'] as String?,
      );
}
FILE_END

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.handyman, size: 72),
              const SizedBox(height: 16),
              Text(
                _isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isSignUp ? 'تسجيل' : 'دخول'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp
                    ? 'عندك حساب؟ سجّل دخول'
                    : 'معندكش حساب؟ اعمل واحد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
FILE_END

cat > apps/customer/lib/screens/home_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = Supabase.instance.client
        .from('products')
        .select()
        .order('created_at', ascending: false)
        .then((rows) => rows.map((r) => Product.fromMap(r)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Handmade'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Scaffold()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Product>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('خطأ: ${snap.error}'),
                ),
              );
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('لا توجد منتجات بعد'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final p = items[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: p.imageUrl == null
                            ? Container(color: Colors.grey.shade200)
                            : CachedNetworkImage(
                                imageUrl: p.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('${p.price.toStringAsFixed(0)} ج.م',
                                style:
                                    const TextStyle(color: Colors.brown)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
FILE_END

echo "✅ Project files created successfully"
ls -R apps/customer
