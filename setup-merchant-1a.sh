#!/bin/bash
set -e

# امسح أي نسخة قديمة
rm -rf apps/merchant
mkdir -p apps/merchant/lib/models
mkdir -p apps/merchant/lib/screens

# ============ pubspec.yaml ============
cat > apps/merchant/pubspec.yaml << 'FILE_END'
name: merchant_app
description: Handmade Marketplace - Merchant App
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
  google_fonts: ^6.1.0
  image_picker: ^1.0.7

flutter:
  uses-material-design: true
FILE_END

# ============ supabase_config.dart ============
cat > apps/merchant/lib/supabase_config.dart << 'FILE_END'
class SupabaseConfig {
  static const String url = 'https://pqovaolgcjrgjoeqkdlf.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxb3Zhb2xnY2pyZ2pvZXFrZGxmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwOTM1NTYsImV4cCI6MjEwNzY2OTU1Nn0.PWA4foPpi15pWl-Hviutu_9stJctjFJor4xx0ghU90Y';
}
FILE_END

# ============ models/store.dart ============
cat > apps/merchant/lib/models/store.dart << 'FILE_END'
class Store {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? phone;
  final String? logoUrl;
  final String status;

  Store({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.phone,
    this.logoUrl,
    required this.status,
  });

  factory Store.fromMap(Map<String, dynamic> m) => Store(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        phone: m['phone'] as String?,
        logoUrl: m['logo_url'] as String?,
        status: m['status'] as String? ?? 'pending',
      );
}
FILE_END

# ============ main.dart ============
cat > apps/merchant/lib/main.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'supabase_config.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const MerchantApp());
}

class MerchantApp extends StatelessWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handmade Merchant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFB07D62),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF7F2),
        textTheme: GoogleFonts.cairoTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFB07D62),
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
FILE_END

# ============ screens/splash_screen.dart ============
cat > apps/merchant/lib/screens/splash_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'store_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Check if user has a store
    try {
      final storeData = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('owner_id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      if (storeData == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StoreSetupScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C1810),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.storefront,
                size: 70,
                color: Color(0xFFB07D62),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Handmade',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'MERCHANT',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 8,
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
cat > apps/merchant/lib/screens/login_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';

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
        MaterialPageRoute(builder: (_) => const SplashScreen()),
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
                child: const Icon(Icons.storefront, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'حساب التاجر',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1810),
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

# ============ screens/store_setup_screen.dart ============
cat > apps/merchant/lib/screens/store_setup_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;

  Future<void> _createStore() async {
    if (_name.text.isEmpty || _phone.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك أكمل البيانات الأساسية')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      
      await Supabase.instance.client.from('stores').insert({
        'owner_id': uid,
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'phone': _phone.text.trim(),
        'status': 'active', // For now active by default
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: const Text('إنشاء متجر'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'أهلاً بيك في Handmade!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'عشان تبدأ تبيع، محتاجين نعرف بيانات متجرك الأول.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'اسم المتجر',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.store),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'نبذة عن المتجر (اختياري)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: _loading ? null : _createStore,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB07D62),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('بدء البيع الآن', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
FILE_END

# ============ screens/dashboard_screen.dart ============
cat > apps/merchant/lib/screens/dashboard_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Store? _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('owner_id', uid)
          .single();
      
      if (!mounted) return;
      setState(() {
        _store = Store.fromMap(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_store?.name ?? 'لوحة التحكم'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 80, color: Color(0xFFB07D62)),
            const SizedBox(height: 20),
            Text(
              'أهلاً بك في متجر: ${_store?.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('قريباً: إضافة المنتجات وإدارة الطلبات'),
          ],
        ),
      ),
    );
  }
}
FILE_END

echo "setup-merchant-1a done"
