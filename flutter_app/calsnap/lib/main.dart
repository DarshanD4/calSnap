import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalSnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: "100");

  Timer? _debounceTimer;
  List<String> _suggestions = [];

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  bool _loading = false;
  String _result = "";

  final _base = "http://10.0.2.2:5000"; // Emulator -> Host PC

  // 🔥 Remove overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // 🔥 Build each suggestion item
  Widget buildSuggestionItem(String text) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.restaurant_menu,
            size: 18,
            color: Colors.blue.shade700,
          ),
        ),
        title: Text(
          text,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        onTap: () {
          _searchCtrl.text = text;
          _removeOverlay();
        },
      ),
    );
  }

  // 🔥 Build the floating Google-style dropdown
  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 40,
        top: 170,
        left: 20,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.1)),
              ],
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                // CATEGORY HEADER
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 16, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        "SIMILAR FOODS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Suggestion items
                ..._suggestions.map((s) => buildSuggestionItem(s)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 Update autocomplete suggestions with debounce
  void _updateSuggestions(String query) {
    if (_debounceTimer != null && _debounceTimer!.isActive) {
      _debounceTimer!.cancel();
    }

    if (query.trim().isEmpty) {
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(Duration(milliseconds: 300), () async {
      final uri = Uri.parse(
        "$_base/autocomplete?query=${Uri.encodeComponent(query)}",
      );

      try {
        final res = await http.get(uri);

        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);

          setState(() => _suggestions = data.cast<String>());

          _removeOverlay();

          if (_suggestions.isNotEmpty) {
            _overlayEntry = _createOverlayEntry();
            Overlay.of(context).insert(_overlayEntry!);
          }
        }
      } catch (e) {
        _removeOverlay();
      }
    });
  }

  // 🔥 Fetch nutrition from backend
  Future<void> lookupName() async {
    final name = _searchCtrl.text.trim();
    final qty = _qtyCtrl.text.trim();

    if (name.isEmpty || qty.isEmpty) {
      _showSnackBar("Enter both food name & quantity");
      return;
    }

    _removeOverlay();

    setState(() {
      _loading = true;
      _result = "";
    });

    final uri = Uri.parse(
      "$_base/lookup?name=${Uri.encodeComponent(name)}&qty_g=$qty",
    );

    try {
      final res = await http.get(uri);
      setState(() {
        _loading = false;
        _result = res.body;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _result = "Error connecting to server";
      });
    }
  }

  // 🔥 Upload photo
  Future<void> pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.camera);

    if (img == null) return;

    _removeOverlay();

    setState(() => _loading = true);

    try {
      final request = http.MultipartRequest("POST", Uri.parse("$_base/upload"));
      request.files.add(await http.MultipartFile.fromPath("image", img.path));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      setState(() {
        _loading = false;
        _result = resp.body;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _result = "Error uploading image";
      });
    }
  }

  // 🔥 Create Food Modal
  void _showAddFoodModal() {
    final TextEditingController nameCtrl = TextEditingController(
      text: _searchCtrl.text,
    );
    final TextEditingController calCtrl = TextEditingController();
    final TextEditingController proCtrl = TextEditingController();
    final TextEditingController carbCtrl = TextEditingController();
    final TextEditingController fatCtrl = TextEditingController();

    List<XFile> images = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              margin: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black.withOpacity(0.2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Create New Food",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 24),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Add nutritional information and images",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 24),

                      // Food Name
                      _buildFormField(
                        controller: nameCtrl,
                        label: "Food Name",
                        icon: Icons.restaurant,
                        isRequired: true,
                      ),
                      SizedBox(height: 16),

                      // Nutrition Fields in 2 columns
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              controller: calCtrl,
                              label: "Calories per 100g",
                              icon: Icons.local_fire_department,
                              keyboardType: TextInputType.number,
                              isRequired: true,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              controller: proCtrl,
                              label: "Protein (g)",
                              icon: Icons.fitness_center,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              controller: carbCtrl,
                              label: "Carbs (g)",
                              icon: Icons.energy_savings_leaf,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              controller: fatCtrl,
                              label: "Fat (g)",
                              icon: Icons.water_drop,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Image Upload Section
                      Text(
                        "Upload Images (3-4 recommended)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Add multiple angles for better AI recognition",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Image Grid
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            // Existing Images
                            for (var img in images)
                              Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: FileImage(File(img.path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => images.remove(img));
                                      },
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // Add Image Button
                            if (images.length < 6)
                              GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (picked != null) {
                                    setState(() => images.add(picked));
                                  }
                                },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        size: 24,
                                        color: Colors.grey.shade600,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Add",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameCtrl.text.isEmpty ||
                                calCtrl.text.isEmpty ||
                                images.isEmpty) {
                              _showSnackBar(
                                "Please fill required fields and add at least one image",
                              );
                              return;
                            }

                            var req = http.MultipartRequest(
                              "POST",
                              Uri.parse("$_base/food/create"),
                            );

                            req.fields['name'] = nameCtrl.text.toLowerCase();
                            req.fields['calories'] = calCtrl.text;
                            req.fields['protein'] = proCtrl.text.isEmpty
                                ? "0"
                                : proCtrl.text;
                            req.fields['carbs'] = carbCtrl.text.isEmpty
                                ? "0"
                                : carbCtrl.text;
                            req.fields['fats'] = fatCtrl.text.isEmpty
                                ? "0"
                                : fatCtrl.text;

                            for (var img in images) {
                              req.files.add(
                                await http.MultipartFile.fromPath(
                                  "images",
                                  img.path,
                                ),
                              );
                            }

                            try {
                              final res = await req.send();
                              if (res.statusCode == 200) {
                                Navigator.pop(context);
                                _showSnackBar("🎉 Food created successfully!");
                                // Clear the form
                                _searchCtrl.clear();
                                _qtyCtrl.text = "100";
                                setState(() => _result = "");
                              } else {
                                _showSnackBar("Error creating food");
                              }
                            } catch (e) {
                              _showSnackBar("Connection error");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "SAVE FOOD",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🔥 Helper for form fields
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            if (isRequired) Text(" *", style: TextStyle(color: Colors.red)),
          ],
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.blue.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  // 🔥 Parse result string and build UI
  Widget buildResultCard() {
    if (_result.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 12),
            Text(
              "No results yet",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Search for a food or take a photo to get started",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    try {
      final data = jsonDecode(_result);

      // If data has matches (no exact match found)
      if (data is Map && data.containsKey("matches")) {
        final matches = data["matches"] as List;
        if (matches.isEmpty) {
          return Column(
            children: [
              Icon(
                Icons.food_bank_outlined,
                size: 48,
                color: Colors.orange.shade400,
              ),
              SizedBox(height: 16),
              Text(
                "Food Not Found",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "This food isn't in our database yet",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showAddFoodModal,
                icon: Icon(Icons.add_circle_outline),
                label: Text("CREATE FOOD ENTRY"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade500,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Did you mean:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            ...matches
                .map(
                  (m) => ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.search, color: Colors.blue, size: 18),
                    ),
                    title: Text(m.toString()),
                    onTap: () {
                      _searchCtrl.text = m.toString();
                      lookupName();
                    },
                  ),
                )
                .toList(),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _showAddFoodModal,
                icon: Icon(Icons.add),
                label: Text("Create New Food"),
              ),
            ),
          ],
        );
      }

      // If data is a single item with nutrition info
      final name = data["name"] ?? data["dish"] ?? "food";
      final q = data["quantity_g"] ?? data["qty_g"] ?? 100;
      final calories = data["calories"] ?? 0;
      final protein = data["protein"] ?? 0;
      final carbs = data["carbohydrates"] ?? data["carbs"] ?? 0;
      final fats = data["fats"] ?? data["fats"] ?? 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$name • ${q}g",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip("🔥 ${calories} kcal"),
              chip("💪 ${protein}g protein"),
              chip("⚡ ${carbs}g carbs"),
              chip("🧈 ${fats}g fat"),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Save to local DB & server
                    final items = [
                      {"name": name, "qty_g": q, "calories": calories},
                    ];
                    final ts = DateTime.now().millisecondsSinceEpoch;

                    // TODO: Uncomment when DBHelper is available
                    /*
                    // local
                    await DBHelper.insertMeal({
                      "id": ts,
                      "timestamp": ts,
                      "note": "",
                      "total_calories": calories,
                      "items": jsonEncode(items)
                    });
                    */

                    // server
                    try {
                      await http.post(
                        Uri.parse("$_base/meal/add"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "items": items,
                          "timestamp": (ts / 1000).round(),
                          "note": "",
                        }),
                      );
                    } catch (e) {
                      print("Server save error: $e");
                    }

                    _showSnackBar("Saved to history");
                  },
                  icon: Icon(Icons.save, size: 20),
                  label: Text("Save"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Add to favorites on server
                    try {
                      await http.post(
                        Uri.parse("$_base/fav/add"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({"name": name}),
                      );
                      _showSnackBar("Added to favorites");
                    } catch (e) {
                      _showSnackBar("Error adding to favorites");
                    }
                  },
                  icon: Icon(Icons.star_border, size: 20),
                  label: Text("Favorite"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } catch (e) {
      // If JSON parsing fails, show raw result
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(height: 8),
            Text(
              "Error parsing result",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _result,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
  }

  Widget chip(String s) => Chip(
    label: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    backgroundColor: Colors.blue.shade50,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: BorderSide.none,
  );

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CalSnap", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // 🔷 SEARCH FOOD CARD
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        "Search Food",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),

                      SizedBox(height: 20),

                      // 🔥 GOOGLE-STYLE AUTOCOMPLETE FIELD
                      CompositedTransformTarget(
                        link: _layerLink,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _updateSuggestions,
                          decoration: InputDecoration(
                            labelText: "Food name",
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.blue.shade600,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Quantity
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Quantity in grams",
                          prefixIcon: Icon(
                            Icons.scale,
                            color: Colors.blue.shade600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixText: "g",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),

                      SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: lookupName,
                              icon: Icon(Icons.analytics),
                              label: Text("LOOKUP NUTRITION"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            width: 50,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _showAddFoodModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade500,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Icon(Icons.add, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // 🔷 PHOTO ANALYSIS CARD
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        "Photo Analysis",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),

                      SizedBox(height: 16),
                      Text(
                        "Take a photo of your food for instant analysis",
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: pickAndUpload,
                        icon: Icon(Icons.camera_alt),
                        label: Text("TAKE PHOTO"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // 🔷 RESULTS CARD
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            color: Colors.blue.shade700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Results",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      if (_loading)
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                "Analyzing...",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),

                      if (!_loading) buildResultCard(),
                    ],
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
