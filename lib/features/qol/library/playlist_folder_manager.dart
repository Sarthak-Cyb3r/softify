// ============================================================================
// Softify Quality of Life (QoL) - Feature 23: Playlist Nested Folder Hierarchy
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/playlist.dart';
import '../../../presentation/theme/app_theme.dart';
import '../../../presentation/theme/app_tokens.dart';

// ============================================================================
// Constants & Keys
// ============================================================================

/// SharedPreferences persistent storage key for playlist folders hierarchy.
const String kPlaylistFoldersPrefKey = 'softify_playlist_folders_hierarchy_v1';

/// SharedPreferences persistent storage key for expanded folder IDs.
const String kPlaylistFolderExpandedIdsPrefKey =
    'softify_playlist_folders_expanded_v1';

/// Maximum allowable nesting depth to prevent layout overflow or recursive cycles.
const int kMaxFolderNestingDepth = 12;

/// Default folder accent color (Metrolist coral accent).
const int kDefaultFolderColorValue = 0xFFED5564;

// ============================================================================
// SharedPreferences Persistence Engine (Self-Contained & Durable)
// ============================================================================

/// Lightweight, self-contained SharedPreferences persistence engine
/// matching the exact `package:shared_preferences` API interface.
///
/// Persists key-value settings to disk safely across app launches
/// while supporting mock environments for testing and headless runs.
class SharedPreferences {
  static SharedPreferences? _instance;
  static Map<String, Object>? _mockInitialValues;

  final Map<String, Object> _store;
  final File? _file;

  SharedPreferences._(this._store, this._file);

  /// Synchronously accessible cached singleton instance if already resolved.
  static SharedPreferences? get instance => _instance;

  /// Injects mock values for testing environments.
  static void setMockInitialValues(Map<String, Object> values) {
    _mockInitialValues = Map<String, Object>.from(values);
    _instance = SharedPreferences._(Map<String, Object>.from(values), null);
  }

  /// Resets the cached singleton instance.
  static void reset() {
    _instance = null;
    _mockInitialValues = null;
  }

  /// Resolves or initializes the SharedPreferences singleton instance.
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    if (_mockInitialValues != null) {
      _instance = SharedPreferences._(
        Map<String, Object>.from(_mockInitialValues!),
        null,
      );
      return _instance!;
    }

    final store = <String, Object>{};
    File? file;

    try {
      file = await _resolveStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            decoded.forEach((key, value) {
              if (value != null) {
                store[key] = value as Object;
              }
            });
          }
        }
      }
    } catch (_) {
      // In-memory fallback if file system access fails
    }

    _instance = SharedPreferences._(store, file);
    return _instance!;
  }

  static Future<File?> _resolveStorageFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final targetDir = Directory(dir.path);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return File(p.join(dir.path, 'shared_preferences.json'));
    } catch (_) {
      try {
        final home = Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            Platform.environment['LOCALAPPDATA'];
        if (home != null && home.isNotEmpty) {
          final dir = Directory(p.join(home, '.softify'));
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          return File(p.join(dir.path, 'shared_preferences.json'));
        }
      } catch (_) {}
      return null;
    }
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_store);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  String? getString(String key) {
    final val = _store[key];
    if (val is String) return val;
    if (val != null) return val.toString();
    return null;
  }

  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  List<String>? getStringList(String key) {
    final val = _store[key];
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    _store[key] = List<String>.from(value);
    await _persist();
    return true;
  }

  bool? getBool(String key) {
    final val = _store[key];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val != 0;
    return null;
  }

  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  int? getInt(String key) {
    final val = _store[key];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    await _persist();
    return true;
  }

  Future<bool> remove(String key) async {
    _store.remove(key);
    await _persist();
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    await _persist();
    return true;
  }

  bool containsKey(String key) => _store.containsKey(key);

  Set<String> getKeys() => Set<String>.from(_store.keys);
}

// ============================================================================
// Model: PlaylistFolder
// ============================================================================

/// Represents a folder used to organize user playlists into arbitrary nested hierarchies.
@immutable
class PlaylistFolder {
  /// Unique identifier of the folder.
  final String id;

  /// Human-readable folder title.
  final String name;

  /// Identifier of the parent folder, or `null` if this is a top-level root folder.
  final String? parentId;

  /// List of playlist IDs directly contained inside this folder.
  final List<String> playlistIds;

  /// Timestamp when the folder was created.
  final DateTime createdAt;

  /// Timestamp when the folder was last modified.
  final DateTime updatedAt;

  /// Optional custom ARGB color value for visual categorization.
  final int? colorValue;

  /// Optional icon name identifier.
  final String? iconName;

