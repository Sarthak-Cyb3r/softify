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

class $SearchEventsTable extends SearchEvents
    with TableInfo<$SearchEventsTable, SearchEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
      'query', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resultIdsJsonMeta =
      const VerificationMeta('resultIdsJson');
  @override
  late final GeneratedColumn<String> resultIdsJson = GeneratedColumn<String>(
      'result_ids_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shownCountMeta =
      const VerificationMeta('shownCount');
  @override
  late final GeneratedColumn<int> shownCount = GeneratedColumn<int>(
      'shown_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _clickedIdMeta =
      const VerificationMeta('clickedId');
  @override
  late final GeneratedColumn<String> clickedId = GeneratedColumn<String>(
      'clicked_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clickedPositionMeta =
      const VerificationMeta('clickedPosition');
  @override
  late final GeneratedColumn<int> clickedPosition = GeneratedColumn<int>(
      'clicked_position', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _msToClickMeta =
      const VerificationMeta('msToClick');
  @override
  late final GeneratedColumn<int> msToClick = GeneratedColumn<int>(
      'ms_to_click', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _rankerVersionMeta =
      const VerificationMeta('rankerVersion');
  @override
  late final GeneratedColumn<String> rankerVersion = GeneratedColumn<String>(
      'ranker_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ts,
        query,
        resultIdsJson,
        shownCount,
        clickedId,
        clickedPosition,
        msToClick,
        rankerVersion
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_events';
  @override
  VerificationContext validateIntegrity(Insertable<SearchEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('query')) {
      context.handle(
          _queryMeta, query.isAcceptableOrUnknown(data['query']!, _queryMeta));
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('result_ids_json')) {
      context.handle(
          _resultIdsJsonMeta,
          resultIdsJson.isAcceptableOrUnknown(
              data['result_ids_json']!, _resultIdsJsonMeta));
    } else if (isInserting) {
      context.missing(_resultIdsJsonMeta);
    }
    if (data.containsKey('shown_count')) {
      context.handle(
          _shownCountMeta,
          shownCount.isAcceptableOrUnknown(
              data['shown_count']!, _shownCountMeta));
    } else if (isInserting) {
      context.missing(_shownCountMeta);
    }
    if (data.containsKey('clicked_id')) {
      context.handle(_clickedIdMeta,
          clickedId.isAcceptableOrUnknown(data['clicked_id']!, _clickedIdMeta));
    }
    if (data.containsKey('clicked_position')) {
      context.handle(
          _clickedPositionMeta,
          clickedPosition.isAcceptableOrUnknown(
              data['clicked_position']!, _clickedPositionMeta));
    }
    if (data.containsKey('ms_to_click')) {
      context.handle(
          _msToClickMeta,
          msToClick.isAcceptableOrUnknown(
              data['ms_to_click']!, _msToClickMeta));
    }
    if (data.containsKey('ranker_version')) {
      context.handle(
          _rankerVersionMeta,
          rankerVersion.isAcceptableOrUnknown(
              data['ranker_version']!, _rankerVersionMeta));
    } else if (isInserting) {
      context.missing(_rankerVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      query: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}query'])!,
      resultIdsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}result_ids_json'])!,
      shownCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}shown_count'])!,
      clickedId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}clicked_id']),
      clickedPosition: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}clicked_position']),
      msToClick: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ms_to_click']),
      rankerVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ranker_version'])!,
    );
  }

  @override
  $SearchEventsTable createAlias(String alias) {
    return $SearchEventsTable(attachedDatabase, alias);
  }
}

class SearchEventRow extends DataClass implements Insertable<SearchEventRow> {
  final int id;
  final int ts;
  final String query;
  final String resultIdsJson;
  final int shownCount;
  final String? clickedId;
  final int? clickedPosition;
  final int? msToClick;
  final String rankerVersion;
  const SearchEventRow(
      {required this.id,
      required this.ts,
      required this.query,
      required this.resultIdsJson,
      required this.shownCount,
      this.clickedId,
      this.clickedPosition,
      this.msToClick,
      required this.rankerVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    map['query'] = Variable<String>(query);
    map['result_ids_json'] = Variable<String>(resultIdsJson);
    map['shown_count'] = Variable<int>(shownCount);
    if (!nullToAbsent || clickedId != null) {
      map['clicked_id'] = Variable<String>(clickedId);
    }
    if (!nullToAbsent || clickedPosition != null) {
      map['clicked_position'] = Variable<int>(clickedPosition);
    }
    if (!nullToAbsent || msToClick != null) {
      map['ms_to_click'] = Variable<int>(msToClick);
    }
    map['ranker_version'] = Variable<String>(rankerVersion);
    return map;
  }

  SearchEventsCompanion toCompanion(bool nullToAbsent) {
    return SearchEventsCompanion(
      id: Value(id),
      ts: Value(ts),
      query: Value(query),
      resultIdsJson: Value(resultIdsJson),
      shownCount: Value(shownCount),
      clickedId: clickedId == null && nullToAbsent
          ? const Value.absent()
          : Value(clickedId),
      clickedPosition: clickedPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(clickedPosition),
      msToClick: msToClick == null && nullToAbsent
          ? const Value.absent()
          : Value(msToClick),
      rankerVersion: Value(rankerVersion),
    );
  }

  factory SearchEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchEventRow(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      query: serializer.fromJson<String>(json['query']),
      resultIdsJson: serializer.fromJson<String>(json['resultIdsJson']),
      shownCount: serializer.fromJson<int>(json['shownCount']),
      clickedId: serializer.fromJson<String?>(json['clickedId']),
      clickedPosition: serializer.fromJson<int?>(json['clickedPosition']),
      msToClick: serializer.fromJson<int?>(json['msToClick']),
      rankerVersion: serializer.fromJson<String>(json['rankerVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'query': serializer.toJson<String>(query),
      'resultIdsJson': serializer.toJson<String>(resultIdsJson),
      'shownCount': serializer.toJson<int>(shownCount),
      'clickedId': serializer.toJson<String?>(clickedId),
      'clickedPosition': serializer.toJson<int?>(clickedPosition),
      'msToClick': serializer.toJson<int?>(msToClick),
      'rankerVersion': serializer.toJson<String>(rankerVersion),
    };
  }

  SearchEventRow copyWith(
          {int? id,
          int? ts,
          String? query,
          String? resultIdsJson,
          int? shownCount,
          Value<String?> clickedId = const Value.absent(),
          Value<int?> clickedPosition = const Value.absent(),
          Value<int?> msToClick = const Value.absent(),
          String? rankerVersion}) =>
      SearchEventRow(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        query: query ?? this.query,
        resultIdsJson: resultIdsJson ?? this.resultIdsJson,
        shownCount: shownCount ?? this.shownCount,
        clickedId: clickedId.present ? clickedId.value : this.clickedId,
        clickedPosition: clickedPosition.present
            ? clickedPosition.value
            : this.clickedPosition,
        msToClick: msToClick.present ? msToClick.value : this.msToClick,
        rankerVersion: rankerVersion ?? this.rankerVersion,
      );
  SearchEventRow copyWithCompanion(SearchEventsCompanion data) {
    return SearchEventRow(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      query: data.query.present ? data.query.value : this.query,
      resultIdsJson: data.resultIdsJson.present
          ? data.resultIdsJson.value
          : this.resultIdsJson,
      shownCount:
          data.shownCount.present ? data.shownCount.value : this.shownCount,
      clickedId: data.clickedId.present ? data.clickedId.value : this.clickedId,
      clickedPosition: data.clickedPosition.present
          ? data.clickedPosition.value
          : this.clickedPosition,
      msToClick: data.msToClick.present ? data.msToClick.value : this.msToClick,
      rankerVersion: data.rankerVersion.present
          ? data.rankerVersion.value
          : this.rankerVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchEventRow(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('query: $query, ')
          ..write('resultIdsJson: $resultIdsJson, ')
          ..write('shownCount: $shownCount, ')
          ..write('clickedId: $clickedId, ')
          ..write('clickedPosition: $clickedPosition, ')
          ..write('msToClick: $msToClick, ')
          ..write('rankerVersion: $rankerVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, query, resultIdsJson, shownCount,
      clickedId, clickedPosition, msToClick, rankerVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchEventRow &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.query == this.query &&
          other.resultIdsJson == this.resultIdsJson &&
          other.shownCount == this.shownCount &&
          other.clickedId == this.clickedId &&
          other.clickedPosition == this.clickedPosition &&
          other.msToClick == this.msToClick &&
          other.rankerVersion == this.rankerVersion);
}

class SearchEventsCompanion extends UpdateCompanion<SearchEventRow> {
  final Value<int> id;
  final Value<int> ts;
  final Value<String> query;
  final Value<String> resultIdsJson;
  final Value<int> shownCount;
  final Value<String?> clickedId;
  final Value<int?> clickedPosition;
  final Value<int?> msToClick;
  final Value<String> rankerVersion;
  const SearchEventsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.query = const Value.absent(),
    this.resultIdsJson = const Value.absent(),
    this.shownCount = const Value.absent(),
    this.clickedId = const Value.absent(),
    this.clickedPosition = const Value.absent(),
    this.msToClick = const Value.absent(),
    this.rankerVersion = const Value.absent(),
  });
  SearchEventsCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    required String query,
    required String resultIdsJson,
    required int shownCount,
    this.clickedId = const Value.absent(),
    this.clickedPosition = const Value.absent(),
    this.msToClick = const Value.absent(),
    required String rankerVersion,
  })  : ts = Value(ts),
        query = Value(query),
        resultIdsJson = Value(resultIdsJson),
        shownCount = Value(shownCount),
        rankerVersion = Value(rankerVersion);
  static Insertable<SearchEventRow> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<String>? query,
    Expression<String>? resultIdsJson,
    Expression<int>? shownCount,
    Expression<String>? clickedId,
    Expression<int>? clickedPosition,
    Expression<int>? msToClick,
    Expression<String>? rankerVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (query != null) 'query': query,
      if (resultIdsJson != null) 'result_ids_json': resultIdsJson,
      if (shownCount != null) 'shown_count': shownCount,
      if (clickedId != null) 'clicked_id': clickedId,
      if (clickedPosition != null) 'clicked_position': clickedPosition,
      if (msToClick != null) 'ms_to_click': msToClick,
      if (rankerVersion != null) 'ranker_version': rankerVersion,
    });
  }

  SearchEventsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ts,
      Value<String>? query,
      Value<String>? resultIdsJson,
      Value<int>? shownCount,
      Value<String?>? clickedId,
      Value<int?>? clickedPosition,
      Value<int?>? msToClick,
      Value<String>? rankerVersion}) {
    return SearchEventsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      query: query ?? this.query,
      resultIdsJson: resultIdsJson ?? this.resultIdsJson,
      shownCount: shownCount ?? this.shownCount,
      clickedId: clickedId ?? this.clickedId,
      clickedPosition: clickedPosition ?? this.clickedPosition,
      msToClick: msToClick ?? this.msToClick,
      rankerVersion: rankerVersion ?? this.rankerVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (resultIdsJson.present) {
      map['result_ids_json'] = Variable<String>(resultIdsJson.value);
    }
    if (shownCount.present) {
      map['shown_count'] = Variable<int>(shownCount.value);
    }
    if (clickedId.present) {
      map['clicked_id'] = Variable<String>(clickedId.value);
    }
    if (clickedPosition.present) {
      map['clicked_position'] = Variable<int>(clickedPosition.value);
    }
    if (msToClick.present) {
      map['ms_to_click'] = Variable<int>(msToClick.value);
    }
    if (rankerVersion.present) {
      map['ranker_version'] = Variable<String>(rankerVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchEventsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('query: $query, ')
          ..write('resultIdsJson: $resultIdsJson, ')
          ..write('shownCount: $shownCount, ')
          ..write('clickedId: $clickedId, ')
          ..write('clickedPosition: $clickedPosition, ')
          ..write('msToClick: $msToClick, ')
          ..write('rankerVersion: $rankerVersion')
          ..write(')'))
        .toString();
  }
}

class $PlayEventsTable extends PlayEvents
    with TableInfo<$PlayEventsTable, PlayEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _listenedMsMeta =
      const VerificationMeta('listenedMs');
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
      'listened_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _skippedEarlyMeta =
      const VerificationMeta('skippedEarly');
  @override
  late final GeneratedColumn<bool> skippedEarly = GeneratedColumn<bool>(
      'skipped_early', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("skipped_early" IN (0, 1))'));
  static const VerificationMeta _savedMeta = const VerificationMeta('saved');
  @override
  late final GeneratedColumn<bool> saved = GeneratedColumn<bool>(
      'saved', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("saved" IN (0, 1))'));
  static const VerificationMeta _addedToPlaylistMeta =
      const VerificationMeta('addedToPlaylist');
  @override
  late final GeneratedColumn<bool> addedToPlaylist = GeneratedColumn<bool>(
      'added_to_playlist', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("added_to_playlist" IN (0, 1))'));
  static const VerificationMeta _rankerVersionMeta =
      const VerificationMeta('rankerVersion');
  @override
  late final GeneratedColumn<String> rankerVersion = GeneratedColumn<String>(
      'ranker_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _featuresJsonMeta =
      const VerificationMeta('featuresJson');
  @override
  late final GeneratedColumn<String> featuresJson = GeneratedColumn<String>(
      'features_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ts,
        trackId,
        source,
        listenedMs,
        durationMs,
        skippedEarly,
        saved,
        addedToPlaylist,
        rankerVersion,
        featuresJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_events';
  @override
  VerificationContext validateIntegrity(Insertable<PlayEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
          _listenedMsMeta,
          listenedMs.isAcceptableOrUnknown(
              data['listened_ms']!, _listenedMsMeta));
    } else if (isInserting) {
      context.missing(_listenedMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('skipped_early')) {
      context.handle(
          _skippedEarlyMeta,
          skippedEarly.isAcceptableOrUnknown(
              data['skipped_early']!, _skippedEarlyMeta));
    } else if (isInserting) {
      context.missing(_skippedEarlyMeta);
    }
    if (data.containsKey('saved')) {
      context.handle(
          _savedMeta, saved.isAcceptableOrUnknown(data['saved']!, _savedMeta));
    } else if (isInserting) {
      context.missing(_savedMeta);
    }
    if (data.containsKey('added_to_playlist')) {
      context.handle(
          _addedToPlaylistMeta,
          addedToPlaylist.isAcceptableOrUnknown(
              data['added_to_playlist']!, _addedToPlaylistMeta));
    } else if (isInserting) {
      context.missing(_addedToPlaylistMeta);
    }
    if (data.containsKey('ranker_version')) {
      context.handle(
          _rankerVersionMeta,
          rankerVersion.isAcceptableOrUnknown(
              data['ranker_version']!, _rankerVersionMeta));
    } else if (isInserting) {
      context.missing(_rankerVersionMeta);
    }
    if (data.containsKey('features_json')) {
      context.handle(
          _featuresJsonMeta,
          featuresJson.isAcceptableOrUnknown(
              data['features_json']!, _featuresJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      listenedMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}listened_ms'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms'])!,
      skippedEarly: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}skipped_early'])!,
      saved: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}saved'])!,
      addedToPlaylist: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}added_to_playlist'])!,
      rankerVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ranker_version'])!,
      featuresJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}features_json']),
    );
  }

  @override
  $PlayEventsTable createAlias(String alias) {
    return $PlayEventsTable(attachedDatabase, alias);
  }
}

