#!/bin/bash

echo "🚀 Starting Phase 3D: Product Video Upload..."

cd "$(dirname "$0")" || exit

# إضافة مكتبات الفيديو والكاميرا
if ! grep -q "image_picker" pubspec.yaml; then
  sed -i '' '/dependencies:/a\
  image_picker: ^1.0.7\
  video_compress: ^3.1.2
  ' pubspec.yaml
fi

# تعديل شاشة إضافة/تعديل المنتج لإضافة زرار الفيديو
# (بما إننا مش عارفين شكل الملف بتاعك بالظبط، هنستخدم sed عشان نضيف الاستيراد والزرار)
if [ -f "lib/screens/add_edit_product_screen.dart" ]; then
  # إضافة الاستيرادات
  sed -i '' "1s/^/import 'package:image_picker\/image_picker.dart';\nimport 'package:video_compress\/video_compress.dart';\nimport 'dart:io';\n/" lib/screens/add_edit_product_screen.dart
  
  # ملاحظة: هتحتاج تضيف الـ State Variables دي جوة الـ State بتاع الشاشة:
  # File? _videoFile;
  # bool _isUploadingVideo = false;
  
  # إضافة الزرار قبل زرار الحفظ
  sed -i '' '/حفظ المنتج/i\
  const SizedBox(height: 16),\
  ElevatedButton.icon(\
    onPressed: () async {\
      final ImagePicker picker = ImagePicker();\
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));\
      if (video != null) {\
        setState(() => _isUploadingVideo = true);\
        final compressed = await VideoCompress.compressVideo(video.path, quality: VideoQuality.MediumQuality);\
        setState(() {\
          _videoFile = File(compressed!.path!);\
          _isUploadingVideo = false;\
        });\
      }\
    },\
    icon: const Icon(Icons.video_library),\
    label: Text(_isUploadingVideo ? "جاري الضغط..." : (_videoFile != null ? "تم اختيار فيديو" : "اختيار فيديو للمنتج (اختياري)")),\
  ),\
  ' lib/screens/add_edit_product_screen.dart
fi

echo "✅ Phase 3D Completed: Video Picker Added!"