  const PlaylistFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.playlistIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.colorValue,
    this.iconName,
  });

  /// Whether this is a top-level folder (no parent).
  bool get isRoot => parentId == null;

  /// Direct playlist count in this specific folder.
  int get playlistCount => playlistIds.length;

  /// Resolves the optional [Color] from [colorValue].
  Color? get color => colorValue != null ? Color(colorValue!) : null;

  PlaylistFolder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool clearParent = false,
    List<String>? playlistIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? colorValue,
    bool clearColor = false,
    String? iconName,
    bool clearIcon = false,
  }) {
    return PlaylistFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      playlistIds: playlistIds ?? this.playlistIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      iconName: clearIcon ? null : (iconName ?? this.iconName),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'playlist_ids': playlistIds,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'color_value': colorValue,
      'icon_name': iconName,
    };
  }

  factory PlaylistFolder.fromMap(Map<String, dynamic> map) {
    return PlaylistFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      playlistIds: (map['playlist_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
      colorValue: (map['color_value'] as num?)?.toInt(),
      iconName: map['icon_name'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PlaylistFolder.fromJson(String jsonStr) =>
      PlaylistFolder.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistFolder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          parentId == other.parentId &&
          colorValue == other.colorValue &&
          iconName == other.iconName;

  @override
  int get hashCode => Object.hash(id, name, parentId, colorValue, iconName);

  @override
  String toString() =>
      'PlaylistFolder(id: $id, name: "$name", parentId: $parentId, playlists: ${playlistIds.length})';
}

// ============================================================================
// Model: PlaylistFolderNode (Hierarchical Tree Representation)
// ============================================================================

/// Represents a node within an expanded or collapsed playlist folder tree hierarchy.
@immutable
class PlaylistFolderNode {
  /// The underlying folder data entity.
  final PlaylistFolder folder;

  /// Tree indentation depth (0 for root, 1 for subfolder, etc.).
  final int depth;

  /// Child subfolder nodes directly under this folder.
  final List<PlaylistFolderNode> subfolders;

  /// IDs of playlists directly inside this folder.
  final List<String> playlistIds;

  /// Whether this folder node is currently expanded in the tree view.
  final bool isExpanded;

  /// Resolved [Playlist] instances if passed during tree building.
  final List<Playlist> resolvedPlaylists;

  const PlaylistFolderNode({
    required this.folder,
    required this.depth,
    this.subfolders = const [],
    this.playlistIds = const [],
    this.isExpanded = false,
    this.resolvedPlaylists = const [],
  });

  /// Number of playlists directly located in this folder.
  int get directPlaylistCount => playlistIds.length;

  /// Total count of playlists located in this folder and all nested descendant subfolders.
  int get totalPlaylistCount {
    int total = directPlaylistCount;
    for (final child in subfolders) {
      total += child.totalPlaylistCount;
    }
    return total;
  }

  /// Whether this folder has any subfolders or playlists inside it.
  bool get hasChildren => subfolders.isNotEmpty || playlistIds.isNotEmpty;

  /// Whether this folder has any subfolders.
  bool get hasSubfolders => subfolders.isNotEmpty;

  /// Whether this folder has any playlists directly inside it.
  bool get hasPlaylists => playlistIds.isNotEmpty;

  @override
  String toString() =>
      'PlaylistFolderNode(name: "${folder.name}", depth: $depth, expanded: $isExpanded, subfolders: ${subfolders.length}, playlists: ${playlistIds.length})';
}

// ============================================================================
// Pure Utility: PlaylistFolderTree
// ============================================================================

/// Pure helper operations for tree traversal, cycle detection, path building,
/// and hierarchical tree construction.
class PlaylistFolderTree {
  const PlaylistFolderTree._();

  /// Determines whether [folderId] is a descendant of [potentialAncestorId].
  ///
  /// Prevents circular folder structures when moving or reparenting folders.
  static bool isDescendant(
    Map<String, PlaylistFolder> folders,
    String folderId,
    String potentialAncestorId,
  ) {
    if (folderId == potentialAncestorId) return true;

    final visited = <String>{folderId};
    String? currentParent = folders[folderId]?.parentId;

    while (currentParent != null) {
      if (currentParent == potentialAncestorId) {
        return true;
      }
      if (visited.contains(currentParent)) {
        break;
      }
      visited.add(currentParent);
      currentParent = folders[currentParent]?.parentId;
    }
    return false;
  }

  /// Resolves the full chain of folders from root down to [folderId].
  static List<PlaylistFolder> getFolderPath(
    Map<String, PlaylistFolder> folders,
    String folderId,
  ) {
    final path = <PlaylistFolder>[];
    String? currentId = folderId;
    final visited = <String>{};

    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);
      final folder = folders[currentId];
      if (folder != null) {
        path.insert(0, folder);
        currentId = folder.parentId;
      } else {
        break;
      }
    }
    return path;
  }

  /// Builds a human-readable breadcrumb path, e.g. "Electronic / Synthwave".
  static String getFolderPathDisplay(
    Map<String, PlaylistFolder> folders,
    String folderId, {
    String separator = ' / ',
  }) {
    final path = getFolderPath(folders, folderId);
    if (path.isEmpty) return '';
    return path.map((f) => f.name).join(separator);
  }

  /// Recursively collects all playlist IDs contained in [folderId] and its descendants.
  static Set<String> getPlaylistIdsRecursive(
    Map<String, PlaylistFolder> folders,
    String folderId, {
    bool recursive = true,
  }) {
    final result = <String>{};
    final folder = folders[folderId];
    if (folder == null) return result;

    result.addAll(folder.playlistIds);
    if (!recursive) return result;

    for (final f in folders.values) {
      if (f.parentId == folderId) {
        result.addAll(
          getPlaylistIdsRecursive(folders, f.id, recursive: true),
        );
      }
    }
    return result;
  }

  /// Constructs the complete hierarchical tree of [PlaylistFolderNode]s.
  ///
  /// Optionally filters by [searchQuery] while preserving matching branches.
  static List<PlaylistFolderNode> buildTree({
    required Map<String, PlaylistFolder> folders,
    required Set<String> expandedIds,
    Map<String, Playlist>? playlistsMap,
    String? searchQuery,
  }) {
    final childrenByParent = <String?, List<PlaylistFolder>>{};
    for (final folder in folders.values) {
      childrenByParent.putIfAbsent(folder.parentId, () => []).add(folder);
    }

    for (final list in childrenByParent.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    PlaylistFolderNode buildNode(PlaylistFolder folder, int depth) {
      final children = childrenByParent[folder.id] ?? [];
      final subfolderNodes = children
          .map((child) => buildNode(child, depth + 1))
          .toList();

      final resolved = <Playlist>[];
      if (playlistsMap != null) {
        for (final pid in folder.playlistIds) {
          final p = playlistsMap[pid];
          if (p != null) resolved.add(p);
        }
      }

      final isExpanded = expandedIds.contains(folder.id);

      return PlaylistFolderNode(
        folder: folder,
        depth: depth,
        subfolders: subfolderNodes,
        playlistIds: folder.playlistIds,
        isExpanded: isExpanded,
        resolvedPlaylists: resolved,
      );
    }

    final roots = childrenByParent[null] ?? [];
    var rootNodes = roots.map((f) => buildNode(f, 0)).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      rootNodes = _filterNodes(rootNodes, query);
    }

    return rootNodes;
  }

  static List<PlaylistFolderNode> _filterNodes(
    List<PlaylistFolderNode> nodes,
    String query,
  ) {
    final filtered = <PlaylistFolderNode>[];

    for (final node in nodes) {
      final matchesSelf = node.folder.name.toLowerCase().contains(query);
      final matchingPlaylists = node.resolvedPlaylists
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
      final filteredSubfolders = _filterNodes(node.subfolders, query);

      if (matchesSelf ||
          matchingPlaylists.isNotEmpty ||
          filteredSubfolders.isNotEmpty) {
        filtered.add(
          PlaylistFolderNode(
            folder: node.folder,
            depth: node.depth,
            subfolders: filteredSubfolders,
            playlistIds: matchesSelf
                ? node.playlistIds
                : matchingPlaylists.map((p) => p.id).toList(),
            isExpanded: true, // Auto-expand matching branches
            resolvedPlaylists: matchesSelf
                ? node.resolvedPlaylists
                : matchingPlaylists,
          ),
        );
      }
    }

    return filtered;
  }
}

// ============================================================================
// State: PlaylistFolderState
// ============================================================================

/// Immutable state containing the collection of folders, expanded states,
/// selection, and filter parameters.
@immutable
class PlaylistFolderState {
  /// All folders indexed by unique folder ID.
  final Map<String, PlaylistFolder> folders;

  /// IDs of folders currently expanded in the tree view.
  final Set<String> expandedFolderIds;

  /// Currently active or selected folder ID, if any.
  final String? selectedFolderId;

  /// Active filter query string.
  final String searchQuery;

  /// Whether folder state is currently loading from persistence.
  final bool isLoading;

  /// Last error message encountered during folder operations.
  final String? errorMessage;

  const PlaylistFolderState({
    this.folders = const {},
    this.expandedFolderIds = const {},
    this.selectedFolderId,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  /// All folders as a list.
  List<PlaylistFolder> get allFolders => folders.values.toList();

  /// Top-level root folders (having no parent), sorted alphabetically.
  List<PlaylistFolder> get rootFolders {
    final roots = folders.values.where((f) => f.parentId == null).toList();
    roots.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return roots;
  }

  /// Direct children of a specified parent folder ID, sorted alphabetically.
  List<PlaylistFolder> getChildFolders(String? parentId) {
    final children =
        folders.values.where((f) => f.parentId == parentId).toList();
    children
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return children;
  }

  /// Whether the specified folder is currently expanded.
  bool isFolderExpanded(String folderId) =>
      expandedFolderIds.contains(folderId);

  /// Retrieves a folder by its ID, or `null` if not found.
  PlaylistFolder? getFolder(String folderId) => folders[folderId];

  /// Full ancestor path for [folderId].
  List<PlaylistFolder> getFolderPath(String folderId) =>
      PlaylistFolderTree.getFolderPath(folders, folderId);

  /// Human-readable breadcrumb display for [folderId].
  String getFolderPathDisplay(String folderId, {String separator = ' / '}) =>
      PlaylistFolderTree.getFolderPathDisplay(
        folders,
        folderId,
        separator: separator,
      );

  /// Finds which folder currently contains [playlistId], if any.
  PlaylistFolder? findFolderForPlaylist(String playlistId) {
    for (final folder in folders.values) {
      if (folder.playlistIds.contains(playlistId)) {
        return folder;
      }
    }
    return null;
  }

  /// Collects all playlist IDs in [folderId], optionally recursively.
  Set<String> getPlaylistsInFolder(String folderId, {bool recursive = true}) =>
      PlaylistFolderTree.getPlaylistIdsRecursive(
        folders,
        folderId,
        recursive: recursive,
      );

  /// Filters out playlists that are already assigned to a folder, returning unfiled playlists.
  List<Playlist> getUnfiledPlaylists(List<Playlist> allPlaylists) {
    return allPlaylists
        .where((p) => findFolderForPlaylist(p.id) == null)
        .toList();
  }

  /// Returns IDs of playlists that are not inside any folder.
  List<String> getUnfiledPlaylistIds(List<String> allPlaylistIds) {
    final assigned = <String>{};
    for (final folder in folders.values) {
      assigned.addAll(folder.playlistIds);
    }
    return allPlaylistIds.where((id) => !assigned.contains(id)).toList();
  }

  /// Constructs the tree nodes hierarchy using the current folders and expansion state.
  List<PlaylistFolderNode> buildTreeNodes({
    Map<String, Playlist>? playlistsMap,
  }) {
    return PlaylistFolderTree.buildTree(
      folders: folders,
      expandedIds: expandedFolderIds,
      playlistsMap: playlistsMap,
      searchQuery: searchQuery,
    );
  }

  PlaylistFolderState copyWith({
    Map<String, PlaylistFolder>? folders,
    Set<String>? expandedFolderIds,
    String? selectedFolderId,
    bool clearSelectedFolder = false,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlaylistFolderState(
      folders: folders ?? this.folders,
      expandedFolderIds: expandedFolderIds ?? this.expandedFolderIds,
      selectedFolderId: clearSelectedFolder
          ? null
          : (selectedFolderId ?? this.selectedFolderId),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ============================================================================
// Controller: PlaylistFolderManager (StateNotifier)
// ============================================================================

/// Manages nested playlist folder creation, renaming, moving, reparenting,
/// deletion, and persistence to SharedPreferences.
class PlaylistFolderManager extends StateNotifier<PlaylistFolderState> {
  SharedPreferences? _prefs;

  PlaylistFolderManager({
    SharedPreferences? prefs,
    PlaylistFolderState? initialState,
  })  : _prefs = prefs,
        super(initialState ?? const PlaylistFolderState()) {
    initialize();
  }

  /// Loads folder hierarchy and expansion state from SharedPreferences.
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;

      // 1. Load folders
      final foldersJson = prefs.getString(kPlaylistFoldersPrefKey);
      final foldersMap = <String, PlaylistFolder>{};

      if (foldersJson != null && foldersJson.trim().isNotEmpty) {
        final decoded = jsonDecode(foldersJson);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final folder = PlaylistFolder.fromMap(item);
              foldersMap[folder.id] = folder;
            } else if (item is Map) {
              final folder =
                  PlaylistFolder.fromMap(Map<String, dynamic>.from(item));
              foldersMap[folder.id] = folder;
            }
          }
        }
      }

      // 2. Load expanded folder IDs
      final expandedList =
          prefs.getStringList(kPlaylistFolderExpandedIdsPrefKey);
      final expandedSet = expandedList != null
          ? Set<String>.from(expandedList)
          : <String>{};

      state = state.copyWith(
        folders: foldersMap,
        expandedFolderIds: expandedSet,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load playlist folders: $e',
      );
    }
  }

  Future<void> _persistState() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;

      // 1. Persist folders JSON
      final folderList = state.folders.values.map((f) => f.toMap()).toList();
      await prefs.setString(kPlaylistFoldersPrefKey, jsonEncode(folderList));

      // 2. Persist expanded IDs
      await prefs.setStringList(
        kPlaylistFolderExpandedIdsPrefKey,
        state.expandedFolderIds.toList(),
      );
    } catch (_) {}
  }

  Future<void> _persistExpandedState() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;
      await prefs.setStringList(
        kPlaylistFolderExpandedIdsPrefKey,
        state.expandedFolderIds.toList(),
      );
    } catch (_) {}
  }

  /// Creates a new folder under [parentFolderId] (or top-level if null).
  Future<PlaylistFolder> createFolder(
    String name, {
    String? parentFolderId,
    int? colorValue,
    String? iconName,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }

    if (parentFolderId != null && !state.folders.containsKey(parentFolderId)) {
      throw ArgumentError('Parent folder "$parentFolderId" does not exist');
    }

    // Check sibling duplicate name
    final siblings = state.getChildFolders(parentFolderId);
    if (siblings
        .any((f) => f.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError(
        'A folder named "$trimmed" already exists in this location',
      );
    }

    // Check depth limit
    if (parentFolderId != null) {
      final path = state.getFolderPath(parentFolderId);
      if (path.length >= kMaxFolderNestingDepth) {
        throw ArgumentError(
          'Maximum folder nesting depth ($kMaxFolderNestingDepth) reached',
        );
      }
    }

    final id =
        'folder_${DateTime.now().microsecondsSinceEpoch}_${(1000 + (DateTime.now().millisecond % 9000))}';
    final now = DateTime.now();

    final newFolder = PlaylistFolder(
      id: id,
      name: trimmed,
      parentId: parentFolderId,
      playlistIds: const [],
      createdAt: now,
      updatedAt: now,
      colorValue: colorValue,
      iconName: iconName,
    );

    final updatedFolders = Map<String, PlaylistFolder>.from(state.folders);
    updatedFolders[id] = newFolder;

    final updatedExpanded = Set<String>.from(state.expandedFolderIds);
    if (parentFolderId != null) {
      updatedExpanded.add(parentFolderId);
    }

    state = state.copyWith(
      folders: updatedFolders,
      expandedFolderIds: updatedExpanded,
      clearError: true,
    );

    await _persistState();
    return newFolder;
  }

  /// Renames an existing folder.
  Future<bool> renameFolder(String folderId, String newName) async {
    final folder = state.folders[folderId];
    if (folder == null) return false;

    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Folder name cannot be empty');
    }

    if (trimmed == folder.name) {
      return true;
    }

    // Check sibling duplicate name
    final siblings = state
        .getChildFolders(folder.parentId)
        .where((f) => f.id != folderId);
    if (siblings
        .any((f) => f.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError(
        'A folder named "$trimmed" already exists in this location',
      );
    }

    final updatedFolder = folder.copyWith(
      name: trimmed,
      updatedAt: DateTime.now(),
    );

    final updatedFolders = Map<String, PlaylistFolder>.from(state.folders);
    updatedFolders[folderId] = updatedFolder;

    state = state.copyWith(folders: updatedFolders, clearError: true);
    await _persistState();
    return true;
  }

  /// Deletes a folder.
  ///
  /// If [deleteChildren] is `true`, all nested subfolders and their contents are deleted.
  /// If `false`, immediate subfolders are reparented to the deleted folder's parent,
  /// and contained playlists are moved to the parent folder (or become unfiled).
  Future<bool> deleteFolder(
    String folderId, {
    bool deleteChildren = false,
  }) async {
    final folder = state.folders[folderId];
    if (folder == null) return false;

    final updatedFolders = Map<String, PlaylistFolder>.from(state.folders);
    final updatedExpanded = Set<String>.from(state.expandedFolderIds);

    if (deleteChildren) {
      final toDelete = <String>{folderId};
      void collectDescendants(String currentId) {
        for (final f in state.folders.values) {
          if (f.parentId == currentId) {
            toDelete.add(f.id);
            collectDescendants(f.id);
          }
        }
      }

      collectDescendants(folderId);

      for (final id in toDelete) {
        updatedFolders.remove(id);
        updatedExpanded.remove(id);
      }
    } else {
      // Reparent immediate subfolders to folder's parent
      for (final child in state.getChildFolders(folderId)) {
        updatedFolders[child.id] = child.copyWith(
          parentId: folder.parentId,
          clearParent: folder.parentId == null,
          updatedAt: DateTime.now(),
        );
      }

      // Reparent playlists inside deleted folder to parent folder if exists
      if (folder.parentId != null &&
          updatedFolders.containsKey(folder.parentId)) {
        final parent = updatedFolders[folder.parentId]!;
        final mergedIds = Set<String>.from(parent.playlistIds)
          ..addAll(folder.playlistIds);
        updatedFolders[parent.id] = parent.copyWith(
          playlistIds: mergedIds.toList(),
          updatedAt: DateTime.now(),
        );
      }

      updatedFolders.remove(folderId);
      updatedExpanded.remove(folderId);
    }

    String? selectedId = state.selectedFolderId;
    if (selectedId == folderId || !updatedFolders.containsKey(selectedId)) {
      selectedId = null;
    }

    state = state.copyWith(
      folders: updatedFolders,
      expandedFolderIds: updatedExpanded,
      selectedFolderId: selectedId,
      clearSelectedFolder: selectedId == null,
      clearError: true,
    );

    await _persistState();
    return true;
  }

  /// Moves a folder to a new parent location, with cycle detection preventing
  /// moving a folder into itself or its own descendants.
  Future<bool> moveFolder({
    required String folderId,
    String? targetParentFolderId,
  }) async {
    final folder = state.folders[folderId];
    if (folder == null) return false;

    if (folder.parentId == targetParentFolderId) {
      return true;
    }

    if (targetParentFolderId == folderId) {
      throw ArgumentError('Cannot move folder into itself');
    }

    if (targetParentFolderId != null) {
      if (!state.folders.containsKey(targetParentFolderId)) {
        throw ArgumentError(
          'Target parent folder "$targetParentFolderId" does not exist',
        );
      }

      // Prevent circular cycles
      if (PlaylistFolderTree.isDescendant(
        state.folders,
        targetParentFolderId,
        folderId,
      )) {
        throw ArgumentError(
          'Cannot move folder into one of its own descendant folders',
        );
      }

      // Check depth limit
      final targetPath = state.getFolderPath(targetParentFolderId);
      if (targetPath.length >= kMaxFolderNestingDepth) {
        throw ArgumentError(
          'Maximum folder nesting depth ($kMaxFolderNestingDepth) reached',
        );
      }

      // Check duplicate sibling name
      final siblings = state
          .getChildFolders(targetParentFolderId)
          .where((f) => f.id != folderId);
      if (siblings
          .any((f) => f.name.toLowerCase() == folder.name.toLowerCase())) {
        throw ArgumentError(
          'A folder named "${folder.name}" already exists in the target location',
        );
      }
    } else {
      // Moving to root: check root siblings
      final rootSiblings =
          state.rootFolders.where((f) => f.id != folderId);
      if (rootSiblings
          .any((f) => f.name.toLowerCase() == folder.name.toLowerCase())) {
        throw ArgumentError(
          'A folder named "${folder.name}" already exists at root level',
        );
      }
    }

    final updatedFolder = folder.copyWith(
      parentId: targetParentFolderId,
      clearParent: targetParentFolderId == null,
      updatedAt: DateTime.now(),
    );

    final updatedFolders = Map<String, PlaylistFolder>.from(state.folders);
    updatedFolders[folderId] = updatedFolder;

    final updatedExpanded = Set<String>.from(state.expandedFolderIds);
    if (targetParentFolderId != null) {
      updatedExpanded.add(targetParentFolderId);
    }

    state = state.copyWith(
      folders: updatedFolders,
      expandedFolderIds: updatedExpanded,
      clearError: true,
    );

    await _persistState();
    return true;
  }

  /// Moves a playlist into [targetFolderId] (or moves it to unfiled/root if `null`).
  Future<bool> movePlaylist({
    required String playlistId,
    String? targetFolderId,
  }) async {
    if (targetFolderId != null && !state.folders.containsKey(targetFolderId)) {
      throw ArgumentError(
        'Target folder "$targetFolderId" does not exist',
      );
    }

    final updatedFolders = Map<String, PlaylistFolder>.from(state.folders);
    final now = DateTime.now();

    // 1. Remove from all existing folders
    for (final entry in state.folders.entries) {
      final f = entry.value;
      if (f.playlistIds.contains(playlistId)) {
        final newIds = List<String>.from(f.playlistIds)..remove(playlistId);
        updatedFolders[f.id] =
            f.copyWith(playlistIds: newIds, updatedAt: now);
      }
    }

    // 2. Add to target folder if specified
    if (targetFolderId != null) {
      final target = updatedFolders[targetFolderId]!;
      final newIds = List<String>.from(target.playlistIds);
      if (!newIds.contains(playlistId)) {
        newIds.add(playlistId);
      }
      updatedFolders[targetFolderId] =
          target.copyWith(playlistIds: newIds, updatedAt: now);
    }

    final updatedExpanded = Set<String>.from(state.expandedFolderIds);
    if (targetFolderId != null) {
      updatedExpanded.add(targetFolderId);
    }

    state = state.copyWith(
      folders: updatedFolders,
      expandedFolderIds: updatedExpanded,
      clearError: true,
    );

    await _persistState();
    return true;
  }

  /// Moves multiple playlists in a single batch operation.
  Future<bool> movePlaylists({
    required List<String> playlistIds,
    String? targetFolderId,
  }) async {
    if (playlistIds.isEmpty) return true;

    if (targetFolderId != null && !state.folders.containsKey(targetFolderId)) {
      throw ArgumentError(
        'Target folder "$targetFolderId" does not exist',
      );
    }

    final updatedFolders = Map<String, PlaylistFolder>.from(state.folders);
    final now = DateTime.now();
    final idsSet = playlistIds.toSet();

    for (final entry in state.folders.entries) {
      final f = entry.value;
      if (f.playlistIds.any(idsSet.contains)) {
        final newIds = List<String>.from(f.playlistIds)
          ..removeWhere(idsSet.contains);
        updatedFolders[f.id] =
            f.copyWith(playlistIds: newIds, updatedAt: now);
      }
    }

    if (targetFolderId != null) {
      final target = updatedFolders[targetFolderId]!;
      final newIds = Set<String>.from(target.playlistIds)..addAll(playlistIds);
      updatedFolders[targetFolderId] = target.copyWith(
        playlistIds: newIds.toList(),
        updatedAt: now,
      );
    }

    final updatedExpanded = Set<String>.from(state.expandedFolderIds);
    if (targetFolderId != null) {
      updatedExpanded.add(targetFolderId);
    }

    state = state.copyWith(
      folders: updatedFolders,
      expandedFolderIds: updatedExpanded,
      clearError: true,
    );

    await _persistState();
    return true;
  }

  /// Removes a playlist from whichever folder it currently resides in.
  Future<bool> removePlaylist(String playlistId) async {
    return movePlaylist(playlistId: playlistId, targetFolderId: null);
  }

  /// Toggles the collapsed/expanded disclosure state of a folder and persists the change.
  void toggleFolderExpanded(String folderId) {
    final updated = Set<String>.from(state.expandedFolderIds);
    if (updated.contains(folderId)) {
      updated.remove(folderId);
    } else {
      updated.add(folderId);
    }
    state = state.copyWith(expandedFolderIds: updated);
    _persistExpandedState();
  }

  /// Sets the collapsed/expanded disclosure state of a folder and persists the change.
  void setFolderExpanded(String folderId, bool isExpanded) {
    final updated = Set<String>.from(state.expandedFolderIds);
    if (isExpanded) {
      updated.add(folderId);
    } else {
      updated.remove(folderId);
    }
    state = state.copyWith(expandedFolderIds: updated);
    _persistExpandedState();
  }

  /// Expands all folders in the hierarchy.
  void expandAll() {
    final allIds = state.folders.keys.toSet();
    state = state.copyWith(expandedFolderIds: allIds);
    _persistExpandedState();
  }

  /// Collapses all folders in the hierarchy.
  void collapseAll() {
    state = state.copyWith(expandedFolderIds: const {});
    _persistExpandedState();
  }

  /// Selects or deselects an active folder.
  void selectFolder(String? folderId) {
    state = state.copyWith(
      selectedFolderId: folderId,
      clearSelectedFolder: folderId == null,
    );
  }

  /// Updates the search filter query for folder/playlist searching.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clears all folders and resets the hierarchy to empty.
  Future<void> clearAllFolders() async {
    state = const PlaylistFolderState();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(kPlaylistFoldersPrefKey);
      await _prefs!.remove(kPlaylistFolderExpandedIdsPrefKey);
    } catch (_) {}
  }

  /// Exports the entire folder hierarchy to a serialized JSON string for backup/export.
  String exportToJson() {
    final list = state.folders.values.map((f) => f.toMap()).toList();
    return jsonEncode(list);
  }

  /// Imports a folder hierarchy from JSON, merging or replacing current state.
  Future<bool> importFromJson(String jsonString, {bool replace = false}) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return false;

      final incoming = <String, PlaylistFolder>{};
      for (final item in decoded) {
        if (item is Map) {
          final folder =
              PlaylistFolder.fromMap(Map<String, dynamic>.from(item));
          incoming[folder.id] = folder;
        }
      }

      final updatedFolders = replace
          ? incoming
          : (Map<String, PlaylistFolder>.from(state.folders)..addAll(incoming));

      state = state.copyWith(folders: updatedFolders);
      await _persistState();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// State notifier provider for managing the playlist folders hierarchy.
