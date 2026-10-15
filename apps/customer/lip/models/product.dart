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
