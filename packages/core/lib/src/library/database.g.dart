// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $WallpapersTable extends Wallpapers
    with TableInfo<$WallpapersTable, LibraryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WallpapersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePageUrlMeta = const VerificationMeta(
    'sourcePageUrl',
  );
  @override
  late final GeneratedColumn<String> sourcePageUrl = GeneratedColumn<String>(
    'source_page_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadUrlMeta = const VerificationMeta(
    'downloadUrl',
  );
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
    'download_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<WallpaperOrientation, String>
  orientation = GeneratedColumn<String>(
    'orientation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<WallpaperOrientation>($WallpapersTable.$converterorientation);
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorNameMeta = const VerificationMeta(
    'authorName',
  );
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
    'author_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorUrlMeta = const VerificationMeta(
    'authorUrl',
  );
  @override
  late final GeneratedColumn<String> authorUrl = GeneratedColumn<String>(
    'author_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licenceMeta = const VerificationMeta(
    'licence',
  );
  @override
  late final GeneratedColumn<String> licence = GeneratedColumn<String>(
    'licence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditLineMeta = const VerificationMeta(
    'creditLine',
  );
  @override
  late final GeneratedColumn<String> creditLine = GeneratedColumn<String>(
    'credit_line',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($WallpapersTable.$convertertags);
  static const VerificationMeta _dominantColourMeta = const VerificationMeta(
    'dominantColour',
  );
  @override
  late final GeneratedColumn<int> dominantColour = GeneratedColumn<int>(
    'dominant_colour',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAppliedAtMeta = const VerificationMeta(
    'lastAppliedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAppliedAt =
      GeneratedColumn<DateTime>(
        'last_applied_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _applyCountMeta = const VerificationMeta(
    'applyCount',
  );
  @override
  late final GeneratedColumn<int> applyCount = GeneratedColumn<int>(
    'apply_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFavouriteMeta = const VerificationMeta(
    'isFavourite',
  );
  @override
  late final GeneratedColumn<bool> isFavourite = GeneratedColumn<bool>(
    'is_favourite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favourite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    sourceId,
    sourcePageUrl,
    downloadUrl,
    relativePath,
    width,
    height,
    orientation,
    fileSize,
    sha256,
    title,
    authorName,
    authorUrl,
    licence,
    creditLine,
    tags,
    dominantColour,
    addedAt,
    lastAppliedAt,
    applyCount,
    isFavourite,
    isHidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallpapers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_page_url')) {
      context.handle(
        _sourcePageUrlMeta,
        sourcePageUrl.isAcceptableOrUnknown(
          data['source_page_url']!,
          _sourcePageUrlMeta,
        ),
      );
    }
    if (data.containsKey('download_url')) {
      context.handle(
        _downloadUrlMeta,
        downloadUrl.isAcceptableOrUnknown(
          data['download_url']!,
          _downloadUrlMeta,
        ),
      );
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('author_name')) {
      context.handle(
        _authorNameMeta,
        authorName.isAcceptableOrUnknown(data['author_name']!, _authorNameMeta),
      );
    }
    if (data.containsKey('author_url')) {
      context.handle(
        _authorUrlMeta,
        authorUrl.isAcceptableOrUnknown(data['author_url']!, _authorUrlMeta),
      );
    }
    if (data.containsKey('licence')) {
      context.handle(
        _licenceMeta,
        licence.isAcceptableOrUnknown(data['licence']!, _licenceMeta),
      );
    }
    if (data.containsKey('credit_line')) {
      context.handle(
        _creditLineMeta,
        creditLine.isAcceptableOrUnknown(data['credit_line']!, _creditLineMeta),
      );
    }
    if (data.containsKey('dominant_colour')) {
      context.handle(
        _dominantColourMeta,
        dominantColour.isAcceptableOrUnknown(
          data['dominant_colour']!,
          _dominantColourMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_applied_at')) {
      context.handle(
        _lastAppliedAtMeta,
        lastAppliedAt.isAcceptableOrUnknown(
          data['last_applied_at']!,
          _lastAppliedAtMeta,
        ),
      );
    }
    if (data.containsKey('apply_count')) {
      context.handle(
        _applyCountMeta,
        applyCount.isAcceptableOrUnknown(data['apply_count']!, _applyCountMeta),
      );
    }
    if (data.containsKey('is_favourite')) {
      context.handle(
        _isFavouriteMeta,
        isFavourite.isAcceptableOrUnknown(
          data['is_favourite']!,
          _isFavouriteMeta,
        ),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {source, sourceId},
  ];
  @override
  LibraryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourcePageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_page_url'],
      ),
      downloadUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_url'],
      ),
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      orientation: $WallpapersTable.$converterorientation.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}orientation'],
        )!,
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      authorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_name'],
      ),
      authorUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_url'],
      ),
      licence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}licence'],
      ),
      creditLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credit_line'],
      ),
      tags: $WallpapersTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      dominantColour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dominant_colour'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastAppliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_applied_at'],
      ),
      applyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}apply_count'],
      )!,
      isFavourite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favourite'],
      )!,
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
    );
  }

  @override
  $WallpapersTable createAlias(String alias) {
    return $WallpapersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<WallpaperOrientation, String, String>
  $converterorientation = const EnumNameConverter<WallpaperOrientation>(
    WallpaperOrientation.values,
  );
  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
}

class LibraryItem extends DataClass implements Insertable<LibraryItem> {
  final int id;

  /// Source id (`wallhaven`, `local`, ...).
  final String source;

  /// The image's id at its source. For local files, the start of its hash.
  final String sourceId;
  final String? sourcePageUrl;
  final String? downloadUrl;