final playlistFolderManagerProvider =
    StateNotifierProvider<PlaylistFolderManager, PlaylistFolderState>((ref) {
  return PlaylistFolderManager();
});

/// Exposes the list of top-level root folders.
final rootFoldersProvider = Provider<List<PlaylistFolder>>((ref) {
  final folderState = ref.watch(playlistFolderManagerProvider);
  return folderState.rootFolders;
});

/// Exposes the set of currently expanded folder IDs.
final expandedFoldersProvider = Provider<Set<String>>((ref) {
  final folderState = ref.watch(playlistFolderManagerProvider);
  return folderState.expandedFolderIds;
});

/// Exposes the hierarchical tree nodes given an input list of playlists.
final folderTreeNodesProvider =
    Provider.family<List<PlaylistFolderNode>, List<Playlist>>(
        (ref, playlists) {
  final folderState = ref.watch(playlistFolderManagerProvider);
  final map = {for (final p in playlists) p.id: p};
  return folderState.buildTreeNodes(playlistsMap: map);
});

/// Exposes the currently selected folder, if any.
final selectedFolderProvider = Provider<PlaylistFolder?>((ref) {
  final folderState = ref.watch(playlistFolderManagerProvider);
  final id = folderState.selectedFolderId;
  return id != null ? folderState.folders[id] : null;
});

