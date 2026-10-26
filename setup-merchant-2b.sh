#!/bin/bash
set -e

mkdir -p apps/merchant/lib/screens
mkdir -p apps/merchant/lib/widgets

# ============ screens/merchant_custom_orders_screen.dart ============
cat > apps/merchant/lib/screens/merchant_custom_orders_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantCustomOrdersScreen extends StatefulWidget {
  const MerchantCustomOrdersScreen({super.key});

  @override
  State<MerchantCustomOrdersScreen> createState() => _MerchantCustomOrdersScreenState();
}

class _MerchantCustomOrdersScreenState extends State<MerchantCustomOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final store = await Supabase.instance.client.from('stores').select('id').eq('owner_id', uid).single();
      
      // جلب الطلبات المخصصة (حالياً بيجيب كل الطلبات، ولما نعمل لوحة التحكم هنفلترها)
      final data = await Supabase.instance.client
          .from('custom_orders')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _orders = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, size: 90, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('مفيش طلبات مخصصة لسه', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (c, i) {
                  final o = _orders[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('طلب خاص #${o['id'].toString().substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text((o['status'] ?? 'pending').toString(), style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Text(o['description'] ?? '', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.category_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(o['product_type'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            const Spacer(),
                            const Icon(Icons.monetization_on_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('ميزانية: ${o['budget'] ?? 'غير محدد'} ج.م', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
FILE_END

# ============ تحديث screens/merchant_profile_screen.dart ============
cat > apps/merchant/lib/screens/merchant_profile_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store.dart';
import 'login_screen.dart';
import 'wallet_screen.dart';
import 'store_settings_screen.dart';

class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  Store? _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client.from('stores').select().eq('owner_id', uid).single();
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

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final user = Supabase.instance.client.auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: const Color(0xFFB07D62).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.store, size: 44, color: Color(0xFFB07D62)),
                ),
                const SizedBox(height: 12),
                Text(_store?.name ?? 'متجري', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _menuItem(Icons.account_balance_wallet_outlined, 'المحفظة والأرباح', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
          _menuItem(Icons.settings_outlined, 'إعدادات المتجر', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreSettingsScreen()))),
          _menuItem(Icons.logout, 'تسجيل الخروج', _logout, color: Colors.red),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color ?? const Color(0xFFB07D62)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? Colors.black)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
FILE_END

# ============ تحديث widgets/main_nav.dart ============
cat > apps/merchant/lib/widgets/main_nav.dart << 'FILE_END'
import 'package:flutter/material.dart';
import '../screens/merchant_products_screen.dart';
import '../screens/merchant_orders_screen.dart';
import '../screens/merchant_custom_orders_screen.dart';
import '../screens/merchant_profile_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;

  final _pages = const [
    MerchantProductsScreen(),
    MerchantOrdersScreen(),
    MerchantCustomOrdersScreen(),
    MerchantProfileScreen(),
  ];

  final _titles = ['منتجاتي', 'طلباتي', 'طلبات مخصصة', 'حسابي'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFFB07D62),
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'المنتجات'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'الطلبات'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_note_outlined), activeIcon: Icon(Icons.edit_note), label: 'مخصصة'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
FILE_END

echo "setup-merchant-2b done"
