#!/bin/bash
set -e

mkdir -p apps/customer/lib/screens
mkdir -p apps/customer/lib/models
mkdir -p apps/customer/lib/providers

# ============ 1. تحديث الموديلات ============
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
  final String? preparationTime;
  final String? availableOptions; // خيارات المنتج
  final int stock;
  final int hubStock;

  Product({
    required this.id, required this.title, this.description, required this.price,
    this.imageUrl, this.storeId, this.categoryId, this.warranty, this.preparationTime,
    this.availableOptions, this.stock = 0, this.hubStock = 0,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String, title: m['title'] as String, description: m['description'] as String?,
        price: (m['price'] as num).toDouble(), imageUrl: m['image_url'] as String?,
        storeId: m['store_id'] as String?, categoryId: m['category_id'] as String?,
        warranty: m['warranty'] as String?, preparationTime: m['preparation_time'] as String?,
        availableOptions: m['available_options'] as String?,
        stock: m['stock'] ?? 0, hubStock: m['hub_stock'] ?? 0,
      );
}
FILE_END

cat > apps/customer/lib/models/cart_item.dart << 'FILE_END'
import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  final String? selectedOptions; // الخيارات اللي العميل اختارها

  CartItem({required this.product, this.quantity = 1, this.selectedOptions});

  double get total => product.price * quantity;
}
FILE_END

