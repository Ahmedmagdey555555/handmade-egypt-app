#!/bin/bash
set -e

mkdir -p apps/customer/lib/screens
mkdir -p apps/customer/lib/models

# ============ Store Screen (صفحة التاجر) ============
cat > apps/customer/lib/screens/store_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class StoreScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  const StoreScreen({super.key, required this.storeId, required this.storeName});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = Supabase.instance.client
        .from('products')
        .select()
        .eq('store_id', widget.storeId)
        .order('created_at', ascending: false)
        .then((rows) => rows.map((r) => Product.fromMap(r)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(title: Text(widget.storeName), backgroundColor: const Color(0xFFB07D62), foregroundColor: Colors.white),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final items = snap.data ?? [];
          if (items.isEmpty) return const Center(child: Text('لا توجد منتجات لهذا المتجر'));
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
            itemCount: items.length,
            itemBuilder: (c, i) {
              final p = items[i];
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
                          child: p.imageUrl == null ? Container(color: Colors.grey.shade200) : CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.cover, width: double.infinity),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${p.price.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Color(0xFFB07D62), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
FILE_END

# ============ Product Detail (تحديث لفتح صفحة التاجر) ============
cat > apps/customer/lib/screens/product_detail_screen.dart << 'FILE_END'
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/reviews_section.dart';
import 'store_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

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
                  
                  // زر الانتقال لصفحة التاجر
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
            onPressed: () {
              context.read<CartProvider>().add(product);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة للسلة'), duration: Duration(seconds: 1)));
            },
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

# ============ تحديث Model Product (إضافة وقت التحضير) ============
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
  final int stock;
  final int hubStock;

  Product({
    required this.id, required this.title, this.description, required this.price,
    this.imageUrl, this.storeId, this.categoryId, this.warranty, this.preparationTime,
    this.stock = 0, this.hubStock = 0,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String, title: m['title'] as String, description: m['description'] as String?,
        price: (m['price'] as num).toDouble(), imageUrl: m['image_url'] as String?,
        storeId: m['store_id'] as String?, categoryId: m['category_id'] as String?,
        warranty: m['warranty'] as String?, preparationTime: m['preparation_time'] as String?,
        stock: m['stock'] ?? 0, hubStock: m['hub_stock'] ?? 0,
      );
}
FILE_END

echo "setup-phase1h done"
