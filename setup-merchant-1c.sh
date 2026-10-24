#!/bin/bash
set -e

mkdir -p apps/merchant/lib/screens

# ============ screens/merchant_orders_screen.dart ============
cat > apps/merchant/lib/screens/merchant_orders_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  String? _storeId;
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
      _storeId = store['id'];

      final data = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('store_id', _storeId!)
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

  Future<void> _updateStatus(String orderId, String newStatus) async {
    await Supabase.instance.client.from('orders').update({'status': newStatus}).eq('id', orderId);
    _load();
  }

  String _statusText(String s) {
    switch (s) {
      case 'pending': return 'قيد المراجعة';
      case 'confirmed': return 'تم التأكيد';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التسليم';
      case 'cancelled': return 'ملغي';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
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
                  Icon(Icons.receipt_long_outlined, size: 90, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('مفيش طلبات لسه', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
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
                  final status = (o['status'] ?? 'pending').toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('طلب #${o['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text(_statusText(status), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text((o['address'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(o['total'] ?? 0).toString()} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFB07D62))),
                            PopupMenuButton<String>(
                              onSelected: (v) => _updateStatus(o['id'].toString(), v),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'confirmed', child: Text('تأكيد الطلب')),
                                PopupMenuItem(value: 'shipped', child: Text('تم الشحن')),
                                PopupMenuItem(value: 'delivered', child: Text('تم التسليم')),
                                PopupMenuItem(value: 'cancelled', child: Text('إلغاء الطلب')),
                              ],
                              child: const Row(
                                children: [
                                  Text('تغيير الحالة', style: TextStyle(color: Color(0xFFB07D62), fontWeight: FontWeight.bold)),
                                  Icon(Icons.arrow_drop_down, color: Color(0xFFB07D62)),
                                ],
                              ),
                            ),
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

# ============ screens/merchant_profile_screen.dart ============
cat > apps/merchant/lib/screens/merchant_profile_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store.dart';
import 'login_screen.dart';

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
                if (_store?.phone != null) ...[
                  const SizedBox(height: 8),
                  Text(_store!.phone!, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }
}
FILE_END

# ============ تحديث dashboard_screen لاستخدام MainNav ============
cat > apps/merchant/lib/screens/dashboard_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import '../widgets/main_nav.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainNav();
  }
}
FILE_END

echo "setup-merchant-1c done"