// ============================================================================
// Widget: PlaylistFolderTreeItem
// ============================================================================

/// Material 3 tree node widget rendering either a folder or an enclosed playlist
/// with proper depth indentation, animated disclosure chevron, count badge,
/// and contextual action menu.
class PlaylistFolderTreeItem extends StatelessWidget {
  /// The folder data if this tree item represents a folder.
  final PlaylistFolder? folder;

  /// The playlist data if this tree item represents a playlist.
  final Playlist? playlist;

  /// Tree indentation depth level (0 for root, 1 for nested subfolders, etc.).
  final int depth;

  /// Whether the folder is currently expanded.
  final bool isExpanded;

  /// Whether this item is visually selected/highlighted.
  final bool isSelected;

  /// Explicit playlist count override for folder badge.
  final int? playlistCount;

  /// Horizontal indent per depth level in logical pixels.
  final double indentWidth;

  /// Whether to render in a compact vertical form factor.
  final bool dense;

  /// Callback when item is tapped.
  final VoidCallback? onTap;

  /// Callback when item is double-tapped.
  final VoidCallback? onDoubleTap;

  /// Callback when disclosure chevron is tapped.
  final VoidCallback? onToggleExpand;

  /// Callback when folder rename is triggered.
  final ValueChanged<String>? onRename;