# ============ 2. تحديث الـ Cart Provider عشان يدعم الخيارات ============
cat > apps/customer/lib/providers/cart_provider.dart << 'FILE_END'
import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;
  int get count => _items.values.fold(0, (s, i) => s + i.quantity);
  double get total => _items.values.fold(0, (s, i) => s + i.total);

  void add(Product p, {String? options}) {
    // لو المنتج ليه خيارات، بنعتبره منتج جديد عشان لو نفس المنتج بخيار تاني
    final key = options == null ? p.id : '${p.id}-$options';
    
    if (_items.containsKey(key)) {
      _items[key]!.quantity++;
    } else {
      _items[key] = CartItem(product: p, selectedOptions: options);
    }
    notifyListeners();
  }

  void remove(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void increment(String key) {
    _items[key]?.quantity++;
    notifyListeners();
  }

  void decrement(String key) {
    final item = _items[key];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(key);
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

# ============ 3. صفحة تفاصيل المنتج (تسأل عن الخيارات) ============
cat > apps/customer/lib/screens/product_detail_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/reviews_section.dart';
import 'store_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  void _addToCart(BuildContext context) {
    if (product.availableOptions == null || product.availableOptions!.isEmpty) {
      context.read<CartProvider>().add(product);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة للسلة')));
      return;
    }

    // لو فيه خيارات، نفتح شاشة نطلب منه يكتبها
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر مواصفات المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text('المتاح: ${product.availableOptions}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'اكتب اختيارك هنا (مثال: أحمر، مقاس L)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62)),
                onPressed: () {
                  if (controller.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('من فضلك اكتب اختيارك')));
                    return;
                  }
                  context.read<CartProvider>().add(product, options: controller.text.trim());
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة للسلة')));
                },
                child: const Text('إضافة للسلة'),
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
    final fav = context.watch<FavoritesProvider>();
    final isFav = fav.isFavorite(product.id);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: const Color(0xFFB07D62),
            foregroundColor: Colors.white,
            actions: [
              IconButton(onPressed: () => fav.toggle(product.id), icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: product.imageUrl == null ? Container(color: Colors.grey.shade300) : CachedNetworkImage(imageUrl: product.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  if (product.storeId != null)
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(storeId: product.storeId!, storeName: 'متجر التاجر'))),
                      child: const Row(
                        children: [
                          Icon(Icons.store, color: Color(0xFFB07D62), size: 20),
                          SizedBox(width: 5),
                          Text('زيارة المتجر', style: TextStyle(color: Color(0xFFB07D62), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 14),
                  Text('${product.price.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFB07D62))),
                  const SizedBox(height: 10),
                  Text('وقت التحضير: ${product.preparationTime ?? "فوري"}', style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                  
                  if (product.availableOptions != null && product.availableOptions!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('الخيارات المتاحة: ${product.availableOptions}', style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],

                  if (product.warranty != null) ...[
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [const Icon(Icons.shield, color: Colors.green), const SizedBox(width: 8), Text('ضمان: ${product.warranty}', style: const TextStyle(color: Colors.green))]),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  const Text('الوصف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(product.description ?? 'لا يوجد وصف', style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.6)),
                  
                  const SizedBox(height: 30),
                  ReviewsSection(productId: product.id),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SafeArea(
          child: FilledButton.icon(
            onPressed: () => _addToCart(context),
            icon: const Icon(Icons.shopping_cart),
            label: const Text('أضف للسلة', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ),
    );
  }
}
FILE_END

# ============ 4. صفحة السلة (عرض الخيارات) ============
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
      appBar: AppBar(title: const Text('السلة'), backgroundColor: const Color(0xFFB07D62), foregroundColor: Colors.white),
      body: items.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 90, color: Colors.grey.shade300), const SizedBox(height: 16), Text('السلة فاضية', style: TextStyle(fontSize: 18, color: Colors.grey.shade600))]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final item = items[i];
                final key = item.selectedOptions == null ? item.product.id : '${item.product.id}-${item.selectedOptions}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.product.imageUrl == null ? Container(width: 80, height: 80, color: Colors.grey.shade200) : CachedNetworkImage(imageUrl: item.product.imageUrl!, width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (item.selectedOptions != null)
                              Text('الخيار: ${item.selectedOptions}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('${item.product.price.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Color(0xFFB07D62), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _qtyBtn(Icons.remove, () => cart.decrement(key)),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                _qtyBtn(Icons.add, () => cart.increment(key)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => cart.remove(key), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي', style: TextStyle(fontSize: 17)), Text('${cart.total.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFB07D62)))]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('إتمام الطلب', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: const Color(0xFFB07D62).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: const Color(0xFFB07D62)),
      ),
    );
  }
}
FILE_END

# ============ 5. صفحة الدفع (خيار الهدية + رسوم التغليف) ============
cat > apps/customer/lib/screens/checkout_screen.dart << 'FILE_END'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _address = TextEditingController();
  final _building = TextEditingController();
  final _apartment = TextEditingController();
  final _landmark = TextEditingController();
  final _phone = TextEditingController();
  final _couponCode = TextEditingController();
  final _giftMessage = TextEditingController(); 
  
  String _payment = 'vodafone';
  String? _governorate;
  double _deliveryFee = 0;
  double _freeAbove = 750;
  bool _loading = false;
  bool _fetchingLocation = true;
  
  bool _isGift = false; 
  final double _giftFee = 20.0; // سعر تغليف الهدية (ممكن تغيره هنا)
  
  double _walletBalance = 0;
  bool _useWallet = false;
  
  double _discount = 0;
  String _couponMsg = '';
  File? _receiptImage;

  String _vodafoneNum = 'جاري التحميل...';
  String _etisalatNum = 'جاري التحميل...';
  String _instapayAddr = 'جاري التحميل...';

  final List<Map<String, dynamic>> _zones = [];
  final List<Map<String, dynamic>> _methods = [
    {'key': 'vodafone', 'name': 'فودافون كاش', 'icon': 'VF', 'enabled': true},
    {'key': 'etisalat', 'name': 'إتصالات كاش', 'icon': 'ET', 'enabled': true},
    {'key': 'instapay', 'name': 'إنستاباي', 'icon': 'IP', 'enabled': true},
    {'key': 'card', 'name': 'بطاقة بنكية', 'icon': 'CD', 'enabled': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _getLocation();
  }

  Future<void> _loadData() async {
    try {
      final data = await Supabase.instance.client.from('delivery_zones').select().eq('is_active', true);
      final settings = await Supabase.instance.client.from('app_settings').select();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      
      if (uid != null) {
        final wallet = await Supabase.instance.client.from('customer_wallets').select().eq('user_id', uid).maybeSingle();
        if (wallet != null) _walletBalance = (wallet['balance'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _zones.addAll(data.cast<Map<String, dynamic>>());
        for (var s in settings) {
          if (s['key'] == 'free_delivery_threshold') _freeAbove = double.tryParse(s['value'].toString()) ?? 750;
          if (s['key'] == 'vodafone_cash_number') _vodafoneNum = s['value'].toString();
          if (s['key'] == 'etisalat_cash_number') _etisalatNum = s['value'].toString();
          if (s['key'] == 'instapay_address') _instapayAddr = s['value'].toString();
        }
      });
    } catch (_) {}
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { setState(() => _fetchingLocation = false); return; }
      
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks[0];
        setState(() {
          _address.text = '${p.street ?? ''} - ${p.subLocality ?? ''}';
          if (p.administrativeArea != null) {
             final matched = _zones.firstWhere((z) => (z['governorate'] as String).contains(p.administrativeArea!), orElse: () => {});
             if (matched.isNotEmpty) _onGovChanged(matched['governorate']);
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _fetchingLocation = false);
  }

  void _onGovChanged(String? gov) {
    if (gov == null) return;
    final zone = _zones.firstWhere((z) => z['governorate'] == gov, orElse: () => {});
    setState(() { _governorate = gov; _deliveryFee = (zone['fee'] as num?)?.toDouble() ?? 0; });
  }

  double _calculateDelivery(double total) => total >= _freeAbove ? 0 : _deliveryFee;

  Future<void> _applyCoupon() async {
    if (_couponCode.text.isEmpty) return;
    setState(() => _couponMsg = 'جاري التحقق...');
    final data = await Supabase.instance.client.from('coupons').select().eq('code', _couponCode.text.trim()).eq('is_active', true).maybeSingle();
    
    if (data == null) { setState(() { _discount = 0; _couponMsg = 'كود غير صحيح'; }); return; }
    final total = context.read<CartProvider>().total;
    if (total < ((data['min_order_amount'] as num?)?.toDouble() ?? 0)) { setState(() { _discount = 0; _couponMsg = 'الحد الأدنى غير مكتمل'; }); return; }

    setState(() {
      _discount = data['discount_type'] == 'percentage' ? total * ((data['discount_value'] as num) / 100) : (data['discount_value'] as num).toDouble();
      _couponMsg = 'تم تطبيق خصم ${_discount.toStringAsFixed(0)} ج.م';
    });
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _receiptImage = File(picked.path));
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرقم')));
  }

  Future<void> _submit() async {
    if (_address.text.isEmpty || _phone.text.isEmpty || _governorate == null || _building.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل البيانات (العنوان ورقم العمارة مطلوبين)')));
      return;
    }
    if (_payment != 'card' && _receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مطلوب رفع صورة إيصال التحويل')));
      return;
    }

    setState(() => _loading = true);
    try {
      final cart = context.read<CartProvider>();
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final delivery = _calculateDelivery(cart.total);
      final currentGiftFee = _isGift ? _giftFee : 0.0;
      
      final walletUsed = _useWallet ? (_walletBalance > (cart.total + delivery + currentGiftFee - _discount) ? (cart.total + delivery + currentGiftFee - _discount) : _walletBalance) : 0;
      final finalTotal = cart.total + delivery + currentGiftFee - _discount - walletUsed;

      String? receiptUrl;
      if (_receiptImage != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('receipts').upload(fileName, _receiptImage!);
        receiptUrl = Supabase.instance.client.storage.from('receipts').getPublicUrl(fileName);
      }

      if (walletUsed > 0) {
        await Supabase.instance.client.from('wallet_transactions').insert({'user_id': uid, 'amount': walletUsed, 'type': 'debit', 'description': 'خصم طلب'});
        await Supabase.instance.client.from('customer_wallets').update({'balance': _walletBalance - walletUsed}).eq('user_id', uid);
      }

      final orderData = await Supabase.instance.client.from('orders').insert({
        'customer_id': uid, 'store_id': cart.items.values.first.product.storeId, 'total': finalTotal,
        'status': 'pending', 'address': _address.text.trim(), 'phone': _phone.text.trim(),
        'governorate': _governorate, 'delivery_fee': delivery,
        'building_no': _building.text.trim(), 'apartment_no': _apartment.text.trim(), 'landmark': _landmark.text.trim(),
        'receipt_image_url': receiptUrl, 'payment_method': _payment,
        'is_gift': _isGift, 'gift_message': _isGift ? _giftMessage.text.trim() : null,
        'gift_fee': currentGiftFee, // حفظ رسوم الهدية
      }).select().single();

      for (final item in cart.items.values) {
        await Supabase.instance.client.from('order_items').insert({
          'order_id': orderData['id'], 'product_id': item.product.id, 'qty': item.quantity, 'price': item.product.price,
        });
      }

      if (!mounted) return;
      cart.clear();
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الطلب بنجاح')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final delivery = _calculateDelivery(cart.total);
    final currentGiftFee = _isGift ? _giftFee : 0.0;
    
    final walletUsed = _useWallet ? (_walletBalance > (cart.total + delivery + currentGiftFee - _discount) ? (cart.total + delivery + currentGiftFee - _discount) : _walletBalance) : 0;
    final finalTotal = cart.total + delivery + currentGiftFee - _discount - walletUsed;

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب'), backgroundColor: const Color(0xFFB07D62), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('بيانات التوصيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _governorate,
            items: _zones.map((z) => DropdownMenuItem<String>(value: z['governorate'] as String, child: Text(z['governorate'] as String))).toList(),
            onChanged: _onGovChanged,
            decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _address, maxLines: 2,
            decoration: InputDecoration(
              labelText: 'اسم الشارع (إجباري)', border: const OutlineInputBorder(),
              suffixIcon: _fetchingLocation ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.my_location), onPressed: _getLocation),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _building, decoration: const InputDecoration(labelText: 'رقم العمارة', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _apartment, decoration: const InputDecoration(labelText: 'رقم الشقة', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _landmark, decoration: const InputDecoration(labelText: 'علامة مميزة', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
          
          const SizedBox(height: 20),
          
          // --- خيار الهدية ---
          SwitchListTile(
            title: const Text('إرسال كهدية 🎁', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('سنقوم بتغليف الطلب كهدية (+$_giftFee ج.م)'),
            value: _isGift,
            activeColor: const Color(0xFFB07D62),
            onChanged: (v) => setState(() => _isGift = v),
          ),
          if (_isGift)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _giftMessage,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'اكتب رسالة الهدية هنا...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.card_giftcard)),
              ),
            ),
          
          const SizedBox(height: 20),
          const Text('طريقة الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ..._methods.map((m) => ListTile(
            leading: Radio<String>(value: m['key'] as String, groupValue: _payment, onChanged: (v) => setState(() => _payment = v!)),
            title: Text(m['name'] as String),
            enabled: m['enabled'] as bool,
          )),
          
          if (_payment != 'card') ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFB07D62).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB07D62).withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('يرجى تحويل المبلغ على هذا الرقم:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB07D62))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_payment == 'vodafone' ? _vodafoneNum : (_payment == 'etisalat' ? _etisalatNum : _instapayAddr), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      IconButton(icon: const Icon(Icons.copy, color: Color(0xFFB07D62)), onPressed: () => _copyToClipboard(_payment == 'vodafone' ? _vodafoneNum : (_payment == 'etisalat' ? _etisalatNum : _instapayAddr))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: const Icon(Icons.upload_file),
              label: Text(_receiptImage == null ? 'رفع صورة إيصال التحويل' : 'تم اختيار الإيصال ✅'),
            ),
          ],

          const SizedBox(height: 20),
          TextField(
            controller: _couponCode,
            decoration: InputDecoration(labelText: 'كود خصم', border: const OutlineInputBorder(), suffixIcon: TextButton(onPressed: _applyCoupon, child: const Text('تطبيق'))),
          ),
          if (_couponMsg.isNotEmpty) Text(_couponMsg, style: TextStyle(color: _discount > 0 ? Colors.green : Colors.red)),

          if (_walletBalance > 0) SwitchListTile(
            title: Text('استخدام رصيد المحفظة (${_walletBalance.toStringAsFixed(0)} ج.م)'),
            value: _useWallet, onChanged: (v) => setState(() => _useWallet = v),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFB07D62).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المنتجات', style: TextStyle(fontSize: 15)), Text('${cart.total.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('التوصيل', style: TextStyle(fontSize: 15)), Text(delivery == 0 ? 'مجاني' : '${delivery.toStringAsFixed(0)} ج.م', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: delivery == 0 ? Colors.green : Colors.black))]),
                
                // سطر رسوم الهدية
                if (_isGift) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('تغليف هدية', style: TextStyle(fontSize: 15, color: Colors.orange)), Text('+ ${_giftFee.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.orange))]),
                ],

                if (_discount > 0) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الخصم', style: TextStyle(fontSize: 15, color: Colors.green)), Text('- ${_discount.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.green))]),
                ],
                if (walletUsed > 0) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('من المحفظة', style: TextStyle(fontSize: 15, color: Colors.blue)), Text('- ${walletUsed.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue))]),
                ],
                const Divider(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Text('${finalTotal.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFB07D62)))]),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد الطلب'),
          ),
        ],
      ),
    );
  }
}
FILE_END

