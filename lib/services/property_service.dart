import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/property.dart';

/// Service that manages [Property] records using Supabase.
///
/// Follows the exact same pattern as [CustomerService].
class PropertyService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'properties';
  static const String _storageBucket = 'property-images';

  List<Property> _properties = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  /// Filtered list used by the UI.
  List<Property> get properties {
    if (_searchQuery.trim().isEmpty) return _properties;
    final q = _searchQuery.trim().toLowerCase();
    return _properties
        .where((p) =>
            p.projectName.toLowerCase().contains(q) ||
            p.location.toLowerCase().contains(q))
        .toList();
  }

  List<Property> get allPropertiesUnfiltered => _properties;

  // ─── Lifecycle ─────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchFromSupabase();
    } catch (e) {
      _errorMessage = 'Database Error: $e';
      debugPrint('[PS] initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncWithDatabase() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchFromSupabase();
    } catch (e) {
      _errorMessage = 'Sync Error: $e';
      debugPrint('[PS] sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _fetchFromSupabase() async {
    final response = await _supabase
        .from(_table)
        .select()
        .order('created_at', ascending: false);

    _properties =
        (response as List).map((row) => Property.fromJson(row)).toList();
  }

  // ─── ADD ───────────────────────────────────────────────────────

  /// Adds a new property.
  ///
  /// [localImagePaths] is a list of absolute local file paths selected by the
  /// user. They will be uploaded to Supabase Storage and the resulting storage
  /// paths stored in the record.
  // ─── ADD ───────────────────────────────────────────────────────

  /// Adds a new property.
  ///
  /// [newImages] is a list of [XFile]s selected by the user.
  /// [localImagePaths] is a list of absolute local file paths for backward compatibility.
  Future<Property?> addProperty(
    Property property, {
    List<XFile> newImages = const [],
    List<String> localImagePaths = const [],
  }) async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Upload images first
      final imagesToUpload = newImages.isNotEmpty ? newImages : localImagePaths;
      final uploadedPaths = await _uploadImages(imagesToUpload);
      debugPrint('[PS] Uploaded ${uploadedPaths.length} image(s): $uploadedPaths');

      // 2. Build record with storage paths
      final withImages = property.copyWith(imagePaths: uploadedPaths);
      final payload = withImages.toJson();
      debugPrint('[PS] Inserting property payload into table "$_table": $payload');

      Map<String, dynamic>? insertedRow;
      int retries = 5;
      while (retries > 0 && insertedRow == null) {
        try {
          insertedRow = await _supabase
              .from(_table)
              .insert(payload)
              .select()
              .single();
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST204' || e.message.contains('schema cache')) {
            final missingColMatch =
                RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
            if (missingColMatch != null) {
              final colName = missingColMatch.group(1);
              if (colName != null && payload.containsKey(colName)) {
                debugPrint('[PS] Column $colName missing in DB schema. Removing from payload & retrying.');
                payload.remove(colName);
                retries--;
                continue;
              }
            }
          }
          rethrow;
        }
      }

      if (insertedRow == null) {
        throw Exception('Failed to insert property record into Supabase.');
      }

      debugPrint('[PS] Successfully inserted property in Supabase. Saved image_paths: ${insertedRow['image_paths']}');

      final newProperty = Property.fromJson(insertedRow);
      _properties.insert(0, newProperty);
      notifyListeners();
      return newProperty;
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to add property: ${e.message}';
      debugPrint('[PS] addProperty PostgrestException: ${e.message}');
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to add property: $e';
      debugPrint('[PS] addProperty Error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── UPDATE ────────────────────────────────────────────────────

  /// Updates an existing property.
  ///
  /// [newImages] = brand-new [XFile]s to upload.
  /// [newLocalImagePaths] = brand-new local file paths to upload (if XFile is unavailable).
  /// [removedStoragePaths] = existing Supabase paths that the user deleted.
  Future<void> updateProperty(
    Property property, {
    List<XFile> newImages = const [],
    List<String> newLocalImagePaths = const [],
    List<String> removedStoragePaths = const [],
  }) async {
    if (property.id == null) return;

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Delete removed images from Storage
      if (removedStoragePaths.isNotEmpty) {
        await _deleteImages(removedStoragePaths);
      }

      // 2. Upload new images
      final imagesToUpload = newImages.isNotEmpty ? newImages : newLocalImagePaths;
      final uploadedPaths = await _uploadImages(imagesToUpload);
      debugPrint('[PS] Uploaded ${uploadedPaths.length} new image(s): $uploadedPaths');

      // 3. Final image list = existing retained paths + newly uploaded
      final finalPaths = [
        ...property.imagePaths,
        ...uploadedPaths,
      ];
      debugPrint('[PS] Updating property ${property.id}. Existing retained: ${property.imagePaths.length}, Newly uploaded: ${uploadedPaths.length}, Total final image_paths: $finalPaths');

      final withImages = property.copyWith(imagePaths: finalPaths);
      final payload = withImages.toJson();
      debugPrint('[PS] Updating property payload in table "$_table": $payload');

      Map<String, dynamic>? updatedRow;
      int retries = 5;
      while (retries > 0 && updatedRow == null) {
        try {
          updatedRow = await _supabase
              .from(_table)
              .update(payload)
              .eq('id', property.id!)
              .select()
              .single();
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST204' || e.message.contains('schema cache')) {
            final missingColMatch =
                RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
            if (missingColMatch != null) {
              final colName = missingColMatch.group(1);
              if (colName != null && payload.containsKey(colName)) {
                debugPrint('[PS] Column $colName missing in DB schema. Removing from payload & retrying.');
                payload.remove(colName);
                retries--;
                continue;
              }
            }
          }
          rethrow;
        }
      }

      if (updatedRow == null) {
        throw Exception('Failed to update property record in Supabase.');
      }

      debugPrint('[PS] Successfully updated property in Supabase. Saved image_paths: ${updatedRow['image_paths']}');

      final updatedProperty = Property.fromJson(updatedRow);
      final idx = _properties.indexWhere((p) => p.id == property.id);
      if (idx != -1) {
        _properties[idx] = updatedProperty;
      } else {
        _properties.insert(0, updatedProperty);
      }
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to update property: ${e.message}';
      debugPrint('[PS] updateProperty PostgrestException: ${e.message}');
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to update property: $e';
      debugPrint('[PS] updateProperty Error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── DELETE ────────────────────────────────────────────────────

  Future<void> deleteProperty(Property property) async {
    if (property.id == null) return;

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Delete all associated storage images first
      await _deleteImages(property.imagePaths);

      await _supabase.from(_table).delete().eq('id', property.id!);

      _properties.removeWhere((p) => p.id == property.id);
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to delete property: ${e.message}';
      debugPrint('[PS] deleteProperty error: ${e.message}');
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to delete: $e';
      debugPrint('[PS] deleteProperty error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── Storage Helpers ───────────────────────────────────────────

  String _extractExtension(dynamic imageSource) {
    String nameOrPath = '';
    if (imageSource is XFile) {
      nameOrPath = imageSource.name;
      if (!nameOrPath.contains('.') && imageSource.path.isNotEmpty) {
        nameOrPath = imageSource.path;
      }
    } else if (imageSource is String) {
      nameOrPath = imageSource;
    }

    if (nameOrPath.contains('?')) {
      nameOrPath = nameOrPath.split('?').first;
    }

    final filename = nameOrPath.split(RegExp(r'[/\\]')).last;
    if (filename.contains('.')) {
      final ext = filename.split('.').last.toLowerCase();
      final cleanExt = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanExt.isNotEmpty && cleanExt.length <= 5) {
        return cleanExt;
      }
    }
    return 'jpg';
  }

  /// Uploads a list of local file paths or [XFile]s to Supabase Storage.
  /// Returns the list of storage object paths (not full URLs).
  Future<List<String>> _uploadImages(List<dynamic> images) async {
    if (images.isEmpty) return [];

    final List<String> uploaded = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final ext = _extractExtension(img);
      final storagePath = '${timestamp}_$i.$ext';

      try {
        Uint8List bytes;
        if (img is XFile) {
          bytes = await img.readAsBytes();
        } else if (img is String) {
          if (kIsWeb) {
            final xfile = XFile(img);
            bytes = await xfile.readAsBytes();
          } else {
            final file = File(img);
            bytes = await file.readAsBytes();
          }
        } else {
          throw Exception('Unsupported image input type: ${img.runtimeType}');
        }

        debugPrint('[PS] Uploading image $i to Storage object path: $storagePath (${bytes.length} bytes)');

        await _supabase.storage.from(_storageBucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: _mimeType(ext),
                upsert: false,
              ),
            );

        uploaded.add(storagePath);
        debugPrint('[PS] Successfully uploaded image to Supabase Storage: $storagePath');
      } catch (e, st) {
        debugPrint('[PS] ERROR uploading image $img to $storagePath: $e\n$st');
        throw Exception('Failed to upload property image ($storagePath): $e');
      }
    }
    return uploaded;
  }

  /// Deletes a list of Supabase Storage paths.
  Future<void> _deleteImages(List<String> storagePaths) async {
    if (storagePaths.isEmpty) return;
    try {
      await _supabase.storage.from(_storageBucket).remove(storagePaths);
      debugPrint('[PS] Deleted ${storagePaths.length} image(s) from storage.');
    } catch (e) {
      debugPrint('[PS] Failed to delete images: $e');
      // Non-fatal – log and continue
    }
  }

  /// Returns a public URL for a given storage path.
  String getImageUrl(String storagePath) {
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      return storagePath;
    }
    return _supabase.storage
        .from(_storageBucket)
        .getPublicUrl(storagePath);
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  // ─── Search ────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