  /// Callback when folder deletion is triggered.
  final VoidCallback? onDelete;

  /// Callback when adding a subfolder inside this folder.
  final VoidCallback? onAddSubfolder;

  /// Callback when moving this folder or playlist.
  final VoidCallback? onMove;

  /// Callback when removing this playlist from its folder.
  final VoidCallback? onRemovePlaylist;

  /// Optional leading widget override.
  final Widget? leading;

  /// Optional trailing widget override.
  final Widget? trailing;

  const PlaylistFolderTreeItem({
    super.key,
    this.folder,
    this.playlist,
    this.depth = 0,
    this.isExpanded = false,
    this.isSelected = false,
    this.playlistCount,
    this.indentWidth = 18.0,
    this.dense = false,
    this.onTap,
    this.onDoubleTap,
    this.onToggleExpand,
    this.onRename,
    this.onDelete,
    this.onAddSubfolder,
    this.onMove,
    this.onRemovePlaylist,
    this.leading,
    this.trailing,
  }) : assert(
          folder != null || playlist != null,
          'Either folder or playlist must be supplied to PlaylistFolderTreeItem',
        );

  /// Convenient constructor for a folder item.
  const PlaylistFolderTreeItem.folder({
    super.key,
    required PlaylistFolder this.folder,
    this.depth = 0,
    this.isExpanded = false,
    this.isSelected = false,
    this.playlistCount,
    this.indentWidth = 18.0,
    this.dense = false,
    this.onTap,
    this.onDoubleTap,
    this.onToggleExpand,
    this.onRename,
    this.onDelete,
    this.onAddSubfolder,
    this.onMove,
    this.leading,
    this.trailing,
  })  : playlist = null,
        onRemovePlaylist = null;

