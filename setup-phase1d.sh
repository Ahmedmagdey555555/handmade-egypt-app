#!/bin/bash
set -e

mkdir -p apps/customer/lib/screens
mkdir -p apps/customer/lib/providers

# ============ providers/favorites_provider.dart ============
cat > apps/customer/lib/providers/favorites_provider.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _ids = {};

  Set<String> get ids => _ids;
  bool isFavorite(String id) => _ids.contains(id);
  int get count => _ids.length;

  Future<void> load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await Supabase.instance.client
          .from('favorites')
          .select('product_id')
          .eq('user_id', uid);
      _ids.clear();
      for (final row in data) {
        _ids.add(row['product_id'].toString());
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle(String productId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      if (_ids.contains(productId)) {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', uid)
            .eq('product_id', productId);
        _ids.remove(productId);
      } else {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': uid,
          'product_id': productId,
        });
        _ids.add(productId);
      }
      notifyListeners();
    } catch (_) {}
  }
}
FILE_END

# ============ screens/favorites_screen.dart ============
cat > apps/customer/lib/screens/favorites_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../providers/favorites_provider.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fav = context.read<FavoritesProvider>();
    await fav.load();
    if (fav.ids.isEmpty) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _loading = false;
      });
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .inFilter('id', fav.ids.toList());
      if (!mounted) return;
      setState(() {
        _products = data.map((e) => Product.fromMap(e)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 90, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('مفيش منتجات في المفضلة',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _products.length,
        itemBuilder: (c, i) {
          final p = _products[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(14)),
                      child: p.imageUrl == null
                          ? Container(color: Colors.grey.shade200)
                          : CachedNetworkImage(
                              imageUrl: p.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${p.price.toStringAsFixed(0)} ج.م',
                            style: const TextStyle(
                                color: Color(0xFFB07D62),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
FILE_END

# ============ screens/orders_screen.dart ============
cat > apps/customer/lib/screens/orders_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('customer_id', uid)
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

  String _statusText(String s) {
    switch (s) {
      case 'pending':
        return 'قيد المراجعة';
      case 'confirmed':
        return 'تم التأكيد';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 90, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('مفيش طلبات لسه',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return RefreshIndicator(
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'طلب #${o['id'].toString().substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusText(status),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (o['address'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(o['total'] ?? 0).toString()} ج.م',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFB07D62),
                      ),
                    ),
                    Text(
                      (o['created_at'] ?? '').toString().split('T').first,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
FILE_END

# ============ screens/profile_screen.dart ============
cat > apps/customer/lib/screens/profile_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'privacy_policy_screen.dart';
import 'support_screen.dart';
import 'about_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('متأكد إنك عايز تسجّل خروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB07D62).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person,
                      size: 44, color: Color(0xFFB07D62)),
                ),
                const SizedBox(height: 12),
                Text(
                  email.split('@').first,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            Icons.support_agent,
            'خدمة العملاء',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
          _menuItem(
            context,
            Icons.privacy_tip_outlined,
            'سياسة الخصوصية',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          ),
          _menuItem(
            context,
            Icons.info_outline,
            'عن التطبيق',
            () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          const SizedBox(height: 16),
          _menuItem(
            context,
            Icons.logout,
            'تسجيل الخروج',
            () => _logout(context),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? const Color(0xFFB07D62)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
FILE_END

# ============ screens/support_screen.dart ============
cat > apps/customer/lib/screens/support_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _phone = '';
  String _whatsapp = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await Supabase.instance.client
          .from('app_settings')
          .select()
          .inFilter('key', ['support_phone', 'whatsapp_number']);
      for (final row in data) {
        if (row['key'] == 'support_phone') _phone = row['value'].toString();
        if (row['key'] == 'whatsapp_number') _whatsapp = row['value'].toString();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:$_phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsappOpen() async {
    final uri = Uri.parse('https://wa.me/$_whatsapp');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openTicketForm() {
    final subject = TextEditingController();
    final message = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أرسل استفسار',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: subject,
              decoration: const InputDecoration(
                labelText: 'الموضوع',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'الرسالة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB07D62),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  if (subject.text.isEmpty || message.text.isEmpty) return;
                  final uid = Supabase.instance.client.auth.currentUser!.id;
                  await Supabase.instance.client.from('support_tickets').insert({
                    'user_id': uid,
                    'subject': subject.text.trim(),
                    'message': message.text.trim(),
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال استفسارك')),
                  );
                },
                child: const Text('إرسال'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: const Text('خدمة العملاء'),
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _actionCard(
            Icons.phone,
            'اتصل بنا',
            _phone.isEmpty ? 'جاري التحميل...' : _phone,
            _phone.isEmpty ? null : _call,
          ),
          _actionCard(
            Icons.chat,
            'واتساب',
            'محادثة مباشرة',
            _whatsapp.isEmpty ? null : _whatsappOpen,
          ),
          _actionCard(
            Icons.email_outlined,
            'أرسل استفسار',
            'سيتم الرد خلال 24 ساعة',
            _openTicketForm,
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
      IconData icon, String title, String subtitle, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFB07D62).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFB07D62)),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
FILE_END

# ============ screens/privacy_policy_screen.dart ============
cat > apps/customer/lib/screens/privacy_policy_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _content = '''
سياسة الخصوصية - Handmade

آخر تحديث: 2026

مرحبًا بك في تطبيق Handmade. نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. توضح هذه السياسة كيفية جمعنا واستخدامنا وحمايتنا لمعلوماتك.

1. البيانات التي نجمعها:
- البريد الإلكتروني عند التسجيل
- رقم الهاتف عند الطلب
- عنوان التوصيل
- الموقع الجغرافي (لتسهيل التوصيل)
- بيانات الطلبات

2. كيف نستخدم بياناتك:
- معالجة طلباتك وتوصيلها
- التواصل معك بخصوص طلباتك
- تحسين خدماتنا
- إرسال إشعارات مهمة

3. حماية البيانات:
نستخدم تقنيات تشفير حديثة لحماية بياناتك، ولا نشاركها مع أي طرف ثالث إلا لأغراض التوصيل.

4. حقوقك:
- الوصول لبياناتك
- تعديلها أو حذفها
- إلغاء حسابك في أي وقت
- الاعتراض على معالجة بياناتك

5. ملفات تعريف الارتباط:
لا نستخدم ملفات تعريف ارتباط لأغراض إعلانية.

6. الأطفال:
التطبيق غير موجه للأطفال تحت 13 عامًا.

7. التعديلات:
قد نحدّث هذه السياسة من وقت لآخر، وسنخبرك بأي تغييرات مهمة.

8. التواصل:
لأي استفسار بخصوص الخصوصية، تواصل معنا عبر صفحة "خدمة العملاء".

باستخدامك للتطبيق، أنت توافق على هذه السياسة.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: const Text('سياسة الخصوصية'),
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          _content,
          style: TextStyle(fontSize: 15, height: 1.8),
        ),
      ),
    );
  }
}
FILE_END

# ============ screens/about_screen.dart ============
cat > apps/customer/lib/screens/about_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: const Text('عن التطبيق'),
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFB07D62),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.handyman, size: 70, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Handmade',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C1810),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الإصدار 1.0.0',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'تطبيق مصري متخصص في بيع المنتجات اليدوية\n'
                'من مشغولات كروشيه وفخار وجلود وليزر\n\n'
                'هدفنا دعم الحرفيين المصريين\n'
                'وتوصيل شغلهم لأكبر عدد من العملاء\n\n'
                'صُنع بحب في مصر',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
FILE_END

echo "setup-phase1d done"
