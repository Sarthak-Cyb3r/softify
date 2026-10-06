// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _matchConfidenceMeta =
      const VerificationMeta('matchConfidence');
  @override
  late final GeneratedColumn<double> matchConfidence = GeneratedColumn<double>(
      'match_confidence', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _isLikedMeta =
      const VerificationMeta('isLiked');
  @override
  late final GeneratedColumn<bool> isLiked = GeneratedColumn<bool>(
      'is_liked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_liked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isUnavailableMeta =
      const VerificationMeta('isUnavailable');
  @override
  late final GeneratedColumn<bool> isUnavailable = GeneratedColumn<bool>(
      'is_unavailable', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_unavailable" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sourceId,
        title,
        artist,
        album,
        durationMs,
        coverUrl,
        matchConfidence,
        isLiked,
        isUnavailable,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(Insertable<TrackRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    }
    if (data.containsKey('match_confidence')) {
      context.handle(
          _matchConfidenceMeta,
          matchConfidence.isAcceptableOrUnknown(
              data['match_confidence']!, _matchConfidenceMeta));
    }
    if (data.containsKey('is_liked')) {
      context.handle(_isLikedMeta,
          isLiked.isAcceptableOrUnknown(data['is_liked']!, _isLikedMeta));
    }
    if (data.containsKey('is_unavailable')) {
      context.handle(
          _isUnavailableMeta,
          isUnavailable.isAcceptableOrUnknown(
              data['is_unavailable']!, _isUnavailableMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {sourceId},
      ];
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album']),
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url']),
      matchConfidence: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}match_confidence']),
      isLiked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_liked'])!,
      isUnavailable: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_unavailable'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final String id;
  final String sourceId;
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
  final String? coverUrl;
  final double? matchConfidence;
  final bool isLiked;
  final bool isUnavailable;
  final int createdAt;
  const TrackRow(
      {required this.id,
      required this.sourceId,
      required this.title,
      required this.artist,
      this.album,
      required this.durationMs,
      this.coverUrl,
      this.matchConfidence,
      required this.isLiked,
      required this.isUnavailable,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || matchConfidence != null) {
      map['match_confidence'] = Variable<double>(matchConfidence);
    }
    map['is_liked'] = Variable<bool>(isLiked);
    map['is_unavailable'] = Variable<bool>(isUnavailable);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      title: Value(title),
      artist: Value(artist),
      album:
          album == null && nullToAbsent ? const Value.absent() : Value(album),
      durationMs: Value(durationMs),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      matchConfidence: matchConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(matchConfidence),
      isLiked: Value(isLiked),
      isUnavailable: Value(isUnavailable),
      createdAt: Value(createdAt),
    );
  }

  factory TrackRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      matchConfidence: serializer.fromJson<double?>(json['matchConfidence']),
      isLiked: serializer.fromJson<bool>(json['isLiked']),
      isUnavailable: serializer.fromJson<bool>(json['isUnavailable']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String?>(album),
      'durationMs': serializer.toJson<int>(durationMs),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'matchConfidence': serializer.toJson<double?>(matchConfidence),
      'isLiked': serializer.toJson<bool>(isLiked),
      'isUnavailable': serializer.toJson<bool>(isUnavailable),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  TrackRow copyWith(
          {String? id,
          String? sourceId,
          String? title,
          String? artist,
          Value<String?> album = const Value.absent(),
          int? durationMs,
          Value<String?> coverUrl = const Value.absent(),
          Value<double?> matchConfidence = const Value.absent(),
          bool? isLiked,
          bool? isUnavailable,
          int? createdAt}) =>
      TrackRow(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album.present ? album.value : this.album,
        durationMs: durationMs ?? this.durationMs,
        coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
        matchConfidence: matchConfidence.present
            ? matchConfidence.value
            : this.matchConfidence,
        isLiked: isLiked ?? this.isLiked,
        isUnavailable: isUnavailable ?? this.isUnavailable,
        createdAt: createdAt ?? this.createdAt,
      );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      matchConfidence: data.matchConfidence.present
          ? data.matchConfidence.value
          : this.matchConfidence,
      isLiked: data.isLiked.present ? data.isLiked.value : this.isLiked,
      isUnavailable: data.isUnavailable.present
          ? data.isUnavailable.value
          : this.isUnavailable,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('matchConfidence: $matchConfidence, ')
          ..write('isLiked: $isLiked, ')
          ..write('isUnavailable: $isUnavailable, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, title, artist, album,
      durationMs, coverUrl, matchConfidence, isLiked, isUnavailable, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.durationMs == this.durationMs &&
          other.coverUrl == this.coverUrl &&
          other.matchConfidence == this.matchConfidence &&
          other.isLiked == this.isLiked &&
          other.isUnavailable == this.isUnavailable &&
          other.createdAt == this.createdAt);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String?> album;
  final Value<int> durationMs;
  final Value<String?> coverUrl;
  final Value<double?> matchConfidence;
  final Value<bool> isLiked;
  final Value<bool> isUnavailable;
  final Value<int> createdAt;
  final Value<int> rowid;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.matchConfidence = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.isUnavailable = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TracksCompanion.insert({
    required String id,
    required String sourceId,
    required String title,
    required String artist,
    this.album = const Value.absent(),
    required int durationMs,
    this.coverUrl = const Value.absent(),
    this.matchConfidence = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.isUnavailable = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sourceId = Value(sourceId),
        title = Value(title),
        artist = Value(artist),
        durationMs = Value(durationMs),
        createdAt = Value(createdAt);
  static Insertable<TrackRow> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? durationMs,
    Expression<String>? coverUrl,
    Expression<double>? matchConfidence,
    Expression<bool>? isLiked,
    Expression<bool>? isUnavailable,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (durationMs != null) 'duration_ms': durationMs,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (matchConfidence != null) 'match_confidence': matchConfidence,
      if (isLiked != null) 'is_liked': isLiked,
      if (isUnavailable != null) 'is_unavailable': isUnavailable,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TracksCompanion copyWith(
      {Value<String>? id,
      Value<String>? sourceId,
      Value<String>? title,
      Value<String>? artist,
      Value<String?>? album,
      Value<int>? durationMs,
      Value<String?>? coverUrl,
      Value<double?>? matchConfidence,
      Value<bool>? isLiked,
      Value<bool>? isUnavailable,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return TracksCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      coverUrl: coverUrl ?? this.coverUrl,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      isLiked: isLiked ?? this.isLiked,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (matchConfidence.present) {
      map['match_confidence'] = Variable<double>(matchConfidence.value);
    }
    if (isLiked.present) {
      map['is_liked'] = Variable<bool>(isLiked.value);
    }
    if (isUnavailable.present) {
      map['is_unavailable'] = Variable<bool>(isUnavailable.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('matchConfidence: $matchConfidence, ')
          ..write('isLiked: $isLiked, ')
          ..write('isUnavailable: $isUnavailable, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isImportedMeta =
      const VerificationMeta('isImported');
  @override
  late final GeneratedColumn<bool> isImported = GeneratedColumn<bool>(
      'is_imported', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_imported" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, description, isImported, sourceUrl, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(Insertable<PlaylistRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('is_imported')) {
      context.handle(
          _isImportedMeta,
          isImported.isAcceptableOrUnknown(
              data['is_imported']!, _isImportedMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      isImported: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_imported'])!,
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final String id;
  final String name;
  final String? description;
  final bool isImported;
  final String? sourceUrl;
  final int createdAt;
  const PlaylistRow(
      {required this.id,
      required this.name,
      this.description,
      required this.isImported,
      this.sourceUrl,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_imported'] = Variable<bool>(isImported);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isImported: Value(isImported),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      createdAt: Value(createdAt),
    );
  }

  factory PlaylistRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isImported: serializer.fromJson<bool>(json['isImported']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isImported': serializer.toJson<bool>(isImported),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PlaylistRow copyWith(
          {String? id,
          String? name,
          Value<String?> description = const Value.absent(),
          bool? isImported,
          Value<String?> sourceUrl = const Value.absent(),
          int? createdAt}) =>
      PlaylistRow(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        isImported: isImported ?? this.isImported,
        sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
        createdAt: createdAt ?? this.createdAt,
      );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      isImported:
          data.isImported.present ? data.isImported.value : this.isImported,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isImported: $isImported, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, isImported, sourceUrl, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.isImported == this.isImported &&
          other.sourceUrl == this.sourceUrl &&
          other.createdAt == this.createdAt);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isImported;
  final Value<String?> sourceUrl;
  final Value<int> createdAt;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isImported = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.isImported = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<PlaylistRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isImported,
    Expression<String>? sourceUrl,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isImported != null) 'is_imported': isImported,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<bool>? isImported,
      Value<String?>? sourceUrl,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isImported: isImported ?? this.isImported,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isImported.present) {
      map['is_imported'] = Variable<bool>(isImported.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isImported: $isImported, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, PlaylistTrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES playlists (id) ON DELETE CASCADE'));
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracks (id) ON DELETE SET NULL'));
  static const VerificationMeta _originalTitleMeta =
      const VerificationMeta('originalTitle');
  @override
  late final GeneratedColumn<String> originalTitle = GeneratedColumn<String>(
      'original_title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalArtistMeta =
      const VerificationMeta('originalArtist');
  @override
  late final GeneratedColumn<String> originalArtist = GeneratedColumn<String>(
      'original_artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _matchStatusMeta =
      const VerificationMeta('matchStatus');
  @override
  late final GeneratedColumn<String> matchStatus = GeneratedColumn<String>(
      'match_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        playlistId,
        position,
        trackId,
        originalTitle,
        originalArtist,
        matchStatus
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(Insertable<PlaylistTrackRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    }
    if (data.containsKey('original_title')) {
      context.handle(
          _originalTitleMeta,
          originalTitle.isAcceptableOrUnknown(
              data['original_title']!, _originalTitleMeta));
    } else if (isInserting) {
      context.missing(_originalTitleMeta);
    }
    if (data.containsKey('original_artist')) {
      context.handle(
          _originalArtistMeta,
          originalArtist.isAcceptableOrUnknown(
              data['original_artist']!, _originalArtistMeta));
    } else if (isInserting) {
      context.missing(_originalArtistMeta);
    }
    if (data.containsKey('match_status')) {
      context.handle(
          _matchStatusMeta,
          matchStatus.isAcceptableOrUnknown(
              data['match_status']!, _matchStatusMeta));
    } else if (isInserting) {
      context.missing(_matchStatusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, position};
  @override
  PlaylistTrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTrackRow(
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}playlist_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id']),
      originalTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}original_title'])!,
      originalArtist: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}original_artist'])!,
      matchStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}match_status'])!,
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class PlaylistTrackRow extends DataClass
    implements Insertable<PlaylistTrackRow> {
  final String playlistId;
  final int position;
  final String? trackId;
  final String originalTitle;
  final String originalArtist;
  final String matchStatus;
  const PlaylistTrackRow(
      {required this.playlistId,
      required this.position,
      this.trackId,
      required this.originalTitle,
      required this.originalArtist,
      required this.matchStatus});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<String>(trackId);
    }
    map['original_title'] = Variable<String>(originalTitle);
    map['original_artist'] = Variable<String>(originalArtist);
    map['match_status'] = Variable<String>(matchStatus);
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      playlistId: Value(playlistId),
      position: Value(position),
      trackId: trackId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackId),
      originalTitle: Value(originalTitle),
      originalArtist: Value(originalArtist),
      matchStatus: Value(matchStatus),
    );
  }

  factory PlaylistTrackRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTrackRow(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      position: serializer.fromJson<int>(json['position']),
      trackId: serializer.fromJson<String?>(json['trackId']),
      originalTitle: serializer.fromJson<String>(json['originalTitle']),
      originalArtist: serializer.fromJson<String>(json['originalArtist']),
      matchStatus: serializer.fromJson<String>(json['matchStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'position': serializer.toJson<int>(position),
      'trackId': serializer.toJson<String?>(trackId),
      'originalTitle': serializer.toJson<String>(originalTitle),
      'originalArtist': serializer.toJson<String>(originalArtist),
      'matchStatus': serializer.toJson<String>(matchStatus),
    };
  }

  PlaylistTrackRow copyWith(
          {String? playlistId,
          int? position,
          Value<String?> trackId = const Value.absent(),
          String? originalTitle,
          String? originalArtist,
          String? matchStatus}) =>
      PlaylistTrackRow(
        playlistId: playlistId ?? this.playlistId,
        position: position ?? this.position,
        trackId: trackId.present ? trackId.value : this.trackId,
        originalTitle: originalTitle ?? this.originalTitle,
        originalArtist: originalArtist ?? this.originalArtist,
        matchStatus: matchStatus ?? this.matchStatus,
      );
  PlaylistTrackRow copyWithCompanion(PlaylistTracksCompanion data) {
    return PlaylistTrackRow(
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      position: data.position.present ? data.position.value : this.position,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      originalTitle: data.originalTitle.present
          ? data.originalTitle.value
          : this.originalTitle,
      originalArtist: data.originalArtist.present
          ? data.originalArtist.value
          : this.originalArtist,
      matchStatus:
          data.matchStatus.present ? data.matchStatus.value : this.matchStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTrackRow(')
          ..write('playlistId: $playlistId, ')
          ..write('position: $position, ')
          ..write('trackId: $trackId, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('originalArtist: $originalArtist, ')
          ..write('matchStatus: $matchStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, position, trackId, originalTitle,
      originalArtist, matchStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTrackRow &&
          other.playlistId == this.playlistId &&
          other.position == this.position &&
          other.trackId == this.trackId &&
          other.originalTitle == this.originalTitle &&
          other.originalArtist == this.originalArtist &&
          other.matchStatus == this.matchStatus);
}

class PlaylistTracksCompanion extends UpdateCompanion<PlaylistTrackRow> {
  final Value<String> playlistId;
  final Value<int> position;
  final Value<String?> trackId;
  final Value<String> originalTitle;
  final Value<String> originalArtist;
  final Value<String> matchStatus;
  final Value<int> rowid;
  const PlaylistTracksCompanion({
    this.playlistId = const Value.absent(),
    this.position = const Value.absent(),
    this.trackId = const Value.absent(),
    this.originalTitle = const Value.absent(),
    this.originalArtist = const Value.absent(),
    this.matchStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    required String playlistId,
    required int position,
    this.trackId = const Value.absent(),
    required String originalTitle,
    required String originalArtist,
    required String matchStatus,
    this.rowid = const Value.absent(),
  })  : playlistId = Value(playlistId),
        position = Value(position),
        originalTitle = Value(originalTitle),
        originalArtist = Value(originalArtist),
        matchStatus = Value(matchStatus);
  static Insertable<PlaylistTrackRow> custom({
    Expression<String>? playlistId,
    Expression<int>? position,
    Expression<String>? trackId,
    Expression<String>? originalTitle,
    Expression<String>? originalArtist,
    Expression<String>? matchStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (position != null) 'position': position,
      if (trackId != null) 'track_id': trackId,
      if (originalTitle != null) 'original_title': originalTitle,
      if (originalArtist != null) 'original_artist': originalArtist,
      if (matchStatus != null) 'match_status': matchStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistTracksCompanion copyWith(
      {Value<String>? playlistId,
      Value<int>? position,
      Value<String?>? trackId,
      Value<String>? originalTitle,
      Value<String>? originalArtist,
      Value<String>? matchStatus,
      Value<int>? rowid}) {
    return PlaylistTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      position: position ?? this.position,
      trackId: trackId ?? this.trackId,
      originalTitle: originalTitle ?? this.originalTitle,
      originalArtist: originalArtist ?? this.originalArtist,
      matchStatus: matchStatus ?? this.matchStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (originalTitle.present) {
      map['original_title'] = Variable<String>(originalTitle.value);
    }
    if (originalArtist.present) {
      map['original_artist'] = Variable<String>(originalArtist.value);
    }
    if (matchStatus.present) {
      map['match_status'] = Variable<String>(matchStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('position: $position, ')
          ..write('trackId: $trackId, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('originalArtist: $originalArtist, ')
          ..write('matchStatus: $matchStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueItemsTable extends QueueItems
    with TableInfo<$QueueItemsTable, QueueItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracks (id) ON DELETE CASCADE'));
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
      'added_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [position, trackId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_items';
  @override
  VerificationContext validateIntegrity(Insertable<QueueItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {position};
  @override
  QueueItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueItemRow(
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $QueueItemsTable createAlias(String alias) {
    return $QueueItemsTable(attachedDatabase, alias);
  }
}

class QueueItemRow extends DataClass implements Insertable<QueueItemRow> {
  final int position;
  final String trackId;
  final int addedAt;
  const QueueItemRow(
      {required this.position, required this.trackId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['track_id'] = Variable<String>(trackId);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  QueueItemsCompanion toCompanion(bool nullToAbsent) {
    return QueueItemsCompanion(
      position: Value(position),
      trackId: Value(trackId),
      addedAt: Value(addedAt),
    );
  }

  factory QueueItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueItemRow(
      position: serializer.fromJson<int>(json['position']),
      trackId: serializer.fromJson<String>(json['trackId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'trackId': serializer.toJson<String>(trackId),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  QueueItemRow copyWith({int? position, String? trackId, int? addedAt}) =>
      QueueItemRow(
        position: position ?? this.position,
        trackId: trackId ?? this.trackId,
        addedAt: addedAt ?? this.addedAt,
      );
  QueueItemRow copyWithCompanion(QueueItemsCompanion data) {
    return QueueItemRow(
      position: data.position.present ? data.position.value : this.position,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueItemRow(')
          ..write('position: $position, ')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(position, trackId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueItemRow &&
          other.position == this.position &&
          other.trackId == this.trackId &&
          other.addedAt == this.addedAt);
}

class QueueItemsCompanion extends UpdateCompanion<QueueItemRow> {
  final Value<int> position;
  final Value<String> trackId;
  final Value<int> addedAt;
  const QueueItemsCompanion({
    this.position = const Value.absent(),
    this.trackId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  QueueItemsCompanion.insert({
    this.position = const Value.absent(),
    required String trackId,
    required int addedAt,
  })  : trackId = Value(trackId),
        addedAt = Value(addedAt);
  static Insertable<QueueItemRow> custom({
    Expression<int>? position,
    Expression<String>? trackId,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (trackId != null) 'track_id': trackId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  QueueItemsCompanion copyWith(
      {Value<int>? position, Value<String>? trackId, Value<int>? addedAt}) {
    return QueueItemsCompanion(
      position: position ?? this.position,
      trackId: trackId ?? this.trackId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueItemsCompanion(')
          ..write('position: $position, ')
          ..write('trackId: $trackId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaybackStatesTable extends PlaybackStates
    with TableInfo<$PlaybackStatesTable, PlaybackStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _currentQueueIndexMeta =
      const VerificationMeta('currentQueueIndex');
  @override
  late final GeneratedColumn<int> currentQueueIndex = GeneratedColumn<int>(
      'current_queue_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currentPositionMsMeta =
      const VerificationMeta('currentPositionMs');
  @override
  late final GeneratedColumn<int> currentPositionMs = GeneratedColumn<int>(
      'current_position_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, currentQueueIndex, currentPositionMs, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_states';
  @override
  VerificationContext validateIntegrity(Insertable<PlaybackStateRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_queue_index')) {
      context.handle(
          _currentQueueIndexMeta,
          currentQueueIndex.isAcceptableOrUnknown(
              data['current_queue_index']!, _currentQueueIndexMeta));
    }
    if (data.containsKey('current_position_ms')) {
      context.handle(
          _currentPositionMsMeta,
          currentPositionMs.isAcceptableOrUnknown(
              data['current_position_ms']!, _currentPositionMsMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackStateRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      currentQueueIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_queue_index'])!,
      currentPositionMs: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_position_ms'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlaybackStatesTable createAlias(String alias) {
    return $PlaybackStatesTable(attachedDatabase, alias);
  }
}

class PlaybackStateRow extends DataClass
    implements Insertable<PlaybackStateRow> {
  final int id;
  final int currentQueueIndex;
  final int currentPositionMs;
  final int updatedAt;
  const PlaybackStateRow(
      {required this.id,
      required this.currentQueueIndex,
      required this.currentPositionMs,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_queue_index'] = Variable<int>(currentQueueIndex);
    map['current_position_ms'] = Variable<int>(currentPositionMs);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaybackStatesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackStatesCompanion(
      id: Value(id),
      currentQueueIndex: Value(currentQueueIndex),
      currentPositionMs: Value(currentPositionMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackStateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackStateRow(
      id: serializer.fromJson<int>(json['id']),
      currentQueueIndex: serializer.fromJson<int>(json['currentQueueIndex']),
      currentPositionMs: serializer.fromJson<int>(json['currentPositionMs']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentQueueIndex': serializer.toJson<int>(currentQueueIndex),
      'currentPositionMs': serializer.toJson<int>(currentPositionMs),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaybackStateRow copyWith(
          {int? id,
          int? currentQueueIndex,
          int? currentPositionMs,
          int? updatedAt}) =>
      PlaybackStateRow(
        id: id ?? this.id,
        currentQueueIndex: currentQueueIndex ?? this.currentQueueIndex,
        currentPositionMs: currentPositionMs ?? this.currentPositionMs,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlaybackStateRow copyWithCompanion(PlaybackStatesCompanion data) {
    return PlaybackStateRow(
      id: data.id.present ? data.id.value : this.id,
      currentQueueIndex: data.currentQueueIndex.present
          ? data.currentQueueIndex.value
          : this.currentQueueIndex,
      currentPositionMs: data.currentPositionMs.present
          ? data.currentPositionMs.value
          : this.currentPositionMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStateRow(')
          ..write('id: $id, ')
          ..write('currentQueueIndex: $currentQueueIndex, ')
          ..write('currentPositionMs: $currentPositionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, currentQueueIndex, currentPositionMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackStateRow &&
          other.id == this.id &&
          other.currentQueueIndex == this.currentQueueIndex &&
          other.currentPositionMs == this.currentPositionMs &&
          other.updatedAt == this.updatedAt);
}

class PlaybackStatesCompanion extends UpdateCompanion<PlaybackStateRow> {
  final Value<int> id;
  final Value<int> currentQueueIndex;
  final Value<int> currentPositionMs;
  final Value<int> updatedAt;
  const PlaybackStatesCompanion({
    this.id = const Value.absent(),
    this.currentQueueIndex = const Value.absent(),
    this.currentPositionMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaybackStatesCompanion.insert({
    this.id = const Value.absent(),
    this.currentQueueIndex = const Value.absent(),
    this.currentPositionMs = const Value.absent(),
    required int updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<PlaybackStateRow> custom({
    Expression<int>? id,
    Expression<int>? currentQueueIndex,
    Expression<int>? currentPositionMs,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentQueueIndex != null) 'current_queue_index': currentQueueIndex,
      if (currentPositionMs != null) 'current_position_ms': currentPositionMs,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaybackStatesCompanion copyWith(
      {Value<int>? id,
      Value<int>? currentQueueIndex,
      Value<int>? currentPositionMs,
      Value<int>? updatedAt}) {
    return PlaybackStatesCompanion(
      id: id ?? this.id,
      currentQueueIndex: currentQueueIndex ?? this.currentQueueIndex,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentQueueIndex.present) {
      map['current_queue_index'] = Variable<int>(currentQueueIndex.value);
    }
    if (currentPositionMs.present) {
      map['current_position_ms'] = Variable<int>(currentPositionMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStatesCompanion(')
          ..write('id: $id, ')
          ..write('currentQueueIndex: $currentQueueIndex, ')
          ..write('currentPositionMs: $currentPositionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoriesTable extends PlayHistories
    with TableInfo<$PlayHistoriesTable, PlayHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracks (id) ON DELETE CASCADE'));
  static const VerificationMeta _playedAtMeta =
      const VerificationMeta('playedAt');
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
      'played_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedRatioMeta =
      const VerificationMeta('completedRatio');
  @override
  late final GeneratedColumn<double> completedRatio = GeneratedColumn<double>(
      'completed_ratio', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, trackId, playedAt, completedRatio];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_histories';
  @override
  VerificationContext validateIntegrity(Insertable<PlayHistoryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(_playedAtMeta,
          playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta));
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('completed_ratio')) {
      context.handle(
          _completedRatioMeta,
          completedRatio.isAcceptableOrUnknown(
              data['completed_ratio']!, _completedRatioMeta));
    } else if (isInserting) {
      context.missing(_completedRatioMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      playedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}played_at'])!,
      completedRatio: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}completed_ratio'])!,
    );
  }

  @override
  $PlayHistoriesTable createAlias(String alias) {
    return $PlayHistoriesTable(attachedDatabase, alias);
  }
}

class PlayHistoryRow extends DataClass implements Insertable<PlayHistoryRow> {
  final int id;
  final String trackId;
  final int playedAt;
  final double completedRatio;
  const PlayHistoryRow(
      {required this.id,
      required this.trackId,
      required this.playedAt,
      required this.completedRatio});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<String>(trackId);
    map['played_at'] = Variable<int>(playedAt);
    map['completed_ratio'] = Variable<double>(completedRatio);
    return map;
  }

  PlayHistoriesCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoriesCompanion(
      id: Value(id),
      trackId: Value(trackId),
      playedAt: Value(playedAt),
      completedRatio: Value(completedRatio),
    );
  }

  factory PlayHistoryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<String>(json['trackId']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
      completedRatio: serializer.fromJson<double>(json['completedRatio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<String>(trackId),
      'playedAt': serializer.toJson<int>(playedAt),
      'completedRatio': serializer.toJson<double>(completedRatio),
    };
  }

  PlayHistoryRow copyWith(
          {int? id, String? trackId, int? playedAt, double? completedRatio}) =>
      PlayHistoryRow(
        id: id ?? this.id,
        trackId: trackId ?? this.trackId,
        playedAt: playedAt ?? this.playedAt,
        completedRatio: completedRatio ?? this.completedRatio,
      );
  PlayHistoryRow copyWithCompanion(PlayHistoriesCompanion data) {
    return PlayHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      completedRatio: data.completedRatio.present
          ? data.completedRatio.value
          : this.completedRatio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryRow(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('completedRatio: $completedRatio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackId, playedAt, completedRatio);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryRow &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.playedAt == this.playedAt &&
          other.completedRatio == this.completedRatio);
}

class PlayHistoriesCompanion extends UpdateCompanion<PlayHistoryRow> {
  final Value<int> id;
  final Value<String> trackId;
  final Value<int> playedAt;
  final Value<double> completedRatio;
  const PlayHistoriesCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.completedRatio = const Value.absent(),
  });
  PlayHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required String trackId,
    required int playedAt,
    required double completedRatio,
  })  : trackId = Value(trackId),
        playedAt = Value(playedAt),
        completedRatio = Value(completedRatio);
  static Insertable<PlayHistoryRow> custom({
    Expression<int>? id,
    Expression<String>? trackId,
    Expression<int>? playedAt,
    Expression<double>? completedRatio,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (playedAt != null) 'played_at': playedAt,
      if (completedRatio != null) 'completed_ratio': completedRatio,
    });
  }

  PlayHistoriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? trackId,
      Value<int>? playedAt,
      Value<double>? completedRatio}) {
    return PlayHistoriesCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      playedAt: playedAt ?? this.playedAt,
      completedRatio: completedRatio ?? this.completedRatio,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (completedRatio.present) {
      map['completed_ratio'] = Variable<double>(completedRatio.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('completedRatio: $completedRatio')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracks (id) ON DELETE CASCADE'));
  static const VerificationMeta _relativePathMeta =
      const VerificationMeta('relativePath');
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
      'relative_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _containerFormatMeta =
      const VerificationMeta('containerFormat');
  @override
  late final GeneratedColumn<String> containerFormat = GeneratedColumn<String>(
      'container_format', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('m4a'));
  static const VerificationMeta _fileSizeBytesMeta =
      const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _bytesDownloadedMeta =
      const VerificationMeta('bytesDownloaded');
  @override
  late final GeneratedColumn<int> bytesDownloaded = GeneratedColumn<int>(
      'bytes_downloaded', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        trackId,
        relativePath,
        containerFormat,
        fileSizeBytes,
        bytesDownloaded,
        status,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
          _relativePathMeta,
          relativePath.isAcceptableOrUnknown(
              data['relative_path']!, _relativePathMeta));
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('container_format')) {
      context.handle(
          _containerFormatMeta,
          containerFormat.isAcceptableOrUnknown(
              data['container_format']!, _containerFormatMeta));
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
          _fileSizeBytesMeta,
          fileSizeBytes.isAcceptableOrUnknown(
              data['file_size_bytes']!, _fileSizeBytesMeta));
    }
    if (data.containsKey('bytes_downloaded')) {
      context.handle(
          _bytesDownloadedMeta,
          bytesDownloaded.isAcceptableOrUnknown(
              data['bytes_downloaded']!, _bytesDownloadedMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      relativePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}relative_path'])!,
      containerFormat: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}container_format'])!,
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes'])!,
      bytesDownloaded: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bytes_downloaded'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  final String trackId;
  final String relativePath;
  final String containerFormat;
  final int fileSizeBytes;
  final int bytesDownloaded;
  final String status;
  final int createdAt;
  const DownloadRow(
      {required this.trackId,
      required this.relativePath,
      required this.containerFormat,
      required this.fileSizeBytes,
      required this.bytesDownloaded,
      required this.status,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['relative_path'] = Variable<String>(relativePath);
    map['container_format'] = Variable<String>(containerFormat);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    map['bytes_downloaded'] = Variable<int>(bytesDownloaded);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      trackId: Value(trackId),
      relativePath: Value(relativePath),
      containerFormat: Value(containerFormat),
      fileSizeBytes: Value(fileSizeBytes),
      bytesDownloaded: Value(bytesDownloaded),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory DownloadRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      trackId: serializer.fromJson<String>(json['trackId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      containerFormat: serializer.fromJson<String>(json['containerFormat']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      bytesDownloaded: serializer.fromJson<int>(json['bytesDownloaded']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'relativePath': serializer.toJson<String>(relativePath),
      'containerFormat': serializer.toJson<String>(containerFormat),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'bytesDownloaded': serializer.toJson<int>(bytesDownloaded),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DownloadRow copyWith(
          {String? trackId,
          String? relativePath,
          String? containerFormat,
          int? fileSizeBytes,
          int? bytesDownloaded,
          String? status,
          int? createdAt}) =>
      DownloadRow(
        trackId: trackId ?? this.trackId,
        relativePath: relativePath ?? this.relativePath,
        containerFormat: containerFormat ?? this.containerFormat,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      containerFormat: data.containerFormat.present
          ? data.containerFormat.value
          : this.containerFormat,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      bytesDownloaded: data.bytesDownloaded.present
          ? data.bytesDownloaded.value
          : this.bytesDownloaded,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('trackId: $trackId, ')
          ..write('relativePath: $relativePath, ')
          ..write('containerFormat: $containerFormat, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, relativePath, containerFormat,
      fileSizeBytes, bytesDownloaded, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.trackId == this.trackId &&
          other.relativePath == this.relativePath &&
          other.containerFormat == this.containerFormat &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.bytesDownloaded == this.bytesDownloaded &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<String> trackId;
  final Value<String> relativePath;
  final Value<String> containerFormat;
  final Value<int> fileSizeBytes;
  final Value<int> bytesDownloaded;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.trackId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.containerFormat = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String trackId,
    required String relativePath,
    this.containerFormat = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.bytesDownloaded = const Value.absent(),
    required String status,
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : trackId = Value(trackId),
        relativePath = Value(relativePath),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<DownloadRow> custom({
    Expression<String>? trackId,
    Expression<String>? relativePath,
    Expression<String>? containerFormat,
    Expression<int>? fileSizeBytes,
    Expression<int>? bytesDownloaded,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (relativePath != null) 'relative_path': relativePath,
      if (containerFormat != null) 'container_format': containerFormat,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (bytesDownloaded != null) 'bytes_downloaded': bytesDownloaded,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith(
      {Value<String>? trackId,
      Value<String>? relativePath,
      Value<String>? containerFormat,
      Value<int>? fileSizeBytes,
      Value<int>? bytesDownloaded,
      Value<String>? status,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return DownloadsCompanion(
      trackId: trackId ?? this.trackId,
      relativePath: relativePath ?? this.relativePath,
      containerFormat: containerFormat ?? this.containerFormat,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (containerFormat.present) {
      map['container_format'] = Variable<String>(containerFormat.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (bytesDownloaded.present) {
      map['bytes_downloaded'] = Variable<int>(bytesDownloaded.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('relativePath: $relativePath, ')
          ..write('containerFormat: $containerFormat, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('bytesDownloaded: $bytesDownloaded, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedLyricsTable extends CachedLyrics
    with TableInfo<$CachedLyricsTable, CachedLyricRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedLyricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tracks (id) ON DELETE CASCADE'));
  static const VerificationMeta _syncedLrcMeta =
      const VerificationMeta('syncedLrc');
  @override
  late final GeneratedColumn<String> syncedLrc = GeneratedColumn<String>(
      'synced_lrc', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _plainTextMeta =
      const VerificationMeta('plainText');
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
      'plain_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isNotFoundMeta =
      const VerificationMeta('isNotFound');
  @override
  late final GeneratedColumn<bool> isNotFound = GeneratedColumn<bool>(
      'is_not_found', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_not_found" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [trackId, syncedLrc, plainText, isNotFound, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_lyrics';
  @override
  VerificationContext validateIntegrity(Insertable<CachedLyricRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('synced_lrc')) {
      context.handle(_syncedLrcMeta,
          syncedLrc.isAcceptableOrUnknown(data['synced_lrc']!, _syncedLrcMeta));
    }
    if (data.containsKey('plain_text')) {
      context.handle(_plainTextMeta,
          plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta));
    }
    if (data.containsKey('is_not_found')) {
      context.handle(
          _isNotFoundMeta,
          isNotFound.isAcceptableOrUnknown(
              data['is_not_found']!, _isNotFoundMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  CachedLyricRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedLyricRow(
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      syncedLrc: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_lrc']),
      plainText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plain_text']),
      isNotFound: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_not_found'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $CachedLyricsTable createAlias(String alias) {
    return $CachedLyricsTable(attachedDatabase, alias);
  }
}

class CachedLyricRow extends DataClass implements Insertable<CachedLyricRow> {
  final String trackId;
  final String? syncedLrc;
  final String? plainText;
  final bool isNotFound;
  final int cachedAt;
  const CachedLyricRow(
      {required this.trackId,
      this.syncedLrc,
      this.plainText,
      required this.isNotFound,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    if (!nullToAbsent || syncedLrc != null) {
      map['synced_lrc'] = Variable<String>(syncedLrc);
    }
    if (!nullToAbsent || plainText != null) {
      map['plain_text'] = Variable<String>(plainText);
    }
    map['is_not_found'] = Variable<bool>(isNotFound);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  CachedLyricsCompanion toCompanion(bool nullToAbsent) {
    return CachedLyricsCompanion(
      trackId: Value(trackId),
      syncedLrc: syncedLrc == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedLrc),
      plainText: plainText == null && nullToAbsent
          ? const Value.absent()
          : Value(plainText),
      isNotFound: Value(isNotFound),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedLyricRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedLyricRow(
      trackId: serializer.fromJson<String>(json['trackId']),
      syncedLrc: serializer.fromJson<String?>(json['syncedLrc']),
      plainText: serializer.fromJson<String?>(json['plainText']),
      isNotFound: serializer.fromJson<bool>(json['isNotFound']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'syncedLrc': serializer.toJson<String?>(syncedLrc),
      'plainText': serializer.toJson<String?>(plainText),
      'isNotFound': serializer.toJson<bool>(isNotFound),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  CachedLyricRow copyWith(
          {String? trackId,
          Value<String?> syncedLrc = const Value.absent(),
          Value<String?> plainText = const Value.absent(),
          bool? isNotFound,
          int? cachedAt}) =>
      CachedLyricRow(
        trackId: trackId ?? this.trackId,
        syncedLrc: syncedLrc.present ? syncedLrc.value : this.syncedLrc,
        plainText: plainText.present ? plainText.value : this.plainText,
        isNotFound: isNotFound ?? this.isNotFound,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CachedLyricRow copyWithCompanion(CachedLyricsCompanion data) {
    return CachedLyricRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      syncedLrc: data.syncedLrc.present ? data.syncedLrc.value : this.syncedLrc,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      isNotFound:
          data.isNotFound.present ? data.isNotFound.value : this.isNotFound,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedLyricRow(')
          ..write('trackId: $trackId, ')
          ..write('syncedLrc: $syncedLrc, ')
          ..write('plainText: $plainText, ')
          ..write('isNotFound: $isNotFound, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackId, syncedLrc, plainText, isNotFound, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedLyricRow &&
          other.trackId == this.trackId &&
          other.syncedLrc == this.syncedLrc &&
          other.plainText == this.plainText &&
          other.isNotFound == this.isNotFound &&
          other.cachedAt == this.cachedAt);
}

class CachedLyricsCompanion extends UpdateCompanion<CachedLyricRow> {
  final Value<String> trackId;
  final Value<String?> syncedLrc;
  final Value<String?> plainText;
  final Value<bool> isNotFound;
  final Value<int> cachedAt;
  final Value<int> rowid;
  const CachedLyricsCompanion({
    this.trackId = const Value.absent(),
    this.syncedLrc = const Value.absent(),
    this.plainText = const Value.absent(),
    this.isNotFound = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedLyricsCompanion.insert({
    required String trackId,
    this.syncedLrc = const Value.absent(),
    this.plainText = const Value.absent(),
    this.isNotFound = const Value.absent(),
    required int cachedAt,
    this.rowid = const Value.absent(),
  })  : trackId = Value(trackId),
        cachedAt = Value(cachedAt);
  static Insertable<CachedLyricRow> custom({
    Expression<String>? trackId,
    Expression<String>? syncedLrc,
    Expression<String>? plainText,
    Expression<bool>? isNotFound,
    Expression<int>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (syncedLrc != null) 'synced_lrc': syncedLrc,
      if (plainText != null) 'plain_text': plainText,
      if (isNotFound != null) 'is_not_found': isNotFound,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedLyricsCompanion copyWith(
      {Value<String>? trackId,
      Value<String?>? syncedLrc,
      Value<String?>? plainText,
      Value<bool>? isNotFound,
      Value<int>? cachedAt,
      Value<int>? rowid}) {
    return CachedLyricsCompanion(
      trackId: trackId ?? this.trackId,
      syncedLrc: syncedLrc ?? this.syncedLrc,
      plainText: plainText ?? this.plainText,
      isNotFound: isNotFound ?? this.isNotFound,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (syncedLrc.present) {
      map['synced_lrc'] = Variable<String>(syncedLrc.value);
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (isNotFound.present) {
      map['is_not_found'] = Variable<bool>(isNotFound.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedLyricsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('syncedLrc: $syncedLrc, ')
          ..write('plainText: $plainText, ')
          ..write('isNotFound: $isNotFound, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) => SettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PipedInstancesTable extends PipedInstances
    with TableInfo<$PipedInstancesTable, PipedInstanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PipedInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latencyMsMeta =
      const VerificationMeta('latencyMs');
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
      'latency_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isHealthyMeta =
      const VerificationMeta('isHealthy');
  @override
  late final GeneratedColumn<bool> isHealthy = GeneratedColumn<bool>(
      'is_healthy', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_healthy" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _lastCheckedMeta =
      const VerificationMeta('lastChecked');
  @override
  late final GeneratedColumn<int> lastChecked = GeneratedColumn<int>(
      'last_checked', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [url, latencyMs, isHealthy, lastChecked];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'piped_instances';
  @override
  VerificationContext validateIntegrity(Insertable<PipedInstanceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(_latencyMsMeta,
          latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta));
    }
    if (data.containsKey('is_healthy')) {
      context.handle(_isHealthyMeta,
          isHealthy.isAcceptableOrUnknown(data['is_healthy']!, _isHealthyMeta));
    }
    if (data.containsKey('last_checked')) {
      context.handle(
          _lastCheckedMeta,
          lastChecked.isAcceptableOrUnknown(
              data['last_checked']!, _lastCheckedMeta));
    } else if (isInserting) {
      context.missing(_lastCheckedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {url};
  @override
  PipedInstanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PipedInstanceRow(
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      latencyMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}latency_ms']),
      isHealthy: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_healthy'])!,
      lastChecked: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_checked'])!,
    );
  }

  @override
  $PipedInstancesTable createAlias(String alias) {
    return $PipedInstancesTable(attachedDatabase, alias);
  }
}

class PipedInstanceRow extends DataClass
    implements Insertable<PipedInstanceRow> {
  final String url;
  final int? latencyMs;
  final bool isHealthy;
  final int lastChecked;
  const PipedInstanceRow(
      {required this.url,
      this.latencyMs,
      required this.isHealthy,
      required this.lastChecked});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    map['is_healthy'] = Variable<bool>(isHealthy);
    map['last_checked'] = Variable<int>(lastChecked);
    return map;
  }

  PipedInstancesCompanion toCompanion(bool nullToAbsent) {
    return PipedInstancesCompanion(
      url: Value(url),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
      isHealthy: Value(isHealthy),
      lastChecked: Value(lastChecked),
    );
  }

  factory PipedInstanceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PipedInstanceRow(
      url: serializer.fromJson<String>(json['url']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
      isHealthy: serializer.fromJson<bool>(json['isHealthy']),
      lastChecked: serializer.fromJson<int>(json['lastChecked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'latencyMs': serializer.toJson<int?>(latencyMs),
      'isHealthy': serializer.toJson<bool>(isHealthy),
      'lastChecked': serializer.toJson<int>(lastChecked),
    };
  }

  PipedInstanceRow copyWith(
          {String? url,
          Value<int?> latencyMs = const Value.absent(),
          bool? isHealthy,
          int? lastChecked}) =>
      PipedInstanceRow(
        url: url ?? this.url,
        latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
        isHealthy: isHealthy ?? this.isHealthy,
        lastChecked: lastChecked ?? this.lastChecked,
      );
  PipedInstanceRow copyWithCompanion(PipedInstancesCompanion data) {
    return PipedInstanceRow(
      url: data.url.present ? data.url.value : this.url,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      isHealthy: data.isHealthy.present ? data.isHealthy.value : this.isHealthy,
      lastChecked:
          data.lastChecked.present ? data.lastChecked.value : this.lastChecked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PipedInstanceRow(')
          ..write('url: $url, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('isHealthy: $isHealthy, ')
          ..write('lastChecked: $lastChecked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(url, latencyMs, isHealthy, lastChecked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PipedInstanceRow &&
          other.url == this.url &&
          other.latencyMs == this.latencyMs &&
          other.isHealthy == this.isHealthy &&
          other.lastChecked == this.lastChecked);
}

class PipedInstancesCompanion extends UpdateCompanion<PipedInstanceRow> {
  final Value<String> url;
  final Value<int?> latencyMs;
  final Value<bool> isHealthy;
  final Value<int> lastChecked;
  final Value<int> rowid;
  const PipedInstancesCompanion({
    this.url = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.isHealthy = const Value.absent(),
    this.lastChecked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PipedInstancesCompanion.insert({
    required String url,
    this.latencyMs = const Value.absent(),
    this.isHealthy = const Value.absent(),
    required int lastChecked,
    this.rowid = const Value.absent(),
  })  : url = Value(url),
        lastChecked = Value(lastChecked);
  static Insertable<PipedInstanceRow> custom({
    Expression<String>? url,
    Expression<int>? latencyMs,
    Expression<bool>? isHealthy,
    Expression<int>? lastChecked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (isHealthy != null) 'is_healthy': isHealthy,
      if (lastChecked != null) 'last_checked': lastChecked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PipedInstancesCompanion copyWith(
      {Value<String>? url,
      Value<int?>? latencyMs,
      Value<bool>? isHealthy,
      Value<int>? lastChecked,
      Value<int>? rowid}) {
    return PipedInstancesCompanion(
      url: url ?? this.url,
      latencyMs: latencyMs ?? this.latencyMs,
      isHealthy: isHealthy ?? this.isHealthy,
      lastChecked: lastChecked ?? this.lastChecked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (isHealthy.present) {
      map['is_healthy'] = Variable<bool>(isHealthy.value);
    }
    if (lastChecked.present) {
      map['last_checked'] = Variable<int>(lastChecked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PipedInstancesCompanion(')
          ..write('url: $url, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('isHealthy: $isHealthy, ')
          ..write('lastChecked: $lastChecked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $QueueItemsTable queueItems = $QueueItemsTable(this);
  late final $PlaybackStatesTable playbackStates = $PlaybackStatesTable(this);
  late final $PlayHistoriesTable playHistories = $PlayHistoriesTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $CachedLyricsTable cachedLyrics = $CachedLyricsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $PipedInstancesTable pipedInstances = $PipedInstancesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        tracks,
        playlists,
        playlistTracks,
        queueItems,
        playbackStates,
        playHistories,
        downloads,
        cachedLyrics,
        settings,
        pipedInstances
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('playlists',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('playlist_tracks', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracks',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('playlist_tracks', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracks',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('queue_items', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracks',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('play_histories', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracks',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('downloads', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tracks',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('cached_lyrics', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  required String id,
  required String sourceId,
  required String title,
  required String artist,
  Value<String?> album,
  required int durationMs,
  Value<String?> coverUrl,
  Value<double?> matchConfidence,
  Value<bool> isLiked,
  Value<bool> isUnavailable,
  required int createdAt,
  Value<int> rowid,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<String> id,
  Value<String> sourceId,
  Value<String> title,
  Value<String> artist,
  Value<String?> album,
  Value<int> durationMs,
  Value<String?> coverUrl,
  Value<double?> matchConfidence,
  Value<bool> isLiked,
  Value<bool> isUnavailable,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$TracksTableReferences
    extends BaseReferences<_$AppDatabase, $TracksTable, TrackRow> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrackRow>>
      _playlistTracksRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playlistTracks,
              aliasName: 'tracks__id__playlist_tracks__track_id');

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager($_db, $_db.playlistTracks)
        .filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$QueueItemsTable, List<QueueItemRow>>
      _queueItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.queueItems,
              aliasName: 'tracks__id__queue_items__track_id');

  $$QueueItemsTableProcessedTableManager get queueItemsRefs {
    final manager = $$QueueItemsTableTableManager($_db, $_db.queueItems)
        .filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_queueItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PlayHistoriesTable, List<PlayHistoryRow>>
      _playHistoriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playHistories,
              aliasName: 'tracks__id__play_histories__track_id');

  $$PlayHistoriesTableProcessedTableManager get playHistoriesRefs {
    final manager = $$PlayHistoriesTableTableManager($_db, $_db.playHistories)
        .filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playHistoriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DownloadsTable, List<DownloadRow>>
      _downloadsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.downloads,
              aliasName: 'tracks__id__downloads__track_id');

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager($_db, $_db.downloads)
        .filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CachedLyricsTable, List<CachedLyricRow>>
      _cachedLyricsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.cachedLyrics,
              aliasName: 'tracks__id__cached_lyrics__track_id');

  $$CachedLyricsTableProcessedTableManager get cachedLyricsRefs {
    final manager = $$CachedLyricsTableTableManager($_db, $_db.cachedLyrics)
        .filter((f) => f.trackId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cachedLyricsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get matchConfidence => $composableBuilder(
      column: $table.matchConfidence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLiked => $composableBuilder(
      column: $table.isLiked, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUnavailable => $composableBuilder(
      column: $table.isUnavailable, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> playlistTracksRefs(
      Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableFilterComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> queueItemsRefs(
      Expression<bool> Function($$QueueItemsTableFilterComposer f) f) {
    final $$QueueItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.queueItems,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$QueueItemsTableFilterComposer(
              $db: $db,
              $table: $db.queueItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> playHistoriesRefs(
      Expression<bool> Function($$PlayHistoriesTableFilterComposer f) f) {
    final $$PlayHistoriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playHistories,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlayHistoriesTableFilterComposer(
              $db: $db,
              $table: $db.playHistories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> downloadsRefs(
      Expression<bool> Function($$DownloadsTableFilterComposer f) f) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.downloads,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DownloadsTableFilterComposer(
              $db: $db,
              $table: $db.downloads,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> cachedLyricsRefs(
      Expression<bool> Function($$CachedLyricsTableFilterComposer f) f) {
    final $$CachedLyricsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.cachedLyrics,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedLyricsTableFilterComposer(
              $db: $db,
              $table: $db.cachedLyrics,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceId => $composableBuilder(
      column: $table.sourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverUrl => $composableBuilder(
      column: $table.coverUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get matchConfidence => $composableBuilder(
      column: $table.matchConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLiked => $composableBuilder(
      column: $table.isLiked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUnavailable => $composableBuilder(
      column: $table.isUnavailable,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<double> get matchConfidence => $composableBuilder(
      column: $table.matchConfidence, builder: (column) => column);

  GeneratedColumn<bool> get isLiked =>
      $composableBuilder(column: $table.isLiked, builder: (column) => column);

  GeneratedColumn<bool> get isUnavailable => $composableBuilder(
      column: $table.isUnavailable, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
      Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableAnnotationComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> queueItemsRefs<T extends Object>(
      Expression<T> Function($$QueueItemsTableAnnotationComposer a) f) {
    final $$QueueItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.queueItems,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$QueueItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.queueItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> playHistoriesRefs<T extends Object>(
      Expression<T> Function($$PlayHistoriesTableAnnotationComposer a) f) {
    final $$PlayHistoriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playHistories,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlayHistoriesTableAnnotationComposer(
              $db: $db,
              $table: $db.playHistories,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> downloadsRefs<T extends Object>(
      Expression<T> Function($$DownloadsTableAnnotationComposer a) f) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.downloads,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DownloadsTableAnnotationComposer(
              $db: $db,
              $table: $db.downloads,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> cachedLyricsRefs<T extends Object>(
      Expression<T> Function($$CachedLyricsTableAnnotationComposer a) f) {
    final $$CachedLyricsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.cachedLyrics,
        getReferencedColumn: (t) => t.trackId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedLyricsTableAnnotationComposer(
              $db: $db,
              $table: $db.cachedLyrics,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TracksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TracksTable,
    TrackRow,
    $$TracksTableFilterComposer,
    $$TracksTableOrderingComposer,
    $$TracksTableAnnotationComposer,
    $$TracksTableCreateCompanionBuilder,
    $$TracksTableUpdateCompanionBuilder,
    (TrackRow, $$TracksTableReferences),
    TrackRow,
    PrefetchHooks Function(
        {bool playlistTracksRefs,
        bool queueItemsRefs,
        bool playHistoriesRefs,
        bool downloadsRefs,
        bool cachedLyricsRefs})> {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sourceId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<String?> coverUrl = const Value.absent(),
            Value<double?> matchConfidence = const Value.absent(),
            Value<bool> isLiked = const Value.absent(),
            Value<bool> isUnavailable = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TracksCompanion(
            id: id,
            sourceId: sourceId,
            title: title,
            artist: artist,
            album: album,
            durationMs: durationMs,
            coverUrl: coverUrl,
            matchConfidence: matchConfidence,
            isLiked: isLiked,
            isUnavailable: isUnavailable,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sourceId,
            required String title,
            required String artist,
            Value<String?> album = const Value.absent(),
            required int durationMs,
            Value<String?> coverUrl = const Value.absent(),
            Value<double?> matchConfidence = const Value.absent(),
            Value<bool> isLiked = const Value.absent(),
            Value<bool> isUnavailable = const Value.absent(),
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TracksCompanion.insert(
            id: id,
            sourceId: sourceId,
            title: title,
            artist: artist,
            album: album,
            durationMs: durationMs,
            coverUrl: coverUrl,
            matchConfidence: matchConfidence,
            isLiked: isLiked,
            isUnavailable: isUnavailable,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TracksTable, TrackRow>(table),
                    $$TracksTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {playlistTracksRefs = false,
              queueItemsRefs = false,
              playHistoriesRefs = false,
              downloadsRefs = false,
              cachedLyricsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksRefs) db.playlistTracks,
                if (queueItemsRefs) db.queueItems,
                if (playHistoriesRefs) db.playHistories,
                if (downloadsRefs) db.downloads,
                if (cachedLyricsRefs) db.cachedLyrics
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksRefs)
                    await $_getPrefetchedData<TrackRow, $TracksTable,
                            PlaylistTrackRow>(
                        currentTable: table,
                        referencedTable: $$TracksTableReferences
                            ._playlistTracksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TracksTableReferences(db, table, p0)
                                .playlistTracksRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.trackId == item.id),
                        typedResults: items),
                  if (queueItemsRefs)
                    await $_getPrefetchedData<TrackRow, $TracksTable,
                            QueueItemRow>(
                        currentTable: table,
                        referencedTable:
                            $$TracksTableReferences._queueItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TracksTableReferences(db, table, p0)
                                .queueItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.trackId == item.id),
                        typedResults: items),
                  if (playHistoriesRefs)
                    await $_getPrefetchedData<TrackRow, $TracksTable,
                            PlayHistoryRow>(
                        currentTable: table,
                        referencedTable:
                            $$TracksTableReferences._playHistoriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TracksTableReferences(db, table, p0)
                                .playHistoriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.trackId == item.id),
                        typedResults: items),
                  if (downloadsRefs)
                    await $_getPrefetchedData<TrackRow, $TracksTable,
                            DownloadRow>(
                        currentTable: table,
                        referencedTable:
                            $$TracksTableReferences._downloadsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TracksTableReferences(db, table, p0)
                                .downloadsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.trackId == item.id),
                        typedResults: items),
                  if (cachedLyricsRefs)
                    await $_getPrefetchedData<TrackRow, $TracksTable,
                            CachedLyricRow>(
                        currentTable: table,
                        referencedTable:
                            $$TracksTableReferences._cachedLyricsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TracksTableReferences(db, table, p0)
                                .cachedLyricsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.trackId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TracksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TracksTable,
    TrackRow,
    $$TracksTableFilterComposer,
    $$TracksTableOrderingComposer,
    $$TracksTableAnnotationComposer,
    $$TracksTableCreateCompanionBuilder,
    $$TracksTableUpdateCompanionBuilder,
    (TrackRow, $$TracksTableReferences),
    TrackRow,
    PrefetchHooks Function(
        {bool playlistTracksRefs,
        bool queueItemsRefs,
        bool playHistoriesRefs,
        bool downloadsRefs,
        bool cachedLyricsRefs})>;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  required String id,
  required String name,
  Value<String?> description,
  Value<bool> isImported,
  Value<String?> sourceUrl,
  required int createdAt,
  Value<int> rowid,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<bool> isImported,
  Value<String?> sourceUrl,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrackRow>>
      _playlistTracksRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.playlistTracks,
              aliasName: 'playlists__id__playlist_tracks__playlist_id');

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager($_db, $_db.playlistTracks)
        .filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isImported => $composableBuilder(
      column: $table.isImported, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> playlistTracksRefs(
      Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.playlistId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableFilterComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isImported => $composableBuilder(
      column: $table.isImported, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get isImported => $composableBuilder(
      column: $table.isImported, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
      Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.playlistTracks,
        getReferencedColumn: (t) => t.playlistId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistTracksTableAnnotationComposer(
              $db: $db,
              $table: $db.playlistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlaylistsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    PlaylistRow,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (PlaylistRow, $$PlaylistsTableReferences),
    PlaylistRow,
    PrefetchHooks Function({bool playlistTracksRefs})> {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isImported = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsCompanion(
            id: id,
            name: name,
            description: description,
            isImported: isImported,
            sourceUrl: sourceUrl,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<bool> isImported = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistsCompanion.insert(
            id: id,
            name: name,
            description: description,
            isImported: isImported,
            sourceUrl: sourceUrl,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PlaylistsTable, PlaylistRow>(table),
                    $$PlaylistsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksRefs) db.playlistTracks
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksRefs)
                    await $_getPrefetchedData<PlaylistRow, $PlaylistsTable,
                            PlaylistTrackRow>(
                        currentTable: table,
                        referencedTable: $$PlaylistsTableReferences
                            ._playlistTracksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlaylistsTableReferences(db, table, p0)
                                .playlistTracksRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.playlistId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlaylistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistsTable,
    PlaylistRow,
    $$PlaylistsTableFilterComposer,
    $$PlaylistsTableOrderingComposer,
    $$PlaylistsTableAnnotationComposer,
    $$PlaylistsTableCreateCompanionBuilder,
    $$PlaylistsTableUpdateCompanionBuilder,
    (PlaylistRow, $$PlaylistsTableReferences),
    PlaylistRow,
    PrefetchHooks Function({bool playlistTracksRefs})>;
typedef $$PlaylistTracksTableCreateCompanionBuilder = PlaylistTracksCompanion
    Function({
  required String playlistId,
  required int position,
  Value<String?> trackId,
  required String originalTitle,
  required String originalArtist,
  required String matchStatus,
  Value<int> rowid,
});
typedef $$PlaylistTracksTableUpdateCompanionBuilder = PlaylistTracksCompanion
    Function({
  Value<String> playlistId,
  Value<int> position,
  Value<String?> trackId,
  Value<String> originalTitle,
  Value<String> originalArtist,
  Value<String> matchStatus,
  Value<int> rowid,
});

final class $$PlaylistTracksTableReferences extends BaseReferences<
    _$AppDatabase, $PlaylistTracksTable, PlaylistTrackRow> {
  $$PlaylistTracksTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_tracks__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager($_db, $_db.playlists)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('playlist_tracks__track_id__tracks__id');

  $$TracksTableProcessedTableManager? get trackId {
    final $_column = $_itemColumn<String>('track_id');
    if ($_column == null) return null;
    final manager = $$TracksTableTableManager($_db, $_db.tracks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalTitle => $composableBuilder(
      column: $table.originalTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalArtist => $composableBuilder(
      column: $table.originalArtist,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get matchStatus => $composableBuilder(
      column: $table.matchStatus, builder: (column) => ColumnFilters(column));

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableFilterComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableFilterComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalTitle => $composableBuilder(
      column: $table.originalTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalArtist => $composableBuilder(
      column: $table.originalArtist,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get matchStatus => $composableBuilder(
      column: $table.matchStatus, builder: (column) => ColumnOrderings(column));

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableOrderingComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableOrderingComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get originalTitle => $composableBuilder(
      column: $table.originalTitle, builder: (column) => column);

  GeneratedColumn<String> get originalArtist => $composableBuilder(
      column: $table.originalArtist, builder: (column) => column);

  GeneratedColumn<String> get matchStatus => $composableBuilder(
      column: $table.matchStatus, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.playlists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlaylistsTableAnnotationComposer(
              $db: $db,
              $table: $db.playlists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableAnnotationComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlaylistTracksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaylistTracksTable,
    PlaylistTrackRow,
    $$PlaylistTracksTableFilterComposer,
    $$PlaylistTracksTableOrderingComposer,
    $$PlaylistTracksTableAnnotationComposer,
    $$PlaylistTracksTableCreateCompanionBuilder,
    $$PlaylistTracksTableUpdateCompanionBuilder,
    (PlaylistTrackRow, $$PlaylistTracksTableReferences),
    PlaylistTrackRow,
    PrefetchHooks Function({bool playlistId, bool trackId})> {
  $$PlaylistTracksTableTableManager(
      _$AppDatabase db, $PlaylistTracksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> playlistId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<String?> trackId = const Value.absent(),
            Value<String> originalTitle = const Value.absent(),
            Value<String> originalArtist = const Value.absent(),
            Value<String> matchStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistTracksCompanion(
            playlistId: playlistId,
            position: position,
            trackId: trackId,
            originalTitle: originalTitle,
            originalArtist: originalArtist,
            matchStatus: matchStatus,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String playlistId,
            required int position,
            Value<String?> trackId = const Value.absent(),
            required String originalTitle,
            required String originalArtist,
            required String matchStatus,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlaylistTracksCompanion.insert(
            playlistId: playlistId,
            position: position,
            trackId: trackId,
            originalTitle: originalTitle,
            originalArtist: originalArtist,
            matchStatus: matchStatus,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PlaylistTracksTable, PlaylistTrackRow>(table),
                    $$PlaylistTracksTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (playlistId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.playlistId,
                    referencedTable:
                        $$PlaylistTracksTableReferences._playlistIdTable(db),
                    referencedColumn:
                        $$PlaylistTracksTableReferences._playlistIdTable(db).id,
                  ) as T;
                }
                if (trackId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackId,
                    referencedTable:
                        $$PlaylistTracksTableReferences._trackIdTable(db),
                    referencedColumn:
                        $$PlaylistTracksTableReferences._trackIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PlaylistTracksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaylistTracksTable,
    PlaylistTrackRow,
    $$PlaylistTracksTableFilterComposer,
    $$PlaylistTracksTableOrderingComposer,
    $$PlaylistTracksTableAnnotationComposer,
    $$PlaylistTracksTableCreateCompanionBuilder,
    $$PlaylistTracksTableUpdateCompanionBuilder,
    (PlaylistTrackRow, $$PlaylistTracksTableReferences),
    PlaylistTrackRow,
    PrefetchHooks Function({bool playlistId, bool trackId})>;
typedef $$QueueItemsTableCreateCompanionBuilder = QueueItemsCompanion Function({
  Value<int> position,
  required String trackId,
  required int addedAt,
});
typedef $$QueueItemsTableUpdateCompanionBuilder = QueueItemsCompanion Function({
  Value<int> position,
  Value<String> trackId,
  Value<int> addedAt,
});

final class $$QueueItemsTableReferences
    extends BaseReferences<_$AppDatabase, $QueueItemsTable, QueueItemRow> {
  $$QueueItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('queue_items__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$TracksTableTableManager($_db, $_db.tracks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$QueueItemsTableFilterComposer
    extends Composer<_$AppDatabase, $QueueItemsTable> {
  $$QueueItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableFilterComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$QueueItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueItemsTable> {
  $$QueueItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableOrderingComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$QueueItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueItemsTable> {
  $$QueueItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableAnnotationComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$QueueItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QueueItemsTable,
    QueueItemRow,
    $$QueueItemsTableFilterComposer,
    $$QueueItemsTableOrderingComposer,
    $$QueueItemsTableAnnotationComposer,
    $$QueueItemsTableCreateCompanionBuilder,
    $$QueueItemsTableUpdateCompanionBuilder,
    (QueueItemRow, $$QueueItemsTableReferences),
    QueueItemRow,
    PrefetchHooks Function({bool trackId})> {
  $$QueueItemsTableTableManager(_$AppDatabase db, $QueueItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> position = const Value.absent(),
            Value<String> trackId = const Value.absent(),
            Value<int> addedAt = const Value.absent(),
          }) =>
              QueueItemsCompanion(
            position: position,
            trackId: trackId,
            addedAt: addedAt,
          ),
          createCompanionCallback: ({
            Value<int> position = const Value.absent(),
            required String trackId,
            required int addedAt,
          }) =>
              QueueItemsCompanion.insert(
            position: position,
            trackId: trackId,
            addedAt: addedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$QueueItemsTable, QueueItemRow>(table),
                    $$QueueItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (trackId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackId,
                    referencedTable:
                        $$QueueItemsTableReferences._trackIdTable(db),
                    referencedColumn:
                        $$QueueItemsTableReferences._trackIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$QueueItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QueueItemsTable,
    QueueItemRow,
    $$QueueItemsTableFilterComposer,
    $$QueueItemsTableOrderingComposer,
    $$QueueItemsTableAnnotationComposer,
    $$QueueItemsTableCreateCompanionBuilder,
    $$QueueItemsTableUpdateCompanionBuilder,
    (QueueItemRow, $$QueueItemsTableReferences),
    QueueItemRow,
    PrefetchHooks Function({bool trackId})>;
typedef $$PlaybackStatesTableCreateCompanionBuilder = PlaybackStatesCompanion
    Function({
  Value<int> id,
  Value<int> currentQueueIndex,
  Value<int> currentPositionMs,
  required int updatedAt,
});
typedef $$PlaybackStatesTableUpdateCompanionBuilder = PlaybackStatesCompanion
    Function({
  Value<int> id,
  Value<int> currentQueueIndex,
  Value<int> currentPositionMs,
  Value<int> updatedAt,
});

class $$PlaybackStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentQueueIndex => $composableBuilder(
      column: $table.currentQueueIndex,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentPositionMs => $composableBuilder(
      column: $table.currentPositionMs,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PlaybackStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentQueueIndex => $composableBuilder(
      column: $table.currentQueueIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentPositionMs => $composableBuilder(
      column: $table.currentPositionMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlaybackStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentQueueIndex => $composableBuilder(
      column: $table.currentQueueIndex, builder: (column) => column);

  GeneratedColumn<int> get currentPositionMs => $composableBuilder(
      column: $table.currentPositionMs, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlaybackStatesTable,
    PlaybackStateRow,
    $$PlaybackStatesTableFilterComposer,
    $$PlaybackStatesTableOrderingComposer,
    $$PlaybackStatesTableAnnotationComposer,
    $$PlaybackStatesTableCreateCompanionBuilder,
    $$PlaybackStatesTableUpdateCompanionBuilder,
    (
      PlaybackStateRow,
      BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackStateRow>
    ),
    PlaybackStateRow,
    PrefetchHooks Function()> {
  $$PlaybackStatesTableTableManager(
      _$AppDatabase db, $PlaybackStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> currentQueueIndex = const Value.absent(),
            Value<int> currentPositionMs = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
          }) =>
              PlaybackStatesCompanion(
            id: id,
            currentQueueIndex: currentQueueIndex,
            currentPositionMs: currentPositionMs,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> currentQueueIndex = const Value.absent(),
            Value<int> currentPositionMs = const Value.absent(),
            required int updatedAt,
          }) =>
              PlaybackStatesCompanion.insert(
            id: id,
            currentQueueIndex: currentQueueIndex,
            currentPositionMs: currentPositionMs,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PlaybackStatesTable, PlaybackStateRow>(table),
                    BaseReferences<_$AppDatabase, $PlaybackStatesTable,
                        PlaybackStateRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlaybackStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlaybackStatesTable,
    PlaybackStateRow,
    $$PlaybackStatesTableFilterComposer,
    $$PlaybackStatesTableOrderingComposer,
    $$PlaybackStatesTableAnnotationComposer,
    $$PlaybackStatesTableCreateCompanionBuilder,
    $$PlaybackStatesTableUpdateCompanionBuilder,
    (
      PlaybackStateRow,
      BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackStateRow>
    ),
    PlaybackStateRow,
    PrefetchHooks Function()>;
typedef $$PlayHistoriesTableCreateCompanionBuilder = PlayHistoriesCompanion
    Function({
  Value<int> id,
  required String trackId,
  required int playedAt,
  required double completedRatio,
});
typedef $$PlayHistoriesTableUpdateCompanionBuilder = PlayHistoriesCompanion
    Function({
  Value<int> id,
  Value<String> trackId,
  Value<int> playedAt,
  Value<double> completedRatio,
});

final class $$PlayHistoriesTableReferences
    extends BaseReferences<_$AppDatabase, $PlayHistoriesTable, PlayHistoryRow> {
  $$PlayHistoriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('play_histories__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$TracksTableTableManager($_db, $_db.tracks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlayHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoriesTable> {
  $$PlayHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get completedRatio => $composableBuilder(
      column: $table.completedRatio,
      builder: (column) => ColumnFilters(column));

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableFilterComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlayHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoriesTable> {
  $$PlayHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get completedRatio => $composableBuilder(
      column: $table.completedRatio,
      builder: (column) => ColumnOrderings(column));

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableOrderingComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlayHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoriesTable> {
  $$PlayHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<double> get completedRatio => $composableBuilder(
      column: $table.completedRatio, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableAnnotationComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlayHistoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlayHistoriesTable,
    PlayHistoryRow,
    $$PlayHistoriesTableFilterComposer,
    $$PlayHistoriesTableOrderingComposer,
    $$PlayHistoriesTableAnnotationComposer,
    $$PlayHistoriesTableCreateCompanionBuilder,
    $$PlayHistoriesTableUpdateCompanionBuilder,
    (PlayHistoryRow, $$PlayHistoriesTableReferences),
    PlayHistoryRow,
    PrefetchHooks Function({bool trackId})> {
  $$PlayHistoriesTableTableManager(_$AppDatabase db, $PlayHistoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> trackId = const Value.absent(),
            Value<int> playedAt = const Value.absent(),
            Value<double> completedRatio = const Value.absent(),
          }) =>
              PlayHistoriesCompanion(
            id: id,
            trackId: trackId,
            playedAt: playedAt,
            completedRatio: completedRatio,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String trackId,
            required int playedAt,
            required double completedRatio,
          }) =>
              PlayHistoriesCompanion.insert(
            id: id,
            trackId: trackId,
            playedAt: playedAt,
            completedRatio: completedRatio,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PlayHistoriesTable, PlayHistoryRow>(table),
                    $$PlayHistoriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (trackId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackId,
                    referencedTable:
                        $$PlayHistoriesTableReferences._trackIdTable(db),
                    referencedColumn:
                        $$PlayHistoriesTableReferences._trackIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PlayHistoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlayHistoriesTable,
    PlayHistoryRow,
    $$PlayHistoriesTableFilterComposer,
    $$PlayHistoriesTableOrderingComposer,
    $$PlayHistoriesTableAnnotationComposer,
    $$PlayHistoriesTableCreateCompanionBuilder,
    $$PlayHistoriesTableUpdateCompanionBuilder,
    (PlayHistoryRow, $$PlayHistoriesTableReferences),
    PlayHistoryRow,
    PrefetchHooks Function({bool trackId})>;
typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  required String trackId,
  required String relativePath,
  Value<String> containerFormat,
  Value<int> fileSizeBytes,
  Value<int> bytesDownloaded,
  required String status,
  required int createdAt,
  Value<int> rowid,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<String> trackId,
  Value<String> relativePath,
  Value<String> containerFormat,
  Value<int> fileSizeBytes,
  Value<int> bytesDownloaded,
  Value<String> status,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$DownloadsTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow> {
  $$DownloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('downloads__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$TracksTableTableManager($_db, $_db.tracks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get relativePath => $composableBuilder(
      column: $table.relativePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get containerFormat => $composableBuilder(
      column: $table.containerFormat,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bytesDownloaded => $composableBuilder(
      column: $table.bytesDownloaded,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableFilterComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get relativePath => $composableBuilder(
      column: $table.relativePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get containerFormat => $composableBuilder(
      column: $table.containerFormat,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bytesDownloaded => $composableBuilder(
      column: $table.bytesDownloaded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableOrderingComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get relativePath => $composableBuilder(
      column: $table.relativePath, builder: (column) => column);

  GeneratedColumn<String> get containerFormat => $composableBuilder(
      column: $table.containerFormat, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumn<int> get bytesDownloaded => $composableBuilder(
      column: $table.bytesDownloaded, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableAnnotationComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DownloadsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadsTable,
    DownloadRow,
    $$DownloadsTableFilterComposer,
    $$DownloadsTableOrderingComposer,
    $$DownloadsTableAnnotationComposer,
    $$DownloadsTableCreateCompanionBuilder,
    $$DownloadsTableUpdateCompanionBuilder,
    (DownloadRow, $$DownloadsTableReferences),
    DownloadRow,
    PrefetchHooks Function({bool trackId})> {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackId = const Value.absent(),
            Value<String> relativePath = const Value.absent(),
            Value<String> containerFormat = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<int> bytesDownloaded = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion(
            trackId: trackId,
            relativePath: relativePath,
            containerFormat: containerFormat,
            fileSizeBytes: fileSizeBytes,
            bytesDownloaded: bytesDownloaded,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackId,
            required String relativePath,
            Value<String> containerFormat = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<int> bytesDownloaded = const Value.absent(),
            required String status,
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion.insert(
            trackId: trackId,
            relativePath: relativePath,
            containerFormat: containerFormat,
            fileSizeBytes: fileSizeBytes,
            bytesDownloaded: bytesDownloaded,
            status: status,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DownloadsTable, DownloadRow>(table),
                    $$DownloadsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (trackId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackId,
                    referencedTable:
                        $$DownloadsTableReferences._trackIdTable(db),
                    referencedColumn:
                        $$DownloadsTableReferences._trackIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DownloadsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadsTable,
    DownloadRow,
    $$DownloadsTableFilterComposer,
    $$DownloadsTableOrderingComposer,
    $$DownloadsTableAnnotationComposer,
    $$DownloadsTableCreateCompanionBuilder,
    $$DownloadsTableUpdateCompanionBuilder,
    (DownloadRow, $$DownloadsTableReferences),
    DownloadRow,
    PrefetchHooks Function({bool trackId})>;
typedef $$CachedLyricsTableCreateCompanionBuilder = CachedLyricsCompanion
    Function({
  required String trackId,
  Value<String?> syncedLrc,
  Value<String?> plainText,
  Value<bool> isNotFound,
  required int cachedAt,
  Value<int> rowid,
});
typedef $$CachedLyricsTableUpdateCompanionBuilder = CachedLyricsCompanion
    Function({
  Value<String> trackId,
  Value<String?> syncedLrc,
  Value<String?> plainText,
  Value<bool> isNotFound,
  Value<int> cachedAt,
  Value<int> rowid,
});

final class $$CachedLyricsTableReferences
    extends BaseReferences<_$AppDatabase, $CachedLyricsTable, CachedLyricRow> {
  $$CachedLyricsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('cached_lyrics__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<String>('track_id')!;

    final manager = $$TracksTableTableManager($_db, $_db.tracks)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CachedLyricsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedLyricsTable> {
  $$CachedLyricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncedLrc => $composableBuilder(
      column: $table.syncedLrc, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plainText => $composableBuilder(
      column: $table.plainText, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isNotFound => $composableBuilder(
      column: $table.isNotFound, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableFilterComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedLyricsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedLyricsTable> {
  $$CachedLyricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncedLrc => $composableBuilder(
      column: $table.syncedLrc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plainText => $composableBuilder(
      column: $table.plainText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isNotFound => $composableBuilder(
      column: $table.isNotFound, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableOrderingComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedLyricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedLyricsTable> {
  $$CachedLyricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncedLrc =>
      $composableBuilder(column: $table.syncedLrc, builder: (column) => column);

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<bool> get isNotFound => $composableBuilder(
      column: $table.isNotFound, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.trackId,
        referencedTable: $db.tracks,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TracksTableAnnotationComposer(
              $db: $db,
              $table: $db.tracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedLyricsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedLyricsTable,
    CachedLyricRow,
    $$CachedLyricsTableFilterComposer,
    $$CachedLyricsTableOrderingComposer,
    $$CachedLyricsTableAnnotationComposer,
    $$CachedLyricsTableCreateCompanionBuilder,
    $$CachedLyricsTableUpdateCompanionBuilder,
    (CachedLyricRow, $$CachedLyricsTableReferences),
    CachedLyricRow,
    PrefetchHooks Function({bool trackId})> {
  $$CachedLyricsTableTableManager(_$AppDatabase db, $CachedLyricsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedLyricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedLyricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedLyricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackId = const Value.absent(),
            Value<String?> syncedLrc = const Value.absent(),
            Value<String?> plainText = const Value.absent(),
            Value<bool> isNotFound = const Value.absent(),
            Value<int> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedLyricsCompanion(
            trackId: trackId,
            syncedLrc: syncedLrc,
            plainText: plainText,
            isNotFound: isNotFound,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackId,
            Value<String?> syncedLrc = const Value.absent(),
            Value<String?> plainText = const Value.absent(),
            Value<bool> isNotFound = const Value.absent(),
            required int cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedLyricsCompanion.insert(
            trackId: trackId,
            syncedLrc: syncedLrc,
            plainText: plainText,
            isNotFound: isNotFound,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedLyricsTable, CachedLyricRow>(table),
                    $$CachedLyricsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (trackId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.trackId,
                    referencedTable:
                        $$CachedLyricsTableReferences._trackIdTable(db),
                    referencedColumn:
                        $$CachedLyricsTableReferences._trackIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CachedLyricsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedLyricsTable,
    CachedLyricRow,
    $$CachedLyricsTableFilterComposer,
    $$CachedLyricsTableOrderingComposer,
    $$CachedLyricsTableAnnotationComposer,
    $$CachedLyricsTableCreateCompanionBuilder,
    $$CachedLyricsTableUpdateCompanionBuilder,
    (CachedLyricRow, $$CachedLyricsTableReferences),
    CachedLyricRow,
    PrefetchHooks Function({bool trackId})>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    SettingRow,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SettingsTable, SettingRow>(table),
                    BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    SettingRow,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()>;
typedef $$PipedInstancesTableCreateCompanionBuilder = PipedInstancesCompanion
    Function({
  required String url,
  Value<int?> latencyMs,
  Value<bool> isHealthy,
  required int lastChecked,
  Value<int> rowid,
});
typedef $$PipedInstancesTableUpdateCompanionBuilder = PipedInstancesCompanion
    Function({
  Value<String> url,
  Value<int?> latencyMs,
  Value<bool> isHealthy,
  Value<int> lastChecked,
  Value<int> rowid,
});

class $$PipedInstancesTableFilterComposer
    extends Composer<_$AppDatabase, $PipedInstancesTable> {
  $$PipedInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHealthy => $composableBuilder(
      column: $table.isHealthy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastChecked => $composableBuilder(
      column: $table.lastChecked, builder: (column) => ColumnFilters(column));
}

class $$PipedInstancesTableOrderingComposer
    extends Composer<_$AppDatabase, $PipedInstancesTable> {
  $$PipedInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url => $composableBuilder(
      column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHealthy => $composableBuilder(
      column: $table.isHealthy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastChecked => $composableBuilder(
      column: $table.lastChecked, builder: (column) => ColumnOrderings(column));
}

class $$PipedInstancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PipedInstancesTable> {
  $$PipedInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<bool> get isHealthy =>
      $composableBuilder(column: $table.isHealthy, builder: (column) => column);

  GeneratedColumn<int> get lastChecked => $composableBuilder(
      column: $table.lastChecked, builder: (column) => column);
}

class $$PipedInstancesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PipedInstancesTable,
    PipedInstanceRow,
    $$PipedInstancesTableFilterComposer,
    $$PipedInstancesTableOrderingComposer,
    $$PipedInstancesTableAnnotationComposer,
    $$PipedInstancesTableCreateCompanionBuilder,
    $$PipedInstancesTableUpdateCompanionBuilder,
    (
      PipedInstanceRow,
      BaseReferences<_$AppDatabase, $PipedInstancesTable, PipedInstanceRow>
    ),
    PipedInstanceRow,
    PrefetchHooks Function()> {
  $$PipedInstancesTableTableManager(
      _$AppDatabase db, $PipedInstancesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PipedInstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PipedInstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PipedInstancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> url = const Value.absent(),
            Value<int?> latencyMs = const Value.absent(),
            Value<bool> isHealthy = const Value.absent(),
            Value<int> lastChecked = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PipedInstancesCompanion(
            url: url,
            latencyMs: latencyMs,
            isHealthy: isHealthy,
            lastChecked: lastChecked,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String url,
            Value<int?> latencyMs = const Value.absent(),
            Value<bool> isHealthy = const Value.absent(),
            required int lastChecked,
            Value<int> rowid = const Value.absent(),
          }) =>
              PipedInstancesCompanion.insert(
            url: url,
            latencyMs: latencyMs,
            isHealthy: isHealthy,
            lastChecked: lastChecked,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PipedInstancesTable, PipedInstanceRow>(table),
                    BaseReferences<_$AppDatabase, $PipedInstancesTable,
                        PipedInstanceRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PipedInstancesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PipedInstancesTable,
    PipedInstanceRow,
    $$PipedInstancesTableFilterComposer,
    $$PipedInstancesTableOrderingComposer,
    $$PipedInstancesTableAnnotationComposer,
    $$PipedInstancesTableCreateCompanionBuilder,
    $$PipedInstancesTableUpdateCompanionBuilder,
    (
      PipedInstanceRow,
      BaseReferences<_$AppDatabase, $PipedInstancesTable, PipedInstanceRow>
    ),
    PipedInstanceRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$QueueItemsTableTableManager get queueItems =>
      $$QueueItemsTableTableManager(_db, _db.queueItems);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(_db, _db.playbackStates);
  $$PlayHistoriesTableTableManager get playHistories =>
      $$PlayHistoriesTableTableManager(_db, _db.playHistories);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$CachedLyricsTableTableManager get cachedLyrics =>
      $$CachedLyricsTableTableManager(_db, _db.cachedLyrics);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$PipedInstancesTableTableManager get pipedInstances =>
      $$PipedInstancesTableTableManager(_db, _db.pipedInstances);
}