  /// Convenient constructor for a playlist item inside a folder hierarchy.
  const PlaylistFolderTreeItem.playlist({
    super.key,
    required Playlist this.playlist,
    this.depth = 1,
    this.isSelected = false,
    this.indentWidth = 18.0,
    this.dense = false,
    this.onTap,
    this.onDoubleTap,
    this.onMove,
    this.onRemovePlaylist,
    this.leading,
    this.trailing,
  })  : folder = null,
        isExpanded = false,
        playlistCount = null,
        onToggleExpand = null,
        onRename = null,
        onDelete = null,
        onAddSubfolder = null;

  bool get isFolder => folder != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = playlistCount ?? folder?.playlistIds.length ?? 0;

    final primaryTextColor = isSelected
        ? AppTheme.accent
        : (theme.textTheme.bodyMedium?.color ?? AppTheme.textPrimary);

    final itemHeight = dense ? 36.0 : 44.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? (isFolder ? onToggleExpand : null),
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppTheme.cardHover.withOpacity(0.5),
        splashColor: AppTheme.accent.withOpacity(0.12),
        child: Container(
          height: itemHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? AppTheme.accent.withOpacity(0.14)
                : Colors.transparent,
            border: isSelected
                ? Border.all(
                    color: AppTheme.accent.withOpacity(0.4),
                    width: 1,
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              // 1. Depth Indentation Spacer
              if (depth > 0) SizedBox(width: depth * indentWidth),

              // 2. Expand/Collapse Chevron or Space Placeholder
              if (isFolder)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: isExpanded ? 'Collapse folder' : 'Expand folder',
                    icon: AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    onPressed: onToggleExpand ?? onTap,
                  ),
                )
              else
                const SizedBox(width: 24),

