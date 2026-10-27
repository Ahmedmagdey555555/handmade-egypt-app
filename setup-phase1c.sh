#!/bin/bash
set -e

mkdir -p apps/customer/lib/screens

# ============ search_screen.dart ============
cat > apps/customer/lib/screens/search_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .ilike('title', '%$q%')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _results = data.map((e) => Product.fromMap(e)).toList();
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'ابحث...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ابحث عن منتج',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? const Center(child: Text('لا توجد نتائج'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (c, i) {
                        final p = _results[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(product: p),
                            ),
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
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                    child: p.imageUrl == null
                                        ? Container(
                                            color: Colors.grey.shade200,
                                          )
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${p.price.toStringAsFixed(0)} ج.م',
                                        style: const TextStyle(
                                          color: Color(0xFFB07D62),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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

# ============ cart_screen.dart ============
cat > apps/customer/lib/screens/cart_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: const Text('السلة'),
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 90,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'السلة فاضية',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final item = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.product.imageUrl == null
                            ? Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade200,
                              )
                            : CachedNetworkImage(
                                imageUrl: item.product.imageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.product.price.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                color: Color(0xFFB07D62),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      cart.decrement(item.product.id),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB07D62)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 18,
                                      color: Color(0xFFB07D62),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      cart.increment(item.product.id),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB07D62)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: Color(0xFFB07D62),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => cart.remove(item.product.id),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(fontSize: 17),
                        ),
                        Text(
                          '${cart.total.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB07D62),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CheckoutScreen(),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB07D62),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'إتمام الطلب',
                          style: TextStyle(fontSize: 16),
                        ),
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

# ============ checkout_screen.dart ============
cat > apps/customer/lib/screens/checkout_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _address = TextEditingController();
  final _phone = TextEditingController();
  String _payment = 'vodafone';
  String? _governorate;
  double _deliveryFee = 0;
  double _freeAbove = 750;
  bool _loading = false;

  final List<Map<String, dynamic>> _zones = [];
  final List<Map<String, dynamic>> _methods = [
    {'key': 'vodafone', 'name': 'فودافون كاش', 'icon': 'VF', 'enabled': true},
    {'key': 'etisalat', 'name': 'إتصالات كاش', 'icon': 'ET', 'enabled': true},
    {'key': 'instapay', 'name': 'إنستاباي', 'icon': 'IP', 'enabled': false},
    {'key': 'card', 'name': 'بطاقة بنكية', 'icon': 'CD', 'enabled': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final data = await Supabase.instance.client
          .from('delivery_zones')
          .select()
          .eq('is_active', true)
          .order('governorate');
      final settings = await Supabase.instance.client
          .from('app_settings')
          .select()
          .eq('key', 'free_delivery_threshold')
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _zones.addAll(data.cast<Map<String, dynamic>>());
        if (settings != null && settings['value'] != null) {
          _freeAbove = double.tryParse(settings['value'].toString()) ?? 750;
        }
      });
    } catch (_) {}
  }

  void _onGovernorateChanged(String? gov) {
    if (gov == null) return;
    final zone = _zones.firstWhere(
      (z) => z['governorate'] == gov,
      orElse: () => {},
    );
    setState(() {
      _governorate = gov;
      _deliveryFee = (zone['fee'] as num?)?.toDouble() ?? 0;
    });
  }

  double _calculateDelivery(double cartTotal) {
    if (cartTotal >= _freeAbove) return 0;
    return _deliveryFee;
  }

  Future<void> _submit() async {
    if (_address.text.isEmpty || _phone.text.isEmpty || _governorate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من فضلك أكمل كل البيانات')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final cart = context.read<CartProvider>();
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final delivery = _calculateDelivery(cart.total);

      final orderData = await Supabase.instance.client.from('orders').insert({
  'customer_id': uid,
  store_id': cart.items.values.first.product.storeId, // 
  'total': cart.total + delivery,
  'status': 'pending',
  'address': _address.text.trim(),
  'phone': _phone.text.trim(),
  'governorate': _governorate,
  'delivery_fee': delivery,
}).select().single();

final orderId = orderData['id'];

for (final item in cart.items.values) {
  await Supabase.instance.client.from('order_items').insert({
    'order_id': orderId,
    'product_id': item.product.id,
    'qty': item.quantity,
    'price': item.product.price,
  });
}

if (!mounted) return;
cart.clear();
_showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('تم الطلب'),
        content: const Text(
          'سيتم التواصل معاك خلال 24 ساعة لتحويل المبلغ وتأكيد الطلب.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final delivery = _calculateDelivery(cart.total);
    final isFree = cart.total >= _freeAbove && _governorate != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: const Text('إتمام الطلب'),
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'بيانات التوصيل',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _governorate,
            items: _zones
                .map((z) => DropdownMenuItem<String>(
                      value: z['governorate'] as String,
                      child: Text(z['governorate'] as String),
                    ))
                .toList(),
            onChanged: _onGovernorateChanged,
            decoration: InputDecoration(
              labelText: 'المحافظة',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _address,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'العنوان بالتفصيل',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'طريقة الدفع',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ..._methods.map((m) {
            final enabled = m['enabled'] as bool;
            final selected = _payment == m['key'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFB07D62)
                      : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
              ),
              child: ListTile(
                enabled: enabled,
                onTap: enabled
                    ? () => setState(() => _payment = m['key'] as String)
                    : null,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB07D62).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    m['icon'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB07D62),
                    ),
                  ),
                ),
                title: Text(
                  m['name'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black : Colors.grey,
                  ),
                ),
                trailing: !enabled
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'قريبًا',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : Radio<String>(
                        value: m['key'] as String,
                        groupValue: _payment,
                        activeColor: const Color(0xFFB07D62),
                        onChanged: (v) =>
                            setState(() => _payment = v ?? 'vodafone'),
                      ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFB07D62).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المنتجات', style: TextStyle(fontSize: 15)),
                    Text(
                      '${cart.total.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('التوصيل', style: TextStyle(fontSize: 15)),
                    _governorate == null
                        ? const Text('اختر المحافظة',
                            style: TextStyle(fontSize: 14, color: Colors.grey))
                        : isFree
                            ? const Text('مجاني',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ))
                            : Text(
                                '${delivery.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الإجمالي',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(cart.total + delivery).toStringAsFixed(0)} ج.م',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB07D62),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
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
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'تأكيد الطلب',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
FILE_END


# ============ custom_order_screen.dart ============
cat > apps/customer/lib/screens/custom_order_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomOrderScreen extends StatefulWidget {
  const CustomOrderScreen({super.key});

  @override
  State<CustomOrderScreen> createState() => _CustomOrderScreenState();
}

class _CustomOrderScreenState extends State<CustomOrderScreen> {
  final _desc = TextEditingController();
  final _budget = TextEditingController();
  final _time = TextEditingController();
  String _type = 'كروشيه';
  bool _loading = false;

  static const _types = [
    'كروشيه',
    'فخار',
    'ملابس',
    'إكسسوارات',
    'ليزر وطباعة',
    'ديكور',
    'جلود',
    'أخرى',
  ];

  Future<void> _submit() async {
    if (_desc.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب وصف الطلب')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('custom_orders').insert({
        'user_id': uid,
        'description': _desc.text.trim(),
        'budget': double.tryParse(_budget.text.trim()),
        'product_type': _type,
        'delivery_time': _time.text.trim(),
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب')),
      );
      Navigator.pop(context);
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
        title: const Text('طلب خاص'),
        backgroundColor: const Color(0xFFB07D62),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFB07D62).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB07D62)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اكتب طلبك بالتفصيل وسيتم التواصل معاك',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'نوع المنتج',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            items: _types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'كروشيه'),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'وصف الطلب *',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'مثال: عايز كروشيه بشكل معين، ألوان كذا وكذا...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'الميزانية المتوقعة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'بالجنيه المصري',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'وقت التسليم المطلوب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _time,
            decoration: InputDecoration(
              hintText: 'مثال: خلال أسبوع',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.schedule),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
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
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'إرسال الطلب',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
FILE_END

echo "setup-phase1c done"