  /// Relative to the library folder, always with `/` separators.
  final String relativePath;
  final int width;
  final int height;
  final WallpaperOrientation orientation;
  final int fileSize;
  final String sha256;
  final String? title;
  final String? authorName;
  final String? authorUrl;
  final String? licence;
  final String? creditLine;
  final List<String> tags;

  /// 0xAARRGGBB.
  final int? dominantColour;
  final DateTime addedAt;
  final DateTime? lastAppliedAt;
  final int applyCount;
  final bool isFavourite;

  /// Kept in the library but left out of rotation.
  final bool isHidden;
  const LibraryItem({
    required this.id,
    required this.source,
    required this.sourceId,
    this.sourcePageUrl,
    this.downloadUrl,
    required this.relativePath,
    required this.width,
    required this.height,
    required this.orientation,
    required this.fileSize,
    required this.sha256,
    this.title,
    this.authorName,
    this.authorUrl,
    this.licence,
    this.creditLine,
    required this.tags,
    this.dominantColour,
    required this.addedAt,
    this.lastAppliedAt,
    required this.applyCount,
    required this.isFavourite,
    required this.isHidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || sourcePageUrl != null) {
      map['source_page_url'] = Variable<String>(sourcePageUrl);
    }
    if (!nullToAbsent || downloadUrl != null) {
      map['download_url'] = Variable<String>(downloadUrl);
    }
    map['relative_path'] = Variable<String>(relativePath);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    {
      map['orientation'] = Variable<String>(
        $WallpapersTable.$converterorientation.toSql(orientation),
      );
    }
    map['file_size'] = Variable<int>(fileSize);
    map['sha256'] = Variable<String>(sha256);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || authorName != null) {
      map['author_name'] = Variable<String>(authorName);
    }
    if (!nullToAbsent || authorUrl != null) {
      map['author_url'] = Variable<String>(authorUrl);
    }
    if (!nullToAbsent || licence != null) {
      map['licence'] = Variable<String>(licence);
    }
    if (!nullToAbsent || creditLine != null) {
      map['credit_line'] = Variable<String>(creditLine);
    }
    {
      map['tags'] = Variable<String>(
        $WallpapersTable.$convertertags.toSql(tags),
      );
    }
    if (!nullToAbsent || dominantColour != null) {
      map['dominant_colour'] = Variable<int>(dominantColour);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastAppliedAt != null) {
      map['last_applied_at'] = Variable<DateTime>(lastAppliedAt);
    }
    map['apply_count'] = Variable<int>(applyCount);
    map['is_favourite'] = Variable<bool>(isFavourite);
    map['is_hidden'] = Variable<bool>(isHidden);
    return map;
  }

  WallpapersCompanion toCompanion(bool nullToAbsent) {
    return WallpapersCompanion(
      id: Value(id),
      source: Value(source),
      sourceId: Value(sourceId),
      sourcePageUrl: sourcePageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePageUrl),
      downloadUrl: downloadUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadUrl),
      relativePath: Value(relativePath),
      width: Value(width),
      height: Value(height),
      orientation: Value(orientation),
      fileSize: Value(fileSize),
      sha256: Value(sha256),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      authorName: authorName == null && nullToAbsent
          ? const Value.absent()
          : Value(authorName),
      authorUrl: authorUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(authorUrl),
      licence: licence == null && nullToAbsent
          ? const Value.absent()
          : Value(licence),
      creditLine: creditLine == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLine),
      tags: Value(tags),
      dominantColour: dominantColour == null && nullToAbsent
          ? const Value.absent()
          : Value(dominantColour),
      addedAt: Value(addedAt),
      lastAppliedAt: lastAppliedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAppliedAt),
      applyCount: Value(applyCount),
      isFavourite: Value(isFavourite),
      isHidden: Value(isHidden),
    );
  }

  factory LibraryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryItem(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourcePageUrl: serializer.fromJson<String?>(json['sourcePageUrl']),
      downloadUrl: serializer.fromJson<String?>(json['downloadUrl']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      orientation: $WallpapersTable.$converterorientation.fromJson(
        serializer.fromJson<String>(json['orientation']),
      ),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      sha256: serializer.fromJson<String>(json['sha256']),
      title: serializer.fromJson<String?>(json['title']),
      authorName: serializer.fromJson<String?>(json['authorName']),
      authorUrl: serializer.fromJson<String?>(json['authorUrl']),
      licence: serializer.fromJson<String?>(json['licence']),
      creditLine: serializer.fromJson<String?>(json['creditLine']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      dominantColour: serializer.fromJson<int?>(json['dominantColour']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastAppliedAt: serializer.fromJson<DateTime?>(json['lastAppliedAt']),
      applyCount: serializer.fromJson<int>(json['applyCount']),
      isFavourite: serializer.fromJson<bool>(json['isFavourite']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourcePageUrl': serializer.toJson<String?>(sourcePageUrl),
      'downloadUrl': serializer.toJson<String?>(downloadUrl),
      'relativePath': serializer.toJson<String>(relativePath),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'orientation': serializer.toJson<String>(
        $WallpapersTable.$converterorientation.toJson(orientation),
      ),
      'fileSize': serializer.toJson<int>(fileSize),
      'sha256': serializer.toJson<String>(sha256),
      'title': serializer.toJson<String?>(title),
      'authorName': serializer.toJson<String?>(authorName),
      'authorUrl': serializer.toJson<String?>(authorUrl),
      'licence': serializer.toJson<String?>(licence),
      'creditLine': serializer.toJson<String?>(creditLine),
      'tags': serializer.toJson<List<String>>(tags),
      'dominantColour': serializer.toJson<int?>(dominantColour),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastAppliedAt': serializer.toJson<DateTime?>(lastAppliedAt),
      'applyCount': serializer.toJson<int>(applyCount),
      'isFavourite': serializer.toJson<bool>(isFavourite),
      'isHidden': serializer.toJson<bool>(isHidden),
    };
  }

  LibraryItem copyWith({
    int? id,
    String? source,
    String? sourceId,
    Value<String?> sourcePageUrl = const Value.absent(),
    Value<String?> downloadUrl = const Value.absent(),
    String? relativePath,
    int? width,
    int? height,
    WallpaperOrientation? orientation,
    int? fileSize,
    String? sha256,
    Value<String?> title = const Value.absent(),
    Value<String?> authorName = const Value.absent(),
    Value<String?> authorUrl = const Value.absent(),
    Value<String?> licence = const Value.absent(),
    Value<String?> creditLine = const Value.absent(),
    List<String>? tags,
    Value<int?> dominantColour = const Value.absent(),
    DateTime? addedAt,
    Value<DateTime?> lastAppliedAt = const Value.absent(),
    int? applyCount,
    bool? isFavourite,
    bool? isHidden,
  }) => LibraryItem(
    id: id ?? this.id,
    source: source ?? this.source,
    sourceId: sourceId ?? this.sourceId,
    sourcePageUrl: sourcePageUrl.present
        ? sourcePageUrl.value
        : this.sourcePageUrl,
    downloadUrl: downloadUrl.present ? downloadUrl.value : this.downloadUrl,
    relativePath: relativePath ?? this.relativePath,
    width: width ?? this.width,
    height: height ?? this.height,
    orientation: orientation ?? this.orientation,
    fileSize: fileSize ?? this.fileSize,
    sha256: sha256 ?? this.sha256,
    title: title.present ? title.value : this.title,
    authorName: authorName.present ? authorName.value : this.authorName,
    authorUrl: authorUrl.present ? authorUrl.value : this.authorUrl,
    licence: licence.present ? licence.value : this.licence,
    creditLine: creditLine.present ? creditLine.value : this.creditLine,
    tags: tags ?? this.tags,
    dominantColour: dominantColour.present
        ? dominantColour.value
        : this.dominantColour,
    addedAt: addedAt ?? this.addedAt,
    lastAppliedAt: lastAppliedAt.present
        ? lastAppliedAt.value
        : this.lastAppliedAt,
    applyCount: applyCount ?? this.applyCount,
    isFavourite: isFavourite ?? this.isFavourite,
    isHidden: isHidden ?? this.isHidden,
  );
  LibraryItem copyWithCompanion(WallpapersCompanion data) {
    return LibraryItem(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourcePageUrl: data.sourcePageUrl.present
          ? data.sourcePageUrl.value
          : this.sourcePageUrl,
      downloadUrl: data.downloadUrl.present
          ? data.downloadUrl.value
          : this.downloadUrl,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      orientation: data.orientation.present
          ? data.orientation.value
          : this.orientation,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      title: data.title.present ? data.title.value : this.title,
      authorName: data.authorName.present
          ? data.authorName.value
          : this.authorName,
      authorUrl: data.authorUrl.present ? data.authorUrl.value : this.authorUrl,
      licence: data.licence.present ? data.licence.value : this.licence,
      creditLine: data.creditLine.present
          ? data.creditLine.value
          : this.creditLine,
      tags: data.tags.present ? data.tags.value : this.tags,
      dominantColour: data.dominantColour.present
          ? data.dominantColour.value
          : this.dominantColour,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastAppliedAt: data.lastAppliedAt.present
          ? data.lastAppliedAt.value
          : this.lastAppliedAt,
      applyCount: data.applyCount.present
          ? data.applyCount.value
          : this.applyCount,
      isFavourite: data.isFavourite.present
          ? data.isFavourite.value
          : this.isFavourite,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItem(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourcePageUrl: $sourcePageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('relativePath: $relativePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('orientation: $orientation, ')
          ..write('fileSize: $fileSize, ')
          ..write('sha256: $sha256, ')
          ..write('title: $title, ')
          ..write('authorName: $authorName, ')
          ..write('authorUrl: $authorUrl, ')
          ..write('licence: $licence, ')
          ..write('creditLine: $creditLine, ')
          ..write('tags: $tags, ')
          ..write('dominantColour: $dominantColour, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastAppliedAt: $lastAppliedAt, ')
          ..write('applyCount: $applyCount, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('isHidden: $isHidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    source,
    sourceId,
    sourcePageUrl,
    downloadUrl,
    relativePath,
    width,
    height,
    orientation,
    fileSize,
    sha256,
    title,
    authorName,
    authorUrl,
    licence,
    creditLine,
    tags,
    dominantColour,
    addedAt,
    lastAppliedAt,
    applyCount,
    isFavourite,
    isHidden,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryItem &&
          other.id == this.id &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.sourcePageUrl == this.sourcePageUrl &&
          other.downloadUrl == this.downloadUrl &&
          other.relativePath == this.relativePath &&
          other.width == this.width &&
          other.height == this.height &&
          other.orientation == this.orientation &&
          other.fileSize == this.fileSize &&
          other.sha256 == this.sha256 &&
          other.title == this.title &&
          other.authorName == this.authorName &&
          other.authorUrl == this.authorUrl &&
          other.licence == this.licence &&
          other.creditLine == this.creditLine &&
          other.tags == this.tags &&
          other.dominantColour == this.dominantColour &&
          other.addedAt == this.addedAt &&
          other.lastAppliedAt == this.lastAppliedAt &&
          other.applyCount == this.applyCount &&
          other.isFavourite == this.isFavourite &&
          other.isHidden == this.isHidden);
}

class WallpapersCompanion extends UpdateCompanion<LibraryItem> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> sourceId;
  final Value<String?> sourcePageUrl;
  final Value<String?> downloadUrl;
  final Value<String> relativePath;
  final Value<int> width;
  final Value<int> height;
  final Value<WallpaperOrientation> orientation;
  final Value<int> fileSize;
  final Value<String> sha256;
  final Value<String?> title;
  final Value<String?> authorName;
  final Value<String?> authorUrl;
  final Value<String?> licence;
  final Value<String?> creditLine;
  final Value<List<String>> tags;
  final Value<int?> dominantColour;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastAppliedAt;
  final Value<int> applyCount;
  final Value<bool> isFavourite;
  final Value<bool> isHidden;
  const WallpapersCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourcePageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.orientation = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.title = const Value.absent(),
    this.authorName = const Value.absent(),
    this.authorUrl = const Value.absent(),
    this.licence = const Value.absent(),
    this.creditLine = const Value.absent(),
    this.tags = const Value.absent(),
    this.dominantColour = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastAppliedAt = const Value.absent(),
    this.applyCount = const Value.absent(),
    this.isFavourite = const Value.absent(),
    this.isHidden = const Value.absent(),
  });
  WallpapersCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String sourceId,
    this.sourcePageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    required String relativePath,
    required int width,
    required int height,
    required WallpaperOrientation orientation,
    required int fileSize,
    required String sha256,
    this.title = const Value.absent(),
    this.authorName = const Value.absent(),
    this.authorUrl = const Value.absent(),
    this.licence = const Value.absent(),
    this.creditLine = const Value.absent(),
    this.tags = const Value.absent(),
    this.dominantColour = const Value.absent(),
    required DateTime addedAt,
    this.lastAppliedAt = const Value.absent(),
    this.applyCount = const Value.absent(),
    this.isFavourite = const Value.absent(),
    this.isHidden = const Value.absent(),
  }) : source = Value(source),
       sourceId = Value(sourceId),
       relativePath = Value(relativePath),
       width = Value(width),
       height = Value(height),
       orientation = Value(orientation),
       fileSize = Value(fileSize),
       sha256 = Value(sha256),
       addedAt = Value(addedAt);
  static Insertable<LibraryItem> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<String>? sourcePageUrl,
    Expression<String>? downloadUrl,
    Expression<String>? relativePath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? orientation,
    Expression<int>? fileSize,
    Expression<String>? sha256,
    Expression<String>? title,
    Expression<String>? authorName,
    Expression<String>? authorUrl,
    Expression<String>? licence,
    Expression<String>? creditLine,
    Expression<String>? tags,
    Expression<int>? dominantColour,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastAppliedAt,
    Expression<int>? applyCount,
    Expression<bool>? isFavourite,
    Expression<bool>? isHidden,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (sourcePageUrl != null) 'source_page_url': sourcePageUrl,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (relativePath != null) 'relative_path': relativePath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (orientation != null) 'orientation': orientation,
      if (fileSize != null) 'file_size': fileSize,
      if (sha256 != null) 'sha256': sha256,
      if (title != null) 'title': title,
      if (authorName != null) 'author_name': authorName,
      if (authorUrl != null) 'author_url': authorUrl,
      if (licence != null) 'licence': licence,
      if (creditLine != null) 'credit_line': creditLine,
      if (tags != null) 'tags': tags,
      if (dominantColour != null) 'dominant_colour': dominantColour,
      if (addedAt != null) 'added_at': addedAt,
      if (lastAppliedAt != null) 'last_applied_at': lastAppliedAt,
      if (applyCount != null) 'apply_count': applyCount,
      if (isFavourite != null) 'is_favourite': isFavourite,
      if (isHidden != null) 'is_hidden': isHidden,
    });
  }

  WallpapersCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? sourceId,
    Value<String?>? sourcePageUrl,
    Value<String?>? downloadUrl,
    Value<String>? relativePath,
    Value<int>? width,
    Value<int>? height,
    Value<WallpaperOrientation>? orientation,
    Value<int>? fileSize,
    Value<String>? sha256,
    Value<String?>? title,
    Value<String?>? authorName,
    Value<String?>? authorUrl,
    Value<String?>? licence,
    Value<String?>? creditLine,
    Value<List<String>>? tags,
    Value<int?>? dominantColour,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastAppliedAt,
    Value<int>? applyCount,
    Value<bool>? isFavourite,
    Value<bool>? isHidden,
  }) {
    return WallpapersCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      sourcePageUrl: sourcePageUrl ?? this.sourcePageUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      relativePath: relativePath ?? this.relativePath,
      width: width ?? this.width,
      height: height ?? this.height,
      orientation: orientation ?? this.orientation,
      fileSize: fileSize ?? this.fileSize,
      sha256: sha256 ?? this.sha256,
      title: title ?? this.title,
      authorName: authorName ?? this.authorName,
      authorUrl: authorUrl ?? this.authorUrl,
      licence: licence ?? this.licence,
      creditLine: creditLine ?? this.creditLine,
      tags: tags ?? this.tags,
      dominantColour: dominantColour ?? this.dominantColour,
      addedAt: addedAt ?? this.addedAt,
      lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
      applyCount: applyCount ?? this.applyCount,
      isFavourite: isFavourite ?? this.isFavourite,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourcePageUrl.present) {
      map['source_page_url'] = Variable<String>(sourcePageUrl.value);
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<String>(
        $WallpapersTable.$converterorientation.toSql(orientation.value),
      );
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (authorUrl.present) {
      map['author_url'] = Variable<String>(authorUrl.value);
    }
    if (licence.present) {
      map['licence'] = Variable<String>(licence.value);
    }
    if (creditLine.present) {
      map['credit_line'] = Variable<String>(creditLine.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $WallpapersTable.$convertertags.toSql(tags.value),
      );
    }
    if (dominantColour.present) {
      map['dominant_colour'] = Variable<int>(dominantColour.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastAppliedAt.present) {
      map['last_applied_at'] = Variable<DateTime>(lastAppliedAt.value);
    }
    if (applyCount.present) {
      map['apply_count'] = Variable<int>(applyCount.value);
    }
    if (isFavourite.present) {
      map['is_favourite'] = Variable<bool>(isFavourite.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WallpapersCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourcePageUrl: $sourcePageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('relativePath: $relativePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('orientation: $orientation, ')
          ..write('fileSize: $fileSize, ')
          ..write('sha256: $sha256, ')
          ..write('title: $title, ')
          ..write('authorName: $authorName, ')
          ..write('authorUrl: $authorUrl, ')
          ..write('licence: $licence, ')
          ..write('creditLine: $creditLine, ')
          ..write('tags: $tags, ')
          ..write('dominantColour: $dominantColour, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastAppliedAt: $lastAppliedAt, ')
          ..write('applyCount: $applyCount, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('isHidden: $isHidden')
          ..write(')'))
        .toString();
  }
}

class $ApplyHistoryTable extends ApplyHistory
    with TableInfo<$ApplyHistoryTable, ApplyHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApplyHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wallpaperIdMeta = const VerificationMeta(
    'wallpaperId',
  );
  @override
  late final GeneratedColumn<int> wallpaperId = GeneratedColumn<int>(
    'wallpaper_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wallpapers (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _appliedAtMeta = const VerificationMeta(
    'appliedAt',
  );
  @override
  late final GeneratedColumn<DateTime> appliedAt = GeneratedColumn<DateTime>(
    'applied_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, wallpaperId, appliedAt, target];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'apply_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ApplyHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('wallpaper_id')) {
      context.handle(
        _wallpaperIdMeta,
        wallpaperId.isAcceptableOrUnknown(
          data['wallpaper_id']!,
          _wallpaperIdMeta,
        ),
      );
    }
    if (data.containsKey('applied_at')) {
      context.handle(
        _appliedAtMeta,
        appliedAt.isAcceptableOrUnknown(data['applied_at']!, _appliedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_appliedAtMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApplyHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApplyHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      wallpaperId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wallpaper_id'],
      ),
      appliedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}applied_at'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
    );
  }

  @override
  $ApplyHistoryTable createAlias(String alias) {
    return $ApplyHistoryTable(attachedDatabase, alias);
  }
}

class ApplyHistoryData extends DataClass
    implements Insertable<ApplyHistoryData> {
  final int id;
  final int? wallpaperId;
  final DateTime appliedAt;

  /// [DisplayTarget.id], e.g. `DP-1` or `lock`.
  final String target;
  const ApplyHistoryData({
    required this.id,
    this.wallpaperId,
    required this.appliedAt,
    required this.target,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || wallpaperId != null) {
      map['wallpaper_id'] = Variable<int>(wallpaperId);
    }
    map['applied_at'] = Variable<DateTime>(appliedAt);
    map['target'] = Variable<String>(target);
    return map;
  }

  ApplyHistoryCompanion toCompanion(bool nullToAbsent) {
    return ApplyHistoryCompanion(
      id: Value(id),
      wallpaperId: wallpaperId == null && nullToAbsent
          ? const Value.absent()
          : Value(wallpaperId),
      appliedAt: Value(appliedAt),
      target: Value(target),
    );
  }

  factory ApplyHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApplyHistoryData(
      id: serializer.fromJson<int>(json['id']),
      wallpaperId: serializer.fromJson<int?>(json['wallpaperId']),
      appliedAt: serializer.fromJson<DateTime>(json['appliedAt']),
      target: serializer.fromJson<String>(json['target']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wallpaperId': serializer.toJson<int?>(wallpaperId),
      'appliedAt': serializer.toJson<DateTime>(appliedAt),
      'target': serializer.toJson<String>(target),
    };
  }

  ApplyHistoryData copyWith({
    int? id,
    Value<int?> wallpaperId = const Value.absent(),
    DateTime? appliedAt,
    String? target,
  }) => ApplyHistoryData(
    id: id ?? this.id,
    wallpaperId: wallpaperId.present ? wallpaperId.value : this.wallpaperId,
    appliedAt: appliedAt ?? this.appliedAt,
    target: target ?? this.target,
  );
  ApplyHistoryData copyWithCompanion(ApplyHistoryCompanion data) {
    return ApplyHistoryData(
      id: data.id.present ? data.id.value : this.id,
      wallpaperId: data.wallpaperId.present
          ? data.wallpaperId.value
          : this.wallpaperId,
      appliedAt: data.appliedAt.present ? data.appliedAt.value : this.appliedAt,
      target: data.target.present ? data.target.value : this.target,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApplyHistoryData(')
          ..write('id: $id, ')
          ..write('wallpaperId: $wallpaperId, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('target: $target')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, wallpaperId, appliedAt, target);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApplyHistoryData &&
          other.id == this.id &&
          other.wallpaperId == this.wallpaperId &&
          other.appliedAt == this.appliedAt &&
          other.target == this.target);
}

class ApplyHistoryCompanion extends UpdateCompanion<ApplyHistoryData> {
  final Value<int> id;
  final Value<int?> wallpaperId;
  final Value<DateTime> appliedAt;
  final Value<String> target;
  const ApplyHistoryCompanion({
    this.id = const Value.absent(),
    this.wallpaperId = const Value.absent(),
    this.appliedAt = const Value.absent(),
    this.target = const Value.absent(),
  });
  ApplyHistoryCompanion.insert({
    this.id = const Value.absent(),
    this.wallpaperId = const Value.absent(),
    required DateTime appliedAt,
    required String target,
  }) : appliedAt = Value(appliedAt),
       target = Value(target);
  static Insertable<ApplyHistoryData> custom({
    Expression<int>? id,
    Expression<int>? wallpaperId,
    Expression<DateTime>? appliedAt,
    Expression<String>? target,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wallpaperId != null) 'wallpaper_id': wallpaperId,
      if (appliedAt != null) 'applied_at': appliedAt,
      if (target != null) 'target': target,
    });
  }

  ApplyHistoryCompanion copyWith({
    Value<int>? id,
    Value<int?>? wallpaperId,
    Value<DateTime>? appliedAt,
    Value<String>? target,
  }) {
    return ApplyHistoryCompanion(
      id: id ?? this.id,
      wallpaperId: wallpaperId ?? this.wallpaperId,
      appliedAt: appliedAt ?? this.appliedAt,
      target: target ?? this.target,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wallpaperId.present) {
      map['wallpaper_id'] = Variable<int>(wallpaperId.value);
    }
    if (appliedAt.present) {
      map['applied_at'] = Variable<DateTime>(appliedAt.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApplyHistoryCompanion(')
          ..write('id: $id, ')
          ..write('wallpaperId: $wallpaperId, ')
          ..write('appliedAt: $appliedAt, ')
          ..write('target: $target')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingEntry extends DataClass implements Insertable<SettingEntry> {
  final String key;
  final String value;
  const SettingEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingEntry(
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

  SettingEntry copyWith({String? key, String? value}) =>
      SettingEntry(key: key ?? this.key, value: value ?? this.value);
  SettingEntry copyWithCompanion(SettingsCompanion data) {
    return SettingEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntry(')
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
      (other is SettingEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingEntry> {
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
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingEntry> custom({
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

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WallpapersTable wallpapers = $WallpapersTable(this);
  late final $ApplyHistoryTable applyHistory = $ApplyHistoryTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index wallpapersSha256 = Index(
    'wallpapers_sha256',
    'CREATE INDEX wallpapers_sha256 ON wallpapers (sha256)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    wallpapers,
    applyHistory,
    settings,
    wallpapersSha256,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'wallpapers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('apply_history', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$WallpapersTableCreateCompanionBuilder = WallpapersCompanion Function({
  Value<int> id,
  required String source,
  required String sourceId,
  Value<String?> sourcePageUrl,
  Value<String?> downloadUrl,
  required String relativePath,
  required int width,
  required int height,
  required WallpaperOrientation orientation,
  required int fileSize,
  required String sha256,
  Value<String?> title,
  Value<String?> authorName,
  Value<String?> authorUrl,
  Value<String?> licence,
  Value<String?> creditLine,
  Value<List<String>> tags,
  Value<int?> dominantColour,
  required DateTime addedAt,
  Value<DateTime?> lastAppliedAt,
  Value<int> applyCount,
  Value<bool> isFavourite,
  Value<bool> isHidden,
});
typedef $$WallpapersTableUpdateCompanionBuilder = WallpapersCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<String> sourceId,
  Value<String?> sourcePageUrl,
  Value<String?> downloadUrl,
  Value<String> relativePath,
  Value<int> width,
  Value<int> height,
  Value<WallpaperOrientation> orientation,
  Value<int> fileSize,
  Value<String> sha256,
  Value<String?> title,
  Value<String?> authorName,
  Value<String?> authorUrl,
  Value<String?> licence,
  Value<String?> creditLine,
  Value<List<String>> tags,
  Value<int?> dominantColour,
  Value<DateTime> addedAt,
  Value<DateTime?> lastAppliedAt,
  Value<int> applyCount,
  Value<bool> isFavourite,
  Value<bool> isHidden,
});

final class $$WallpapersTableReferences
    extends BaseReferences<_$AppDatabase, $WallpapersTable, LibraryItem> {
  $$WallpapersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ApplyHistoryTable, List<ApplyHistoryData>>
  _applyHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.applyHistory,
    aliasName: 'wallpapers__id__apply_history__wallpaper_id',
  );

  $$ApplyHistoryTableProcessedTableManager get applyHistoryRefs {
    final manager = $$ApplyHistoryTableTableManager(
      $_db,
      $_db.applyHistory,
    ).filter((f) => f.wallpaperId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_applyHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WallpapersTableFilterComposer
    extends Composer<_$AppDatabase, $WallpapersTable> {
  $$WallpapersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePageUrl => $composableBuilder(
    column: $table.sourcePageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    WallpaperOrientation,
    WallpaperOrientation,
    String
  >
  get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorUrl => $composableBuilder(
    column: $table.authorUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licence => $composableBuilder(
    column: $table.licence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creditLine => $composableBuilder(
    column: $table.creditLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get dominantColour => $composableBuilder(
    column: $table.dominantColour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAppliedAt => $composableBuilder(
    column: $table.lastAppliedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get applyCount => $composableBuilder(
    column: $table.applyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavourite => $composableBuilder(
    column: $table.isFavourite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> applyHistoryRefs(
    Expression<bool> Function($$ApplyHistoryTableFilterComposer f) f,
  ) {
    final $$ApplyHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.applyHistory,
      getReferencedColumn: (t) => t.wallpaperId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplyHistoryTableFilterComposer(
            $db: $db,
            $table: $db.applyHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WallpapersTableOrderingComposer
    extends Composer<_$AppDatabase, $WallpapersTable> {
  $$WallpapersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePageUrl => $composableBuilder(
    column: $table.sourcePageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorUrl => $composableBuilder(
    column: $table.authorUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licence => $composableBuilder(
    column: $table.licence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creditLine => $composableBuilder(
    column: $table.creditLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dominantColour => $composableBuilder(
    column: $table.dominantColour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAppliedAt => $composableBuilder(
    column: $table.lastAppliedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get applyCount => $composableBuilder(
    column: $table.applyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavourite => $composableBuilder(
    column: $table.isFavourite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WallpapersTableAnnotationComposer
    extends Composer<_$AppDatabase, $WallpapersTable> {
  $$WallpapersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourcePageUrl => $composableBuilder(
    column: $table.sourcePageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WallpaperOrientation, String>
  get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorUrl =>
      $composableBuilder(column: $table.authorUrl, builder: (column) => column);

  GeneratedColumn<String> get licence =>
      $composableBuilder(column: $table.licence, builder: (column) => column);

  GeneratedColumn<String> get creditLine => $composableBuilder(
    column: $table.creditLine,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get dominantColour => $composableBuilder(
    column: $table.dominantColour,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAppliedAt => $composableBuilder(
    column: $table.lastAppliedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get applyCount => $composableBuilder(
    column: $table.applyCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavourite => $composableBuilder(
    column: $table.isFavourite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  Expression<T> applyHistoryRefs<T extends Object>(
    Expression<T> Function($$ApplyHistoryTableAnnotationComposer a) f,
  ) {
    final $$ApplyHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.applyHistory,
      getReferencedColumn: (t) => t.wallpaperId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplyHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.applyHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WallpapersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WallpapersTable,
          LibraryItem,
          $$WallpapersTableFilterComposer,
          $$WallpapersTableOrderingComposer,
          $$WallpapersTableAnnotationComposer,
          $$WallpapersTableCreateCompanionBuilder,
          $$WallpapersTableUpdateCompanionBuilder,
          (LibraryItem, $$WallpapersTableReferences),
          LibraryItem,
          PrefetchHooks Function({bool applyHistoryRefs})
        > {
  $$WallpapersTableTableManager(_$AppDatabase db, $WallpapersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WallpapersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WallpapersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WallpapersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> sourcePageUrl = const Value.absent(),
                Value<String?> downloadUrl = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<WallpaperOrientation> orientation = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> authorName = const Value.absent(),
                Value<String?> authorUrl = const Value.absent(),
                Value<String?> licence = const Value.absent(),
                Value<String?> creditLine = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<int?> dominantColour = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastAppliedAt = const Value.absent(),
                Value<int> applyCount = const Value.absent(),
                Value<bool> isFavourite = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
              }) => WallpapersCompanion(
                id: id,
                source: source,
                sourceId: sourceId,
                sourcePageUrl: sourcePageUrl,
                downloadUrl: downloadUrl,
                relativePath: relativePath,
                width: width,
                height: height,
                orientation: orientation,
                fileSize: fileSize,
                sha256: sha256,
                title: title,
                authorName: authorName,
                authorUrl: authorUrl,
                licence: licence,
                creditLine: creditLine,
                tags: tags,
                dominantColour: dominantColour,
                addedAt: addedAt,
                lastAppliedAt: lastAppliedAt,
                applyCount: applyCount,
                isFavourite: isFavourite,
                isHidden: isHidden,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String sourceId,
                Value<String?> sourcePageUrl = const Value.absent(),
                Value<String?> downloadUrl = const Value.absent(),
                required String relativePath,
                required int width,
                required int height,
                required WallpaperOrientation orientation,
                required int fileSize,
                required String sha256,
                Value<String?> title = const Value.absent(),
                Value<String?> authorName = const Value.absent(),
                Value<String?> authorUrl = const Value.absent(),
                Value<String?> licence = const Value.absent(),
                Value<String?> creditLine = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<int?> dominantColour = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> lastAppliedAt = const Value.absent(),
                Value<int> applyCount = const Value.absent(),
                Value<bool> isFavourite = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
              }) => WallpapersCompanion.insert(
                id: id,
                source: source,
                sourceId: sourceId,
                sourcePageUrl: sourcePageUrl,
                downloadUrl: downloadUrl,
                relativePath: relativePath,
                width: width,
                height: height,
                orientation: orientation,
                fileSize: fileSize,
                sha256: sha256,
                title: title,
                authorName: authorName,
                authorUrl: authorUrl,
                licence: licence,
                creditLine: creditLine,
                tags: tags,
                dominantColour: dominantColour,
                addedAt: addedAt,
                lastAppliedAt: lastAppliedAt,
                applyCount: applyCount,
                isFavourite: isFavourite,
                isHidden: isHidden,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WallpapersTable, LibraryItem>(table),
                  $$WallpapersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({applyHistoryRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (applyHistoryRefs) db.applyHistory],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (applyHistoryRefs)
                    await $_getPrefetchedDataByColumns<
                      LibraryItem,
                      $WallpapersTable,
                      ApplyHistoryData,
                      $ApplyHistoryTable
                    >(
                      currentTable: table,
                      referencedTable: $$WallpapersTableReferences
                          ._applyHistoryRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WallpapersTableReferences(
                            db,
                            table,
                            p0,
                          ).applyHistoryRefs,
                      currentColumn: 'id',
                      referencedColumn: 'wallpaper_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WallpapersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WallpapersTable,
      LibraryItem,
      $$WallpapersTableFilterComposer,
      $$WallpapersTableOrderingComposer,
      $$WallpapersTableAnnotationComposer,
      $$WallpapersTableCreateCompanionBuilder,
      $$WallpapersTableUpdateCompanionBuilder,
      (LibraryItem, $$WallpapersTableReferences),
      LibraryItem,
      PrefetchHooks Function({bool applyHistoryRefs})
    >;
typedef $$ApplyHistoryTableCreateCompanionBuilder =
    ApplyHistoryCompanion Function({
      Value<int> id,
      Value<int?> wallpaperId,
      required DateTime appliedAt,
      required String target,
    });
typedef $$ApplyHistoryTableUpdateCompanionBuilder =
    ApplyHistoryCompanion Function({
      Value<int> id,
      Value<int?> wallpaperId,
      Value<DateTime> appliedAt,
      Value<String> target,
    });

final class $$ApplyHistoryTableReferences
    extends
        BaseReferences<_$AppDatabase, $ApplyHistoryTable, ApplyHistoryData> {
  $$ApplyHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WallpapersTable _wallpaperIdTable(_$AppDatabase db) =>
      db.wallpapers.createAlias('apply_history__wallpaper_id__wallpapers__id');

  $$WallpapersTableProcessedTableManager? get wallpaperId {
    final $_column = $_itemColumn<int>('wallpaper_id');
    if ($_column == null) return null;
    final manager = $$WallpapersTableTableManager(
      $_db,
      $_db.wallpapers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wallpaperIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ApplyHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ApplyHistoryTable> {
  $$ApplyHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  $$WallpapersTableFilterComposer get wallpaperId {
    final $$WallpapersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallpaperId,
      referencedTable: $db.wallpapers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallpapersTableFilterComposer(
            $db: $db,
            $table: $db.wallpapers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApplyHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ApplyHistoryTable> {
  $$ApplyHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get appliedAt => $composableBuilder(
    column: $table.appliedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  $$WallpapersTableOrderingComposer get wallpaperId {
    final $$WallpapersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallpaperId,
      referencedTable: $db.wallpapers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallpapersTableOrderingComposer(
            $db: $db,
            $table: $db.wallpapers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApplyHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ApplyHistoryTable> {
  $$ApplyHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get appliedAt =>
      $composableBuilder(column: $table.appliedAt, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  $$WallpapersTableAnnotationComposer get wallpaperId {
    final $$WallpapersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wallpaperId,
      referencedTable: $db.wallpapers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WallpapersTableAnnotationComposer(
            $db: $db,
            $table: $db.wallpapers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApplyHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ApplyHistoryTable,
          ApplyHistoryData,
          $$ApplyHistoryTableFilterComposer,
          $$ApplyHistoryTableOrderingComposer,
          $$ApplyHistoryTableAnnotationComposer,
          $$ApplyHistoryTableCreateCompanionBuilder,
          $$ApplyHistoryTableUpdateCompanionBuilder,
          (ApplyHistoryData, $$ApplyHistoryTableReferences),
          ApplyHistoryData,
          PrefetchHooks Function({bool wallpaperId})
        > {
  $$ApplyHistoryTableTableManager(_$AppDatabase db, $ApplyHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApplyHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApplyHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApplyHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> wallpaperId = const Value.absent(),
                Value<DateTime> appliedAt = const Value.absent(),
                Value<String> target = const Value.absent(),
              }) => ApplyHistoryCompanion(
                id: id,
                wallpaperId: wallpaperId,
                appliedAt: appliedAt,
                target: target,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> wallpaperId = const Value.absent(),
                required DateTime appliedAt,
                required String target,
              }) => ApplyHistoryCompanion.insert(
                id: id,
                wallpaperId: wallpaperId,
                appliedAt: appliedAt,
                target: target,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ApplyHistoryTable, ApplyHistoryData>(table),
                  $$ApplyHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wallpaperId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (wallpaperId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.wallpaperId,
                        referencedTable: $$ApplyHistoryTableReferences
                            ._wallpaperIdTable(db),
                        referencedColumn: $$ApplyHistoryTableReferences
                            ._wallpaperIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ApplyHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ApplyHistoryTable,
      ApplyHistoryData,
      $$ApplyHistoryTableFilterComposer,
      $$ApplyHistoryTableOrderingComposer,
      $$ApplyHistoryTableAnnotationComposer,
      $$ApplyHistoryTableCreateCompanionBuilder,
      $$ApplyHistoryTableUpdateCompanionBuilder,
      (ApplyHistoryData, $$ApplyHistoryTableReferences),
      ApplyHistoryData,
      PrefetchHooks Function({bool wallpaperId})
    >;
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
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
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

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingEntry,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingEntry,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingEntry>,
          ),
          SettingEntry,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
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
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingEntry>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingEntry,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (
        SettingEntry,
        BaseReferences<_$AppDatabase, $SettingsTable, SettingEntry>,
      ),
      SettingEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WallpapersTableTableManager get wallpapers =>
      $$WallpapersTableTableManager(_db, _db.wallpapers);
  $$ApplyHistoryTableTableManager get applyHistory =>
      $$ApplyHistoryTableTableManager(_db, _db.applyHistory);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