class PlayEventRow extends DataClass implements Insertable<PlayEventRow> {
  final int id;
  final int ts;
  final String trackId;
  final String source;
  final int listenedMs;
  final int durationMs;
  final bool skippedEarly;
  final bool saved;
  final bool addedToPlaylist;
  final String rankerVersion;
  final String? featuresJson;
  const PlayEventRow(
      {required this.id,
      required this.ts,
      required this.trackId,
      required this.source,
      required this.listenedMs,
      required this.durationMs,
      required this.skippedEarly,
      required this.saved,
      required this.addedToPlaylist,
      required this.rankerVersion,
      this.featuresJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    map['track_id'] = Variable<String>(trackId);
    map['source'] = Variable<String>(source);
    map['listened_ms'] = Variable<int>(listenedMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['skipped_early'] = Variable<bool>(skippedEarly);
    map['saved'] = Variable<bool>(saved);
    map['added_to_playlist'] = Variable<bool>(addedToPlaylist);
    map['ranker_version'] = Variable<String>(rankerVersion);
    if (!nullToAbsent || featuresJson != null) {
      map['features_json'] = Variable<String>(featuresJson);
    }
    return map;
  }

  PlayEventsCompanion toCompanion(bool nullToAbsent) {
    return PlayEventsCompanion(
      id: Value(id),
      ts: Value(ts),
      trackId: Value(trackId),
      source: Value(source),
      listenedMs: Value(listenedMs),
      durationMs: Value(durationMs),
      skippedEarly: Value(skippedEarly),
      saved: Value(saved),
      addedToPlaylist: Value(addedToPlaylist),
      rankerVersion: Value(rankerVersion),
      featuresJson: featuresJson == null && nullToAbsent
          ? const Value.absent()
          : Value(featuresJson),
    );
  }

  factory PlayEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayEventRow(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      trackId: serializer.fromJson<String>(json['trackId']),
      source: serializer.fromJson<String>(json['source']),
      listenedMs: serializer.fromJson<int>(json['listenedMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      skippedEarly: serializer.fromJson<bool>(json['skippedEarly']),
      saved: serializer.fromJson<bool>(json['saved']),
      addedToPlaylist: serializer.fromJson<bool>(json['addedToPlaylist']),
      rankerVersion: serializer.fromJson<String>(json['rankerVersion']),
      featuresJson: serializer.fromJson<String?>(json['featuresJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'trackId': serializer.toJson<String>(trackId),
      'source': serializer.toJson<String>(source),
      'listenedMs': serializer.toJson<int>(listenedMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'skippedEarly': serializer.toJson<bool>(skippedEarly),
      'saved': serializer.toJson<bool>(saved),
      'addedToPlaylist': serializer.toJson<bool>(addedToPlaylist),
      'rankerVersion': serializer.toJson<String>(rankerVersion),
      'featuresJson': serializer.toJson<String?>(featuresJson),
    };
  }

  PlayEventRow copyWith(
          {int? id,
          int? ts,
          String? trackId,
          String? source,
          int? listenedMs,
          int? durationMs,
          bool? skippedEarly,
          bool? saved,
          bool? addedToPlaylist,
          String? rankerVersion,
          Value<String?> featuresJson = const Value.absent()}) =>
      PlayEventRow(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        trackId: trackId ?? this.trackId,
        source: source ?? this.source,
        listenedMs: listenedMs ?? this.listenedMs,
        durationMs: durationMs ?? this.durationMs,
        skippedEarly: skippedEarly ?? this.skippedEarly,
        saved: saved ?? this.saved,
        addedToPlaylist: addedToPlaylist ?? this.addedToPlaylist,
        rankerVersion: rankerVersion ?? this.rankerVersion,
        featuresJson:
            featuresJson.present ? featuresJson.value : this.featuresJson,
      );
  PlayEventRow copyWithCompanion(PlayEventsCompanion data) {
    return PlayEventRow(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      source: data.source.present ? data.source.value : this.source,
      listenedMs:
          data.listenedMs.present ? data.listenedMs.value : this.listenedMs,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      skippedEarly: data.skippedEarly.present
          ? data.skippedEarly.value
          : this.skippedEarly,
      saved: data.saved.present ? data.saved.value : this.saved,
      addedToPlaylist: data.addedToPlaylist.present
          ? data.addedToPlaylist.value
          : this.addedToPlaylist,
      rankerVersion: data.rankerVersion.present
          ? data.rankerVersion.value
          : this.rankerVersion,
      featuresJson: data.featuresJson.present
          ? data.featuresJson.value
          : this.featuresJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayEventRow(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('trackId: $trackId, ')
          ..write('source: $source, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('skippedEarly: $skippedEarly, ')
          ..write('saved: $saved, ')
          ..write('addedToPlaylist: $addedToPlaylist, ')
          ..write('rankerVersion: $rankerVersion, ')
          ..write('featuresJson: $featuresJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      ts,
      trackId,
      source,
      listenedMs,
      durationMs,
      skippedEarly,
      saved,
      addedToPlaylist,
      rankerVersion,
      featuresJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayEventRow &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.trackId == this.trackId &&
          other.source == this.source &&
          other.listenedMs == this.listenedMs &&
          other.durationMs == this.durationMs &&
          other.skippedEarly == this.skippedEarly &&
          other.saved == this.saved &&
          other.addedToPlaylist == this.addedToPlaylist &&
          other.rankerVersion == this.rankerVersion &&
          other.featuresJson == this.featuresJson);
}

class PlayEventsCompanion extends UpdateCompanion<PlayEventRow> {
  final Value<int> id;
  final Value<int> ts;
  final Value<String> trackId;
  final Value<String> source;
  final Value<int> listenedMs;
  final Value<int> durationMs;
  final Value<bool> skippedEarly;
  final Value<bool> saved;
  final Value<bool> addedToPlaylist;
  final Value<String> rankerVersion;
  final Value<String?> featuresJson;
  const PlayEventsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.trackId = const Value.absent(),
    this.source = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.skippedEarly = const Value.absent(),
    this.saved = const Value.absent(),
    this.addedToPlaylist = const Value.absent(),
    this.rankerVersion = const Value.absent(),
    this.featuresJson = const Value.absent(),
  });
  PlayEventsCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    required String trackId,
    required String source,
    required int listenedMs,
    required int durationMs,
    required bool skippedEarly,
    required bool saved,
    required bool addedToPlaylist,
    required String rankerVersion,
    this.featuresJson = const Value.absent(),
  })  : ts = Value(ts),
        trackId = Value(trackId),
        source = Value(source),
        listenedMs = Value(listenedMs),
        durationMs = Value(durationMs),
        skippedEarly = Value(skippedEarly),
        saved = Value(saved),
        addedToPlaylist = Value(addedToPlaylist),
        rankerVersion = Value(rankerVersion);
  static Insertable<PlayEventRow> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<String>? trackId,
    Expression<String>? source,
    Expression<int>? listenedMs,
    Expression<int>? durationMs,
    Expression<bool>? skippedEarly,
    Expression<bool>? saved,
    Expression<bool>? addedToPlaylist,
    Expression<String>? rankerVersion,
    Expression<String>? featuresJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (trackId != null) 'track_id': trackId,
      if (source != null) 'source': source,
      if (listenedMs != null) 'listened_ms': listenedMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (skippedEarly != null) 'skipped_early': skippedEarly,
      if (saved != null) 'saved': saved,
      if (addedToPlaylist != null) 'added_to_playlist': addedToPlaylist,
      if (rankerVersion != null) 'ranker_version': rankerVersion,
      if (featuresJson != null) 'features_json': featuresJson,
    });
  }

  PlayEventsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ts,
      Value<String>? trackId,
      Value<String>? source,
      Value<int>? listenedMs,
      Value<int>? durationMs,
      Value<bool>? skippedEarly,
      Value<bool>? saved,
      Value<bool>? addedToPlaylist,
      Value<String>? rankerVersion,
      Value<String?>? featuresJson}) {
    return PlayEventsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      trackId: trackId ?? this.trackId,
      source: source ?? this.source,
      listenedMs: listenedMs ?? this.listenedMs,
      durationMs: durationMs ?? this.durationMs,
      skippedEarly: skippedEarly ?? this.skippedEarly,
      saved: saved ?? this.saved,
      addedToPlaylist: addedToPlaylist ?? this.addedToPlaylist,
      rankerVersion: rankerVersion ?? this.rankerVersion,
      featuresJson: featuresJson ?? this.featuresJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (skippedEarly.present) {
      map['skipped_early'] = Variable<bool>(skippedEarly.value);
    }
    if (saved.present) {
      map['saved'] = Variable<bool>(saved.value);
    }
    if (addedToPlaylist.present) {
      map['added_to_playlist'] = Variable<bool>(addedToPlaylist.value);
    }
    if (rankerVersion.present) {
      map['ranker_version'] = Variable<String>(rankerVersion.value);
    }
    if (featuresJson.present) {
      map['features_json'] = Variable<String>(featuresJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayEventsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('trackId: $trackId, ')
          ..write('source: $source, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('skippedEarly: $skippedEarly, ')
          ..write('saved: $saved, ')
          ..write('addedToPlaylist: $addedToPlaylist, ')
          ..write('rankerVersion: $rankerVersion, ')
          ..write('featuresJson: $featuresJson')
          ..write(')'))
        .toString();
  }
}

class $ImpressionsTable extends Impressions
    with TableInfo<$ImpressionsTable, ImpressionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImpressionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _surfaceMeta =
      const VerificationMeta('surface');
  @override
  late final GeneratedColumn<String> surface = GeneratedColumn<String>(
      'surface', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, ts, surface, itemId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'impressions';
  @override
  VerificationContext validateIntegrity(Insertable<ImpressionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('surface')) {
      context.handle(_surfaceMeta,
          surface.isAcceptableOrUnknown(data['surface']!, _surfaceMeta));
    } else if (isInserting) {
      context.missing(_surfaceMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImpressionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImpressionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
      surface: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}surface'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $ImpressionsTable createAlias(String alias) {
    return $ImpressionsTable(attachedDatabase, alias);
  }
}

class ImpressionRow extends DataClass implements Insertable<ImpressionRow> {
  final int id;
  final int ts;
  final String surface;
  final String itemId;
  final int position;
  const ImpressionRow(
      {required this.id,
      required this.ts,
      required this.surface,
      required this.itemId,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ts'] = Variable<int>(ts);
    map['surface'] = Variable<String>(surface);
    map['item_id'] = Variable<String>(itemId);
    map['position'] = Variable<int>(position);
    return map;
  }

  ImpressionsCompanion toCompanion(bool nullToAbsent) {
    return ImpressionsCompanion(
      id: Value(id),
      ts: Value(ts),
      surface: Value(surface),
      itemId: Value(itemId),
      position: Value(position),
    );
  }

  factory ImpressionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImpressionRow(
      id: serializer.fromJson<int>(json['id']),
      ts: serializer.fromJson<int>(json['ts']),
      surface: serializer.fromJson<String>(json['surface']),
      itemId: serializer.fromJson<String>(json['itemId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ts': serializer.toJson<int>(ts),
      'surface': serializer.toJson<String>(surface),
      'itemId': serializer.toJson<String>(itemId),
      'position': serializer.toJson<int>(position),
    };
  }

  ImpressionRow copyWith(
          {int? id, int? ts, String? surface, String? itemId, int? position}) =>
      ImpressionRow(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        surface: surface ?? this.surface,
        itemId: itemId ?? this.itemId,
        position: position ?? this.position,
      );
  ImpressionRow copyWithCompanion(ImpressionsCompanion data) {
    return ImpressionRow(
      id: data.id.present ? data.id.value : this.id,
      ts: data.ts.present ? data.ts.value : this.ts,
      surface: data.surface.present ? data.surface.value : this.surface,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImpressionRow(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('surface: $surface, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ts, surface, itemId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImpressionRow &&
          other.id == this.id &&
          other.ts == this.ts &&
          other.surface == this.surface &&
          other.itemId == this.itemId &&
          other.position == this.position);
}

class ImpressionsCompanion extends UpdateCompanion<ImpressionRow> {
  final Value<int> id;
  final Value<int> ts;
  final Value<String> surface;
  final Value<String> itemId;
  final Value<int> position;
  const ImpressionsCompanion({
    this.id = const Value.absent(),
    this.ts = const Value.absent(),
    this.surface = const Value.absent(),
    this.itemId = const Value.absent(),
    this.position = const Value.absent(),
  });
  ImpressionsCompanion.insert({
    this.id = const Value.absent(),
    required int ts,
    required String surface,
    required String itemId,
    required int position,
  })  : ts = Value(ts),
        surface = Value(surface),
        itemId = Value(itemId),
        position = Value(position);
  static Insertable<ImpressionRow> custom({
    Expression<int>? id,
    Expression<int>? ts,
    Expression<String>? surface,
    Expression<String>? itemId,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ts != null) 'ts': ts,
      if (surface != null) 'surface': surface,
      if (itemId != null) 'item_id': itemId,
      if (position != null) 'position': position,
    });
  }

  ImpressionsCompanion copyWith(
      {Value<int>? id,
      Value<int>? ts,
      Value<String>? surface,
      Value<String>? itemId,
      Value<int>? position}) {
    return ImpressionsCompanion(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      surface: surface ?? this.surface,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (surface.present) {
      map['surface'] = Variable<String>(surface.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImpressionsCompanion(')
          ..write('id: $id, ')
          ..write('ts: $ts, ')
          ..write('surface: $surface, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $TasteProfilesTable extends TasteProfiles
    with TableInfo<$TasteProfilesTable, TasteProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasteProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _slowWeightMeta =
      const VerificationMeta('slowWeight');
  @override
  late final GeneratedColumn<double> slowWeight = GeneratedColumn<double>(
      'slow_weight', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _fastWeightMeta =
      const VerificationMeta('fastWeight');
  @override
  late final GeneratedColumn<double> fastWeight = GeneratedColumn<double>(
      'fast_weight', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, entityType, entityId, slowWeight, fastWeight, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'taste_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<TasteProfileRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('slow_weight')) {
      context.handle(
          _slowWeightMeta,
          slowWeight.isAcceptableOrUnknown(
              data['slow_weight']!, _slowWeightMeta));
    }
    if (data.containsKey('fast_weight')) {
      context.handle(
          _fastWeightMeta,
          fastWeight.isAcceptableOrUnknown(
              data['fast_weight']!, _fastWeightMeta));
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {entityType, entityId},
      ];
  @override
  TasteProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TasteProfileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      slowWeight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}slow_weight'])!,
      fastWeight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fast_weight'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TasteProfilesTable createAlias(String alias) {
    return $TasteProfilesTable(attachedDatabase, alias);
  }
}

class TasteProfileRow extends DataClass implements Insertable<TasteProfileRow> {
  final int id;
  final String entityType;
  final String entityId;
  final double slowWeight;
  final double fastWeight;
  final int updatedAt;
  const TasteProfileRow(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.slowWeight,
      required this.fastWeight,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['slow_weight'] = Variable<double>(slowWeight);
    map['fast_weight'] = Variable<double>(fastWeight);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TasteProfilesCompanion toCompanion(bool nullToAbsent) {
    return TasteProfilesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      slowWeight: Value(slowWeight),
      fastWeight: Value(fastWeight),
      updatedAt: Value(updatedAt),
    );
  }

  factory TasteProfileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TasteProfileRow(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      slowWeight: serializer.fromJson<double>(json['slowWeight']),
      fastWeight: serializer.fromJson<double>(json['fastWeight']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'slowWeight': serializer.toJson<double>(slowWeight),
      'fastWeight': serializer.toJson<double>(fastWeight),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TasteProfileRow copyWith(
          {int? id,
          String? entityType,
          String? entityId,
          double? slowWeight,
          double? fastWeight,
          int? updatedAt}) =>
      TasteProfileRow(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        slowWeight: slowWeight ?? this.slowWeight,
        fastWeight: fastWeight ?? this.fastWeight,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  TasteProfileRow copyWithCompanion(TasteProfilesCompanion data) {
    return TasteProfileRow(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      slowWeight:
          data.slowWeight.present ? data.slowWeight.value : this.slowWeight,
      fastWeight:
          data.fastWeight.present ? data.fastWeight.value : this.fastWeight,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TasteProfileRow(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('slowWeight: $slowWeight, ')
          ..write('fastWeight: $fastWeight, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityType, entityId, slowWeight, fastWeight, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TasteProfileRow &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.slowWeight == this.slowWeight &&
          other.fastWeight == this.fastWeight &&
          other.updatedAt == this.updatedAt);
}

class TasteProfilesCompanion extends UpdateCompanion<TasteProfileRow> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<double> slowWeight;
  final Value<double> fastWeight;
  final Value<int> updatedAt;
  const TasteProfilesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.slowWeight = const Value.absent(),
    this.fastWeight = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TasteProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    this.slowWeight = const Value.absent(),
    this.fastWeight = const Value.absent(),
    required int updatedAt,
  })  : entityType = Value(entityType),
        entityId = Value(entityId),
        updatedAt = Value(updatedAt);
  static Insertable<TasteProfileRow> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<double>? slowWeight,
    Expression<double>? fastWeight,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (slowWeight != null) 'slow_weight': slowWeight,
      if (fastWeight != null) 'fast_weight': fastWeight,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TasteProfilesCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityType,
      Value<String>? entityId,
      Value<double>? slowWeight,
      Value<double>? fastWeight,
      Value<int>? updatedAt}) {
    return TasteProfilesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      slowWeight: slowWeight ?? this.slowWeight,
      fastWeight: fastWeight ?? this.fastWeight,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (slowWeight.present) {
      map['slow_weight'] = Variable<double>(slowWeight.value);
    }
    if (fastWeight.present) {
      map['fast_weight'] = Variable<double>(fastWeight.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasteProfilesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('slowWeight: $slowWeight, ')
          ..write('fastWeight: $fastWeight, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CooccurrencesTable extends Cooccurrences
    with TableInfo<$CooccurrencesTable, CooccurrenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CooccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackAMeta = const VerificationMeta('trackA');
  @override
  late final GeneratedColumn<String> trackA = GeneratedColumn<String>(
      'track_a', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _trackBMeta = const VerificationMeta('trackB');
  @override
  late final GeneratedColumn<String> trackB = GeneratedColumn<String>(
      'track_b', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
      'score', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [trackA, trackB, score, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cooccurrences';
  @override
  VerificationContext validateIntegrity(Insertable<CooccurrenceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_a')) {
      context.handle(_trackAMeta,
          trackA.isAcceptableOrUnknown(data['track_a']!, _trackAMeta));
    } else if (isInserting) {
      context.missing(_trackAMeta);
    }
    if (data.containsKey('track_b')) {
      context.handle(_trackBMeta,
          trackB.isAcceptableOrUnknown(data['track_b']!, _trackBMeta));
    } else if (isInserting) {
      context.missing(_trackBMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    } else if (isInserting) {
      context.missing(_scoreMeta);
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
  Set<GeneratedColumn> get $primaryKey => {trackA, trackB};
  @override
  CooccurrenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CooccurrenceRow(
      trackA: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_a'])!,
      trackB: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_b'])!,
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CooccurrencesTable createAlias(String alias) {
    return $CooccurrencesTable(attachedDatabase, alias);
  }
}

class CooccurrenceRow extends DataClass implements Insertable<CooccurrenceRow> {
  final String trackA;
  final String trackB;
  final double score;
  final int updatedAt;
  const CooccurrenceRow(
      {required this.trackA,
      required this.trackB,
      required this.score,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_a'] = Variable<String>(trackA);
    map['track_b'] = Variable<String>(trackB);
    map['score'] = Variable<double>(score);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CooccurrencesCompanion toCompanion(bool nullToAbsent) {
    return CooccurrencesCompanion(
      trackA: Value(trackA),
      trackB: Value(trackB),
      score: Value(score),
      updatedAt: Value(updatedAt),
    );
  }

  factory CooccurrenceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CooccurrenceRow(
      trackA: serializer.fromJson<String>(json['trackA']),
      trackB: serializer.fromJson<String>(json['trackB']),
      score: serializer.fromJson<double>(json['score']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackA': serializer.toJson<String>(trackA),
      'trackB': serializer.toJson<String>(trackB),
      'score': serializer.toJson<double>(score),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CooccurrenceRow copyWith(
          {String? trackA, String? trackB, double? score, int? updatedAt}) =>
      CooccurrenceRow(
        trackA: trackA ?? this.trackA,
        trackB: trackB ?? this.trackB,
        score: score ?? this.score,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CooccurrenceRow copyWithCompanion(CooccurrencesCompanion data) {
    return CooccurrenceRow(
      trackA: data.trackA.present ? data.trackA.value : this.trackA,
      trackB: data.trackB.present ? data.trackB.value : this.trackB,
      score: data.score.present ? data.score.value : this.score,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CooccurrenceRow(')
          ..write('trackA: $trackA, ')
          ..write('trackB: $trackB, ')
          ..write('score: $score, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackA, trackB, score, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CooccurrenceRow &&
          other.trackA == this.trackA &&
          other.trackB == this.trackB &&
          other.score == this.score &&
          other.updatedAt == this.updatedAt);
}

class CooccurrencesCompanion extends UpdateCompanion<CooccurrenceRow> {
  final Value<String> trackA;
  final Value<String> trackB;
  final Value<double> score;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CooccurrencesCompanion({
    this.trackA = const Value.absent(),
    this.trackB = const Value.absent(),
    this.score = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CooccurrencesCompanion.insert({
    required String trackA,
    required String trackB,
    required double score,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : trackA = Value(trackA),
        trackB = Value(trackB),
        score = Value(score),
        updatedAt = Value(updatedAt);
  static Insertable<CooccurrenceRow> custom({
    Expression<String>? trackA,
    Expression<String>? trackB,
    Expression<double>? score,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackA != null) 'track_a': trackA,
      if (trackB != null) 'track_b': trackB,
      if (score != null) 'score': score,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CooccurrencesCompanion copyWith(
      {Value<String>? trackA,
      Value<String>? trackB,
      Value<double>? score,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return CooccurrencesCompanion(
      trackA: trackA ?? this.trackA,
      trackB: trackB ?? this.trackB,
      score: score ?? this.score,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackA.present) {
      map['track_a'] = Variable<String>(trackA.value);
    }
    if (trackB.present) {
      map['track_b'] = Variable<String>(trackB.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CooccurrencesCompanion(')
          ..write('trackA: $trackA, ')
          ..write('trackB: $trackB, ')
          ..write('score: $score, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueryCompletionsTable extends QueryCompletions
    with TableInfo<$QueryCompletionsTable, QueryCompletionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueryCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
      'query', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedPrefixMeta =
      const VerificationMeta('normalizedPrefix');
  @override
  late final GeneratedColumn<String> normalizedPrefix = GeneratedColumn<String>(
      'normalized_prefix', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _streamCountMeta =
      const VerificationMeta('streamCount');
  @override
  late final GeneratedColumn<int> streamCount = GeneratedColumn<int>(
      'stream_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastUsedTsMeta =
      const VerificationMeta('lastUsedTs');
  @override
  late final GeneratedColumn<int> lastUsedTs = GeneratedColumn<int>(
      'last_used_ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [query, normalizedPrefix, streamCount, lastUsedTs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'query_completions';
  @override
  VerificationContext validateIntegrity(Insertable<QueryCompletionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
          _queryMeta, query.isAcceptableOrUnknown(data['query']!, _queryMeta));
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('normalized_prefix')) {
      context.handle(
          _normalizedPrefixMeta,
          normalizedPrefix.isAcceptableOrUnknown(
              data['normalized_prefix']!, _normalizedPrefixMeta));
    } else if (isInserting) {
      context.missing(_normalizedPrefixMeta);
    }
    if (data.containsKey('stream_count')) {
      context.handle(
          _streamCountMeta,
          streamCount.isAcceptableOrUnknown(
              data['stream_count']!, _streamCountMeta));
    }
    if (data.containsKey('last_used_ts')) {
      context.handle(
          _lastUsedTsMeta,
          lastUsedTs.isAcceptableOrUnknown(
              data['last_used_ts']!, _lastUsedTsMeta));
    } else if (isInserting) {
      context.missing(_lastUsedTsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  QueryCompletionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueryCompletionRow(
      query: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}query'])!,
      normalizedPrefix: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_prefix'])!,
      streamCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stream_count'])!,
      lastUsedTs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_used_ts'])!,
    );
  }

  @override
  $QueryCompletionsTable createAlias(String alias) {
    return $QueryCompletionsTable(attachedDatabase, alias);
  }
}

class QueryCompletionRow extends DataClass
    implements Insertable<QueryCompletionRow> {
  final String query;
  final String normalizedPrefix;
  final int streamCount;
  final int lastUsedTs;
  const QueryCompletionRow(
      {required this.query,
      required this.normalizedPrefix,
      required this.streamCount,
      required this.lastUsedTs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['normalized_prefix'] = Variable<String>(normalizedPrefix);
    map['stream_count'] = Variable<int>(streamCount);
    map['last_used_ts'] = Variable<int>(lastUsedTs);
    return map;
  }

  QueryCompletionsCompanion toCompanion(bool nullToAbsent) {
    return QueryCompletionsCompanion(
      query: Value(query),
      normalizedPrefix: Value(normalizedPrefix),
      streamCount: Value(streamCount),
      lastUsedTs: Value(lastUsedTs),
    );
  }

  factory QueryCompletionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueryCompletionRow(
      query: serializer.fromJson<String>(json['query']),
      normalizedPrefix: serializer.fromJson<String>(json['normalizedPrefix']),
      streamCount: serializer.fromJson<int>(json['streamCount']),
      lastUsedTs: serializer.fromJson<int>(json['lastUsedTs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'normalizedPrefix': serializer.toJson<String>(normalizedPrefix),
      'streamCount': serializer.toJson<int>(streamCount),
      'lastUsedTs': serializer.toJson<int>(lastUsedTs),
    };
  }

  QueryCompletionRow copyWith(
          {String? query,
          String? normalizedPrefix,
          int? streamCount,
          int? lastUsedTs}) =>
      QueryCompletionRow(
        query: query ?? this.query,
        normalizedPrefix: normalizedPrefix ?? this.normalizedPrefix,
        streamCount: streamCount ?? this.streamCount,
        lastUsedTs: lastUsedTs ?? this.lastUsedTs,
      );
  QueryCompletionRow copyWithCompanion(QueryCompletionsCompanion data) {
    return QueryCompletionRow(
      query: data.query.present ? data.query.value : this.query,
      normalizedPrefix: data.normalizedPrefix.present
          ? data.normalizedPrefix.value
          : this.normalizedPrefix,
      streamCount:
          data.streamCount.present ? data.streamCount.value : this.streamCount,
      lastUsedTs:
          data.lastUsedTs.present ? data.lastUsedTs.value : this.lastUsedTs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueryCompletionRow(')
          ..write('query: $query, ')
          ..write('normalizedPrefix: $normalizedPrefix, ')
          ..write('streamCount: $streamCount, ')
          ..write('lastUsedTs: $lastUsedTs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(query, normalizedPrefix, streamCount, lastUsedTs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryCompletionRow &&
          other.query == this.query &&
          other.normalizedPrefix == this.normalizedPrefix &&
          other.streamCount == this.streamCount &&
          other.lastUsedTs == this.lastUsedTs);
}

class QueryCompletionsCompanion extends UpdateCompanion<QueryCompletionRow> {
  final Value<String> query;
  final Value<String> normalizedPrefix;
  final Value<int> streamCount;
  final Value<int> lastUsedTs;
  final Value<int> rowid;
  const QueryCompletionsCompanion({
    this.query = const Value.absent(),
    this.normalizedPrefix = const Value.absent(),
    this.streamCount = const Value.absent(),
    this.lastUsedTs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueryCompletionsCompanion.insert({
    required String query,
    required String normalizedPrefix,
    this.streamCount = const Value.absent(),
    required int lastUsedTs,
    this.rowid = const Value.absent(),
  })  : query = Value(query),
        normalizedPrefix = Value(normalizedPrefix),
        lastUsedTs = Value(lastUsedTs);
  static Insertable<QueryCompletionRow> custom({
    Expression<String>? query,
    Expression<String>? normalizedPrefix,
    Expression<int>? streamCount,
    Expression<int>? lastUsedTs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (normalizedPrefix != null) 'normalized_prefix': normalizedPrefix,
      if (streamCount != null) 'stream_count': streamCount,
      if (lastUsedTs != null) 'last_used_ts': lastUsedTs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueryCompletionsCompanion copyWith(
      {Value<String>? query,
      Value<String>? normalizedPrefix,
      Value<int>? streamCount,
      Value<int>? lastUsedTs,
      Value<int>? rowid}) {
    return QueryCompletionsCompanion(
      query: query ?? this.query,
      normalizedPrefix: normalizedPrefix ?? this.normalizedPrefix,
      streamCount: streamCount ?? this.streamCount,
      lastUsedTs: lastUsedTs ?? this.lastUsedTs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (normalizedPrefix.present) {
      map['normalized_prefix'] = Variable<String>(normalizedPrefix.value);
    }
    if (streamCount.present) {
      map['stream_count'] = Variable<int>(streamCount.value);
    }
    if (lastUsedTs.present) {
      map['last_used_ts'] = Variable<int>(lastUsedTs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueryCompletionsCompanion(')
          ..write('query: $query, ')
          ..write('normalizedPrefix: $normalizedPrefix, ')
          ..write('streamCount: $streamCount, ')
          ..write('lastUsedTs: $lastUsedTs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BanditStatesTable extends BanditStates
    with TableInfo<$BanditStatesTable, BanditStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BanditStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _shelfIdMeta =
      const VerificationMeta('shelfId');
  @override
  late final GeneratedColumn<String> shelfId = GeneratedColumn<String>(
      'shelf_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _epsilonMeta =
      const VerificationMeta('epsilon');
  @override
  late final GeneratedColumn<double> epsilon = GeneratedColumn<double>(
      'epsilon', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.1));
  static const VerificationMeta _pullCountMeta =
      const VerificationMeta('pullCount');
  @override
  late final GeneratedColumn<int> pullCount = GeneratedColumn<int>(
      'pull_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _cumulativeRewardMeta =
      const VerificationMeta('cumulativeReward');
  @override
  late final GeneratedColumn<double> cumulativeReward = GeneratedColumn<double>(
      'cumulative_reward', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _currentNoveltyRatioMeta =
      const VerificationMeta('currentNoveltyRatio');
  @override
  late final GeneratedColumn<double> currentNoveltyRatio =
      GeneratedColumn<double>('current_novelty_ratio', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.2));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        shelfId,
        epsilon,
        pullCount,
        cumulativeReward,
        currentNoveltyRatio,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bandit_states';
  @override
  VerificationContext validateIntegrity(Insertable<BanditStateRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('shelf_id')) {
      context.handle(_shelfIdMeta,
          shelfId.isAcceptableOrUnknown(data['shelf_id']!, _shelfIdMeta));
    } else if (isInserting) {
      context.missing(_shelfIdMeta);
    }
    if (data.containsKey('epsilon')) {
      context.handle(_epsilonMeta,
          epsilon.isAcceptableOrUnknown(data['epsilon']!, _epsilonMeta));
    }
    if (data.containsKey('pull_count')) {
      context.handle(_pullCountMeta,
          pullCount.isAcceptableOrUnknown(data['pull_count']!, _pullCountMeta));
    }
    if (data.containsKey('cumulative_reward')) {
      context.handle(
          _cumulativeRewardMeta,
          cumulativeReward.isAcceptableOrUnknown(
              data['cumulative_reward']!, _cumulativeRewardMeta));
    }
    if (data.containsKey('current_novelty_ratio')) {
      context.handle(
          _currentNoveltyRatioMeta,
          currentNoveltyRatio.isAcceptableOrUnknown(
              data['current_novelty_ratio']!, _currentNoveltyRatioMeta));
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
  Set<GeneratedColumn> get $primaryKey => {shelfId};
  @override
  BanditStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BanditStateRow(
      shelfId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shelf_id'])!,
      epsilon: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}epsilon'])!,
      pullCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pull_count'])!,
      cumulativeReward: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}cumulative_reward'])!,
      currentNoveltyRatio: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}current_novelty_ratio'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $BanditStatesTable createAlias(String alias) {
    return $BanditStatesTable(attachedDatabase, alias);
  }
}

class BanditStateRow extends DataClass implements Insertable<BanditStateRow> {
  final String shelfId;
  final double epsilon;
  final int pullCount;
  final double cumulativeReward;
  final double currentNoveltyRatio;
  final int updatedAt;
  const BanditStateRow(
      {required this.shelfId,
      required this.epsilon,
      required this.pullCount,
      required this.cumulativeReward,
      required this.currentNoveltyRatio,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['shelf_id'] = Variable<String>(shelfId);
    map['epsilon'] = Variable<double>(epsilon);
    map['pull_count'] = Variable<int>(pullCount);
    map['cumulative_reward'] = Variable<double>(cumulativeReward);
    map['current_novelty_ratio'] = Variable<double>(currentNoveltyRatio);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  BanditStatesCompanion toCompanion(bool nullToAbsent) {
    return BanditStatesCompanion(
      shelfId: Value(shelfId),
      epsilon: Value(epsilon),
      pullCount: Value(pullCount),
      cumulativeReward: Value(cumulativeReward),
      currentNoveltyRatio: Value(currentNoveltyRatio),
      updatedAt: Value(updatedAt),
    );
  }

  factory BanditStateRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BanditStateRow(
      shelfId: serializer.fromJson<String>(json['shelfId']),
      epsilon: serializer.fromJson<double>(json['epsilon']),
      pullCount: serializer.fromJson<int>(json['pullCount']),
      cumulativeReward: serializer.fromJson<double>(json['cumulativeReward']),
      currentNoveltyRatio:
          serializer.fromJson<double>(json['currentNoveltyRatio']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'shelfId': serializer.toJson<String>(shelfId),
      'epsilon': serializer.toJson<double>(epsilon),
      'pullCount': serializer.toJson<int>(pullCount),
      'cumulativeReward': serializer.toJson<double>(cumulativeReward),
      'currentNoveltyRatio': serializer.toJson<double>(currentNoveltyRatio),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  BanditStateRow copyWith(
          {String? shelfId,
          double? epsilon,
          int? pullCount,
          double? cumulativeReward,
          double? currentNoveltyRatio,
          int? updatedAt}) =>
      BanditStateRow(
        shelfId: shelfId ?? this.shelfId,
        epsilon: epsilon ?? this.epsilon,
        pullCount: pullCount ?? this.pullCount,
        cumulativeReward: cumulativeReward ?? this.cumulativeReward,
        currentNoveltyRatio: currentNoveltyRatio ?? this.currentNoveltyRatio,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  BanditStateRow copyWithCompanion(BanditStatesCompanion data) {
    return BanditStateRow(
      shelfId: data.shelfId.present ? data.shelfId.value : this.shelfId,
      epsilon: data.epsilon.present ? data.epsilon.value : this.epsilon,
      pullCount: data.pullCount.present ? data.pullCount.value : this.pullCount,
      cumulativeReward: data.cumulativeReward.present
          ? data.cumulativeReward.value
          : this.cumulativeReward,
      currentNoveltyRatio: data.currentNoveltyRatio.present
          ? data.currentNoveltyRatio.value
          : this.currentNoveltyRatio,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BanditStateRow(')
          ..write('shelfId: $shelfId, ')
          ..write('epsilon: $epsilon, ')
          ..write('pullCount: $pullCount, ')
          ..write('cumulativeReward: $cumulativeReward, ')
          ..write('currentNoveltyRatio: $currentNoveltyRatio, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(shelfId, epsilon, pullCount, cumulativeReward,
      currentNoveltyRatio, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BanditStateRow &&
          other.shelfId == this.shelfId &&
          other.epsilon == this.epsilon &&
          other.pullCount == this.pullCount &&
          other.cumulativeReward == this.cumulativeReward &&
          other.currentNoveltyRatio == this.currentNoveltyRatio &&
          other.updatedAt == this.updatedAt);
}

class BanditStatesCompanion extends UpdateCompanion<BanditStateRow> {
  final Value<String> shelfId;
  final Value<double> epsilon;
  final Value<int> pullCount;
  final Value<double> cumulativeReward;
  final Value<double> currentNoveltyRatio;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const BanditStatesCompanion({
    this.shelfId = const Value.absent(),
    this.epsilon = const Value.absent(),
    this.pullCount = const Value.absent(),
    this.cumulativeReward = const Value.absent(),
    this.currentNoveltyRatio = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BanditStatesCompanion.insert({
    required String shelfId,
    this.epsilon = const Value.absent(),
    this.pullCount = const Value.absent(),
    this.cumulativeReward = const Value.absent(),
    this.currentNoveltyRatio = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : shelfId = Value(shelfId),
        updatedAt = Value(updatedAt);
  static Insertable<BanditStateRow> custom({
    Expression<String>? shelfId,
    Expression<double>? epsilon,
    Expression<int>? pullCount,
    Expression<double>? cumulativeReward,
    Expression<double>? currentNoveltyRatio,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (shelfId != null) 'shelf_id': shelfId,
      if (epsilon != null) 'epsilon': epsilon,
      if (pullCount != null) 'pull_count': pullCount,
      if (cumulativeReward != null) 'cumulative_reward': cumulativeReward,
      if (currentNoveltyRatio != null)
        'current_novelty_ratio': currentNoveltyRatio,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BanditStatesCompanion copyWith(
      {Value<String>? shelfId,
      Value<double>? epsilon,
      Value<int>? pullCount,
      Value<double>? cumulativeReward,
      Value<double>? currentNoveltyRatio,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return BanditStatesCompanion(
      shelfId: shelfId ?? this.shelfId,
      epsilon: epsilon ?? this.epsilon,
      pullCount: pullCount ?? this.pullCount,
      cumulativeReward: cumulativeReward ?? this.cumulativeReward,
      currentNoveltyRatio: currentNoveltyRatio ?? this.currentNoveltyRatio,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (shelfId.present) {
      map['shelf_id'] = Variable<String>(shelfId.value);
    }
    if (epsilon.present) {
      map['epsilon'] = Variable<double>(epsilon.value);
    }
    if (pullCount.present) {
      map['pull_count'] = Variable<int>(pullCount.value);
    }
    if (cumulativeReward.present) {
      map['cumulative_reward'] = Variable<double>(cumulativeReward.value);
    }
    if (currentNoveltyRatio.present) {
      map['current_novelty_ratio'] =
          Variable<double>(currentNoveltyRatio.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BanditStatesCompanion(')
          ..write('shelfId: $shelfId, ')
          ..write('epsilon: $epsilon, ')
          ..write('pullCount: $pullCount, ')
          ..write('cumulativeReward: $cumulativeReward, ')
          ..write('currentNoveltyRatio: $currentNoveltyRatio, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistSnoozesTable extends ArtistSnoozes
    with TableInfo<$ArtistSnoozesTable, ArtistSnoozeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistSnoozesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _artistIdMeta =
      const VerificationMeta('artistId');
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
      'artist_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _snoozedUntilMeta =
      const VerificationMeta('snoozedUntil');
  @override
  late final GeneratedColumn<int> snoozedUntil = GeneratedColumn<int>(
      'snoozed_until', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [artistId, snoozedUntil];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artist_snoozes';
  @override
  VerificationContext validateIntegrity(Insertable<ArtistSnoozeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('artist_id')) {
      context.handle(_artistIdMeta,
          artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta));
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
          _snoozedUntilMeta,
          snoozedUntil.isAcceptableOrUnknown(
              data['snoozed_until']!, _snoozedUntilMeta));
    } else if (isInserting) {
      context.missing(_snoozedUntilMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artistId};
  @override
  ArtistSnoozeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistSnoozeRow(
      artistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist_id'])!,
      snoozedUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}snoozed_until'])!,
    );
  }

  @override
  $ArtistSnoozesTable createAlias(String alias) {
    return $ArtistSnoozesTable(attachedDatabase, alias);
  }
}

class ArtistSnoozeRow extends DataClass implements Insertable<ArtistSnoozeRow> {
  final String artistId;
  final int snoozedUntil;
  const ArtistSnoozeRow({required this.artistId, required this.snoozedUntil});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['artist_id'] = Variable<String>(artistId);
    map['snoozed_until'] = Variable<int>(snoozedUntil);
    return map;
  }

  ArtistSnoozesCompanion toCompanion(bool nullToAbsent) {
    return ArtistSnoozesCompanion(
      artistId: Value(artistId),
      snoozedUntil: Value(snoozedUntil),
    );
  }

  factory ArtistSnoozeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistSnoozeRow(
      artistId: serializer.fromJson<String>(json['artistId']),
      snoozedUntil: serializer.fromJson<int>(json['snoozedUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'artistId': serializer.toJson<String>(artistId),
      'snoozedUntil': serializer.toJson<int>(snoozedUntil),
    };
  }

  ArtistSnoozeRow copyWith({String? artistId, int? snoozedUntil}) =>
      ArtistSnoozeRow(
        artistId: artistId ?? this.artistId,
        snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      );
  ArtistSnoozeRow copyWithCompanion(ArtistSnoozesCompanion data) {
    return ArtistSnoozeRow(
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistSnoozeRow(')
          ..write('artistId: $artistId, ')
          ..write('snoozedUntil: $snoozedUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(artistId, snoozedUntil);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistSnoozeRow &&
          other.artistId == this.artistId &&
          other.snoozedUntil == this.snoozedUntil);
}

class ArtistSnoozesCompanion extends UpdateCompanion<ArtistSnoozeRow> {
  final Value<String> artistId;
  final Value<int> snoozedUntil;
  final Value<int> rowid;
  const ArtistSnoozesCompanion({
    this.artistId = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistSnoozesCompanion.insert({
    required String artistId,
    required int snoozedUntil,
    this.rowid = const Value.absent(),
  })  : artistId = Value(artistId),
        snoozedUntil = Value(snoozedUntil);
  static Insertable<ArtistSnoozeRow> custom({
    Expression<String>? artistId,
    Expression<int>? snoozedUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (artistId != null) 'artist_id': artistId,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistSnoozesCompanion copyWith(
      {Value<String>? artistId, Value<int>? snoozedUntil, Value<int>? rowid}) {
    return ArtistSnoozesCompanion(
      artistId: artistId ?? this.artistId,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<int>(snoozedUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistSnoozesCompanion(')
          ..write('artistId: $artistId, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InterleaveOutcomesTable extends InterleaveOutcomes
    with TableInfo<$InterleaveOutcomesTable, InterleaveOutcomeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InterleaveOutcomesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _queryOrContextMeta =
      const VerificationMeta('queryOrContext');
  @override
  late final GeneratedColumn<String> queryOrContext = GeneratedColumn<String>(
      'query_or_context', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelAIdMeta =
      const VerificationMeta('modelAId');
  @override
  late final GeneratedColumn<String> modelAId = GeneratedColumn<String>(
      'model_a_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelBIdMeta =
      const VerificationMeta('modelBId');
  @override
  late final GeneratedColumn<String> modelBId = GeneratedColumn<String>(
      'model_b_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _winningModelIdMeta =
      const VerificationMeta('winningModelId');
  @override
  late final GeneratedColumn<String> winningModelId = GeneratedColumn<String>(
      'winning_model_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
      'ts', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, queryOrContext, modelAId, modelBId, winningModelId, ts];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interleave_outcomes';
  @override
  VerificationContext validateIntegrity(
      Insertable<InterleaveOutcomeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query_or_context')) {
      context.handle(
          _queryOrContextMeta,
          queryOrContext.isAcceptableOrUnknown(
              data['query_or_context']!, _queryOrContextMeta));
    } else if (isInserting) {
      context.missing(_queryOrContextMeta);
    }
    if (data.containsKey('model_a_id')) {
      context.handle(_modelAIdMeta,
          modelAId.isAcceptableOrUnknown(data['model_a_id']!, _modelAIdMeta));
    } else if (isInserting) {
      context.missing(_modelAIdMeta);
    }
    if (data.containsKey('model_b_id')) {
      context.handle(_modelBIdMeta,
          modelBId.isAcceptableOrUnknown(data['model_b_id']!, _modelBIdMeta));
    } else if (isInserting) {
      context.missing(_modelBIdMeta);
    }
    if (data.containsKey('winning_model_id')) {
      context.handle(
          _winningModelIdMeta,
          winningModelId.isAcceptableOrUnknown(
              data['winning_model_id']!, _winningModelIdMeta));
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InterleaveOutcomeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InterleaveOutcomeRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      queryOrContext: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}query_or_context'])!,
      modelAId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_a_id'])!,
      modelBId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model_b_id'])!,
      winningModelId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}winning_model_id']),
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts'])!,
    );
  }

  @override
  $InterleaveOutcomesTable createAlias(String alias) {
    return $InterleaveOutcomesTable(attachedDatabase, alias);
  }
}

class InterleaveOutcomeRow extends DataClass
    implements Insertable<InterleaveOutcomeRow> {
  final int id;
  final String queryOrContext;
  final String modelAId;
  final String modelBId;
  final String? winningModelId;
  final int ts;
  const InterleaveOutcomeRow(
      {required this.id,
      required this.queryOrContext,
      required this.modelAId,
      required this.modelBId,
      this.winningModelId,
      required this.ts});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query_or_context'] = Variable<String>(queryOrContext);
    map['model_a_id'] = Variable<String>(modelAId);
    map['model_b_id'] = Variable<String>(modelBId);
    if (!nullToAbsent || winningModelId != null) {
      map['winning_model_id'] = Variable<String>(winningModelId);
    }
    map['ts'] = Variable<int>(ts);
    return map;
  }

  InterleaveOutcomesCompanion toCompanion(bool nullToAbsent) {
    return InterleaveOutcomesCompanion(
      id: Value(id),
      queryOrContext: Value(queryOrContext),
      modelAId: Value(modelAId),
      modelBId: Value(modelBId),
      winningModelId: winningModelId == null && nullToAbsent
          ? const Value.absent()
          : Value(winningModelId),
      ts: Value(ts),
    );
  }

  factory InterleaveOutcomeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InterleaveOutcomeRow(
      id: serializer.fromJson<int>(json['id']),
      queryOrContext: serializer.fromJson<String>(json['queryOrContext']),
      modelAId: serializer.fromJson<String>(json['modelAId']),
      modelBId: serializer.fromJson<String>(json['modelBId']),
      winningModelId: serializer.fromJson<String?>(json['winningModelId']),
      ts: serializer.fromJson<int>(json['ts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'queryOrContext': serializer.toJson<String>(queryOrContext),
      'modelAId': serializer.toJson<String>(modelAId),
      'modelBId': serializer.toJson<String>(modelBId),
      'winningModelId': serializer.toJson<String?>(winningModelId),
      'ts': serializer.toJson<int>(ts),
    };
  }

  InterleaveOutcomeRow copyWith(
          {int? id,
          String? queryOrContext,
          String? modelAId,
          String? modelBId,
          Value<String?> winningModelId = const Value.absent(),
          int? ts}) =>
      InterleaveOutcomeRow(
        id: id ?? this.id,
        queryOrContext: queryOrContext ?? this.queryOrContext,
        modelAId: modelAId ?? this.modelAId,
        modelBId: modelBId ?? this.modelBId,
        winningModelId:
            winningModelId.present ? winningModelId.value : this.winningModelId,
        ts: ts ?? this.ts,
      );
  InterleaveOutcomeRow copyWithCompanion(InterleaveOutcomesCompanion data) {
    return InterleaveOutcomeRow(
      id: data.id.present ? data.id.value : this.id,
      queryOrContext: data.queryOrContext.present
          ? data.queryOrContext.value
          : this.queryOrContext,
      modelAId: data.modelAId.present ? data.modelAId.value : this.modelAId,
      modelBId: data.modelBId.present ? data.modelBId.value : this.modelBId,
      winningModelId: data.winningModelId.present
          ? data.winningModelId.value
          : this.winningModelId,
      ts: data.ts.present ? data.ts.value : this.ts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InterleaveOutcomeRow(')
          ..write('id: $id, ')
          ..write('queryOrContext: $queryOrContext, ')
          ..write('modelAId: $modelAId, ')
          ..write('modelBId: $modelBId, ')
          ..write('winningModelId: $winningModelId, ')
          ..write('ts: $ts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, queryOrContext, modelAId, modelBId, winningModelId, ts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterleaveOutcomeRow &&
          other.id == this.id &&
          other.queryOrContext == this.queryOrContext &&
          other.modelAId == this.modelAId &&
          other.modelBId == this.modelBId &&
          other.winningModelId == this.winningModelId &&
          other.ts == this.ts);
}

class InterleaveOutcomesCompanion
    extends UpdateCompanion<InterleaveOutcomeRow> {
  final Value<int> id;
  final Value<String> queryOrContext;
  final Value<String> modelAId;
  final Value<String> modelBId;
  final Value<String?> winningModelId;
  final Value<int> ts;
  const InterleaveOutcomesCompanion({
    this.id = const Value.absent(),
    this.queryOrContext = const Value.absent(),
    this.modelAId = const Value.absent(),
    this.modelBId = const Value.absent(),
    this.winningModelId = const Value.absent(),
    this.ts = const Value.absent(),
  });
  InterleaveOutcomesCompanion.insert({
    this.id = const Value.absent(),
    required String queryOrContext,
    required String modelAId,
    required String modelBId,
    this.winningModelId = const Value.absent(),
    required int ts,
  })  : queryOrContext = Value(queryOrContext),
        modelAId = Value(modelAId),
        modelBId = Value(modelBId),
        ts = Value(ts);
  static Insertable<InterleaveOutcomeRow> custom({
    Expression<int>? id,
    Expression<String>? queryOrContext,
    Expression<String>? modelAId,
    Expression<String>? modelBId,
    Expression<String>? winningModelId,
    Expression<int>? ts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (queryOrContext != null) 'query_or_context': queryOrContext,
      if (modelAId != null) 'model_a_id': modelAId,
      if (modelBId != null) 'model_b_id': modelBId,
      if (winningModelId != null) 'winning_model_id': winningModelId,
      if (ts != null) 'ts': ts,
    });
  }

  InterleaveOutcomesCompanion copyWith(
      {Value<int>? id,
      Value<String>? queryOrContext,
      Value<String>? modelAId,
      Value<String>? modelBId,
      Value<String?>? winningModelId,
      Value<int>? ts}) {
    return InterleaveOutcomesCompanion(
      id: id ?? this.id,
      queryOrContext: queryOrContext ?? this.queryOrContext,
      modelAId: modelAId ?? this.modelAId,
      modelBId: modelBId ?? this.modelBId,
      winningModelId: winningModelId ?? this.winningModelId,
      ts: ts ?? this.ts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (queryOrContext.present) {
      map['query_or_context'] = Variable<String>(queryOrContext.value);
    }
    if (modelAId.present) {
      map['model_a_id'] = Variable<String>(modelAId.value);
    }
    if (modelBId.present) {
      map['model_b_id'] = Variable<String>(modelBId.value);
    }
    if (winningModelId.present) {
      map['winning_model_id'] = Variable<String>(winningModelId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InterleaveOutcomesCompanion(')
          ..write('id: $id, ')
          ..write('queryOrContext: $queryOrContext, ')
          ..write('modelAId: $modelAId, ')
          ..write('modelBId: $modelBId, ')
          ..write('winningModelId: $winningModelId, ')
          ..write('ts: $ts')
          ..write(')'))
        .toString();
  }
}

class $TrackEmbeddingsTable extends TrackEmbeddings
    with TableInfo<$TrackEmbeddingsTable, TrackEmbeddingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vectorMeta = const VerificationMeta('vector');
  @override
  late final GeneratedColumn<Uint8List> vector = GeneratedColumn<Uint8List>(
      'vector', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [trackId, vector, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_embeddings';
  @override
  VerificationContext validateIntegrity(Insertable<TrackEmbeddingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('vector')) {
      context.handle(_vectorMeta,
          vector.isAcceptableOrUnknown(data['vector']!, _vectorMeta));
    } else if (isInserting) {
      context.missing(_vectorMeta);
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
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  TrackEmbeddingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackEmbeddingRow(
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      vector: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}vector'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TrackEmbeddingsTable createAlias(String alias) {
    return $TrackEmbeddingsTable(attachedDatabase, alias);
  }
}

class TrackEmbeddingRow extends DataClass
    implements Insertable<TrackEmbeddingRow> {
  final String trackId;
  final Uint8List vector;
  final int updatedAt;
  const TrackEmbeddingRow(
      {required this.trackId, required this.vector, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<String>(trackId);
    map['vector'] = Variable<Uint8List>(vector);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TrackEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return TrackEmbeddingsCompanion(
      trackId: Value(trackId),
      vector: Value(vector),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrackEmbeddingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackEmbeddingRow(
      trackId: serializer.fromJson<String>(json['trackId']),
      vector: serializer.fromJson<Uint8List>(json['vector']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<String>(trackId),
      'vector': serializer.toJson<Uint8List>(vector),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TrackEmbeddingRow copyWith(
          {String? trackId, Uint8List? vector, int? updatedAt}) =>
      TrackEmbeddingRow(
        trackId: trackId ?? this.trackId,
        vector: vector ?? this.vector,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  TrackEmbeddingRow copyWithCompanion(TrackEmbeddingsCompanion data) {
    return TrackEmbeddingRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      vector: data.vector.present ? data.vector.value : this.vector,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackEmbeddingRow(')
          ..write('trackId: $trackId, ')
          ..write('vector: $vector, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackId, $driftBlobEquality.hash(vector), updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackEmbeddingRow &&
          other.trackId == this.trackId &&
          $driftBlobEquality.equals(other.vector, this.vector) &&
          other.updatedAt == this.updatedAt);
}

class TrackEmbeddingsCompanion extends UpdateCompanion<TrackEmbeddingRow> {
  final Value<String> trackId;
  final Value<Uint8List> vector;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TrackEmbeddingsCompanion({
    this.trackId = const Value.absent(),
    this.vector = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackEmbeddingsCompanion.insert({
    required String trackId,
    required Uint8List vector,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : trackId = Value(trackId),
        vector = Value(vector),
        updatedAt = Value(updatedAt);
  static Insertable<TrackEmbeddingRow> custom({
    Expression<String>? trackId,
    Expression<Uint8List>? vector,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (vector != null) 'vector': vector,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackEmbeddingsCompanion copyWith(
      {Value<String>? trackId,
      Value<Uint8List>? vector,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return TrackEmbeddingsCompanion(
      trackId: trackId ?? this.trackId,
      vector: vector ?? this.vector,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (vector.present) {
      map['vector'] = Variable<Uint8List>(vector.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackEmbeddingsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('vector: $vector, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $YoutubeHistoryTable extends YoutubeHistory
    with TableInfo<$YoutubeHistoryTable, YoutubeHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $YoutubeHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _channelMeta =
      const VerificationMeta('channel');
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
      'channel', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _thumbnailUrlMeta =
      const VerificationMeta('thumbnailUrl');
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastPlayedAtMeta =
      const VerificationMeta('lastPlayedAt');
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
      'last_played_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [videoId, title, channel, thumbnailUrl, durationSeconds, lastPlayedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'youtube_history';
  @override
  VerificationContext validateIntegrity(Insertable<YoutubeHistoryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(_channelMeta,
          channel.isAcceptableOrUnknown(data['channel']!, _channelMeta));
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
          _thumbnailUrlMeta,
          thumbnailUrl.isAcceptableOrUnknown(
              data['thumbnail_url']!, _thumbnailUrlMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
          _lastPlayedAtMeta,
          lastPlayedAt.isAcceptableOrUnknown(
              data['last_played_at']!, _lastPlayedAtMeta));
    } else if (isInserting) {
      context.missing(_lastPlayedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  YoutubeHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return YoutubeHistoryRow(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      channel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url']),
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      lastPlayedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_played_at'])!,
    );
  }

  @override
  $YoutubeHistoryTable createAlias(String alias) {
    return $YoutubeHistoryTable(attachedDatabase, alias);
  }
}

class YoutubeHistoryRow extends DataClass
    implements Insertable<YoutubeHistoryRow> {
  final String videoId;
  final String title;
  final String channel;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int lastPlayedAt;
  const YoutubeHistoryRow(
      {required this.videoId,
      required this.title,
      required this.channel,
      this.thumbnailUrl,
      required this.durationSeconds,
      required this.lastPlayedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['channel'] = Variable<String>(channel);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['last_played_at'] = Variable<int>(lastPlayedAt);
    return map;
  }

  YoutubeHistoryCompanion toCompanion(bool nullToAbsent) {
    return YoutubeHistoryCompanion(
      videoId: Value(videoId),
      title: Value(title),
      channel: Value(channel),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationSeconds: Value(durationSeconds),
      lastPlayedAt: Value(lastPlayedAt),
    );
  }

  factory YoutubeHistoryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return YoutubeHistoryRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      channel: serializer.fromJson<String>(json['channel']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      lastPlayedAt: serializer.fromJson<int>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'channel': serializer.toJson<String>(channel),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'lastPlayedAt': serializer.toJson<int>(lastPlayedAt),
    };
  }

  YoutubeHistoryRow copyWith(
          {String? videoId,
          String? title,
          String? channel,
          Value<String?> thumbnailUrl = const Value.absent(),
          int? durationSeconds,
          int? lastPlayedAt}) =>
      YoutubeHistoryRow(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        channel: channel ?? this.channel,
        thumbnailUrl:
            thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      );
  YoutubeHistoryRow copyWithCompanion(YoutubeHistoryCompanion data) {
    return YoutubeHistoryRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      channel: data.channel.present ? data.channel.value : this.channel,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('YoutubeHistoryRow(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('channel: $channel, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      videoId, title, channel, thumbnailUrl, durationSeconds, lastPlayedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is YoutubeHistoryRow &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.channel == this.channel &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationSeconds == this.durationSeconds &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class YoutubeHistoryCompanion extends UpdateCompanion<YoutubeHistoryRow> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> channel;
  final Value<String?> thumbnailUrl;
  final Value<int> durationSeconds;
  final Value<int> lastPlayedAt;
  final Value<int> rowid;
  const YoutubeHistoryCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.channel = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  YoutubeHistoryCompanion.insert({
    required String videoId,
    required String title,
    required String channel,
    this.thumbnailUrl = const Value.absent(),
    required int durationSeconds,
    required int lastPlayedAt,
    this.rowid = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        channel = Value(channel),
        durationSeconds = Value(durationSeconds),
        lastPlayedAt = Value(lastPlayedAt);
  static Insertable<YoutubeHistoryRow> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? channel,
    Expression<String>? thumbnailUrl,
    Expression<int>? durationSeconds,
    Expression<int>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (channel != null) 'channel': channel,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  YoutubeHistoryCompanion copyWith(
      {Value<String>? videoId,
      Value<String>? title,
      Value<String>? channel,
      Value<String?>? thumbnailUrl,
      Value<int>? durationSeconds,
      Value<int>? lastPlayedAt,
      Value<int>? rowid}) {
    return YoutubeHistoryCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      channel: channel ?? this.channel,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('YoutubeHistoryCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('channel: $channel, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
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
  late final $SearchEventsTable searchEvents = $SearchEventsTable(this);
  late final $PlayEventsTable playEvents = $PlayEventsTable(this);
  late final $ImpressionsTable impressions = $ImpressionsTable(this);
  late final $TasteProfilesTable tasteProfiles = $TasteProfilesTable(this);
  late final $CooccurrencesTable cooccurrences = $CooccurrencesTable(this);
  late final $QueryCompletionsTable queryCompletions =
      $QueryCompletionsTable(this);
  late final $BanditStatesTable banditStates = $BanditStatesTable(this);
  late final $ArtistSnoozesTable artistSnoozes = $ArtistSnoozesTable(this);
  late final $InterleaveOutcomesTable interleaveOutcomes =
      $InterleaveOutcomesTable(this);
  late final $TrackEmbeddingsTable trackEmbeddings =
      $TrackEmbeddingsTable(this);
  late final $YoutubeHistoryTable youtubeHistory = $YoutubeHistoryTable(this);
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
        pipedInstances,
        searchEvents,
        playEvents,
        impressions,
        tasteProfiles,
        cooccurrences,
        queryCompletions,
        banditStates,
        artistSnoozes,
        interleaveOutcomes,
        trackEmbeddings,
        youtubeHistory
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
typedef $$SearchEventsTableCreateCompanionBuilder = SearchEventsCompanion
    Function({
  Value<int> id,
  required int ts,
  required String query,
  required String resultIdsJson,
  required int shownCount,
  Value<String?> clickedId,
  Value<int?> clickedPosition,
  Value<int?> msToClick,
  required String rankerVersion,
});
typedef $$SearchEventsTableUpdateCompanionBuilder = SearchEventsCompanion
    Function({
  Value<int> id,
  Value<int> ts,
  Value<String> query,
  Value<String> resultIdsJson,
  Value<int> shownCount,
  Value<String?> clickedId,
  Value<int?> clickedPosition,
  Value<int?> msToClick,
  Value<String> rankerVersion,
});

class $$SearchEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchEventsTable> {
  $$SearchEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultIdsJson => $composableBuilder(
      column: $table.resultIdsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get shownCount => $composableBuilder(
      column: $table.shownCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clickedId => $composableBuilder(
      column: $table.clickedId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get clickedPosition => $composableBuilder(
      column: $table.clickedPosition,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get msToClick => $composableBuilder(
      column: $table.msToClick, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rankerVersion => $composableBuilder(
      column: $table.rankerVersion, builder: (column) => ColumnFilters(column));
}

class $$SearchEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchEventsTable> {
  $$SearchEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultIdsJson => $composableBuilder(
      column: $table.resultIdsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get shownCount => $composableBuilder(
      column: $table.shownCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clickedId => $composableBuilder(
      column: $table.clickedId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get clickedPosition => $composableBuilder(
      column: $table.clickedPosition,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get msToClick => $composableBuilder(
      column: $table.msToClick, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rankerVersion => $composableBuilder(
      column: $table.rankerVersion,
      builder: (column) => ColumnOrderings(column));
}

class $$SearchEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchEventsTable> {
  $$SearchEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get resultIdsJson => $composableBuilder(
      column: $table.resultIdsJson, builder: (column) => column);

  GeneratedColumn<int> get shownCount => $composableBuilder(
      column: $table.shownCount, builder: (column) => column);

  GeneratedColumn<String> get clickedId =>
      $composableBuilder(column: $table.clickedId, builder: (column) => column);

  GeneratedColumn<int> get clickedPosition => $composableBuilder(
      column: $table.clickedPosition, builder: (column) => column);

  GeneratedColumn<int> get msToClick =>
      $composableBuilder(column: $table.msToClick, builder: (column) => column);

  GeneratedColumn<String> get rankerVersion => $composableBuilder(
      column: $table.rankerVersion, builder: (column) => column);
}

class $$SearchEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SearchEventsTable,
    SearchEventRow,
    $$SearchEventsTableFilterComposer,
    $$SearchEventsTableOrderingComposer,
    $$SearchEventsTableAnnotationComposer,
    $$SearchEventsTableCreateCompanionBuilder,
    $$SearchEventsTableUpdateCompanionBuilder,
    (
      SearchEventRow,
      BaseReferences<_$AppDatabase, $SearchEventsTable, SearchEventRow>
    ),
    SearchEventRow,
    PrefetchHooks Function()> {
  $$SearchEventsTableTableManager(_$AppDatabase db, $SearchEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<String> query = const Value.absent(),
            Value<String> resultIdsJson = const Value.absent(),
            Value<int> shownCount = const Value.absent(),
            Value<String?> clickedId = const Value.absent(),
            Value<int?> clickedPosition = const Value.absent(),
            Value<int?> msToClick = const Value.absent(),
            Value<String> rankerVersion = const Value.absent(),
          }) =>
              SearchEventsCompanion(
            id: id,
            ts: ts,
            query: query,
            resultIdsJson: resultIdsJson,
            shownCount: shownCount,
            clickedId: clickedId,
            clickedPosition: clickedPosition,
            msToClick: msToClick,
            rankerVersion: rankerVersion,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ts,
            required String query,
            required String resultIdsJson,
            required int shownCount,
            Value<String?> clickedId = const Value.absent(),
            Value<int?> clickedPosition = const Value.absent(),
            Value<int?> msToClick = const Value.absent(),
            required String rankerVersion,
          }) =>
              SearchEventsCompanion.insert(
            id: id,
            ts: ts,
            query: query,
            resultIdsJson: resultIdsJson,
            shownCount: shownCount,
            clickedId: clickedId,
            clickedPosition: clickedPosition,
            msToClick: msToClick,
            rankerVersion: rankerVersion,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SearchEventsTable, SearchEventRow>(table),
                    BaseReferences<_$AppDatabase, $SearchEventsTable,
                        SearchEventRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SearchEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SearchEventsTable,
    SearchEventRow,
    $$SearchEventsTableFilterComposer,
    $$SearchEventsTableOrderingComposer,
    $$SearchEventsTableAnnotationComposer,
    $$SearchEventsTableCreateCompanionBuilder,
    $$SearchEventsTableUpdateCompanionBuilder,
    (
      SearchEventRow,
      BaseReferences<_$AppDatabase, $SearchEventsTable, SearchEventRow>
    ),
    SearchEventRow,
    PrefetchHooks Function()>;
typedef $$PlayEventsTableCreateCompanionBuilder = PlayEventsCompanion Function({
  Value<int> id,
  required int ts,
  required String trackId,
  required String source,
  required int listenedMs,
  required int durationMs,
  required bool skippedEarly,
  required bool saved,
  required bool addedToPlaylist,
  required String rankerVersion,
  Value<String?> featuresJson,
});
typedef $$PlayEventsTableUpdateCompanionBuilder = PlayEventsCompanion Function({
  Value<int> id,
  Value<int> ts,
  Value<String> trackId,
  Value<String> source,
  Value<int> listenedMs,
  Value<int> durationMs,
  Value<bool> skippedEarly,
  Value<bool> saved,
  Value<bool> addedToPlaylist,
  Value<String> rankerVersion,
  Value<String?> featuresJson,
});

class $$PlayEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PlayEventsTable> {
  $$PlayEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trackId => $composableBuilder(
      column: $table.trackId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get listenedMs => $composableBuilder(
      column: $table.listenedMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get skippedEarly => $composableBuilder(
      column: $table.skippedEarly, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get saved => $composableBuilder(
      column: $table.saved, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get addedToPlaylist => $composableBuilder(
      column: $table.addedToPlaylist,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rankerVersion => $composableBuilder(
      column: $table.rankerVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get featuresJson => $composableBuilder(
      column: $table.featuresJson, builder: (column) => ColumnFilters(column));
}

class $$PlayEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayEventsTable> {
  $$PlayEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trackId => $composableBuilder(
      column: $table.trackId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get listenedMs => $composableBuilder(
      column: $table.listenedMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get skippedEarly => $composableBuilder(
      column: $table.skippedEarly,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get saved => $composableBuilder(
      column: $table.saved, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get addedToPlaylist => $composableBuilder(
      column: $table.addedToPlaylist,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rankerVersion => $composableBuilder(
      column: $table.rankerVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get featuresJson => $composableBuilder(
      column: $table.featuresJson,
      builder: (column) => ColumnOrderings(column));
}

class $$PlayEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayEventsTable> {
  $$PlayEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get listenedMs => $composableBuilder(
      column: $table.listenedMs, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<bool> get skippedEarly => $composableBuilder(
      column: $table.skippedEarly, builder: (column) => column);

  GeneratedColumn<bool> get saved =>
      $composableBuilder(column: $table.saved, builder: (column) => column);

  GeneratedColumn<bool> get addedToPlaylist => $composableBuilder(
      column: $table.addedToPlaylist, builder: (column) => column);

  GeneratedColumn<String> get rankerVersion => $composableBuilder(
      column: $table.rankerVersion, builder: (column) => column);

  GeneratedColumn<String> get featuresJson => $composableBuilder(
      column: $table.featuresJson, builder: (column) => column);
}

class $$PlayEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlayEventsTable,
    PlayEventRow,
    $$PlayEventsTableFilterComposer,
    $$PlayEventsTableOrderingComposer,
    $$PlayEventsTableAnnotationComposer,
    $$PlayEventsTableCreateCompanionBuilder,
    $$PlayEventsTableUpdateCompanionBuilder,
    (
      PlayEventRow,
      BaseReferences<_$AppDatabase, $PlayEventsTable, PlayEventRow>
    ),
    PlayEventRow,
    PrefetchHooks Function()> {
  $$PlayEventsTableTableManager(_$AppDatabase db, $PlayEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<String> trackId = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> listenedMs = const Value.absent(),
            Value<int> durationMs = const Value.absent(),
            Value<bool> skippedEarly = const Value.absent(),
            Value<bool> saved = const Value.absent(),
            Value<bool> addedToPlaylist = const Value.absent(),
            Value<String> rankerVersion = const Value.absent(),
            Value<String?> featuresJson = const Value.absent(),
          }) =>
              PlayEventsCompanion(
            id: id,
            ts: ts,
            trackId: trackId,
            source: source,
            listenedMs: listenedMs,
            durationMs: durationMs,
            skippedEarly: skippedEarly,
            saved: saved,
            addedToPlaylist: addedToPlaylist,
            rankerVersion: rankerVersion,
            featuresJson: featuresJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ts,
            required String trackId,
            required String source,
            required int listenedMs,
            required int durationMs,
            required bool skippedEarly,
            required bool saved,
            required bool addedToPlaylist,
            required String rankerVersion,
            Value<String?> featuresJson = const Value.absent(),
          }) =>
              PlayEventsCompanion.insert(
            id: id,
            ts: ts,
            trackId: trackId,
            source: source,
            listenedMs: listenedMs,
            durationMs: durationMs,
            skippedEarly: skippedEarly,
            saved: saved,
            addedToPlaylist: addedToPlaylist,
            rankerVersion: rankerVersion,
            featuresJson: featuresJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PlayEventsTable, PlayEventRow>(table),
                    BaseReferences<_$AppDatabase, $PlayEventsTable,
                        PlayEventRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlayEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlayEventsTable,
    PlayEventRow,
    $$PlayEventsTableFilterComposer,
    $$PlayEventsTableOrderingComposer,
    $$PlayEventsTableAnnotationComposer,
    $$PlayEventsTableCreateCompanionBuilder,
    $$PlayEventsTableUpdateCompanionBuilder,
    (
      PlayEventRow,
      BaseReferences<_$AppDatabase, $PlayEventsTable, PlayEventRow>
    ),
    PlayEventRow,
    PrefetchHooks Function()>;
typedef $$ImpressionsTableCreateCompanionBuilder = ImpressionsCompanion
    Function({
  Value<int> id,
  required int ts,
  required String surface,
  required String itemId,
  required int position,
});
typedef $$ImpressionsTableUpdateCompanionBuilder = ImpressionsCompanion
    Function({
  Value<int> id,
  Value<int> ts,
  Value<String> surface,
  Value<String> itemId,
  Value<int> position,
});

class $$ImpressionsTableFilterComposer
    extends Composer<_$AppDatabase, $ImpressionsTable> {
  $$ImpressionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get surface => $composableBuilder(
      column: $table.surface, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));
}

class $$ImpressionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImpressionsTable> {
  $$ImpressionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get surface => $composableBuilder(
      column: $table.surface, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));
}

class $$ImpressionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImpressionsTable> {
  $$ImpressionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get surface =>
      $composableBuilder(column: $table.surface, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$ImpressionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ImpressionsTable,
    ImpressionRow,
    $$ImpressionsTableFilterComposer,
    $$ImpressionsTableOrderingComposer,
    $$ImpressionsTableAnnotationComposer,
    $$ImpressionsTableCreateCompanionBuilder,
    $$ImpressionsTableUpdateCompanionBuilder,
    (
      ImpressionRow,
      BaseReferences<_$AppDatabase, $ImpressionsTable, ImpressionRow>
    ),
    ImpressionRow,
    PrefetchHooks Function()> {
  $$ImpressionsTableTableManager(_$AppDatabase db, $ImpressionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImpressionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImpressionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImpressionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> ts = const Value.absent(),
            Value<String> surface = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> position = const Value.absent(),
          }) =>
              ImpressionsCompanion(
            id: id,
            ts: ts,
            surface: surface,
            itemId: itemId,
            position: position,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int ts,
            required String surface,
            required String itemId,
            required int position,
          }) =>
              ImpressionsCompanion.insert(
            id: id,
            ts: ts,
            surface: surface,
            itemId: itemId,
            position: position,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ImpressionsTable, ImpressionRow>(table),
                    BaseReferences<_$AppDatabase, $ImpressionsTable,
                        ImpressionRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ImpressionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ImpressionsTable,
    ImpressionRow,
    $$ImpressionsTableFilterComposer,
    $$ImpressionsTableOrderingComposer,
    $$ImpressionsTableAnnotationComposer,
    $$ImpressionsTableCreateCompanionBuilder,
    $$ImpressionsTableUpdateCompanionBuilder,
    (
      ImpressionRow,
      BaseReferences<_$AppDatabase, $ImpressionsTable, ImpressionRow>
    ),
    ImpressionRow,
    PrefetchHooks Function()>;
typedef $$TasteProfilesTableCreateCompanionBuilder = TasteProfilesCompanion
    Function({
  Value<int> id,
  required String entityType,
  required String entityId,
  Value<double> slowWeight,
  Value<double> fastWeight,
  required int updatedAt,
});
typedef $$TasteProfilesTableUpdateCompanionBuilder = TasteProfilesCompanion
    Function({
  Value<int> id,
  Value<String> entityType,
  Value<String> entityId,
  Value<double> slowWeight,
  Value<double> fastWeight,
  Value<int> updatedAt,
});

class $$TasteProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $TasteProfilesTable> {
  $$TasteProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get slowWeight => $composableBuilder(
      column: $table.slowWeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fastWeight => $composableBuilder(
      column: $table.fastWeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TasteProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $TasteProfilesTable> {
  $$TasteProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get slowWeight => $composableBuilder(
      column: $table.slowWeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fastWeight => $composableBuilder(
      column: $table.fastWeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TasteProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasteProfilesTable> {
  $$TasteProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<double> get slowWeight => $composableBuilder(
      column: $table.slowWeight, builder: (column) => column);

  GeneratedColumn<double> get fastWeight => $composableBuilder(
      column: $table.fastWeight, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TasteProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TasteProfilesTable,
    TasteProfileRow,
    $$TasteProfilesTableFilterComposer,
    $$TasteProfilesTableOrderingComposer,
    $$TasteProfilesTableAnnotationComposer,
    $$TasteProfilesTableCreateCompanionBuilder,
    $$TasteProfilesTableUpdateCompanionBuilder,
    (
      TasteProfileRow,
      BaseReferences<_$AppDatabase, $TasteProfilesTable, TasteProfileRow>
    ),
    TasteProfileRow,
    PrefetchHooks Function()> {
  $$TasteProfilesTableTableManager(_$AppDatabase db, $TasteProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasteProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasteProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasteProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<double> slowWeight = const Value.absent(),
            Value<double> fastWeight = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
          }) =>
              TasteProfilesCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            slowWeight: slowWeight,
            fastWeight: fastWeight,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityType,
            required String entityId,
            Value<double> slowWeight = const Value.absent(),
            Value<double> fastWeight = const Value.absent(),
            required int updatedAt,
          }) =>
              TasteProfilesCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            slowWeight: slowWeight,
            fastWeight: fastWeight,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TasteProfilesTable, TasteProfileRow>(table),
                    BaseReferences<_$AppDatabase, $TasteProfilesTable,
                        TasteProfileRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TasteProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TasteProfilesTable,
    TasteProfileRow,
    $$TasteProfilesTableFilterComposer,
    $$TasteProfilesTableOrderingComposer,
    $$TasteProfilesTableAnnotationComposer,
    $$TasteProfilesTableCreateCompanionBuilder,
    $$TasteProfilesTableUpdateCompanionBuilder,
    (
      TasteProfileRow,
      BaseReferences<_$AppDatabase, $TasteProfilesTable, TasteProfileRow>
    ),
    TasteProfileRow,
    PrefetchHooks Function()>;
typedef $$CooccurrencesTableCreateCompanionBuilder = CooccurrencesCompanion
    Function({
  required String trackA,
  required String trackB,
  required double score,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$CooccurrencesTableUpdateCompanionBuilder = CooccurrencesCompanion
    Function({
  Value<String> trackA,
  Value<String> trackB,
  Value<double> score,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$CooccurrencesTableFilterComposer
    extends Composer<_$AppDatabase, $CooccurrencesTable> {
  $$CooccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackA => $composableBuilder(
      column: $table.trackA, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trackB => $composableBuilder(
      column: $table.trackB, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CooccurrencesTableOrderingComposer
    extends Composer<_$AppDatabase, $CooccurrencesTable> {
  $$CooccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackA => $composableBuilder(
      column: $table.trackA, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trackB => $composableBuilder(
      column: $table.trackB, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CooccurrencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CooccurrencesTable> {
  $$CooccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackA =>
      $composableBuilder(column: $table.trackA, builder: (column) => column);

  GeneratedColumn<String> get trackB =>
      $composableBuilder(column: $table.trackB, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CooccurrencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CooccurrencesTable,
    CooccurrenceRow,
    $$CooccurrencesTableFilterComposer,
    $$CooccurrencesTableOrderingComposer,
    $$CooccurrencesTableAnnotationComposer,
    $$CooccurrencesTableCreateCompanionBuilder,
    $$CooccurrencesTableUpdateCompanionBuilder,
    (
      CooccurrenceRow,
      BaseReferences<_$AppDatabase, $CooccurrencesTable, CooccurrenceRow>
    ),
    CooccurrenceRow,
    PrefetchHooks Function()> {
  $$CooccurrencesTableTableManager(_$AppDatabase db, $CooccurrencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CooccurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CooccurrencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CooccurrencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackA = const Value.absent(),
            Value<String> trackB = const Value.absent(),
            Value<double> score = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CooccurrencesCompanion(
            trackA: trackA,
            trackB: trackB,
            score: score,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackA,
            required String trackB,
            required double score,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CooccurrencesCompanion.insert(
            trackA: trackA,
            trackB: trackB,
            score: score,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CooccurrencesTable, CooccurrenceRow>(table),
                    BaseReferences<_$AppDatabase, $CooccurrencesTable,
                        CooccurrenceRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CooccurrencesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CooccurrencesTable,
    CooccurrenceRow,
    $$CooccurrencesTableFilterComposer,
    $$CooccurrencesTableOrderingComposer,
    $$CooccurrencesTableAnnotationComposer,
    $$CooccurrencesTableCreateCompanionBuilder,
    $$CooccurrencesTableUpdateCompanionBuilder,
    (
      CooccurrenceRow,
      BaseReferences<_$AppDatabase, $CooccurrencesTable, CooccurrenceRow>
    ),
    CooccurrenceRow,
    PrefetchHooks Function()>;
typedef $$QueryCompletionsTableCreateCompanionBuilder
    = QueryCompletionsCompanion Function({
  required String query,
  required String normalizedPrefix,
  Value<int> streamCount,
  required int lastUsedTs,
  Value<int> rowid,
});
typedef $$QueryCompletionsTableUpdateCompanionBuilder
    = QueryCompletionsCompanion Function({
  Value<String> query,
  Value<String> normalizedPrefix,
  Value<int> streamCount,
  Value<int> lastUsedTs,
  Value<int> rowid,
});

class $$QueryCompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $QueryCompletionsTable> {
  $$QueryCompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedPrefix => $composableBuilder(
      column: $table.normalizedPrefix,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get streamCount => $composableBuilder(
      column: $table.streamCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastUsedTs => $composableBuilder(
      column: $table.lastUsedTs, builder: (column) => ColumnFilters(column));
}

class $$QueryCompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QueryCompletionsTable> {
  $$QueryCompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
      column: $table.query, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedPrefix => $composableBuilder(
      column: $table.normalizedPrefix,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get streamCount => $composableBuilder(
      column: $table.streamCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastUsedTs => $composableBuilder(
      column: $table.lastUsedTs, builder: (column) => ColumnOrderings(column));
}

class $$QueryCompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueryCompletionsTable> {
  $$QueryCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get normalizedPrefix => $composableBuilder(
      column: $table.normalizedPrefix, builder: (column) => column);

  GeneratedColumn<int> get streamCount => $composableBuilder(
      column: $table.streamCount, builder: (column) => column);

  GeneratedColumn<int> get lastUsedTs => $composableBuilder(
      column: $table.lastUsedTs, builder: (column) => column);
}

class $$QueryCompletionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QueryCompletionsTable,
    QueryCompletionRow,
    $$QueryCompletionsTableFilterComposer,
    $$QueryCompletionsTableOrderingComposer,
    $$QueryCompletionsTableAnnotationComposer,
    $$QueryCompletionsTableCreateCompanionBuilder,
    $$QueryCompletionsTableUpdateCompanionBuilder,
    (
      QueryCompletionRow,
      BaseReferences<_$AppDatabase, $QueryCompletionsTable, QueryCompletionRow>
    ),
    QueryCompletionRow,
    PrefetchHooks Function()> {
  $$QueryCompletionsTableTableManager(
      _$AppDatabase db, $QueryCompletionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueryCompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueryCompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueryCompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> query = const Value.absent(),
            Value<String> normalizedPrefix = const Value.absent(),
            Value<int> streamCount = const Value.absent(),
            Value<int> lastUsedTs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QueryCompletionsCompanion(
            query: query,
            normalizedPrefix: normalizedPrefix,
            streamCount: streamCount,
            lastUsedTs: lastUsedTs,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String query,
            required String normalizedPrefix,
            Value<int> streamCount = const Value.absent(),
            required int lastUsedTs,
            Value<int> rowid = const Value.absent(),
          }) =>
              QueryCompletionsCompanion.insert(
            query: query,
            normalizedPrefix: normalizedPrefix,
            streamCount: streamCount,
            lastUsedTs: lastUsedTs,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$QueryCompletionsTable, QueryCompletionRow>(
                        table),
                    BaseReferences<_$AppDatabase, $QueryCompletionsTable,
                        QueryCompletionRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QueryCompletionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QueryCompletionsTable,
    QueryCompletionRow,
    $$QueryCompletionsTableFilterComposer,
    $$QueryCompletionsTableOrderingComposer,
    $$QueryCompletionsTableAnnotationComposer,
    $$QueryCompletionsTableCreateCompanionBuilder,
    $$QueryCompletionsTableUpdateCompanionBuilder,
    (
      QueryCompletionRow,
      BaseReferences<_$AppDatabase, $QueryCompletionsTable, QueryCompletionRow>
    ),
    QueryCompletionRow,
    PrefetchHooks Function()>;
typedef $$BanditStatesTableCreateCompanionBuilder = BanditStatesCompanion
    Function({
  required String shelfId,
  Value<double> epsilon,
  Value<int> pullCount,
  Value<double> cumulativeReward,
  Value<double> currentNoveltyRatio,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$BanditStatesTableUpdateCompanionBuilder = BanditStatesCompanion
    Function({
  Value<String> shelfId,
  Value<double> epsilon,
  Value<int> pullCount,
  Value<double> cumulativeReward,
  Value<double> currentNoveltyRatio,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$BanditStatesTableFilterComposer
    extends Composer<_$AppDatabase, $BanditStatesTable> {
  $$BanditStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get shelfId => $composableBuilder(
      column: $table.shelfId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get epsilon => $composableBuilder(
      column: $table.epsilon, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pullCount => $composableBuilder(
      column: $table.pullCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get cumulativeReward => $composableBuilder(
      column: $table.cumulativeReward,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get currentNoveltyRatio => $composableBuilder(
      column: $table.currentNoveltyRatio,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$BanditStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $BanditStatesTable> {
  $$BanditStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get shelfId => $composableBuilder(
      column: $table.shelfId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get epsilon => $composableBuilder(
      column: $table.epsilon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pullCount => $composableBuilder(
      column: $table.pullCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cumulativeReward => $composableBuilder(
      column: $table.cumulativeReward,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get currentNoveltyRatio => $composableBuilder(
      column: $table.currentNoveltyRatio,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$BanditStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BanditStatesTable> {
  $$BanditStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get shelfId =>
      $composableBuilder(column: $table.shelfId, builder: (column) => column);

  GeneratedColumn<double> get epsilon =>
      $composableBuilder(column: $table.epsilon, builder: (column) => column);

  GeneratedColumn<int> get pullCount =>
      $composableBuilder(column: $table.pullCount, builder: (column) => column);

  GeneratedColumn<double> get cumulativeReward => $composableBuilder(
      column: $table.cumulativeReward, builder: (column) => column);

  GeneratedColumn<double> get currentNoveltyRatio => $composableBuilder(
      column: $table.currentNoveltyRatio, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BanditStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BanditStatesTable,
    BanditStateRow,
    $$BanditStatesTableFilterComposer,
    $$BanditStatesTableOrderingComposer,
    $$BanditStatesTableAnnotationComposer,
    $$BanditStatesTableCreateCompanionBuilder,
    $$BanditStatesTableUpdateCompanionBuilder,
    (
      BanditStateRow,
      BaseReferences<_$AppDatabase, $BanditStatesTable, BanditStateRow>
    ),
    BanditStateRow,
    PrefetchHooks Function()> {
  $$BanditStatesTableTableManager(_$AppDatabase db, $BanditStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BanditStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BanditStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BanditStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> shelfId = const Value.absent(),
            Value<double> epsilon = const Value.absent(),
            Value<int> pullCount = const Value.absent(),
            Value<double> cumulativeReward = const Value.absent(),
            Value<double> currentNoveltyRatio = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BanditStatesCompanion(
            shelfId: shelfId,
            epsilon: epsilon,
            pullCount: pullCount,
            cumulativeReward: cumulativeReward,
            currentNoveltyRatio: currentNoveltyRatio,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String shelfId,
            Value<double> epsilon = const Value.absent(),
            Value<int> pullCount = const Value.absent(),
            Value<double> cumulativeReward = const Value.absent(),
            Value<double> currentNoveltyRatio = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BanditStatesCompanion.insert(
            shelfId: shelfId,
            epsilon: epsilon,
            pullCount: pullCount,
            cumulativeReward: cumulativeReward,
            currentNoveltyRatio: currentNoveltyRatio,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$BanditStatesTable, BanditStateRow>(table),
                    BaseReferences<_$AppDatabase, $BanditStatesTable,
                        BanditStateRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BanditStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BanditStatesTable,
    BanditStateRow,
    $$BanditStatesTableFilterComposer,
    $$BanditStatesTableOrderingComposer,
    $$BanditStatesTableAnnotationComposer,
    $$BanditStatesTableCreateCompanionBuilder,
    $$BanditStatesTableUpdateCompanionBuilder,
    (
      BanditStateRow,
      BaseReferences<_$AppDatabase, $BanditStatesTable, BanditStateRow>
    ),
    BanditStateRow,
    PrefetchHooks Function()>;
typedef $$ArtistSnoozesTableCreateCompanionBuilder = ArtistSnoozesCompanion
    Function({
  required String artistId,
  required int snoozedUntil,
  Value<int> rowid,
});
typedef $$ArtistSnoozesTableUpdateCompanionBuilder = ArtistSnoozesCompanion
    Function({
  Value<String> artistId,
  Value<int> snoozedUntil,
  Value<int> rowid,
});

class $$ArtistSnoozesTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistSnoozesTable> {
  $$ArtistSnoozesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get snoozedUntil => $composableBuilder(
      column: $table.snoozedUntil, builder: (column) => ColumnFilters(column));
}

class $$ArtistSnoozesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistSnoozesTable> {
  $$ArtistSnoozesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get snoozedUntil => $composableBuilder(
      column: $table.snoozedUntil,
      builder: (column) => ColumnOrderings(column));
}

class $$ArtistSnoozesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistSnoozesTable> {
  $$ArtistSnoozesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<int> get snoozedUntil => $composableBuilder(
      column: $table.snoozedUntil, builder: (column) => column);
}

class $$ArtistSnoozesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ArtistSnoozesTable,
    ArtistSnoozeRow,
    $$ArtistSnoozesTableFilterComposer,
    $$ArtistSnoozesTableOrderingComposer,
    $$ArtistSnoozesTableAnnotationComposer,
    $$ArtistSnoozesTableCreateCompanionBuilder,
    $$ArtistSnoozesTableUpdateCompanionBuilder,
    (
      ArtistSnoozeRow,
      BaseReferences<_$AppDatabase, $ArtistSnoozesTable, ArtistSnoozeRow>
    ),
    ArtistSnoozeRow,
    PrefetchHooks Function()> {
  $$ArtistSnoozesTableTableManager(_$AppDatabase db, $ArtistSnoozesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistSnoozesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistSnoozesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistSnoozesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> artistId = const Value.absent(),
            Value<int> snoozedUntil = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ArtistSnoozesCompanion(
            artistId: artistId,
            snoozedUntil: snoozedUntil,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String artistId,
            required int snoozedUntil,
            Value<int> rowid = const Value.absent(),
          }) =>
              ArtistSnoozesCompanion.insert(
            artistId: artistId,
            snoozedUntil: snoozedUntil,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ArtistSnoozesTable, ArtistSnoozeRow>(table),
                    BaseReferences<_$AppDatabase, $ArtistSnoozesTable,
                        ArtistSnoozeRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ArtistSnoozesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ArtistSnoozesTable,
    ArtistSnoozeRow,
    $$ArtistSnoozesTableFilterComposer,
    $$ArtistSnoozesTableOrderingComposer,
    $$ArtistSnoozesTableAnnotationComposer,
    $$ArtistSnoozesTableCreateCompanionBuilder,
    $$ArtistSnoozesTableUpdateCompanionBuilder,
    (
      ArtistSnoozeRow,
      BaseReferences<_$AppDatabase, $ArtistSnoozesTable, ArtistSnoozeRow>
    ),
    ArtistSnoozeRow,
    PrefetchHooks Function()>;
typedef $$InterleaveOutcomesTableCreateCompanionBuilder
    = InterleaveOutcomesCompanion Function({
  Value<int> id,
  required String queryOrContext,
  required String modelAId,
  required String modelBId,
  Value<String?> winningModelId,
  required int ts,
});
typedef $$InterleaveOutcomesTableUpdateCompanionBuilder
    = InterleaveOutcomesCompanion Function({
  Value<int> id,
  Value<String> queryOrContext,
  Value<String> modelAId,
  Value<String> modelBId,
  Value<String?> winningModelId,
  Value<int> ts,
});

class $$InterleaveOutcomesTableFilterComposer
    extends Composer<_$AppDatabase, $InterleaveOutcomesTable> {
  $$InterleaveOutcomesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get queryOrContext => $composableBuilder(
      column: $table.queryOrContext,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modelAId => $composableBuilder(
      column: $table.modelAId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modelBId => $composableBuilder(
      column: $table.modelBId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get winningModelId => $composableBuilder(
      column: $table.winningModelId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));
}

class $$InterleaveOutcomesTableOrderingComposer
    extends Composer<_$AppDatabase, $InterleaveOutcomesTable> {
  $$InterleaveOutcomesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get queryOrContext => $composableBuilder(
      column: $table.queryOrContext,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modelAId => $composableBuilder(
      column: $table.modelAId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modelBId => $composableBuilder(
      column: $table.modelBId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get winningModelId => $composableBuilder(
      column: $table.winningModelId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));
}

class $$InterleaveOutcomesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InterleaveOutcomesTable> {
  $$InterleaveOutcomesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get queryOrContext => $composableBuilder(
      column: $table.queryOrContext, builder: (column) => column);

  GeneratedColumn<String> get modelAId =>
      $composableBuilder(column: $table.modelAId, builder: (column) => column);

  GeneratedColumn<String> get modelBId =>
      $composableBuilder(column: $table.modelBId, builder: (column) => column);

  GeneratedColumn<String> get winningModelId => $composableBuilder(
      column: $table.winningModelId, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);
}

class $$InterleaveOutcomesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InterleaveOutcomesTable,
    InterleaveOutcomeRow,
    $$InterleaveOutcomesTableFilterComposer,
    $$InterleaveOutcomesTableOrderingComposer,
    $$InterleaveOutcomesTableAnnotationComposer,
    $$InterleaveOutcomesTableCreateCompanionBuilder,
    $$InterleaveOutcomesTableUpdateCompanionBuilder,
    (
      InterleaveOutcomeRow,
      BaseReferences<_$AppDatabase, $InterleaveOutcomesTable,
          InterleaveOutcomeRow>
    ),
    InterleaveOutcomeRow,
    PrefetchHooks Function()> {
  $$InterleaveOutcomesTableTableManager(
      _$AppDatabase db, $InterleaveOutcomesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InterleaveOutcomesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InterleaveOutcomesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InterleaveOutcomesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> queryOrContext = const Value.absent(),
            Value<String> modelAId = const Value.absent(),
            Value<String> modelBId = const Value.absent(),
            Value<String?> winningModelId = const Value.absent(),
            Value<int> ts = const Value.absent(),
          }) =>
              InterleaveOutcomesCompanion(
            id: id,
            queryOrContext: queryOrContext,
            modelAId: modelAId,
            modelBId: modelBId,
            winningModelId: winningModelId,
            ts: ts,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String queryOrContext,
            required String modelAId,
            required String modelBId,
            Value<String?> winningModelId = const Value.absent(),
            required int ts,
          }) =>
              InterleaveOutcomesCompanion.insert(
            id: id,
            queryOrContext: queryOrContext,
            modelAId: modelAId,
            modelBId: modelBId,
            winningModelId: winningModelId,
            ts: ts,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$InterleaveOutcomesTable, InterleaveOutcomeRow>(
                        table),
                    BaseReferences<_$AppDatabase, $InterleaveOutcomesTable,
                        InterleaveOutcomeRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InterleaveOutcomesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InterleaveOutcomesTable,
    InterleaveOutcomeRow,
    $$InterleaveOutcomesTableFilterComposer,
    $$InterleaveOutcomesTableOrderingComposer,
    $$InterleaveOutcomesTableAnnotationComposer,
    $$InterleaveOutcomesTableCreateCompanionBuilder,
    $$InterleaveOutcomesTableUpdateCompanionBuilder,
    (
      InterleaveOutcomeRow,
      BaseReferences<_$AppDatabase, $InterleaveOutcomesTable,
          InterleaveOutcomeRow>
    ),
    InterleaveOutcomeRow,
    PrefetchHooks Function()>;
typedef $$TrackEmbeddingsTableCreateCompanionBuilder = TrackEmbeddingsCompanion
    Function({
  required String trackId,
  required Uint8List vector,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$TrackEmbeddingsTableUpdateCompanionBuilder = TrackEmbeddingsCompanion
    Function({
  Value<String> trackId,
  Value<Uint8List> vector,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$TrackEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackEmbeddingsTable> {
  $$TrackEmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackId => $composableBuilder(
      column: $table.trackId, builder: (column) => ColumnFilters(column));

  ColumnFilters<Uint8List> get vector => $composableBuilder(
      column: $table.vector, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TrackEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackEmbeddingsTable> {
  $$TrackEmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackId => $composableBuilder(
      column: $table.trackId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get vector => $composableBuilder(
      column: $table.vector, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TrackEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackEmbeddingsTable> {
  $$TrackEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<Uint8List> get vector =>
      $composableBuilder(column: $table.vector, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TrackEmbeddingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrackEmbeddingsTable,
    TrackEmbeddingRow,
    $$TrackEmbeddingsTableFilterComposer,
    $$TrackEmbeddingsTableOrderingComposer,
    $$TrackEmbeddingsTableAnnotationComposer,
    $$TrackEmbeddingsTableCreateCompanionBuilder,
    $$TrackEmbeddingsTableUpdateCompanionBuilder,
    (
      TrackEmbeddingRow,
      BaseReferences<_$AppDatabase, $TrackEmbeddingsTable, TrackEmbeddingRow>
    ),
    TrackEmbeddingRow,
    PrefetchHooks Function()> {
  $$TrackEmbeddingsTableTableManager(
      _$AppDatabase db, $TrackEmbeddingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackEmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackEmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackEmbeddingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackId = const Value.absent(),
            Value<Uint8List> vector = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackEmbeddingsCompanion(
            trackId: trackId,
            vector: vector,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackId,
            required Uint8List vector,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackEmbeddingsCompanion.insert(
            trackId: trackId,
            vector: vector,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TrackEmbeddingsTable, TrackEmbeddingRow>(
                        table),
                    BaseReferences<_$AppDatabase, $TrackEmbeddingsTable,
                        TrackEmbeddingRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrackEmbeddingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TrackEmbeddingsTable,
    TrackEmbeddingRow,
    $$TrackEmbeddingsTableFilterComposer,
    $$TrackEmbeddingsTableOrderingComposer,
    $$TrackEmbeddingsTableAnnotationComposer,
    $$TrackEmbeddingsTableCreateCompanionBuilder,
    $$TrackEmbeddingsTableUpdateCompanionBuilder,
    (
      TrackEmbeddingRow,
      BaseReferences<_$AppDatabase, $TrackEmbeddingsTable, TrackEmbeddingRow>
    ),
    TrackEmbeddingRow,
    PrefetchHooks Function()>;
typedef $$YoutubeHistoryTableCreateCompanionBuilder = YoutubeHistoryCompanion
    Function({
  required String videoId,
  required String title,
  required String channel,
  Value<String?> thumbnailUrl,
  required int durationSeconds,
  required int lastPlayedAt,
  Value<int> rowid,
});
typedef $$YoutubeHistoryTableUpdateCompanionBuilder = YoutubeHistoryCompanion
    Function({
  Value<String> videoId,
  Value<String> title,
  Value<String> channel,
  Value<String?> thumbnailUrl,
  Value<int> durationSeconds,
  Value<int> lastPlayedAt,
  Value<int> rowid,
});

class $$YoutubeHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $YoutubeHistoryTable> {
  $$YoutubeHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => ColumnFilters(column));
}

class $$YoutubeHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $YoutubeHistoryTable> {
  $$YoutubeHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$YoutubeHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $YoutubeHistoryTable> {
  $$YoutubeHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
      column: $table.thumbnailUrl, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
      column: $table.lastPlayedAt, builder: (column) => column);
}

class $$YoutubeHistoryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $YoutubeHistoryTable,
    YoutubeHistoryRow,
    $$YoutubeHistoryTableFilterComposer,
    $$YoutubeHistoryTableOrderingComposer,
    $$YoutubeHistoryTableAnnotationComposer,
    $$YoutubeHistoryTableCreateCompanionBuilder,
    $$YoutubeHistoryTableUpdateCompanionBuilder,
    (
      YoutubeHistoryRow,
      BaseReferences<_$AppDatabase, $YoutubeHistoryTable, YoutubeHistoryRow>
    ),
    YoutubeHistoryRow,
    PrefetchHooks Function()> {
  $$YoutubeHistoryTableTableManager(
      _$AppDatabase db, $YoutubeHistoryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$YoutubeHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$YoutubeHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$YoutubeHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> videoId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> channel = const Value.absent(),
            Value<String?> thumbnailUrl = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<int> lastPlayedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              YoutubeHistoryCompanion(
            videoId: videoId,
            title: title,
            channel: channel,
            thumbnailUrl: thumbnailUrl,
            durationSeconds: durationSeconds,
            lastPlayedAt: lastPlayedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String videoId,
            required String title,
            required String channel,
            Value<String?> thumbnailUrl = const Value.absent(),
            required int durationSeconds,
            required int lastPlayedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              YoutubeHistoryCompanion.insert(
            videoId: videoId,
            title: title,
            channel: channel,
            thumbnailUrl: thumbnailUrl,
            durationSeconds: durationSeconds,
            lastPlayedAt: lastPlayedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$YoutubeHistoryTable, YoutubeHistoryRow>(table),
                    BaseReferences<_$AppDatabase, $YoutubeHistoryTable,
                        YoutubeHistoryRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$YoutubeHistoryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $YoutubeHistoryTable,
    YoutubeHistoryRow,
    $$YoutubeHistoryTableFilterComposer,
    $$YoutubeHistoryTableOrderingComposer,
    $$YoutubeHistoryTableAnnotationComposer,
    $$YoutubeHistoryTableCreateCompanionBuilder,
    $$YoutubeHistoryTableUpdateCompanionBuilder,
    (
      YoutubeHistoryRow,
      BaseReferences<_$AppDatabase, $YoutubeHistoryTable, YoutubeHistoryRow>
    ),
    YoutubeHistoryRow,
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
  $$SearchEventsTableTableManager get searchEvents =>
      $$SearchEventsTableTableManager(_db, _db.searchEvents);
  $$PlayEventsTableTableManager get playEvents =>
      $$PlayEventsTableTableManager(_db, _db.playEvents);
  $$ImpressionsTableTableManager get impressions =>
      $$ImpressionsTableTableManager(_db, _db.impressions);
  $$TasteProfilesTableTableManager get tasteProfiles =>
      $$TasteProfilesTableTableManager(_db, _db.tasteProfiles);
  $$CooccurrencesTableTableManager get cooccurrences =>
      $$CooccurrencesTableTableManager(_db, _db.cooccurrences);
  $$QueryCompletionsTableTableManager get queryCompletions =>
      $$QueryCompletionsTableTableManager(_db, _db.queryCompletions);
  $$BanditStatesTableTableManager get banditStates =>
      $$BanditStatesTableTableManager(_db, _db.banditStates);
  $$ArtistSnoozesTableTableManager get artistSnoozes =>
      $$ArtistSnoozesTableTableManager(_db, _db.artistSnoozes);
  $$InterleaveOutcomesTableTableManager get interleaveOutcomes =>
      $$InterleaveOutcomesTableTableManager(_db, _db.interleaveOutcomes);
  $$TrackEmbeddingsTableTableManager get trackEmbeddings =>
      $$TrackEmbeddingsTableTableManager(_db, _db.trackEmbeddings);
  $$YoutubeHistoryTableTableManager get youtubeHistory =>
      $$YoutubeHistoryTableTableManager(_db, _db.youtubeHistory);
}