              const SizedBox(width: 4),

              // 3. Leading Icon
              leading ??
                  (isFolder
                      ? Icon(
                          isExpanded
                              ? Icons.folder_open_rounded
                              : Icons.folder_rounded,
                          size: 20,
                          color: folder?.color ?? AppTheme.accent,
                        )
                      : const Icon(
                          Icons.playlist_play_rounded,
                          size: 20,
                          color: AppTheme.textSecondary,
                        )),

              const SizedBox(width: 8),

              // 4. Title & optional track count
              Expanded(
                child: Text(
                  isFolder ? folder!.name : playlist!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense ? 13 : 14,
                    fontWeight: isFolder ? FontWeight.w600 : FontWeight.w400,
                    color: primaryTextColor,
                  ),
                ),
              ),

              // 5. Playlist count badge for folder
              if (isFolder && count > 0)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.divider.withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),

              // 6. Trailing Action Menu or Custom Widget
              trailing ??
                  PopupMenuButton<String>(
                    tooltip: 'Folder options',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    padding: EdgeInsets.zero,
                    elevation: 4,
                    color: AppTheme.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: AppTheme.divider.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'add_subfolder':
                          onAddSubfolder?.call();
                          break;
                        case 'rename':
                          onRename?.call(folder?.name ?? '');
                          break;
                        case 'move':
                          onMove?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                        case 'remove_playlist':
                          onRemovePlaylist?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      if (isFolder) {
                        return [
                          const PopupMenuItem(
                            value: 'add_subfolder',
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'New Subfolder',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Rename',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'move',
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drive_file_move_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Move Folder',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 8),
                          const PopupMenuItem(
                            value: 'delete',
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: AppTheme.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      } else {
                        return [
                          const PopupMenuItem(
                            value: 'move',
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drive_file_move_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Move to Folder',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove_playlist',
                            height: 36,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_off_outlined,
                                  size: 16,
                                  color: AppTheme.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Remove from Folder',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      }
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Dialogs & Modals: PlaylistFolderDialogs
// ============================================================================

/// Helper dialogs for creating, renaming, deleting, and moving folders and playlists.
class PlaylistFolderDialogs {
  const PlaylistFolderDialogs._();

  /// Displays a dialog to create a new folder.
  static Future<String?> showCreateFolderDialog(
    BuildContext context, {
    String? parentFolderId,
    String? parentFolderName,
    Future<void> Function(String name)? onCreated,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            parentFolderName != null
                ? 'New Subfolder in "$parentFolderName"'
                : 'New Playlist Folder',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Folder name',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.accent),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a folder name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final name = controller.text.trim();
                  if (onCreated != null) {
                    await onCreated(name);
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(name);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  /// Displays a dialog to rename an existing folder.
  static Future<String?> showRenameFolderDialog(
    BuildContext context, {
    required PlaylistFolder folder,
    Future<void> Function(String newName)? onRenamed,
  }) async {
    final controller = TextEditingController(text: folder.name);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Rename Folder',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'New folder name',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.accent),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a folder name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final newName = controller.text.trim();
                  if (onRenamed != null) {
                    await onRenamed(newName);
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(newName);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Displays a confirmation dialog to delete a folder.
  static Future<bool?> showDeleteFolderDialog(
    BuildContext context, {
    required PlaylistFolder folder,
    Future<void> Function(bool deleteChildren)? onDeleted,
  }) async {
    bool deleteChildren = false;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete "${folder.name}"?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you sure you want to delete this folder?',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: deleteChildren,
                    onChanged: (val) {
                      setState(() {
                        deleteChildren = val ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.error,
                    title: const Text(
                      'Also delete subfolders inside',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (onDeleted != null) {
                      await onDeleted(deleteChildren);
                    }
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Displays a dialog to move a playlist to any folder or unfiled root.
  static Future<String?> showMovePlaylistDialog(
    BuildContext context, {
    required String playlistId,
    required List<PlaylistFolder> availableFolders,
    String? currentFolderId,
    Future<void> Function(String? targetFolderId)? onMoved,
  }) async {
    String? selectedFolderId = currentFolderId;

    return showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Move to Folder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              content: SizedBox(
                width: 320,
                height: 280,
                child: ListView(
                  children: [
                    RadioListTile<String?>(
                      value: null,
                      groupValue: selectedFolderId,
                      activeColor: AppTheme.accent,
                      onChanged: (val) {
                        setState(() => selectedFolderId = val);
                      },
                      title: const Text(
                        'Root (No Folder)',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.folder_off_outlined,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Divider(color: AppTheme.divider, height: 1),
                    ...availableFolders.map((f) {
                      return RadioListTile<String?>(
                        value: f.id,
                        groupValue: selectedFolderId,
                        activeColor: AppTheme.accent,
                        onChanged: (val) {
                          setState(() => selectedFolderId = val);
                        },
                        title: Text(
                          f.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${f.playlistIds.length} playlists',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        secondary: Icon(
                          Icons.folder_rounded,
                          color: f.color ?? AppTheme.accent,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (onMoved != null) {
                      await onMoved(selectedFolderId);
                    }
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop(selectedFolderId);
                    }
                  },
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// Full View Widget: PlaylistFolderTreeView
// ============================================================================

/// Complete tree view widget rendering the recursive hierarchy of folders and playlists,
/// complete with search filtering, top actions, expand/collapse toggles, and empty state.
class PlaylistFolderTreeView extends ConsumerStatefulWidget {
  /// All user playlists to be mapped into the folder tree.
  final List<Playlist> playlists;

  /// Callback when a playlist inside the tree is tapped.
  final ValueChanged<Playlist>? onPlaylistSelected;

  /// Callback when a folder inside the tree is tapped.
  final ValueChanged<PlaylistFolder>? onFolderSelected;

  /// Whether to show the search bar at the top of the tree view.
  final bool showSearchBar;

  /// Whether to show the action buttons header (New Folder, Expand/Collapse All).
  final bool showHeaderActions;

  const PlaylistFolderTreeView({
    super.key,
    this.playlists = const [],
    this.onPlaylistSelected,
    this.onFolderSelected,
    this.showSearchBar = true,
    this.showHeaderActions = true,
  });

  @override
  ConsumerState<PlaylistFolderTreeView> createState() =>
      _PlaylistFolderTreeViewState();
}

class _PlaylistFolderTreeViewState
    extends ConsumerState<PlaylistFolderTreeView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(playlistFolderManagerProvider);
    final manager = ref.read(playlistFolderManagerProvider.notifier);

    final playlistsMap = {for (final p in widget.playlists) p.id: p};
    final treeNodes = folderState.buildTreeNodes(playlistsMap: playlistsMap);
    final unfiledPlaylists = folderState.getUnfiledPlaylists(widget.playlists);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Optional Search & Top Header Controls
        if (widget.showSearchBar || widget.showHeaderActions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (widget.showSearchBar)
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        onChanged: manager.setSearchQuery,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Filter folders & playlists...',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    manager.setSearchQuery('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.card,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.showHeaderActions) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'New Folder',
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 20,
                      color: AppTheme.textPrimary,
                    ),
                    onPressed: () {
                      PlaylistFolderDialogs.showCreateFolderDialog(
                        context,
                        onCreated: (name) => manager.createFolder(name),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: folderState.expandedFolderIds.isEmpty
                        ? 'Expand All'
                        : 'Collapse All',
                    icon: Icon(
                      folderState.expandedFolderIds.isEmpty
                          ? Icons.unfold_more_rounded
                          : Icons.unfold_less_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      if (folderState.expandedFolderIds.isEmpty) {
                        manager.expandAll();
                      } else {
                        manager.collapseAll();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

        // 2. Main Tree List or Empty State
        Expanded(
          child: (treeNodes.isEmpty && unfiledPlaylists.isEmpty)
              ? _buildEmptyState(context, manager)
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  children: [
                    // Render Hierarchical Tree Nodes
                    ...treeNodes.expand((node) => _renderNode(node, manager)),

                    // Unfiled Playlists Section
                    if (unfiledPlaylists.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          'UNFILED PLAYLISTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      ...unfiledPlaylists.map((p) {
                        return PlaylistFolderTreeItem.playlist(
                          playlist: p,
                          depth: 0,
                          onTap: () => widget.onPlaylistSelected?.call(p),
                          onMove: () {
                            PlaylistFolderDialogs.showMovePlaylistDialog(
                              context,
                              playlistId: p.id,
                              availableFolders: folderState.allFolders,
                              onMoved: (targetId) => manager.movePlaylist(
                                playlistId: p.id,
                                targetFolderId: targetId,
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// Recursively renders a folder node and its children according to expansion state.
  List<Widget> _renderNode(
    PlaylistFolderNode node,
    PlaylistFolderManager manager,
  ) {
    final widgets = <Widget>[];

    widgets.add(
      PlaylistFolderTreeItem.folder(
        folder: node.folder,
        depth: node.depth,
        isExpanded: node.isExpanded,
        isSelected: ref.watch(playlistFolderManagerProvider).selectedFolderId ==
            node.folder.id,
        onTap: () {
          manager.selectFolder(node.folder.id);
          widget.onFolderSelected?.call(node.folder);
        },
        onToggleExpand: () => manager.toggleFolderExpanded(node.folder.id),
        onAddSubfolder: () {
          PlaylistFolderDialogs.showCreateFolderDialog(
            context,
            parentFolderId: node.folder.id,
            parentFolderName: node.folder.name,
            onCreated: (name) => manager.createFolder(
              name,
              parentFolderId: node.folder.id,
            ),
          );
        },
        onRename: (currentName) {
          PlaylistFolderDialogs.showRenameFolderDialog(
            context,
            folder: node.folder,
            onRenamed: (newName) =>
                manager.renameFolder(node.folder.id, newName),
          );
        },
        onDelete: () {
          PlaylistFolderDialogs.showDeleteFolderDialog(
            context,
            folder: node.folder,
            onDeleted: (deleteChildren) => manager.deleteFolder(
              node.folder.id,
              deleteChildren: deleteChildren,
            ),
          );
        },
      ),
    );

    // If expanded, render child subfolders and child playlists
    if (node.isExpanded) {
      for (final sub in node.subfolders) {
        widgets.addAll(_renderNode(sub, manager));
      }

      for (final playlist in node.resolvedPlaylists) {
        widgets.add(
          PlaylistFolderTreeItem.playlist(
            playlist: playlist,
            depth: node.depth + 1,
            onTap: () => widget.onPlaylistSelected?.call(playlist),
            onMove: () {
              PlaylistFolderDialogs.showMovePlaylistDialog(
                context,
                playlistId: playlist.id,
                currentFolderId: node.folder.id,
                availableFolders:
                    ref.read(playlistFolderManagerProvider).allFolders,
                onMoved: (targetId) => manager.movePlaylist(
                  playlistId: playlist.id,
                  targetFolderId: targetId,
                ),
              );
            },
            onRemovePlaylist: () => manager.removePlaylist(playlist.id),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildEmptyState(
    BuildContext context,
    PlaylistFolderManager manager,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_special_rounded,
                size: 40,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Folders Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Organize your playlists into nested folders for quick library navigation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.create_new_folder_rounded, size: 18),
              label: const Text('Create Folder'),
              onPressed: () {
                PlaylistFolderDialogs.showCreateFolderDialog(
                  context,
                  onCreated: (name) => manager.createFolder(name),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
