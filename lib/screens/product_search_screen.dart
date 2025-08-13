import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io';
import 'dart:convert';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  List<dynamic> _results = [];
  String? _errorMessage;

  final String apiUrl = "http://10.0.2.2:8000/gorsel-ile-ara/";

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _results = [];
        _errorMessage = null;
      });
      _searchSimilarProducts();
    }
  }

  Future<void> _searchSimilarProducts() async {
    if (_selectedImage == null) return;
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('image_file', _selectedImage!.path),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        var decodedResponse = json.decode(responseBody);
        setState(() {
          _results = decodedResponse['results'] ?? [];
        });
      } else {
        setState(() => _errorMessage = 'Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Bağlantı hatası oluştu. Lütfen backend sunucunuzun çalıştığından emin olun.');
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görsel Ürün Arama'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Uygulama Hakkında',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Görsel Arama Prototipi',
                applicationVersion: 'v1.0.0',
                applicationLegalese: '© 2025 Sem Samsum',
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: Text('Bu uygulama, FastAPI, TensorFlow ve Flutter kullanılarak geliştirilmiş bir hızlı prototipleme çalışmasıdır.'),
                  )
                ],
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: 500.ms,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
              },
              child: _selectedImage == null
                  ? _buildImagePickerPlaceholder()
                  : _buildSelectedImage(),
            ),
            
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text("Galeri"),
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text("Kamera"),
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
            
            const SizedBox(height: 24),
            
            Expanded(
              child: _isLoading
                  ? _buildShimmerLoading()
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center))
                      : _results.isEmpty && _selectedImage != null
                          ? const Center(child: Text("Benzer ürün bulunamadı.", style: TextStyle(fontSize: 16)))
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final result = _results[index];
                                final score = (result['benzerlik_skoru'] * 100).toStringAsFixed(1);
                                
                                // --- SON VE KESİN DÜZELTME BURASI ---
                                // Hatalı `Animate` widget'ı yerine, en başta kullandığımız
                                // `.animate()` zincirleme metoduna geri döndük. `delay`
                                // parametresi doğrudan efektlerin içinde olduğunda genellikle
                                // daha stabil çalışır.
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    title: Text(result['urun_adi'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                    trailing: Text(
                                      "Benzerlik: %$score",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: (150 * index).ms, duration: 500.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.5, duration: 500.ms, curve: Curves.easeOut);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerPlaceholder() {
    return InkWell(
      key: const ValueKey('placeholder'),
      onTap: () => _pickImage(ImageSource.gallery),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 64, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            const Text('Aramak için resim seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImage() {
    return ClipRRect(
      key: ValueKey(_selectedImage!.path),
      borderRadius: BorderRadius.circular(12),
      child: Image.file(_selectedImage!, height: 250, fit: BoxFit.cover, width: double.infinity),
    );
  }
  
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Container(height: 16, width: 150, color: Colors.white),
            trailing: Container(height: 16, width: 80, color: Colors.white),
          ),
        ),
      ),
    );
  }
}