# ============ 6. صفحة تسجيل الدخول (Google/Facebook) ============
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
        await auth.signUp(email: _email.text.trim(), password: _password.text.trim());
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text.trim());
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _socialLogin(OAuthProvider provider) async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(provider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ، تأكد من إعدادات التطبيق')));
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
              const SizedBox(height: 40),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(color: const Color(0xFFB07D62), borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.handyman, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('Handmade', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF2C1810), letterSpacing: 2)),
              const SizedBox(height: 8),
              Text(_isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 30),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 16),
              TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07D62), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isSignUp ? 'إنشاء الحساب' : 'تسجيل الدخول', style: const TextStyle(fontSize: 16)),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp ? 'عندك حساب؟ سجّل دخول' : 'معندكش حساب؟ اعمل واحد', style: const TextStyle(color: Color(0xFFB07D62))),
              ),
              
              const SizedBox(height: 20),
              const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("أو سجل باستخدام", style: TextStyle(color: Colors.grey))), Expanded(child: Divider())]),
              const SizedBox(height: 20),
              
              // أزرار السوشيال ميديا
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _socialLogin(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red), // أيقونة جوجل
                    label: const Text('Google', style: TextStyle(color: Colors.black)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), side: const BorderSide(color: Colors.grey)),
                  ),
                  const SizedBox(width: 15),
                  OutlinedButton.icon(
                    onPressed: () => _socialLogin(OAuthProvider.facebook),
                    icon: const Icon(Icons.facebook, size: 24, color: Colors.blue),
                    label: const Text('Facebook', style: TextStyle(color: Colors.black)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), side: const BorderSide(color: Colors.grey)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
FILE_END

# ============ 7. تحديث الـ Home Screen (البنرات) ============
# (نفس الكود اللي بعتهولك فوق في الرسالة السابقة عشان البنرات تظبط)
cat > apps/customer/lib/screens/home_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/ad.dart';
import 'product_detail_screen.dart';
import 'category_products_screen.dart';
import 'search_screen.dart';
import 'custom_order_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sb = Supabase.instance.client;
  List<Product> _products = [];
  List<Category> _categories = [];
  List<Ad> _ads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _sb.from('products').select().order('created_at', ascending: false),
        _sb.from('categories').select().order('name'),
        _sb.from('ads').select().eq('is_active', true),
      ]);
      if (!mounted) return;
      
      final rawProducts = (results[0] as List).map((e) => Product.fromMap(e)).toList();
      final availableProducts = rawProducts.where((p) => (p.hubStock + p.stock) > 0).toList();

      setState(() {
        _products = availableProducts;
        _categories = (results[1] as List).map((e) => Category.fromMap(e)).toList();
        _ads = (results[2] as List).map((e) => Ad.fromMap(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomOrderScreen())),
        backgroundColor: const Color(0xFFB07D62),
        icon: const Icon(Icons.edit_note, color: Colors.white),
        label: const Text('اطلب طلب خاص', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.grey.shade500),
                                const SizedBox(width: 10),
                                Text('ابحث عن منتج...', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_ads.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _ads[0].imageUrl == null
                                ? Container(height: 150, color: Colors.grey.shade300)
                                : CachedNetworkImage(imageUrl: _ads[0].imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text('الأقسام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C1810))),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _categories.length,
                          itemBuilder: (c, i) {
                            final cat = _categories[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: cat))),
                              child: Container(
                                width: 90,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 66, height: 66,
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                      alignment: Alignment.center,
                                      child: Text(cat.icon ?? '📦', style: const TextStyle(fontSize: 30)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(cat.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_ads.length > 1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _ads.length - 1,
                              itemBuilder: (c, i) {
                                final ad = _ads[i + 1];
                                return Container(
                                  width: 220,
                                  margin: const EdgeInsets.only(left: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ad.imageUrl == null
                                        ? Container(color: Colors.grey.shade300)
                                        : CachedNetworkImage(imageUrl: ad.imageUrl!, fit: BoxFit.cover),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text('المنتجات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C1810))),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
                        delegate: SliverChildBuilderDelegate(
                          (c, i) {
                            final p = _products[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
                              child: Container(
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                        child: p.imageUrl == null
                                            ? Container(color: Colors.grey.shade200)
                                            : CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.cover, width: double.infinity),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Text('${p.price.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Color(0xFFB07D62), fontWeight: FontWeight.bold, fontSize: 15)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _products.length,
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

echo "setup-phase1i done"
