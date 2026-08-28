import 'dart:io';

import 'package:flutter/foundation.dart';
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
  Future<Property?> addProperty(
    Property property, {
    List<String> localImagePaths = const [],
  }) async {
    _isSyncing = true;
    notifyListeners();

    try {
      // 1. Upload images first
      final uploadedPaths = await _uploadImages(localImagePaths);

      // 2. Build record with storage paths
      final withImages = property.copyWith(imagePaths: uploadedPaths);

      final insertedRow = await _supabase
          .from(_table)
          .insert(withImages.toJson())
          .select()
          .single();

      final newProperty = Property.fromJson(insertedRow);
      _properties.insert(0, newProperty);
      notifyListeners();
      return newProperty;
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to add property: ${e.message}';
      debugPrint('[PS] addProperty error: ${e.message}');
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to add property: $e';
      debugPrint('[PS] addProperty error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── UPDATE ────────────────────────────────────────────────────

  /// Updates an existing property.
  ///
  /// [newLocalImagePaths] = brand-new local files to upload.
  /// [removedStoragePaths] = existing Supabase paths that the user deleted.
  Future<void> updateProperty(
    Property property, {
    List<String> newLocalImagePaths = const [],
    List<String> removedStoragePaths = const [],
  }) async {
    if (property.id == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      // 1. Delete removed images from Storage
      await _deleteImages(removedStoragePaths);

      // 2. Upload new images
      final uploadedPaths = await _uploadImages(newLocalImagePaths);

      // 3. Final image list = existing retained paths + newly uploaded
      final finalPaths = [
        ...property.imagePaths, // already-retained paths (not removed)
        ...uploadedPaths,
      ];

      final withImages = property.copyWith(imagePaths: finalPaths);

      final updatedRow = await _supabase
          .from(_table)
          .update(withImages.toJson())
          .eq('id', property.id!)
          .select()
          .single();

      final updatedProperty = Property.fromJson(updatedRow);
      final idx = _properties.indexWhere((p) => p.id == property.id);
      if (idx != -1) {
        _properties[idx] = updatedProperty;
      } else {
        _properties.insert(0, updatedProperty);
      }
    } on PostgrestException catch (e) {
      _errorMessage = 'Failed to update property: ${e.message}';
      debugPrint('[PS] updateProperty error: ${e.message}');
      rethrow;
    } catch (e) {
      _errorMessage = 'Failed to update property: $e';
      debugPrint('[PS] updateProperty error: $e');
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

  /// Uploads a list of local file paths to Supabase Storage.
  /// Returns the list of storage object paths (not full URLs).
  Future<List<String>> _uploadImages(List<String> localPaths) async {
    if (kIsWeb || localPaths.isEmpty) return [];

    final List<String> uploaded = [];
    for (final localPath in localPaths) {
      try {
        final file = File(localPath);
        final ext = localPath.split('.').last.toLowerCase();
        final storagePath =
            '${DateTime.now().millisecondsSinceEpoch}_${uploaded.length}.$ext';

        await _supabase.storage
            .from(_storageBucket)
            .upload(storagePath, file,
                fileOptions: FileOptions(
                  contentType: _mimeType(ext),
                  upsert: false,
                ));

        uploaded.add(storagePath);
        debugPrint('[PS] Uploaded image: $storagePath');
      } catch (e) {
        debugPrint('[PS] Failed to upload image $localPath: $e');
        // Continue uploading others; skip this one
      }
    }
    return uploaded;
  }

  /// Deletes a list of Supabase Storage paths.
  Future<void> _deleteImages(List<String> storagePaths) async {
    if (kIsWeb || storagePaths.isEmpty) return;
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
