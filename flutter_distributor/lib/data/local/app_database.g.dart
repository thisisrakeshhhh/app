// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProductsTable extends Products
    with TableInfo<$ProductsTable, ProductEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hindiNameMeta = const VerificationMeta(
    'hindiName',
  );
  @override
  late final GeneratedColumn<String> hindiName = GeneratedColumn<String>(
    'hindi_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mrpRupeesMeta = const VerificationMeta(
    'mrpRupees',
  );
  @override
  late final GeneratedColumn<double> mrpRupees = GeneratedColumn<double>(
    'mrp_rupees',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mrpPaiseMeta = const VerificationMeta(
    'mrpPaise',
  );
  @override
  late final GeneratedColumn<int> mrpPaise = GeneratedColumn<int>(
    'mrp_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _piecePricePaiseMeta = const VerificationMeta(
    'piecePricePaise',
  );
  @override
  late final GeneratedColumn<int> piecePricePaise = GeneratedColumn<int>(
    'piece_price_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stripQtyMeta = const VerificationMeta(
    'stripQty',
  );
  @override
  late final GeneratedColumn<int> stripQty = GeneratedColumn<int>(
    'strip_qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxQtyMeta = const VerificationMeta('boxQty');
  @override
  late final GeneratedColumn<int> boxQty = GeneratedColumn<int>(
    'box_qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gstRateMeta = const VerificationMeta(
    'gstRate',
  );
  @override
  late final GeneratedColumn<double> gstRate = GeneratedColumn<double>(
    'gst_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(18.0),
  );
  static const VerificationMeta _badgeMeta = const VerificationMeta('badge');
  @override
  late final GeneratedColumn<String> badge = GeneratedColumn<String>(
    'badge',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    hindiName,
    category,
    mrpRupees,
    mrpPaise,
    piecePricePaise,
    stripQty,
    boxQty,
    gstRate,
    badge,
    imageUrl,
    isArchived,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('hindi_name')) {
      context.handle(
        _hindiNameMeta,
        hindiName.isAcceptableOrUnknown(data['hindi_name']!, _hindiNameMeta),
      );
    } else if (isInserting) {
      context.missing(_hindiNameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('mrp_rupees')) {
      context.handle(
        _mrpRupeesMeta,
        mrpRupees.isAcceptableOrUnknown(data['mrp_rupees']!, _mrpRupeesMeta),
      );
    } else if (isInserting) {
      context.missing(_mrpRupeesMeta);
    }
    if (data.containsKey('mrp_paise')) {
      context.handle(
        _mrpPaiseMeta,
        mrpPaise.isAcceptableOrUnknown(data['mrp_paise']!, _mrpPaiseMeta),
      );
    }
    if (data.containsKey('piece_price_paise')) {
      context.handle(
        _piecePricePaiseMeta,
        piecePricePaise.isAcceptableOrUnknown(
          data['piece_price_paise']!,
          _piecePricePaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_piecePricePaiseMeta);
    }
    if (data.containsKey('strip_qty')) {
      context.handle(
        _stripQtyMeta,
        stripQty.isAcceptableOrUnknown(data['strip_qty']!, _stripQtyMeta),
      );
    } else if (isInserting) {
      context.missing(_stripQtyMeta);
    }
    if (data.containsKey('box_qty')) {
      context.handle(
        _boxQtyMeta,
        boxQty.isAcceptableOrUnknown(data['box_qty']!, _boxQtyMeta),
      );
    } else if (isInserting) {
      context.missing(_boxQtyMeta);
    }
    if (data.containsKey('gst_rate')) {
      context.handle(
        _gstRateMeta,
        gstRate.isAcceptableOrUnknown(data['gst_rate']!, _gstRateMeta),
      );
    }
    if (data.containsKey('badge')) {
      context.handle(
        _badgeMeta,
        badge.isAcceptableOrUnknown(data['badge']!, _badgeMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      hindiName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hindi_name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      mrpRupees: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mrp_rupees'],
      )!,
      mrpPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mrp_paise'],
      )!,
      piecePricePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}piece_price_paise'],
      )!,
      stripQty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}strip_qty'],
      )!,
      boxQty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box_qty'],
      )!,
      gstRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gst_rate'],
      )!,
      badge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}badge'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class ProductEntry extends DataClass implements Insertable<ProductEntry> {
  final String id;
  final String name;
  final String hindiName;
  final String category;
  final double mrpRupees;
  final int mrpPaise;
  final int piecePricePaise;
  final int stripQty;
  final int boxQty;
  final double gstRate;
  final String badge;
  final String imageUrl;
  final bool isArchived;
  final DateTime createdAt;
  const ProductEntry({
    required this.id,
    required this.name,
    required this.hindiName,
    required this.category,
    required this.mrpRupees,
    required this.mrpPaise,
    required this.piecePricePaise,
    required this.stripQty,
    required this.boxQty,
    required this.gstRate,
    required this.badge,
    required this.imageUrl,
    required this.isArchived,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['hindi_name'] = Variable<String>(hindiName);
    map['category'] = Variable<String>(category);
    map['mrp_rupees'] = Variable<double>(mrpRupees);
    map['mrp_paise'] = Variable<int>(mrpPaise);
    map['piece_price_paise'] = Variable<int>(piecePricePaise);
    map['strip_qty'] = Variable<int>(stripQty);
    map['box_qty'] = Variable<int>(boxQty);
    map['gst_rate'] = Variable<double>(gstRate);
    map['badge'] = Variable<String>(badge);
    map['image_url'] = Variable<String>(imageUrl);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      hindiName: Value(hindiName),
      category: Value(category),
      mrpRupees: Value(mrpRupees),
      mrpPaise: Value(mrpPaise),
      piecePricePaise: Value(piecePricePaise),
      stripQty: Value(stripQty),
      boxQty: Value(boxQty),
      gstRate: Value(gstRate),
      badge: Value(badge),
      imageUrl: Value(imageUrl),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
    );
  }

  factory ProductEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      hindiName: serializer.fromJson<String>(json['hindiName']),
      category: serializer.fromJson<String>(json['category']),
      mrpRupees: serializer.fromJson<double>(json['mrpRupees']),
      mrpPaise: serializer.fromJson<int>(json['mrpPaise']),
      piecePricePaise: serializer.fromJson<int>(json['piecePricePaise']),
      stripQty: serializer.fromJson<int>(json['stripQty']),
      boxQty: serializer.fromJson<int>(json['boxQty']),
      gstRate: serializer.fromJson<double>(json['gstRate']),
      badge: serializer.fromJson<String>(json['badge']),
      imageUrl: serializer.fromJson<String>(json['imageUrl']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'hindiName': serializer.toJson<String>(hindiName),
      'category': serializer.toJson<String>(category),
      'mrpRupees': serializer.toJson<double>(mrpRupees),
      'mrpPaise': serializer.toJson<int>(mrpPaise),
      'piecePricePaise': serializer.toJson<int>(piecePricePaise),
      'stripQty': serializer.toJson<int>(stripQty),
      'boxQty': serializer.toJson<int>(boxQty),
      'gstRate': serializer.toJson<double>(gstRate),
      'badge': serializer.toJson<String>(badge),
      'imageUrl': serializer.toJson<String>(imageUrl),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProductEntry copyWith({
    String? id,
    String? name,
    String? hindiName,
    String? category,
    double? mrpRupees,
    int? mrpPaise,
    int? piecePricePaise,
    int? stripQty,
    int? boxQty,
    double? gstRate,
    String? badge,
    String? imageUrl,
    bool? isArchived,
    DateTime? createdAt,
  }) => ProductEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    hindiName: hindiName ?? this.hindiName,
    category: category ?? this.category,
    mrpRupees: mrpRupees ?? this.mrpRupees,
    mrpPaise: mrpPaise ?? this.mrpPaise,
    piecePricePaise: piecePricePaise ?? this.piecePricePaise,
    stripQty: stripQty ?? this.stripQty,
    boxQty: boxQty ?? this.boxQty,
    gstRate: gstRate ?? this.gstRate,
    badge: badge ?? this.badge,
    imageUrl: imageUrl ?? this.imageUrl,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
  );
  ProductEntry copyWithCompanion(ProductsCompanion data) {
    return ProductEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      hindiName: data.hindiName.present ? data.hindiName.value : this.hindiName,
      category: data.category.present ? data.category.value : this.category,
      mrpRupees: data.mrpRupees.present ? data.mrpRupees.value : this.mrpRupees,
      mrpPaise: data.mrpPaise.present ? data.mrpPaise.value : this.mrpPaise,
      piecePricePaise: data.piecePricePaise.present
          ? data.piecePricePaise.value
          : this.piecePricePaise,
      stripQty: data.stripQty.present ? data.stripQty.value : this.stripQty,
      boxQty: data.boxQty.present ? data.boxQty.value : this.boxQty,
      gstRate: data.gstRate.present ? data.gstRate.value : this.gstRate,
      badge: data.badge.present ? data.badge.value : this.badge,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hindiName: $hindiName, ')
          ..write('category: $category, ')
          ..write('mrpRupees: $mrpRupees, ')
          ..write('mrpPaise: $mrpPaise, ')
          ..write('piecePricePaise: $piecePricePaise, ')
          ..write('stripQty: $stripQty, ')
          ..write('boxQty: $boxQty, ')
          ..write('gstRate: $gstRate, ')
          ..write('badge: $badge, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    hindiName,
    category,
    mrpRupees,
    mrpPaise,
    piecePricePaise,
    stripQty,
    boxQty,
    gstRate,
    badge,
    imageUrl,
    isArchived,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.hindiName == this.hindiName &&
          other.category == this.category &&
          other.mrpRupees == this.mrpRupees &&
          other.mrpPaise == this.mrpPaise &&
          other.piecePricePaise == this.piecePricePaise &&
          other.stripQty == this.stripQty &&
          other.boxQty == this.boxQty &&
          other.gstRate == this.gstRate &&
          other.badge == this.badge &&
          other.imageUrl == this.imageUrl &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt);
}

class ProductsCompanion extends UpdateCompanion<ProductEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> hindiName;
  final Value<String> category;
  final Value<double> mrpRupees;
  final Value<int> mrpPaise;
  final Value<int> piecePricePaise;
  final Value<int> stripQty;
  final Value<int> boxQty;
  final Value<double> gstRate;
  final Value<String> badge;
  final Value<String> imageUrl;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.hindiName = const Value.absent(),
    this.category = const Value.absent(),
    this.mrpRupees = const Value.absent(),
    this.mrpPaise = const Value.absent(),
    this.piecePricePaise = const Value.absent(),
    this.stripQty = const Value.absent(),
    this.boxQty = const Value.absent(),
    this.gstRate = const Value.absent(),
    this.badge = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String name,
    required String hindiName,
    required String category,
    required double mrpRupees,
    this.mrpPaise = const Value.absent(),
    required int piecePricePaise,
    required int stripQty,
    required int boxQty,
    this.gstRate = const Value.absent(),
    this.badge = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       hindiName = Value(hindiName),
       category = Value(category),
       mrpRupees = Value(mrpRupees),
       piecePricePaise = Value(piecePricePaise),
       stripQty = Value(stripQty),
       boxQty = Value(boxQty),
       createdAt = Value(createdAt);
  static Insertable<ProductEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? hindiName,
    Expression<String>? category,
    Expression<double>? mrpRupees,
    Expression<int>? mrpPaise,
    Expression<int>? piecePricePaise,
    Expression<int>? stripQty,
    Expression<int>? boxQty,
    Expression<double>? gstRate,
    Expression<String>? badge,
    Expression<String>? imageUrl,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (hindiName != null) 'hindi_name': hindiName,
      if (category != null) 'category': category,
      if (mrpRupees != null) 'mrp_rupees': mrpRupees,
      if (mrpPaise != null) 'mrp_paise': mrpPaise,
      if (piecePricePaise != null) 'piece_price_paise': piecePricePaise,
      if (stripQty != null) 'strip_qty': stripQty,
      if (boxQty != null) 'box_qty': boxQty,
      if (gstRate != null) 'gst_rate': gstRate,
      if (badge != null) 'badge': badge,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? hindiName,
    Value<String>? category,
    Value<double>? mrpRupees,
    Value<int>? mrpPaise,
    Value<int>? piecePricePaise,
    Value<int>? stripQty,
    Value<int>? boxQty,
    Value<double>? gstRate,
    Value<String>? badge,
    Value<String>? imageUrl,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      hindiName: hindiName ?? this.hindiName,
      category: category ?? this.category,
      mrpRupees: mrpRupees ?? this.mrpRupees,
      mrpPaise: mrpPaise ?? this.mrpPaise,
      piecePricePaise: piecePricePaise ?? this.piecePricePaise,
      stripQty: stripQty ?? this.stripQty,
      boxQty: boxQty ?? this.boxQty,
      gstRate: gstRate ?? this.gstRate,
      badge: badge ?? this.badge,
      imageUrl: imageUrl ?? this.imageUrl,
      isArchived: isArchived ?? this.isArchived,
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
    if (hindiName.present) {
      map['hindi_name'] = Variable<String>(hindiName.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (mrpRupees.present) {
      map['mrp_rupees'] = Variable<double>(mrpRupees.value);
    }
    if (mrpPaise.present) {
      map['mrp_paise'] = Variable<int>(mrpPaise.value);
    }
    if (piecePricePaise.present) {
      map['piece_price_paise'] = Variable<int>(piecePricePaise.value);
    }
    if (stripQty.present) {
      map['strip_qty'] = Variable<int>(stripQty.value);
    }
    if (boxQty.present) {
      map['box_qty'] = Variable<int>(boxQty.value);
    }
    if (gstRate.present) {
      map['gst_rate'] = Variable<double>(gstRate.value);
    }
    if (badge.present) {
      map['badge'] = Variable<String>(badge.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('hindiName: $hindiName, ')
          ..write('category: $category, ')
          ..write('mrpRupees: $mrpRupees, ')
          ..write('mrpPaise: $mrpPaise, ')
          ..write('piecePricePaise: $piecePricePaise, ')
          ..write('stripQty: $stripQty, ')
          ..write('boxQty: $boxQty, ')
          ..write('gstRate: $gstRate, ')
          ..write('badge: $badge, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RetailersTable extends Retailers
    with TableInfo<$RetailersTable, RetailerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RetailersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNameMeta = const VerificationMeta(
    'ownerName',
  );
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
    'owner_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditLimitPaiseMeta = const VerificationMeta(
    'creditLimitPaise',
  );
  @override
  late final GeneratedColumn<int> creditLimitPaise = GeneratedColumn<int>(
    'credit_limit_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outstandingPaiseMeta = const VerificationMeta(
    'outstandingPaise',
  );
  @override
  late final GeneratedColumn<int> outstandingPaise = GeneratedColumn<int>(
    'outstanding_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitedTodayMeta = const VerificationMeta(
    'visitedToday',
  );
  @override
  late final GeneratedColumn<bool> visitedToday = GeneratedColumn<bool>(
    'visited_today',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("visited_today" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _totalTimeSpentSecondsMeta =
      const VerificationMeta('totalTimeSpentSeconds');
  @override
  late final GeneratedColumn<int> totalTimeSpentSeconds = GeneratedColumn<int>(
    'total_time_spent_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _visitCountTodayMeta = const VerificationMeta(
    'visitCountToday',
  );
  @override
  late final GeneratedColumn<int> visitCountToday = GeneratedColumn<int>(
    'visit_count_today',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classTypeMeta = const VerificationMeta(
    'classType',
  );
  @override
  late final GeneratedColumn<String> classType = GeneratedColumn<String>(
    'class_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NEW'),
  );
  static const VerificationMeta _classSourceMeta = const VerificationMeta(
    'classSource',
  );
  @override
  late final GeneratedColumn<String> classSource = GeneratedColumn<String>(
    'class_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('MANUAL'),
  );
  static const VerificationMeta _routeIdMeta = const VerificationMeta(
    'routeId',
  );
  @override
  late final GeneratedColumn<String> routeId = GeneratedColumn<String>(
    'route_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shopTypeMeta = const VerificationMeta(
    'shopType',
  );
  @override
  late final GeneratedColumn<String> shopType = GeneratedColumn<String>(
    'shop_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('KIRANA'),
  );
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  @override
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
    'gstin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pincodeMeta = const VerificationMeta(
    'pincode',
  );
  @override
  late final GeneratedColumn<String> pincode = GeneratedColumn<String>(
    'pincode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _landmarkMeta = const VerificationMeta(
    'landmark',
  );
  @override
  late final GeneratedColumn<String> landmark = GeneratedColumn<String>(
    'landmark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ACTIVE'),
  );
  static const VerificationMeta _createdByUserIdMeta = const VerificationMeta(
    'createdByUserId',
  );
  @override
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
    'created_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationAccuracyMetersMeta =
      const VerificationMeta('locationAccuracyMeters');
  @override
  late final GeneratedColumn<double> locationAccuracyMeters =
      GeneratedColumn<double>(
        'location_accuracy_meters',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ownerName,
    phone,
    address,
    area,
    creditLimitPaise,
    outstandingPaise,
    visitedToday,
    totalTimeSpentSeconds,
    visitCountToday,
    latitude,
    longitude,
    classType,
    classSource,
    routeId,
    shopType,
    gstin,
    pincode,
    landmark,
    status,
    createdByUserId,
    locationAccuracyMeters,
    syncStatus,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'retailers';
  @override
  VerificationContext validateIntegrity(
    Insertable<RetailerEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('owner_name')) {
      context.handle(
        _ownerNameMeta,
        ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    } else if (isInserting) {
      context.missing(_areaMeta);
    }
    if (data.containsKey('credit_limit_paise')) {
      context.handle(
        _creditLimitPaiseMeta,
        creditLimitPaise.isAcceptableOrUnknown(
          data['credit_limit_paise']!,
          _creditLimitPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creditLimitPaiseMeta);
    }
    if (data.containsKey('outstanding_paise')) {
      context.handle(
        _outstandingPaiseMeta,
        outstandingPaise.isAcceptableOrUnknown(
          data['outstanding_paise']!,
          _outstandingPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outstandingPaiseMeta);
    }
    if (data.containsKey('visited_today')) {
      context.handle(
        _visitedTodayMeta,
        visitedToday.isAcceptableOrUnknown(
          data['visited_today']!,
          _visitedTodayMeta,
        ),
      );
    }
    if (data.containsKey('total_time_spent_seconds')) {
      context.handle(
        _totalTimeSpentSecondsMeta,
        totalTimeSpentSeconds.isAcceptableOrUnknown(
          data['total_time_spent_seconds']!,
          _totalTimeSpentSecondsMeta,
        ),
      );
    }
    if (data.containsKey('visit_count_today')) {
      context.handle(
        _visitCountTodayMeta,
        visitCountToday.isAcceptableOrUnknown(
          data['visit_count_today']!,
          _visitCountTodayMeta,
        ),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('class_type')) {
      context.handle(
        _classTypeMeta,
        classType.isAcceptableOrUnknown(data['class_type']!, _classTypeMeta),
      );
    }
    if (data.containsKey('class_source')) {
      context.handle(
        _classSourceMeta,
        classSource.isAcceptableOrUnknown(
          data['class_source']!,
          _classSourceMeta,
        ),
      );
    }
    if (data.containsKey('route_id')) {
      context.handle(
        _routeIdMeta,
        routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta),
      );
    }
    if (data.containsKey('shop_type')) {
      context.handle(
        _shopTypeMeta,
        shopType.isAcceptableOrUnknown(data['shop_type']!, _shopTypeMeta),
      );
    }
    if (data.containsKey('gstin')) {
      context.handle(
        _gstinMeta,
        gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta),
      );
    }
    if (data.containsKey('pincode')) {
      context.handle(
        _pincodeMeta,
        pincode.isAcceptableOrUnknown(data['pincode']!, _pincodeMeta),
      );
    }
    if (data.containsKey('landmark')) {
      context.handle(
        _landmarkMeta,
        landmark.isAcceptableOrUnknown(data['landmark']!, _landmarkMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
        _createdByUserIdMeta,
        createdByUserId.isAcceptableOrUnknown(
          data['created_by_user_id']!,
          _createdByUserIdMeta,
        ),
      );
    }
    if (data.containsKey('location_accuracy_meters')) {
      context.handle(
        _locationAccuracyMetersMeta,
        locationAccuracyMeters.isAcceptableOrUnknown(
          data['location_accuracy_meters']!,
          _locationAccuracyMetersMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RetailerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RetailerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ownerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      )!,
      creditLimitPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_limit_paise'],
      )!,
      outstandingPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}outstanding_paise'],
      )!,
      visitedToday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}visited_today'],
      )!,
      totalTimeSpentSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_time_spent_seconds'],
      )!,
      visitCountToday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visit_count_today'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      classType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_type'],
      )!,
      classSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_source'],
      )!,
      routeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_id'],
      ),
      shopType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_type'],
      )!,
      gstin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gstin'],
      ),
      pincode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pincode'],
      ),
      landmark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}landmark'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_user_id'],
      ),
      locationAccuracyMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}location_accuracy_meters'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RetailersTable createAlias(String alias) {
    return $RetailersTable(attachedDatabase, alias);
  }
}

class RetailerEntry extends DataClass implements Insertable<RetailerEntry> {
  final String id;
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String area;
  final int creditLimitPaise;
  final int outstandingPaise;
  final bool visitedToday;
  final int totalTimeSpentSeconds;
  final int visitCountToday;
  final double? latitude;
  final double? longitude;
  final String classType;
  final String classSource;
  final String? routeId;
  final String shopType;
  final String? gstin;
  final String? pincode;
  final String? landmark;
  final String status;
  final String? createdByUserId;
  final double? locationAccuracyMeters;
  final String syncStatus;
  final DateTime createdAt;
  const RetailerEntry({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.creditLimitPaise,
    required this.outstandingPaise,
    required this.visitedToday,
    required this.totalTimeSpentSeconds,
    required this.visitCountToday,
    this.latitude,
    this.longitude,
    required this.classType,
    required this.classSource,
    this.routeId,
    required this.shopType,
    this.gstin,
    this.pincode,
    this.landmark,
    required this.status,
    this.createdByUserId,
    this.locationAccuracyMeters,
    required this.syncStatus,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['owner_name'] = Variable<String>(ownerName);
    map['phone'] = Variable<String>(phone);
    map['address'] = Variable<String>(address);
    map['area'] = Variable<String>(area);
    map['credit_limit_paise'] = Variable<int>(creditLimitPaise);
    map['outstanding_paise'] = Variable<int>(outstandingPaise);
    map['visited_today'] = Variable<bool>(visitedToday);
    map['total_time_spent_seconds'] = Variable<int>(totalTimeSpentSeconds);
    map['visit_count_today'] = Variable<int>(visitCountToday);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['class_type'] = Variable<String>(classType);
    map['class_source'] = Variable<String>(classSource);
    if (!nullToAbsent || routeId != null) {
      map['route_id'] = Variable<String>(routeId);
    }
    map['shop_type'] = Variable<String>(shopType);
    if (!nullToAbsent || gstin != null) {
      map['gstin'] = Variable<String>(gstin);
    }
    if (!nullToAbsent || pincode != null) {
      map['pincode'] = Variable<String>(pincode);
    }
    if (!nullToAbsent || landmark != null) {
      map['landmark'] = Variable<String>(landmark);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || createdByUserId != null) {
      map['created_by_user_id'] = Variable<String>(createdByUserId);
    }
    if (!nullToAbsent || locationAccuracyMeters != null) {
      map['location_accuracy_meters'] = Variable<double>(
        locationAccuracyMeters,
      );
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RetailersCompanion toCompanion(bool nullToAbsent) {
    return RetailersCompanion(
      id: Value(id),
      name: Value(name),
      ownerName: Value(ownerName),
      phone: Value(phone),
      address: Value(address),
      area: Value(area),
      creditLimitPaise: Value(creditLimitPaise),
      outstandingPaise: Value(outstandingPaise),
      visitedToday: Value(visitedToday),
      totalTimeSpentSeconds: Value(totalTimeSpentSeconds),
      visitCountToday: Value(visitCountToday),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      classType: Value(classType),
      classSource: Value(classSource),
      routeId: routeId == null && nullToAbsent
          ? const Value.absent()
          : Value(routeId),
      shopType: Value(shopType),
      gstin: gstin == null && nullToAbsent
          ? const Value.absent()
          : Value(gstin),
      pincode: pincode == null && nullToAbsent
          ? const Value.absent()
          : Value(pincode),
      landmark: landmark == null && nullToAbsent
          ? const Value.absent()
          : Value(landmark),
      status: Value(status),
      createdByUserId: createdByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByUserId),
      locationAccuracyMeters: locationAccuracyMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(locationAccuracyMeters),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
    );
  }

  factory RetailerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RetailerEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ownerName: serializer.fromJson<String>(json['ownerName']),
      phone: serializer.fromJson<String>(json['phone']),
      address: serializer.fromJson<String>(json['address']),
      area: serializer.fromJson<String>(json['area']),
      creditLimitPaise: serializer.fromJson<int>(json['creditLimitPaise']),
      outstandingPaise: serializer.fromJson<int>(json['outstandingPaise']),
      visitedToday: serializer.fromJson<bool>(json['visitedToday']),
      totalTimeSpentSeconds: serializer.fromJson<int>(
        json['totalTimeSpentSeconds'],
      ),
      visitCountToday: serializer.fromJson<int>(json['visitCountToday']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      classType: serializer.fromJson<String>(json['classType']),
      classSource: serializer.fromJson<String>(json['classSource']),
      routeId: serializer.fromJson<String?>(json['routeId']),
      shopType: serializer.fromJson<String>(json['shopType']),
      gstin: serializer.fromJson<String?>(json['gstin']),
      pincode: serializer.fromJson<String?>(json['pincode']),
      landmark: serializer.fromJson<String?>(json['landmark']),
      status: serializer.fromJson<String>(json['status']),
      createdByUserId: serializer.fromJson<String?>(json['createdByUserId']),
      locationAccuracyMeters: serializer.fromJson<double?>(
        json['locationAccuracyMeters'],
      ),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'ownerName': serializer.toJson<String>(ownerName),
      'phone': serializer.toJson<String>(phone),
      'address': serializer.toJson<String>(address),
      'area': serializer.toJson<String>(area),
      'creditLimitPaise': serializer.toJson<int>(creditLimitPaise),
      'outstandingPaise': serializer.toJson<int>(outstandingPaise),
      'visitedToday': serializer.toJson<bool>(visitedToday),
      'totalTimeSpentSeconds': serializer.toJson<int>(totalTimeSpentSeconds),
      'visitCountToday': serializer.toJson<int>(visitCountToday),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'classType': serializer.toJson<String>(classType),
      'classSource': serializer.toJson<String>(classSource),
      'routeId': serializer.toJson<String?>(routeId),
      'shopType': serializer.toJson<String>(shopType),
      'gstin': serializer.toJson<String?>(gstin),
      'pincode': serializer.toJson<String?>(pincode),
      'landmark': serializer.toJson<String?>(landmark),
      'status': serializer.toJson<String>(status),
      'createdByUserId': serializer.toJson<String?>(createdByUserId),
      'locationAccuracyMeters': serializer.toJson<double?>(
        locationAccuracyMeters,
      ),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RetailerEntry copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? phone,
    String? address,
    String? area,
    int? creditLimitPaise,
    int? outstandingPaise,
    bool? visitedToday,
    int? totalTimeSpentSeconds,
    int? visitCountToday,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    String? classType,
    String? classSource,
    Value<String?> routeId = const Value.absent(),
    String? shopType,
    Value<String?> gstin = const Value.absent(),
    Value<String?> pincode = const Value.absent(),
    Value<String?> landmark = const Value.absent(),
    String? status,
    Value<String?> createdByUserId = const Value.absent(),
    Value<double?> locationAccuracyMeters = const Value.absent(),
    String? syncStatus,
    DateTime? createdAt,
  }) => RetailerEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    ownerName: ownerName ?? this.ownerName,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    area: area ?? this.area,
    creditLimitPaise: creditLimitPaise ?? this.creditLimitPaise,
    outstandingPaise: outstandingPaise ?? this.outstandingPaise,
    visitedToday: visitedToday ?? this.visitedToday,
    totalTimeSpentSeconds: totalTimeSpentSeconds ?? this.totalTimeSpentSeconds,
    visitCountToday: visitCountToday ?? this.visitCountToday,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    classType: classType ?? this.classType,
    classSource: classSource ?? this.classSource,
    routeId: routeId.present ? routeId.value : this.routeId,
    shopType: shopType ?? this.shopType,
    gstin: gstin.present ? gstin.value : this.gstin,
    pincode: pincode.present ? pincode.value : this.pincode,
    landmark: landmark.present ? landmark.value : this.landmark,
    status: status ?? this.status,
    createdByUserId: createdByUserId.present
        ? createdByUserId.value
        : this.createdByUserId,
    locationAccuracyMeters: locationAccuracyMeters.present
        ? locationAccuracyMeters.value
        : this.locationAccuracyMeters,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
  );
  RetailerEntry copyWithCompanion(RetailersCompanion data) {
    return RetailerEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      area: data.area.present ? data.area.value : this.area,
      creditLimitPaise: data.creditLimitPaise.present
          ? data.creditLimitPaise.value
          : this.creditLimitPaise,
      outstandingPaise: data.outstandingPaise.present
          ? data.outstandingPaise.value
          : this.outstandingPaise,
      visitedToday: data.visitedToday.present
          ? data.visitedToday.value
          : this.visitedToday,
      totalTimeSpentSeconds: data.totalTimeSpentSeconds.present
          ? data.totalTimeSpentSeconds.value
          : this.totalTimeSpentSeconds,
      visitCountToday: data.visitCountToday.present
          ? data.visitCountToday.value
          : this.visitCountToday,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      classType: data.classType.present ? data.classType.value : this.classType,
      classSource: data.classSource.present
          ? data.classSource.value
          : this.classSource,
      routeId: data.routeId.present ? data.routeId.value : this.routeId,
      shopType: data.shopType.present ? data.shopType.value : this.shopType,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      pincode: data.pincode.present ? data.pincode.value : this.pincode,
      landmark: data.landmark.present ? data.landmark.value : this.landmark,
      status: data.status.present ? data.status.value : this.status,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      locationAccuracyMeters: data.locationAccuracyMeters.present
          ? data.locationAccuracyMeters.value
          : this.locationAccuracyMeters,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RetailerEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ownerName: $ownerName, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('area: $area, ')
          ..write('creditLimitPaise: $creditLimitPaise, ')
          ..write('outstandingPaise: $outstandingPaise, ')
          ..write('visitedToday: $visitedToday, ')
          ..write('totalTimeSpentSeconds: $totalTimeSpentSeconds, ')
          ..write('visitCountToday: $visitCountToday, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('classType: $classType, ')
          ..write('classSource: $classSource, ')
          ..write('routeId: $routeId, ')
          ..write('shopType: $shopType, ')
          ..write('gstin: $gstin, ')
          ..write('pincode: $pincode, ')
          ..write('landmark: $landmark, ')
          ..write('status: $status, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('locationAccuracyMeters: $locationAccuracyMeters, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    ownerName,
    phone,
    address,
    area,
    creditLimitPaise,
    outstandingPaise,
    visitedToday,
    totalTimeSpentSeconds,
    visitCountToday,
    latitude,
    longitude,
    classType,
    classSource,
    routeId,
    shopType,
    gstin,
    pincode,
    landmark,
    status,
    createdByUserId,
    locationAccuracyMeters,
    syncStatus,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RetailerEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.ownerName == this.ownerName &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.area == this.area &&
          other.creditLimitPaise == this.creditLimitPaise &&
          other.outstandingPaise == this.outstandingPaise &&
          other.visitedToday == this.visitedToday &&
          other.totalTimeSpentSeconds == this.totalTimeSpentSeconds &&
          other.visitCountToday == this.visitCountToday &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.classType == this.classType &&
          other.classSource == this.classSource &&
          other.routeId == this.routeId &&
          other.shopType == this.shopType &&
          other.gstin == this.gstin &&
          other.pincode == this.pincode &&
          other.landmark == this.landmark &&
          other.status == this.status &&
          other.createdByUserId == this.createdByUserId &&
          other.locationAccuracyMeters == this.locationAccuracyMeters &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt);
}

class RetailersCompanion extends UpdateCompanion<RetailerEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> ownerName;
  final Value<String> phone;
  final Value<String> address;
  final Value<String> area;
  final Value<int> creditLimitPaise;
  final Value<int> outstandingPaise;
  final Value<bool> visitedToday;
  final Value<int> totalTimeSpentSeconds;
  final Value<int> visitCountToday;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String> classType;
  final Value<String> classSource;
  final Value<String?> routeId;
  final Value<String> shopType;
  final Value<String?> gstin;
  final Value<String?> pincode;
  final Value<String?> landmark;
  final Value<String> status;
  final Value<String?> createdByUserId;
  final Value<double?> locationAccuracyMeters;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RetailersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.area = const Value.absent(),
    this.creditLimitPaise = const Value.absent(),
    this.outstandingPaise = const Value.absent(),
    this.visitedToday = const Value.absent(),
    this.totalTimeSpentSeconds = const Value.absent(),
    this.visitCountToday = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.classType = const Value.absent(),
    this.classSource = const Value.absent(),
    this.routeId = const Value.absent(),
    this.shopType = const Value.absent(),
    this.gstin = const Value.absent(),
    this.pincode = const Value.absent(),
    this.landmark = const Value.absent(),
    this.status = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.locationAccuracyMeters = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RetailersCompanion.insert({
    required String id,
    required String name,
    required String ownerName,
    required String phone,
    required String address,
    required String area,
    required int creditLimitPaise,
    required int outstandingPaise,
    this.visitedToday = const Value.absent(),
    this.totalTimeSpentSeconds = const Value.absent(),
    this.visitCountToday = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.classType = const Value.absent(),
    this.classSource = const Value.absent(),
    this.routeId = const Value.absent(),
    this.shopType = const Value.absent(),
    this.gstin = const Value.absent(),
    this.pincode = const Value.absent(),
    this.landmark = const Value.absent(),
    this.status = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.locationAccuracyMeters = const Value.absent(),
    this.syncStatus = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       ownerName = Value(ownerName),
       phone = Value(phone),
       address = Value(address),
       area = Value(area),
       creditLimitPaise = Value(creditLimitPaise),
       outstandingPaise = Value(outstandingPaise),
       createdAt = Value(createdAt);
  static Insertable<RetailerEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? ownerName,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? area,
    Expression<int>? creditLimitPaise,
    Expression<int>? outstandingPaise,
    Expression<bool>? visitedToday,
    Expression<int>? totalTimeSpentSeconds,
    Expression<int>? visitCountToday,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? classType,
    Expression<String>? classSource,
    Expression<String>? routeId,
    Expression<String>? shopType,
    Expression<String>? gstin,
    Expression<String>? pincode,
    Expression<String>? landmark,
    Expression<String>? status,
    Expression<String>? createdByUserId,
    Expression<double>? locationAccuracyMeters,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ownerName != null) 'owner_name': ownerName,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (area != null) 'area': area,
      if (creditLimitPaise != null) 'credit_limit_paise': creditLimitPaise,
      if (outstandingPaise != null) 'outstanding_paise': outstandingPaise,
      if (visitedToday != null) 'visited_today': visitedToday,
      if (totalTimeSpentSeconds != null)
        'total_time_spent_seconds': totalTimeSpentSeconds,
      if (visitCountToday != null) 'visit_count_today': visitCountToday,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (classType != null) 'class_type': classType,
      if (classSource != null) 'class_source': classSource,
      if (routeId != null) 'route_id': routeId,
      if (shopType != null) 'shop_type': shopType,
      if (gstin != null) 'gstin': gstin,
      if (pincode != null) 'pincode': pincode,
      if (landmark != null) 'landmark': landmark,
      if (status != null) 'status': status,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (locationAccuracyMeters != null)
        'location_accuracy_meters': locationAccuracyMeters,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RetailersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? ownerName,
    Value<String>? phone,
    Value<String>? address,
    Value<String>? area,
    Value<int>? creditLimitPaise,
    Value<int>? outstandingPaise,
    Value<bool>? visitedToday,
    Value<int>? totalTimeSpentSeconds,
    Value<int>? visitCountToday,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String>? classType,
    Value<String>? classSource,
    Value<String?>? routeId,
    Value<String>? shopType,
    Value<String?>? gstin,
    Value<String?>? pincode,
    Value<String?>? landmark,
    Value<String>? status,
    Value<String?>? createdByUserId,
    Value<double?>? locationAccuracyMeters,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RetailersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      area: area ?? this.area,
      creditLimitPaise: creditLimitPaise ?? this.creditLimitPaise,
      outstandingPaise: outstandingPaise ?? this.outstandingPaise,
      visitedToday: visitedToday ?? this.visitedToday,
      totalTimeSpentSeconds:
          totalTimeSpentSeconds ?? this.totalTimeSpentSeconds,
      visitCountToday: visitCountToday ?? this.visitCountToday,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      classType: classType ?? this.classType,
      classSource: classSource ?? this.classSource,
      routeId: routeId ?? this.routeId,
      shopType: shopType ?? this.shopType,
      gstin: gstin ?? this.gstin,
      pincode: pincode ?? this.pincode,
      landmark: landmark ?? this.landmark,
      status: status ?? this.status,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      locationAccuracyMeters:
          locationAccuracyMeters ?? this.locationAccuracyMeters,
      syncStatus: syncStatus ?? this.syncStatus,
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
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (creditLimitPaise.present) {
      map['credit_limit_paise'] = Variable<int>(creditLimitPaise.value);
    }
    if (outstandingPaise.present) {
      map['outstanding_paise'] = Variable<int>(outstandingPaise.value);
    }
    if (visitedToday.present) {
      map['visited_today'] = Variable<bool>(visitedToday.value);
    }
    if (totalTimeSpentSeconds.present) {
      map['total_time_spent_seconds'] = Variable<int>(
        totalTimeSpentSeconds.value,
      );
    }
    if (visitCountToday.present) {
      map['visit_count_today'] = Variable<int>(visitCountToday.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (classType.present) {
      map['class_type'] = Variable<String>(classType.value);
    }
    if (classSource.present) {
      map['class_source'] = Variable<String>(classSource.value);
    }
    if (routeId.present) {
      map['route_id'] = Variable<String>(routeId.value);
    }
    if (shopType.present) {
      map['shop_type'] = Variable<String>(shopType.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (pincode.present) {
      map['pincode'] = Variable<String>(pincode.value);
    }
    if (landmark.present) {
      map['landmark'] = Variable<String>(landmark.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (locationAccuracyMeters.present) {
      map['location_accuracy_meters'] = Variable<double>(
        locationAccuracyMeters.value,
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RetailersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ownerName: $ownerName, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('area: $area, ')
          ..write('creditLimitPaise: $creditLimitPaise, ')
          ..write('outstandingPaise: $outstandingPaise, ')
          ..write('visitedToday: $visitedToday, ')
          ..write('totalTimeSpentSeconds: $totalTimeSpentSeconds, ')
          ..write('visitCountToday: $visitCountToday, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('classType: $classType, ')
          ..write('classSource: $classSource, ')
          ..write('routeId: $routeId, ')
          ..write('shopType: $shopType, ')
          ..write('gstin: $gstin, ')
          ..write('pincode: $pincode, ')
          ..write('landmark: $landmark, ')
          ..write('status: $status, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('locationAccuracyMeters: $locationAccuracyMeters, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventorySnapshotsTable extends InventorySnapshots
    with TableInfo<$InventorySnapshotsTable, InventorySnapshotEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventorySnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _godownCartonsMeta = const VerificationMeta(
    'godownCartons',
  );
  @override
  late final GeneratedColumn<int> godownCartons = GeneratedColumn<int>(
    'godown_cartons',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _godownLoosePiecesMeta = const VerificationMeta(
    'godownLoosePieces',
  );
  @override
  late final GeneratedColumn<int> godownLoosePieces = GeneratedColumn<int>(
    'godown_loose_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _carCartonsMeta = const VerificationMeta(
    'carCartons',
  );
  @override
  late final GeneratedColumn<int> carCartons = GeneratedColumn<int>(
    'car_cartons',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _carLoosePiecesMeta = const VerificationMeta(
    'carLoosePieces',
  );
  @override
  late final GeneratedColumn<int> carLoosePieces = GeneratedColumn<int>(
    'car_loose_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _damagedCartonsMeta = const VerificationMeta(
    'damagedCartons',
  );
  @override
  late final GeneratedColumn<int> damagedCartons = GeneratedColumn<int>(
    'damaged_cartons',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _damagedLoosePiecesMeta =
      const VerificationMeta('damagedLoosePieces');
  @override
  late final GeneratedColumn<int> damagedLoosePieces = GeneratedColumn<int>(
    'damaged_loose_pieces',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    productId,
    godownCartons,
    godownLoosePieces,
    carCartons,
    carLoosePieces,
    damagedCartons,
    damagedLoosePieces,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<InventorySnapshotEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('godown_cartons')) {
      context.handle(
        _godownCartonsMeta,
        godownCartons.isAcceptableOrUnknown(
          data['godown_cartons']!,
          _godownCartonsMeta,
        ),
      );
    }
    if (data.containsKey('godown_loose_pieces')) {
      context.handle(
        _godownLoosePiecesMeta,
        godownLoosePieces.isAcceptableOrUnknown(
          data['godown_loose_pieces']!,
          _godownLoosePiecesMeta,
        ),
      );
    }
    if (data.containsKey('car_cartons')) {
      context.handle(
        _carCartonsMeta,
        carCartons.isAcceptableOrUnknown(data['car_cartons']!, _carCartonsMeta),
      );
    }
    if (data.containsKey('car_loose_pieces')) {
      context.handle(
        _carLoosePiecesMeta,
        carLoosePieces.isAcceptableOrUnknown(
          data['car_loose_pieces']!,
          _carLoosePiecesMeta,
        ),
      );
    }
    if (data.containsKey('damaged_cartons')) {
      context.handle(
        _damagedCartonsMeta,
        damagedCartons.isAcceptableOrUnknown(
          data['damaged_cartons']!,
          _damagedCartonsMeta,
        ),
      );
    }
    if (data.containsKey('damaged_loose_pieces')) {
      context.handle(
        _damagedLoosePiecesMeta,
        damagedLoosePieces.isAcceptableOrUnknown(
          data['damaged_loose_pieces']!,
          _damagedLoosePiecesMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {productId};
  @override
  InventorySnapshotEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventorySnapshotEntry(
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      godownCartons: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}godown_cartons'],
      )!,
      godownLoosePieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}godown_loose_pieces'],
      )!,
      carCartons: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}car_cartons'],
      )!,
      carLoosePieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}car_loose_pieces'],
      )!,
      damagedCartons: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}damaged_cartons'],
      )!,
      damagedLoosePieces: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}damaged_loose_pieces'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $InventorySnapshotsTable createAlias(String alias) {
    return $InventorySnapshotsTable(attachedDatabase, alias);
  }
}

class InventorySnapshotEntry extends DataClass
    implements Insertable<InventorySnapshotEntry> {
  final String productId;
  final int godownCartons;
  final int godownLoosePieces;
  final int carCartons;
  final int carLoosePieces;
  final int damagedCartons;
  final int damagedLoosePieces;
  final DateTime updatedAt;
  const InventorySnapshotEntry({
    required this.productId,
    required this.godownCartons,
    required this.godownLoosePieces,
    required this.carCartons,
    required this.carLoosePieces,
    required this.damagedCartons,
    required this.damagedLoosePieces,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['product_id'] = Variable<String>(productId);
    map['godown_cartons'] = Variable<int>(godownCartons);
    map['godown_loose_pieces'] = Variable<int>(godownLoosePieces);
    map['car_cartons'] = Variable<int>(carCartons);
    map['car_loose_pieces'] = Variable<int>(carLoosePieces);
    map['damaged_cartons'] = Variable<int>(damagedCartons);
    map['damaged_loose_pieces'] = Variable<int>(damagedLoosePieces);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InventorySnapshotsCompanion toCompanion(bool nullToAbsent) {
    return InventorySnapshotsCompanion(
      productId: Value(productId),
      godownCartons: Value(godownCartons),
      godownLoosePieces: Value(godownLoosePieces),
      carCartons: Value(carCartons),
      carLoosePieces: Value(carLoosePieces),
      damagedCartons: Value(damagedCartons),
      damagedLoosePieces: Value(damagedLoosePieces),
      updatedAt: Value(updatedAt),
    );
  }

  factory InventorySnapshotEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventorySnapshotEntry(
      productId: serializer.fromJson<String>(json['productId']),
      godownCartons: serializer.fromJson<int>(json['godownCartons']),
      godownLoosePieces: serializer.fromJson<int>(json['godownLoosePieces']),
      carCartons: serializer.fromJson<int>(json['carCartons']),
      carLoosePieces: serializer.fromJson<int>(json['carLoosePieces']),
      damagedCartons: serializer.fromJson<int>(json['damagedCartons']),
      damagedLoosePieces: serializer.fromJson<int>(json['damagedLoosePieces']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'productId': serializer.toJson<String>(productId),
      'godownCartons': serializer.toJson<int>(godownCartons),
      'godownLoosePieces': serializer.toJson<int>(godownLoosePieces),
      'carCartons': serializer.toJson<int>(carCartons),
      'carLoosePieces': serializer.toJson<int>(carLoosePieces),
      'damagedCartons': serializer.toJson<int>(damagedCartons),
      'damagedLoosePieces': serializer.toJson<int>(damagedLoosePieces),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InventorySnapshotEntry copyWith({
    String? productId,
    int? godownCartons,
    int? godownLoosePieces,
    int? carCartons,
    int? carLoosePieces,
    int? damagedCartons,
    int? damagedLoosePieces,
    DateTime? updatedAt,
  }) => InventorySnapshotEntry(
    productId: productId ?? this.productId,
    godownCartons: godownCartons ?? this.godownCartons,
    godownLoosePieces: godownLoosePieces ?? this.godownLoosePieces,
    carCartons: carCartons ?? this.carCartons,
    carLoosePieces: carLoosePieces ?? this.carLoosePieces,
    damagedCartons: damagedCartons ?? this.damagedCartons,
    damagedLoosePieces: damagedLoosePieces ?? this.damagedLoosePieces,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InventorySnapshotEntry copyWithCompanion(InventorySnapshotsCompanion data) {
    return InventorySnapshotEntry(
      productId: data.productId.present ? data.productId.value : this.productId,
      godownCartons: data.godownCartons.present
          ? data.godownCartons.value
          : this.godownCartons,
      godownLoosePieces: data.godownLoosePieces.present
          ? data.godownLoosePieces.value
          : this.godownLoosePieces,
      carCartons: data.carCartons.present
          ? data.carCartons.value
          : this.carCartons,
      carLoosePieces: data.carLoosePieces.present
          ? data.carLoosePieces.value
          : this.carLoosePieces,
      damagedCartons: data.damagedCartons.present
          ? data.damagedCartons.value
          : this.damagedCartons,
      damagedLoosePieces: data.damagedLoosePieces.present
          ? data.damagedLoosePieces.value
          : this.damagedLoosePieces,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventorySnapshotEntry(')
          ..write('productId: $productId, ')
          ..write('godownCartons: $godownCartons, ')
          ..write('godownLoosePieces: $godownLoosePieces, ')
          ..write('carCartons: $carCartons, ')
          ..write('carLoosePieces: $carLoosePieces, ')
          ..write('damagedCartons: $damagedCartons, ')
          ..write('damagedLoosePieces: $damagedLoosePieces, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    productId,
    godownCartons,
    godownLoosePieces,
    carCartons,
    carLoosePieces,
    damagedCartons,
    damagedLoosePieces,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventorySnapshotEntry &&
          other.productId == this.productId &&
          other.godownCartons == this.godownCartons &&
          other.godownLoosePieces == this.godownLoosePieces &&
          other.carCartons == this.carCartons &&
          other.carLoosePieces == this.carLoosePieces &&
          other.damagedCartons == this.damagedCartons &&
          other.damagedLoosePieces == this.damagedLoosePieces &&
          other.updatedAt == this.updatedAt);
}

class InventorySnapshotsCompanion
    extends UpdateCompanion<InventorySnapshotEntry> {
  final Value<String> productId;
  final Value<int> godownCartons;
  final Value<int> godownLoosePieces;
  final Value<int> carCartons;
  final Value<int> carLoosePieces;
  final Value<int> damagedCartons;
  final Value<int> damagedLoosePieces;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InventorySnapshotsCompanion({
    this.productId = const Value.absent(),
    this.godownCartons = const Value.absent(),
    this.godownLoosePieces = const Value.absent(),
    this.carCartons = const Value.absent(),
    this.carLoosePieces = const Value.absent(),
    this.damagedCartons = const Value.absent(),
    this.damagedLoosePieces = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventorySnapshotsCompanion.insert({
    required String productId,
    this.godownCartons = const Value.absent(),
    this.godownLoosePieces = const Value.absent(),
    this.carCartons = const Value.absent(),
    this.carLoosePieces = const Value.absent(),
    this.damagedCartons = const Value.absent(),
    this.damagedLoosePieces = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : productId = Value(productId),
       updatedAt = Value(updatedAt);
  static Insertable<InventorySnapshotEntry> custom({
    Expression<String>? productId,
    Expression<int>? godownCartons,
    Expression<int>? godownLoosePieces,
    Expression<int>? carCartons,
    Expression<int>? carLoosePieces,
    Expression<int>? damagedCartons,
    Expression<int>? damagedLoosePieces,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (godownCartons != null) 'godown_cartons': godownCartons,
      if (godownLoosePieces != null) 'godown_loose_pieces': godownLoosePieces,
      if (carCartons != null) 'car_cartons': carCartons,
      if (carLoosePieces != null) 'car_loose_pieces': carLoosePieces,
      if (damagedCartons != null) 'damaged_cartons': damagedCartons,
      if (damagedLoosePieces != null)
        'damaged_loose_pieces': damagedLoosePieces,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventorySnapshotsCompanion copyWith({
    Value<String>? productId,
    Value<int>? godownCartons,
    Value<int>? godownLoosePieces,
    Value<int>? carCartons,
    Value<int>? carLoosePieces,
    Value<int>? damagedCartons,
    Value<int>? damagedLoosePieces,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InventorySnapshotsCompanion(
      productId: productId ?? this.productId,
      godownCartons: godownCartons ?? this.godownCartons,
      godownLoosePieces: godownLoosePieces ?? this.godownLoosePieces,
      carCartons: carCartons ?? this.carCartons,
      carLoosePieces: carLoosePieces ?? this.carLoosePieces,
      damagedCartons: damagedCartons ?? this.damagedCartons,
      damagedLoosePieces: damagedLoosePieces ?? this.damagedLoosePieces,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (godownCartons.present) {
      map['godown_cartons'] = Variable<int>(godownCartons.value);
    }
    if (godownLoosePieces.present) {
      map['godown_loose_pieces'] = Variable<int>(godownLoosePieces.value);
    }
    if (carCartons.present) {
      map['car_cartons'] = Variable<int>(carCartons.value);
    }
    if (carLoosePieces.present) {
      map['car_loose_pieces'] = Variable<int>(carLoosePieces.value);
    }
    if (damagedCartons.present) {
      map['damaged_cartons'] = Variable<int>(damagedCartons.value);
    }
    if (damagedLoosePieces.present) {
      map['damaged_loose_pieces'] = Variable<int>(damagedLoosePieces.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventorySnapshotsCompanion(')
          ..write('productId: $productId, ')
          ..write('godownCartons: $godownCartons, ')
          ..write('godownLoosePieces: $godownLoosePieces, ')
          ..write('carCartons: $carCartons, ')
          ..write('carLoosePieces: $carLoosePieces, ')
          ..write('damagedCartons: $damagedCartons, ')
          ..write('damagedLoosePieces: $damagedLoosePieces, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryMovementsTable extends InventoryMovements
    with TableInfo<$InventoryMovementsTable, InventoryMovementEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _movementTypeMeta = const VerificationMeta(
    'movementType',
  );
  @override
  late final GeneratedColumn<String> movementType = GeneratedColumn<String>(
    'movement_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cartonDeltaMeta = const VerificationMeta(
    'cartonDelta',
  );
  @override
  late final GeneratedColumn<int> cartonDelta = GeneratedColumn<int>(
    'carton_delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loosePieceDeltaMeta = const VerificationMeta(
    'loosePieceDelta',
  );
  @override
  late final GeneratedColumn<int> loosePieceDelta = GeneratedColumn<int>(
    'loose_piece_delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invoiceNumberMeta = const VerificationMeta(
    'invoiceNumber',
  );
  @override
  late final GeneratedColumn<String> invoiceNumber = GeneratedColumn<String>(
    'invoice_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batchNumberMeta = const VerificationMeta(
    'batchNumber',
  );
  @override
  late final GeneratedColumn<String> batchNumber = GeneratedColumn<String>(
    'batch_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supplierNameMeta = const VerificationMeta(
    'supplierName',
  );
  @override
  late final GeneratedColumn<String> supplierName = GeneratedColumn<String>(
    'supplier_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    movementType,
    cartonDelta,
    loosePieceDelta,
    reason,
    locationId,
    invoiceNumber,
    batchNumber,
    supplierName,
    idempotencyKey,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<InventoryMovementEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('movement_type')) {
      context.handle(
        _movementTypeMeta,
        movementType.isAcceptableOrUnknown(
          data['movement_type']!,
          _movementTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_movementTypeMeta);
    }
    if (data.containsKey('carton_delta')) {
      context.handle(
        _cartonDeltaMeta,
        cartonDelta.isAcceptableOrUnknown(
          data['carton_delta']!,
          _cartonDeltaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cartonDeltaMeta);
    }
    if (data.containsKey('loose_piece_delta')) {
      context.handle(
        _loosePieceDeltaMeta,
        loosePieceDelta.isAcceptableOrUnknown(
          data['loose_piece_delta']!,
          _loosePieceDeltaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loosePieceDeltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('invoice_number')) {
      context.handle(
        _invoiceNumberMeta,
        invoiceNumber.isAcceptableOrUnknown(
          data['invoice_number']!,
          _invoiceNumberMeta,
        ),
      );
    }
    if (data.containsKey('batch_number')) {
      context.handle(
        _batchNumberMeta,
        batchNumber.isAcceptableOrUnknown(
          data['batch_number']!,
          _batchNumberMeta,
        ),
      );
    }
    if (data.containsKey('supplier_name')) {
      context.handle(
        _supplierNameMeta,
        supplierName.isAcceptableOrUnknown(
          data['supplier_name']!,
          _supplierNameMeta,
        ),
      );
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryMovementEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryMovementEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      movementType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}movement_type'],
      )!,
      cartonDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carton_delta'],
      )!,
      loosePieceDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loose_piece_delta'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      invoiceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_number'],
      ),
      batchNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_number'],
      ),
      supplierName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_name'],
      ),
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $InventoryMovementsTable createAlias(String alias) {
    return $InventoryMovementsTable(attachedDatabase, alias);
  }
}

class InventoryMovementEntry extends DataClass
    implements Insertable<InventoryMovementEntry> {
  final String id;
  final String productId;
  final String movementType;
  final int cartonDelta;
  final int loosePieceDelta;
  final String reason;
  final String? locationId;
  final String? invoiceNumber;
  final String? batchNumber;
  final String? supplierName;
  final String? idempotencyKey;
  final DateTime createdAt;
  const InventoryMovementEntry({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.cartonDelta,
    required this.loosePieceDelta,
    required this.reason,
    this.locationId,
    this.invoiceNumber,
    this.batchNumber,
    this.supplierName,
    this.idempotencyKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['movement_type'] = Variable<String>(movementType);
    map['carton_delta'] = Variable<int>(cartonDelta);
    map['loose_piece_delta'] = Variable<int>(loosePieceDelta);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    if (!nullToAbsent || invoiceNumber != null) {
      map['invoice_number'] = Variable<String>(invoiceNumber);
    }
    if (!nullToAbsent || batchNumber != null) {
      map['batch_number'] = Variable<String>(batchNumber);
    }
    if (!nullToAbsent || supplierName != null) {
      map['supplier_name'] = Variable<String>(supplierName);
    }
    if (!nullToAbsent || idempotencyKey != null) {
      map['idempotency_key'] = Variable<String>(idempotencyKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  InventoryMovementsCompanion toCompanion(bool nullToAbsent) {
    return InventoryMovementsCompanion(
      id: Value(id),
      productId: Value(productId),
      movementType: Value(movementType),
      cartonDelta: Value(cartonDelta),
      loosePieceDelta: Value(loosePieceDelta),
      reason: Value(reason),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      invoiceNumber: invoiceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceNumber),
      batchNumber: batchNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(batchNumber),
      supplierName: supplierName == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierName),
      idempotencyKey: idempotencyKey == null && nullToAbsent
          ? const Value.absent()
          : Value(idempotencyKey),
      createdAt: Value(createdAt),
    );
  }

  factory InventoryMovementEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryMovementEntry(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      movementType: serializer.fromJson<String>(json['movementType']),
      cartonDelta: serializer.fromJson<int>(json['cartonDelta']),
      loosePieceDelta: serializer.fromJson<int>(json['loosePieceDelta']),
      reason: serializer.fromJson<String>(json['reason']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      invoiceNumber: serializer.fromJson<String?>(json['invoiceNumber']),
      batchNumber: serializer.fromJson<String?>(json['batchNumber']),
      supplierName: serializer.fromJson<String?>(json['supplierName']),
      idempotencyKey: serializer.fromJson<String?>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'movementType': serializer.toJson<String>(movementType),
      'cartonDelta': serializer.toJson<int>(cartonDelta),
      'loosePieceDelta': serializer.toJson<int>(loosePieceDelta),
      'reason': serializer.toJson<String>(reason),
      'locationId': serializer.toJson<String?>(locationId),
      'invoiceNumber': serializer.toJson<String?>(invoiceNumber),
      'batchNumber': serializer.toJson<String?>(batchNumber),
      'supplierName': serializer.toJson<String?>(supplierName),
      'idempotencyKey': serializer.toJson<String?>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  InventoryMovementEntry copyWith({
    String? id,
    String? productId,
    String? movementType,
    int? cartonDelta,
    int? loosePieceDelta,
    String? reason,
    Value<String?> locationId = const Value.absent(),
    Value<String?> invoiceNumber = const Value.absent(),
    Value<String?> batchNumber = const Value.absent(),
    Value<String?> supplierName = const Value.absent(),
    Value<String?> idempotencyKey = const Value.absent(),
    DateTime? createdAt,
  }) => InventoryMovementEntry(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    movementType: movementType ?? this.movementType,
    cartonDelta: cartonDelta ?? this.cartonDelta,
    loosePieceDelta: loosePieceDelta ?? this.loosePieceDelta,
    reason: reason ?? this.reason,
    locationId: locationId.present ? locationId.value : this.locationId,
    invoiceNumber: invoiceNumber.present
        ? invoiceNumber.value
        : this.invoiceNumber,
    batchNumber: batchNumber.present ? batchNumber.value : this.batchNumber,
    supplierName: supplierName.present ? supplierName.value : this.supplierName,
    idempotencyKey: idempotencyKey.present
        ? idempotencyKey.value
        : this.idempotencyKey,
    createdAt: createdAt ?? this.createdAt,
  );
  InventoryMovementEntry copyWithCompanion(InventoryMovementsCompanion data) {
    return InventoryMovementEntry(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      movementType: data.movementType.present
          ? data.movementType.value
          : this.movementType,
      cartonDelta: data.cartonDelta.present
          ? data.cartonDelta.value
          : this.cartonDelta,
      loosePieceDelta: data.loosePieceDelta.present
          ? data.loosePieceDelta.value
          : this.loosePieceDelta,
      reason: data.reason.present ? data.reason.value : this.reason,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      invoiceNumber: data.invoiceNumber.present
          ? data.invoiceNumber.value
          : this.invoiceNumber,
      batchNumber: data.batchNumber.present
          ? data.batchNumber.value
          : this.batchNumber,
      supplierName: data.supplierName.present
          ? data.supplierName.value
          : this.supplierName,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryMovementEntry(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('movementType: $movementType, ')
          ..write('cartonDelta: $cartonDelta, ')
          ..write('loosePieceDelta: $loosePieceDelta, ')
          ..write('reason: $reason, ')
          ..write('locationId: $locationId, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('supplierName: $supplierName, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    movementType,
    cartonDelta,
    loosePieceDelta,
    reason,
    locationId,
    invoiceNumber,
    batchNumber,
    supplierName,
    idempotencyKey,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryMovementEntry &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.movementType == this.movementType &&
          other.cartonDelta == this.cartonDelta &&
          other.loosePieceDelta == this.loosePieceDelta &&
          other.reason == this.reason &&
          other.locationId == this.locationId &&
          other.invoiceNumber == this.invoiceNumber &&
          other.batchNumber == this.batchNumber &&
          other.supplierName == this.supplierName &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt);
}

class InventoryMovementsCompanion
    extends UpdateCompanion<InventoryMovementEntry> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> movementType;
  final Value<int> cartonDelta;
  final Value<int> loosePieceDelta;
  final Value<String> reason;
  final Value<String?> locationId;
  final Value<String?> invoiceNumber;
  final Value<String?> batchNumber;
  final Value<String?> supplierName;
  final Value<String?> idempotencyKey;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const InventoryMovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.movementType = const Value.absent(),
    this.cartonDelta = const Value.absent(),
    this.loosePieceDelta = const Value.absent(),
    this.reason = const Value.absent(),
    this.locationId = const Value.absent(),
    this.invoiceNumber = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryMovementsCompanion.insert({
    required String id,
    required String productId,
    required String movementType,
    required int cartonDelta,
    required int loosePieceDelta,
    this.reason = const Value.absent(),
    this.locationId = const Value.absent(),
    this.invoiceNumber = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       movementType = Value(movementType),
       cartonDelta = Value(cartonDelta),
       loosePieceDelta = Value(loosePieceDelta),
       createdAt = Value(createdAt);
  static Insertable<InventoryMovementEntry> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? movementType,
    Expression<int>? cartonDelta,
    Expression<int>? loosePieceDelta,
    Expression<String>? reason,
    Expression<String>? locationId,
    Expression<String>? invoiceNumber,
    Expression<String>? batchNumber,
    Expression<String>? supplierName,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (movementType != null) 'movement_type': movementType,
      if (cartonDelta != null) 'carton_delta': cartonDelta,
      if (loosePieceDelta != null) 'loose_piece_delta': loosePieceDelta,
      if (reason != null) 'reason': reason,
      if (locationId != null) 'location_id': locationId,
      if (invoiceNumber != null) 'invoice_number': invoiceNumber,
      if (batchNumber != null) 'batch_number': batchNumber,
      if (supplierName != null) 'supplier_name': supplierName,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<String>? movementType,
    Value<int>? cartonDelta,
    Value<int>? loosePieceDelta,
    Value<String>? reason,
    Value<String?>? locationId,
    Value<String?>? invoiceNumber,
    Value<String?>? batchNumber,
    Value<String?>? supplierName,
    Value<String?>? idempotencyKey,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return InventoryMovementsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      movementType: movementType ?? this.movementType,
      cartonDelta: cartonDelta ?? this.cartonDelta,
      loosePieceDelta: loosePieceDelta ?? this.loosePieceDelta,
      reason: reason ?? this.reason,
      locationId: locationId ?? this.locationId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      batchNumber: batchNumber ?? this.batchNumber,
      supplierName: supplierName ?? this.supplierName,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
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
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (movementType.present) {
      map['movement_type'] = Variable<String>(movementType.value);
    }
    if (cartonDelta.present) {
      map['carton_delta'] = Variable<int>(cartonDelta.value);
    }
    if (loosePieceDelta.present) {
      map['loose_piece_delta'] = Variable<int>(loosePieceDelta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (invoiceNumber.present) {
      map['invoice_number'] = Variable<String>(invoiceNumber.value);
    }
    if (batchNumber.present) {
      map['batch_number'] = Variable<String>(batchNumber.value);
    }
    if (supplierName.present) {
      map['supplier_name'] = Variable<String>(supplierName.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryMovementsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('movementType: $movementType, ')
          ..write('cartonDelta: $cartonDelta, ')
          ..write('loosePieceDelta: $loosePieceDelta, ')
          ..write('reason: $reason, ')
          ..write('locationId: $locationId, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('supplierName: $supplierName, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DatabaseMetadataTable extends DatabaseMetadata
    with TableInfo<$DatabaseMetadataTable, DatabaseMetadataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatabaseMetadataTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'database_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<DatabaseMetadataEntry> instance, {
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DatabaseMetadataEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatabaseMetadataEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DatabaseMetadataTable createAlias(String alias) {
    return $DatabaseMetadataTable(attachedDatabase, alias);
  }
}

class DatabaseMetadataEntry extends DataClass
    implements Insertable<DatabaseMetadataEntry> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const DatabaseMetadataEntry({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DatabaseMetadataCompanion toCompanion(bool nullToAbsent) {
    return DatabaseMetadataCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory DatabaseMetadataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatabaseMetadataEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DatabaseMetadataEntry copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => DatabaseMetadataEntry(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DatabaseMetadataEntry copyWithCompanion(DatabaseMetadataCompanion data) {
    return DatabaseMetadataEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatabaseMetadataEntry(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatabaseMetadataEntry &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class DatabaseMetadataCompanion extends UpdateCompanion<DatabaseMetadataEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DatabaseMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatabaseMetadataCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<DatabaseMetadataEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatabaseMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DatabaseMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatabaseMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxMutationsTable extends OutboxMutations
    with TableInfo<$OutboxMutationsTable, OutboxMutationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _organizationIdMeta = const VerificationMeta(
    'organizationId',
  );
  @override
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _mutationTypeMeta = const VerificationMeta(
    'mutationType',
  );
  @override
  late final GeneratedColumn<String> mutationType = GeneratedColumn<String>(
    'mutation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceOrderMeta = const VerificationMeta(
    'sequenceOrder',
  );
  @override
  late final GeneratedColumn<int> sequenceOrder = GeneratedColumn<int>(
    'sequence_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _provisionalBusinessIdMeta =
      const VerificationMeta('provisionalBusinessId');
  @override
  late final GeneratedColumn<String> provisionalBusinessId =
      GeneratedColumn<String>(
        'provisional_business_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _leaseTokenMeta = const VerificationMeta(
    'leaseToken',
  );
  @override
  late final GeneratedColumn<String> leaseToken = GeneratedColumn<String>(
    'lease_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseGenerationMeta = const VerificationMeta(
    'leaseGeneration',
  );
  @override
  late final GeneratedColumn<int> leaseGeneration = GeneratedColumn<int>(
    'lease_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _leaseExpiresAtMsMeta = const VerificationMeta(
    'leaseExpiresAtMs',
  );
  @override
  late final GeneratedColumn<int> leaseExpiresAtMs = GeneratedColumn<int>(
    'lease_expires_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextRetryAtMsMeta = const VerificationMeta(
    'nextRetryAtMs',
  );
  @override
  late final GeneratedColumn<int> nextRetryAtMs = GeneratedColumn<int>(
    'next_retry_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtEpochMsMeta = const VerificationMeta(
    'syncedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> syncedAtEpochMs = GeneratedColumn<int>(
    'synced_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    userId,
    idempotencyKey,
    mutationType,
    payloadJson,
    sequenceOrder,
    syncStatus,
    provisionalBusinessId,
    leaseToken,
    leaseGeneration,
    leaseExpiresAtMs,
    attemptCount,
    lastErrorCode,
    nextRetryAtMs,
    createdAtEpochMs,
    syncedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxMutationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('organization_id')) {
      context.handle(
        _organizationIdMeta,
        organizationId.isAcceptableOrUnknown(
          data['organization_id']!,
          _organizationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_organizationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('mutation_type')) {
      context.handle(
        _mutationTypeMeta,
        mutationType.isAcceptableOrUnknown(
          data['mutation_type']!,
          _mutationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mutationTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('sequence_order')) {
      context.handle(
        _sequenceOrderMeta,
        sequenceOrder.isAcceptableOrUnknown(
          data['sequence_order']!,
          _sequenceOrderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceOrderMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('provisional_business_id')) {
      context.handle(
        _provisionalBusinessIdMeta,
        provisionalBusinessId.isAcceptableOrUnknown(
          data['provisional_business_id']!,
          _provisionalBusinessIdMeta,
        ),
      );
    }
    if (data.containsKey('lease_token')) {
      context.handle(
        _leaseTokenMeta,
        leaseToken.isAcceptableOrUnknown(data['lease_token']!, _leaseTokenMeta),
      );
    }
    if (data.containsKey('lease_generation')) {
      context.handle(
        _leaseGenerationMeta,
        leaseGeneration.isAcceptableOrUnknown(
          data['lease_generation']!,
          _leaseGenerationMeta,
        ),
      );
    }
    if (data.containsKey('lease_expires_at_ms')) {
      context.handle(
        _leaseExpiresAtMsMeta,
        leaseExpiresAtMs.isAcceptableOrUnknown(
          data['lease_expires_at_ms']!,
          _leaseExpiresAtMsMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('next_retry_at_ms')) {
      context.handle(
        _nextRetryAtMsMeta,
        nextRetryAtMs.isAcceptableOrUnknown(
          data['next_retry_at_ms']!,
          _nextRetryAtMsMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('synced_at_epoch_ms')) {
      context.handle(
        _syncedAtEpochMsMeta,
        syncedAtEpochMs.isAcceptableOrUnknown(
          data['synced_at_epoch_ms']!,
          _syncedAtEpochMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxMutationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxMutationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      mutationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      sequenceOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_order'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      provisionalBusinessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provisional_business_id'],
      ),
      leaseToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_token'],
      ),
      leaseGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_generation'],
      )!,
      leaseExpiresAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_expires_at_ms'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      nextRetryAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at_ms'],
      ),
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      syncedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at_epoch_ms'],
      ),
    );
  }

  @override
  $OutboxMutationsTable createAlias(String alias) {
    return $OutboxMutationsTable(attachedDatabase, alias);
  }
}

class OutboxMutationEntry extends DataClass
    implements Insertable<OutboxMutationEntry> {
  final String id;
  final String organizationId;
  final String userId;
  final String idempotencyKey;
  final String mutationType;
  final String payloadJson;
  final int sequenceOrder;
  final String syncStatus;
  final String? provisionalBusinessId;
  final String? leaseToken;
  final int leaseGeneration;
  final int? leaseExpiresAtMs;
  final int attemptCount;
  final String? lastErrorCode;
  final int? nextRetryAtMs;
  final int createdAtEpochMs;
  final int? syncedAtEpochMs;
  const OutboxMutationEntry({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.idempotencyKey,
    required this.mutationType,
    required this.payloadJson,
    required this.sequenceOrder,
    required this.syncStatus,
    this.provisionalBusinessId,
    this.leaseToken,
    required this.leaseGeneration,
    this.leaseExpiresAtMs,
    required this.attemptCount,
    this.lastErrorCode,
    this.nextRetryAtMs,
    required this.createdAtEpochMs,
    this.syncedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['user_id'] = Variable<String>(userId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['mutation_type'] = Variable<String>(mutationType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['sequence_order'] = Variable<int>(sequenceOrder);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || provisionalBusinessId != null) {
      map['provisional_business_id'] = Variable<String>(provisionalBusinessId);
    }
    if (!nullToAbsent || leaseToken != null) {
      map['lease_token'] = Variable<String>(leaseToken);
    }
    map['lease_generation'] = Variable<int>(leaseGeneration);
    if (!nullToAbsent || leaseExpiresAtMs != null) {
      map['lease_expires_at_ms'] = Variable<int>(leaseExpiresAtMs);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    if (!nullToAbsent || nextRetryAtMs != null) {
      map['next_retry_at_ms'] = Variable<int>(nextRetryAtMs);
    }
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    if (!nullToAbsent || syncedAtEpochMs != null) {
      map['synced_at_epoch_ms'] = Variable<int>(syncedAtEpochMs);
    }
    return map;
  }

  OutboxMutationsCompanion toCompanion(bool nullToAbsent) {
    return OutboxMutationsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      userId: Value(userId),
      idempotencyKey: Value(idempotencyKey),
      mutationType: Value(mutationType),
      payloadJson: Value(payloadJson),
      sequenceOrder: Value(sequenceOrder),
      syncStatus: Value(syncStatus),
      provisionalBusinessId: provisionalBusinessId == null && nullToAbsent
          ? const Value.absent()
          : Value(provisionalBusinessId),
      leaseToken: leaseToken == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseToken),
      leaseGeneration: Value(leaseGeneration),
      leaseExpiresAtMs: leaseExpiresAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseExpiresAtMs),
      attemptCount: Value(attemptCount),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      nextRetryAtMs: nextRetryAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAtMs),
      createdAtEpochMs: Value(createdAtEpochMs),
      syncedAtEpochMs: syncedAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAtEpochMs),
    );
  }

  factory OutboxMutationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxMutationEntry(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      userId: serializer.fromJson<String>(json['userId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      mutationType: serializer.fromJson<String>(json['mutationType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      sequenceOrder: serializer.fromJson<int>(json['sequenceOrder']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      provisionalBusinessId: serializer.fromJson<String?>(
        json['provisionalBusinessId'],
      ),
      leaseToken: serializer.fromJson<String?>(json['leaseToken']),
      leaseGeneration: serializer.fromJson<int>(json['leaseGeneration']),
      leaseExpiresAtMs: serializer.fromJson<int?>(json['leaseExpiresAtMs']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      nextRetryAtMs: serializer.fromJson<int?>(json['nextRetryAtMs']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      syncedAtEpochMs: serializer.fromJson<int?>(json['syncedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'userId': serializer.toJson<String>(userId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'mutationType': serializer.toJson<String>(mutationType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'sequenceOrder': serializer.toJson<int>(sequenceOrder),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'provisionalBusinessId': serializer.toJson<String?>(
        provisionalBusinessId,
      ),
      'leaseToken': serializer.toJson<String?>(leaseToken),
      'leaseGeneration': serializer.toJson<int>(leaseGeneration),
      'leaseExpiresAtMs': serializer.toJson<int?>(leaseExpiresAtMs),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'nextRetryAtMs': serializer.toJson<int?>(nextRetryAtMs),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'syncedAtEpochMs': serializer.toJson<int?>(syncedAtEpochMs),
    };
  }

  OutboxMutationEntry copyWith({
    String? id,
    String? organizationId,
    String? userId,
    String? idempotencyKey,
    String? mutationType,
    String? payloadJson,
    int? sequenceOrder,
    String? syncStatus,
    Value<String?> provisionalBusinessId = const Value.absent(),
    Value<String?> leaseToken = const Value.absent(),
    int? leaseGeneration,
    Value<int?> leaseExpiresAtMs = const Value.absent(),
    int? attemptCount,
    Value<String?> lastErrorCode = const Value.absent(),
    Value<int?> nextRetryAtMs = const Value.absent(),
    int? createdAtEpochMs,
    Value<int?> syncedAtEpochMs = const Value.absent(),
  }) => OutboxMutationEntry(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    userId: userId ?? this.userId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    mutationType: mutationType ?? this.mutationType,
    payloadJson: payloadJson ?? this.payloadJson,
    sequenceOrder: sequenceOrder ?? this.sequenceOrder,
    syncStatus: syncStatus ?? this.syncStatus,
    provisionalBusinessId: provisionalBusinessId.present
        ? provisionalBusinessId.value
        : this.provisionalBusinessId,
    leaseToken: leaseToken.present ? leaseToken.value : this.leaseToken,
    leaseGeneration: leaseGeneration ?? this.leaseGeneration,
    leaseExpiresAtMs: leaseExpiresAtMs.present
        ? leaseExpiresAtMs.value
        : this.leaseExpiresAtMs,
    attemptCount: attemptCount ?? this.attemptCount,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    nextRetryAtMs: nextRetryAtMs.present
        ? nextRetryAtMs.value
        : this.nextRetryAtMs,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    syncedAtEpochMs: syncedAtEpochMs.present
        ? syncedAtEpochMs.value
        : this.syncedAtEpochMs,
  );
  OutboxMutationEntry copyWithCompanion(OutboxMutationsCompanion data) {
    return OutboxMutationEntry(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      mutationType: data.mutationType.present
          ? data.mutationType.value
          : this.mutationType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      sequenceOrder: data.sequenceOrder.present
          ? data.sequenceOrder.value
          : this.sequenceOrder,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      provisionalBusinessId: data.provisionalBusinessId.present
          ? data.provisionalBusinessId.value
          : this.provisionalBusinessId,
      leaseToken: data.leaseToken.present
          ? data.leaseToken.value
          : this.leaseToken,
      leaseGeneration: data.leaseGeneration.present
          ? data.leaseGeneration.value
          : this.leaseGeneration,
      leaseExpiresAtMs: data.leaseExpiresAtMs.present
          ? data.leaseExpiresAtMs.value
          : this.leaseExpiresAtMs,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      nextRetryAtMs: data.nextRetryAtMs.present
          ? data.nextRetryAtMs.value
          : this.nextRetryAtMs,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      syncedAtEpochMs: data.syncedAtEpochMs.present
          ? data.syncedAtEpochMs.value
          : this.syncedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMutationEntry(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('userId: $userId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('mutationType: $mutationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('sequenceOrder: $sequenceOrder, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('provisionalBusinessId: $provisionalBusinessId, ')
          ..write('leaseToken: $leaseToken, ')
          ..write('leaseGeneration: $leaseGeneration, ')
          ..write('leaseExpiresAtMs: $leaseExpiresAtMs, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('nextRetryAtMs: $nextRetryAtMs, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('syncedAtEpochMs: $syncedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    userId,
    idempotencyKey,
    mutationType,
    payloadJson,
    sequenceOrder,
    syncStatus,
    provisionalBusinessId,
    leaseToken,
    leaseGeneration,
    leaseExpiresAtMs,
    attemptCount,
    lastErrorCode,
    nextRetryAtMs,
    createdAtEpochMs,
    syncedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxMutationEntry &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.userId == this.userId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.mutationType == this.mutationType &&
          other.payloadJson == this.payloadJson &&
          other.sequenceOrder == this.sequenceOrder &&
          other.syncStatus == this.syncStatus &&
          other.provisionalBusinessId == this.provisionalBusinessId &&
          other.leaseToken == this.leaseToken &&
          other.leaseGeneration == this.leaseGeneration &&
          other.leaseExpiresAtMs == this.leaseExpiresAtMs &&
          other.attemptCount == this.attemptCount &&
          other.lastErrorCode == this.lastErrorCode &&
          other.nextRetryAtMs == this.nextRetryAtMs &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.syncedAtEpochMs == this.syncedAtEpochMs);
}

class OutboxMutationsCompanion extends UpdateCompanion<OutboxMutationEntry> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> userId;
  final Value<String> idempotencyKey;
  final Value<String> mutationType;
  final Value<String> payloadJson;
  final Value<int> sequenceOrder;
  final Value<String> syncStatus;
  final Value<String?> provisionalBusinessId;
  final Value<String?> leaseToken;
  final Value<int> leaseGeneration;
  final Value<int?> leaseExpiresAtMs;
  final Value<int> attemptCount;
  final Value<String?> lastErrorCode;
  final Value<int?> nextRetryAtMs;
  final Value<int> createdAtEpochMs;
  final Value<int?> syncedAtEpochMs;
  final Value<int> rowid;
  const OutboxMutationsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.mutationType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.sequenceOrder = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.provisionalBusinessId = const Value.absent(),
    this.leaseToken = const Value.absent(),
    this.leaseGeneration = const Value.absent(),
    this.leaseExpiresAtMs = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.nextRetryAtMs = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.syncedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxMutationsCompanion.insert({
    required String id,
    required String organizationId,
    required String userId,
    required String idempotencyKey,
    required String mutationType,
    required String payloadJson,
    required int sequenceOrder,
    this.syncStatus = const Value.absent(),
    this.provisionalBusinessId = const Value.absent(),
    this.leaseToken = const Value.absent(),
    this.leaseGeneration = const Value.absent(),
    this.leaseExpiresAtMs = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.nextRetryAtMs = const Value.absent(),
    required int createdAtEpochMs,
    this.syncedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       userId = Value(userId),
       idempotencyKey = Value(idempotencyKey),
       mutationType = Value(mutationType),
       payloadJson = Value(payloadJson),
       sequenceOrder = Value(sequenceOrder),
       createdAtEpochMs = Value(createdAtEpochMs);
  static Insertable<OutboxMutationEntry> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? userId,
    Expression<String>? idempotencyKey,
    Expression<String>? mutationType,
    Expression<String>? payloadJson,
    Expression<int>? sequenceOrder,
    Expression<String>? syncStatus,
    Expression<String>? provisionalBusinessId,
    Expression<String>? leaseToken,
    Expression<int>? leaseGeneration,
    Expression<int>? leaseExpiresAtMs,
    Expression<int>? attemptCount,
    Expression<String>? lastErrorCode,
    Expression<int>? nextRetryAtMs,
    Expression<int>? createdAtEpochMs,
    Expression<int>? syncedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (userId != null) 'user_id': userId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (mutationType != null) 'mutation_type': mutationType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (sequenceOrder != null) 'sequence_order': sequenceOrder,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (provisionalBusinessId != null)
        'provisional_business_id': provisionalBusinessId,
      if (leaseToken != null) 'lease_token': leaseToken,
      if (leaseGeneration != null) 'lease_generation': leaseGeneration,
      if (leaseExpiresAtMs != null) 'lease_expires_at_ms': leaseExpiresAtMs,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (nextRetryAtMs != null) 'next_retry_at_ms': nextRetryAtMs,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (syncedAtEpochMs != null) 'synced_at_epoch_ms': syncedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxMutationsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? userId,
    Value<String>? idempotencyKey,
    Value<String>? mutationType,
    Value<String>? payloadJson,
    Value<int>? sequenceOrder,
    Value<String>? syncStatus,
    Value<String?>? provisionalBusinessId,
    Value<String?>? leaseToken,
    Value<int>? leaseGeneration,
    Value<int?>? leaseExpiresAtMs,
    Value<int>? attemptCount,
    Value<String?>? lastErrorCode,
    Value<int?>? nextRetryAtMs,
    Value<int>? createdAtEpochMs,
    Value<int?>? syncedAtEpochMs,
    Value<int>? rowid,
  }) {
    return OutboxMutationsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      mutationType: mutationType ?? this.mutationType,
      payloadJson: payloadJson ?? this.payloadJson,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      syncStatus: syncStatus ?? this.syncStatus,
      provisionalBusinessId:
          provisionalBusinessId ?? this.provisionalBusinessId,
      leaseToken: leaseToken ?? this.leaseToken,
      leaseGeneration: leaseGeneration ?? this.leaseGeneration,
      leaseExpiresAtMs: leaseExpiresAtMs ?? this.leaseExpiresAtMs,
      attemptCount: attemptCount ?? this.attemptCount,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      nextRetryAtMs: nextRetryAtMs ?? this.nextRetryAtMs,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      syncedAtEpochMs: syncedAtEpochMs ?? this.syncedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (mutationType.present) {
      map['mutation_type'] = Variable<String>(mutationType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (sequenceOrder.present) {
      map['sequence_order'] = Variable<int>(sequenceOrder.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (provisionalBusinessId.present) {
      map['provisional_business_id'] = Variable<String>(
        provisionalBusinessId.value,
      );
    }
    if (leaseToken.present) {
      map['lease_token'] = Variable<String>(leaseToken.value);
    }
    if (leaseGeneration.present) {
      map['lease_generation'] = Variable<int>(leaseGeneration.value);
    }
    if (leaseExpiresAtMs.present) {
      map['lease_expires_at_ms'] = Variable<int>(leaseExpiresAtMs.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (nextRetryAtMs.present) {
      map['next_retry_at_ms'] = Variable<int>(nextRetryAtMs.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (syncedAtEpochMs.present) {
      map['synced_at_epoch_ms'] = Variable<int>(syncedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMutationsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('userId: $userId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('mutationType: $mutationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('sequenceOrder: $sequenceOrder, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('provisionalBusinessId: $provisionalBusinessId, ')
          ..write('leaseToken: $leaseToken, ')
          ..write('leaseGeneration: $leaseGeneration, ')
          ..write('leaseExpiresAtMs: $leaseExpiresAtMs, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('nextRetryAtMs: $nextRetryAtMs, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('syncedAtEpochMs: $syncedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WarehouseHubsTable extends WarehouseHubs
    with TableInfo<$WarehouseHubsTable, WarehouseHubEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WarehouseHubsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capacityBoxesMeta = const VerificationMeta(
    'capacityBoxes',
  );
  @override
  late final GeneratedColumn<int> capacityBoxes = GeneratedColumn<int>(
    'capacity_boxes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activeStaffCountMeta = const VerificationMeta(
    'activeStaffCount',
  );
  @override
  late final GeneratedColumn<int> activeStaffCount = GeneratedColumn<int>(
    'active_staff_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    code,
    address,
    latitude,
    longitude,
    capacityBoxes,
    activeStaffCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'warehouse_hubs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WarehouseHubEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('capacity_boxes')) {
      context.handle(
        _capacityBoxesMeta,
        capacityBoxes.isAcceptableOrUnknown(
          data['capacity_boxes']!,
          _capacityBoxesMeta,
        ),
      );
    }
    if (data.containsKey('active_staff_count')) {
      context.handle(
        _activeStaffCountMeta,
        activeStaffCount.isAcceptableOrUnknown(
          data['active_staff_count']!,
          _activeStaffCountMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WarehouseHubEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WarehouseHubEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      capacityBoxes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capacity_boxes'],
      )!,
      activeStaffCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_staff_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WarehouseHubsTable createAlias(String alias) {
    return $WarehouseHubsTable(attachedDatabase, alias);
  }
}

class WarehouseHubEntry extends DataClass
    implements Insertable<WarehouseHubEntry> {
  final String id;
  final String name;
  final String code;
  final String address;
  final double? latitude;
  final double? longitude;
  final int capacityBoxes;
  final int activeStaffCount;
  final DateTime createdAt;
  const WarehouseHubEntry({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    this.latitude,
    this.longitude,
    required this.capacityBoxes,
    required this.activeStaffCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['address'] = Variable<String>(address);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['capacity_boxes'] = Variable<int>(capacityBoxes);
    map['active_staff_count'] = Variable<int>(activeStaffCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WarehouseHubsCompanion toCompanion(bool nullToAbsent) {
    return WarehouseHubsCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      address: Value(address),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      capacityBoxes: Value(capacityBoxes),
      activeStaffCount: Value(activeStaffCount),
      createdAt: Value(createdAt),
    );
  }

  factory WarehouseHubEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WarehouseHubEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      address: serializer.fromJson<String>(json['address']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      capacityBoxes: serializer.fromJson<int>(json['capacityBoxes']),
      activeStaffCount: serializer.fromJson<int>(json['activeStaffCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'address': serializer.toJson<String>(address),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'capacityBoxes': serializer.toJson<int>(capacityBoxes),
      'activeStaffCount': serializer.toJson<int>(activeStaffCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WarehouseHubEntry copyWith({
    String? id,
    String? name,
    String? code,
    String? address,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    int? capacityBoxes,
    int? activeStaffCount,
    DateTime? createdAt,
  }) => WarehouseHubEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    address: address ?? this.address,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    capacityBoxes: capacityBoxes ?? this.capacityBoxes,
    activeStaffCount: activeStaffCount ?? this.activeStaffCount,
    createdAt: createdAt ?? this.createdAt,
  );
  WarehouseHubEntry copyWithCompanion(WarehouseHubsCompanion data) {
    return WarehouseHubEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      address: data.address.present ? data.address.value : this.address,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      capacityBoxes: data.capacityBoxes.present
          ? data.capacityBoxes.value
          : this.capacityBoxes,
      activeStaffCount: data.activeStaffCount.present
          ? data.activeStaffCount.value
          : this.activeStaffCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WarehouseHubEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('capacityBoxes: $capacityBoxes, ')
          ..write('activeStaffCount: $activeStaffCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    code,
    address,
    latitude,
    longitude,
    capacityBoxes,
    activeStaffCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WarehouseHubEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.address == this.address &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.capacityBoxes == this.capacityBoxes &&
          other.activeStaffCount == this.activeStaffCount &&
          other.createdAt == this.createdAt);
}

class WarehouseHubsCompanion extends UpdateCompanion<WarehouseHubEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> code;
  final Value<String> address;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> capacityBoxes;
  final Value<int> activeStaffCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WarehouseHubsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.capacityBoxes = const Value.absent(),
    this.activeStaffCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WarehouseHubsCompanion.insert({
    required String id,
    required String name,
    required String code,
    required String address,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.capacityBoxes = const Value.absent(),
    this.activeStaffCount = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       code = Value(code),
       address = Value(address),
       createdAt = Value(createdAt);
  static Insertable<WarehouseHubEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? address,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? capacityBoxes,
    Expression<int>? activeStaffCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (capacityBoxes != null) 'capacity_boxes': capacityBoxes,
      if (activeStaffCount != null) 'active_staff_count': activeStaffCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WarehouseHubsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? code,
    Value<String>? address,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int>? capacityBoxes,
    Value<int>? activeStaffCount,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WarehouseHubsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacityBoxes: capacityBoxes ?? this.capacityBoxes,
      activeStaffCount: activeStaffCount ?? this.activeStaffCount,
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
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (capacityBoxes.present) {
      map['capacity_boxes'] = Variable<int>(capacityBoxes.value);
    }
    if (activeStaffCount.present) {
      map['active_staff_count'] = Variable<int>(activeStaffCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WarehouseHubsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('capacityBoxes: $capacityBoxes, ')
          ..write('activeStaffCount: $activeStaffCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutesTable extends Routes with TableInfo<$RoutesTable, RouteEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<String> dayOfWeek = GeneratedColumn<String>(
    'day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    code,
    dayOfWeek,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<RouteEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RouteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RouteEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_of_week'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RoutesTable createAlias(String alias) {
    return $RoutesTable(attachedDatabase, alias);
  }
}

class RouteEntry extends DataClass implements Insertable<RouteEntry> {
  final String id;
  final String name;
  final String code;
  final String dayOfWeek;
  final bool isActive;
  final DateTime createdAt;
  const RouteEntry({
    required this.id,
    required this.name,
    required this.code,
    required this.dayOfWeek,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    map['day_of_week'] = Variable<String>(dayOfWeek);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RoutesCompanion toCompanion(bool nullToAbsent) {
    return RoutesCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
      dayOfWeek: Value(dayOfWeek),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory RouteEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RouteEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
      dayOfWeek: serializer.fromJson<String>(json['dayOfWeek']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
      'dayOfWeek': serializer.toJson<String>(dayOfWeek),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RouteEntry copyWith({
    String? id,
    String? name,
    String? code,
    String? dayOfWeek,
    bool? isActive,
    DateTime? createdAt,
  }) => RouteEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  RouteEntry copyWithCompanion(RoutesCompanion data) {
    return RouteEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RouteEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, code, dayOfWeek, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RouteEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code &&
          other.dayOfWeek == this.dayOfWeek &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class RoutesCompanion extends UpdateCompanion<RouteEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> code;
  final Value<String> dayOfWeek;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RoutesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutesCompanion.insert({
    required String id,
    required String name,
    required String code,
    required String dayOfWeek,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       code = Value(code),
       dayOfWeek = Value(dayOfWeek),
       createdAt = Value(createdAt);
  static Insertable<RouteEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? dayOfWeek,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? code,
    Value<String>? dayOfWeek,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RoutesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isActive: isActive ?? this.isActive,
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
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<String>(dayOfWeek.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RouteStopsTable extends RouteStops
    with TableInfo<$RouteStopsTable, RouteStopEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RouteStopsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routeIdMeta = const VerificationMeta(
    'routeId',
  );
  @override
  late final GeneratedColumn<String> routeId = GeneratedColumn<String>(
    'route_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routes (id)',
    ),
  );
  static const VerificationMeta _retailerIdMeta = const VerificationMeta(
    'retailerId',
  );
  @override
  late final GeneratedColumn<String> retailerId = GeneratedColumn<String>(
    'retailer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES retailers (id)',
    ),
  );
  static const VerificationMeta _stopSequenceMeta = const VerificationMeta(
    'stopSequence',
  );
  @override
  late final GeneratedColumn<int> stopSequence = GeneratedColumn<int>(
    'stop_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routeId,
    retailerId,
    stopSequence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'route_stops';
  @override
  VerificationContext validateIntegrity(
    Insertable<RouteStopEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('route_id')) {
      context.handle(
        _routeIdMeta,
        routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('retailer_id')) {
      context.handle(
        _retailerIdMeta,
        retailerId.isAcceptableOrUnknown(data['retailer_id']!, _retailerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_retailerIdMeta);
    }
    if (data.containsKey('stop_sequence')) {
      context.handle(
        _stopSequenceMeta,
        stopSequence.isAcceptableOrUnknown(
          data['stop_sequence']!,
          _stopSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stopSequenceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RouteStopEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RouteStopEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_id'],
      )!,
      retailerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}retailer_id'],
      )!,
      stopSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stop_sequence'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RouteStopsTable createAlias(String alias) {
    return $RouteStopsTable(attachedDatabase, alias);
  }
}

class RouteStopEntry extends DataClass implements Insertable<RouteStopEntry> {
  final String id;
  final String routeId;
  final String retailerId;
  final int stopSequence;
  final DateTime createdAt;
  const RouteStopEntry({
    required this.id,
    required this.routeId,
    required this.retailerId,
    required this.stopSequence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['route_id'] = Variable<String>(routeId);
    map['retailer_id'] = Variable<String>(retailerId);
    map['stop_sequence'] = Variable<int>(stopSequence);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RouteStopsCompanion toCompanion(bool nullToAbsent) {
    return RouteStopsCompanion(
      id: Value(id),
      routeId: Value(routeId),
      retailerId: Value(retailerId),
      stopSequence: Value(stopSequence),
      createdAt: Value(createdAt),
    );
  }

  factory RouteStopEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RouteStopEntry(
      id: serializer.fromJson<String>(json['id']),
      routeId: serializer.fromJson<String>(json['routeId']),
      retailerId: serializer.fromJson<String>(json['retailerId']),
      stopSequence: serializer.fromJson<int>(json['stopSequence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routeId': serializer.toJson<String>(routeId),
      'retailerId': serializer.toJson<String>(retailerId),
      'stopSequence': serializer.toJson<int>(stopSequence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RouteStopEntry copyWith({
    String? id,
    String? routeId,
    String? retailerId,
    int? stopSequence,
    DateTime? createdAt,
  }) => RouteStopEntry(
    id: id ?? this.id,
    routeId: routeId ?? this.routeId,
    retailerId: retailerId ?? this.retailerId,
    stopSequence: stopSequence ?? this.stopSequence,
    createdAt: createdAt ?? this.createdAt,
  );
  RouteStopEntry copyWithCompanion(RouteStopsCompanion data) {
    return RouteStopEntry(
      id: data.id.present ? data.id.value : this.id,
      routeId: data.routeId.present ? data.routeId.value : this.routeId,
      retailerId: data.retailerId.present
          ? data.retailerId.value
          : this.retailerId,
      stopSequence: data.stopSequence.present
          ? data.stopSequence.value
          : this.stopSequence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RouteStopEntry(')
          ..write('id: $id, ')
          ..write('routeId: $routeId, ')
          ..write('retailerId: $retailerId, ')
          ..write('stopSequence: $stopSequence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, routeId, retailerId, stopSequence, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RouteStopEntry &&
          other.id == this.id &&
          other.routeId == this.routeId &&
          other.retailerId == this.retailerId &&
          other.stopSequence == this.stopSequence &&
          other.createdAt == this.createdAt);
}

class RouteStopsCompanion extends UpdateCompanion<RouteStopEntry> {
  final Value<String> id;
  final Value<String> routeId;
  final Value<String> retailerId;
  final Value<int> stopSequence;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RouteStopsCompanion({
    this.id = const Value.absent(),
    this.routeId = const Value.absent(),
    this.retailerId = const Value.absent(),
    this.stopSequence = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RouteStopsCompanion.insert({
    required String id,
    required String routeId,
    required String retailerId,
    required int stopSequence,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routeId = Value(routeId),
       retailerId = Value(retailerId),
       stopSequence = Value(stopSequence),
       createdAt = Value(createdAt);
  static Insertable<RouteStopEntry> custom({
    Expression<String>? id,
    Expression<String>? routeId,
    Expression<String>? retailerId,
    Expression<int>? stopSequence,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routeId != null) 'route_id': routeId,
      if (retailerId != null) 'retailer_id': retailerId,
      if (stopSequence != null) 'stop_sequence': stopSequence,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RouteStopsCompanion copyWith({
    Value<String>? id,
    Value<String>? routeId,
    Value<String>? retailerId,
    Value<int>? stopSequence,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RouteStopsCompanion(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      retailerId: retailerId ?? this.retailerId,
      stopSequence: stopSequence ?? this.stopSequence,
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
    if (routeId.present) {
      map['route_id'] = Variable<String>(routeId.value);
    }
    if (retailerId.present) {
      map['retailer_id'] = Variable<String>(retailerId.value);
    }
    if (stopSequence.present) {
      map['stop_sequence'] = Variable<int>(stopSequence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RouteStopsCompanion(')
          ..write('id: $id, ')
          ..write('routeId: $routeId, ')
          ..write('retailerId: $retailerId, ')
          ..write('stopSequence: $stopSequence, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClassSettingsTable extends ClassSettings
    with TableInfo<$ClassSettingsTable, ClassSettingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _classNameMeta = const VerificationMeta(
    'className',
  );
  @override
  late final GeneratedColumn<String> className = GeneratedColumn<String>(
    'class_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultCreditLimitPaiseMeta =
      const VerificationMeta('defaultCreditLimitPaise');
  @override
  late final GeneratedColumn<int> defaultCreditLimitPaise =
      GeneratedColumn<int>(
        'default_credit_limit_paise',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _creditDaysMeta = const VerificationMeta(
    'creditDays',
  );
  @override
  late final GeneratedColumn<int> creditDays = GeneratedColumn<int>(
    'credit_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitFrequencyDaysMeta =
      const VerificationMeta('visitFrequencyDays');
  @override
  late final GeneratedColumn<int> visitFrequencyDays = GeneratedColumn<int>(
    'visit_frequency_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    className,
    defaultCreditLimitPaise,
    creditDays,
    visitFrequencyDays,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'class_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassSettingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('class_name')) {
      context.handle(
        _classNameMeta,
        className.isAcceptableOrUnknown(data['class_name']!, _classNameMeta),
      );
    } else if (isInserting) {
      context.missing(_classNameMeta);
    }
    if (data.containsKey('default_credit_limit_paise')) {
      context.handle(
        _defaultCreditLimitPaiseMeta,
        defaultCreditLimitPaise.isAcceptableOrUnknown(
          data['default_credit_limit_paise']!,
          _defaultCreditLimitPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultCreditLimitPaiseMeta);
    }
    if (data.containsKey('credit_days')) {
      context.handle(
        _creditDaysMeta,
        creditDays.isAcceptableOrUnknown(data['credit_days']!, _creditDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_creditDaysMeta);
    }
    if (data.containsKey('visit_frequency_days')) {
      context.handle(
        _visitFrequencyDaysMeta,
        visitFrequencyDays.isAcceptableOrUnknown(
          data['visit_frequency_days']!,
          _visitFrequencyDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_visitFrequencyDaysMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {className};
  @override
  ClassSettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassSettingEntry(
      className: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_name'],
      )!,
      defaultCreditLimitPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_credit_limit_paise'],
      )!,
      creditDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_days'],
      )!,
      visitFrequencyDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visit_frequency_days'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ClassSettingsTable createAlias(String alias) {
    return $ClassSettingsTable(attachedDatabase, alias);
  }
}

class ClassSettingEntry extends DataClass
    implements Insertable<ClassSettingEntry> {
  final String className;
  final int defaultCreditLimitPaise;
  final int creditDays;
  final int visitFrequencyDays;
  final DateTime updatedAt;
  const ClassSettingEntry({
    required this.className,
    required this.defaultCreditLimitPaise,
    required this.creditDays,
    required this.visitFrequencyDays,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['class_name'] = Variable<String>(className);
    map['default_credit_limit_paise'] = Variable<int>(defaultCreditLimitPaise);
    map['credit_days'] = Variable<int>(creditDays);
    map['visit_frequency_days'] = Variable<int>(visitFrequencyDays);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ClassSettingsCompanion toCompanion(bool nullToAbsent) {
    return ClassSettingsCompanion(
      className: Value(className),
      defaultCreditLimitPaise: Value(defaultCreditLimitPaise),
      creditDays: Value(creditDays),
      visitFrequencyDays: Value(visitFrequencyDays),
      updatedAt: Value(updatedAt),
    );
  }

  factory ClassSettingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassSettingEntry(
      className: serializer.fromJson<String>(json['className']),
      defaultCreditLimitPaise: serializer.fromJson<int>(
        json['defaultCreditLimitPaise'],
      ),
      creditDays: serializer.fromJson<int>(json['creditDays']),
      visitFrequencyDays: serializer.fromJson<int>(json['visitFrequencyDays']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'className': serializer.toJson<String>(className),
      'defaultCreditLimitPaise': serializer.toJson<int>(
        defaultCreditLimitPaise,
      ),
      'creditDays': serializer.toJson<int>(creditDays),
      'visitFrequencyDays': serializer.toJson<int>(visitFrequencyDays),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ClassSettingEntry copyWith({
    String? className,
    int? defaultCreditLimitPaise,
    int? creditDays,
    int? visitFrequencyDays,
    DateTime? updatedAt,
  }) => ClassSettingEntry(
    className: className ?? this.className,
    defaultCreditLimitPaise:
        defaultCreditLimitPaise ?? this.defaultCreditLimitPaise,
    creditDays: creditDays ?? this.creditDays,
    visitFrequencyDays: visitFrequencyDays ?? this.visitFrequencyDays,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ClassSettingEntry copyWithCompanion(ClassSettingsCompanion data) {
    return ClassSettingEntry(
      className: data.className.present ? data.className.value : this.className,
      defaultCreditLimitPaise: data.defaultCreditLimitPaise.present
          ? data.defaultCreditLimitPaise.value
          : this.defaultCreditLimitPaise,
      creditDays: data.creditDays.present
          ? data.creditDays.value
          : this.creditDays,
      visitFrequencyDays: data.visitFrequencyDays.present
          ? data.visitFrequencyDays.value
          : this.visitFrequencyDays,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassSettingEntry(')
          ..write('className: $className, ')
          ..write('defaultCreditLimitPaise: $defaultCreditLimitPaise, ')
          ..write('creditDays: $creditDays, ')
          ..write('visitFrequencyDays: $visitFrequencyDays, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    className,
    defaultCreditLimitPaise,
    creditDays,
    visitFrequencyDays,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassSettingEntry &&
          other.className == this.className &&
          other.defaultCreditLimitPaise == this.defaultCreditLimitPaise &&
          other.creditDays == this.creditDays &&
          other.visitFrequencyDays == this.visitFrequencyDays &&
          other.updatedAt == this.updatedAt);
}

class ClassSettingsCompanion extends UpdateCompanion<ClassSettingEntry> {
  final Value<String> className;
  final Value<int> defaultCreditLimitPaise;
  final Value<int> creditDays;
  final Value<int> visitFrequencyDays;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ClassSettingsCompanion({
    this.className = const Value.absent(),
    this.defaultCreditLimitPaise = const Value.absent(),
    this.creditDays = const Value.absent(),
    this.visitFrequencyDays = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClassSettingsCompanion.insert({
    required String className,
    required int defaultCreditLimitPaise,
    required int creditDays,
    required int visitFrequencyDays,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : className = Value(className),
       defaultCreditLimitPaise = Value(defaultCreditLimitPaise),
       creditDays = Value(creditDays),
       visitFrequencyDays = Value(visitFrequencyDays),
       updatedAt = Value(updatedAt);
  static Insertable<ClassSettingEntry> custom({
    Expression<String>? className,
    Expression<int>? defaultCreditLimitPaise,
    Expression<int>? creditDays,
    Expression<int>? visitFrequencyDays,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (className != null) 'class_name': className,
      if (defaultCreditLimitPaise != null)
        'default_credit_limit_paise': defaultCreditLimitPaise,
      if (creditDays != null) 'credit_days': creditDays,
      if (visitFrequencyDays != null)
        'visit_frequency_days': visitFrequencyDays,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClassSettingsCompanion copyWith({
    Value<String>? className,
    Value<int>? defaultCreditLimitPaise,
    Value<int>? creditDays,
    Value<int>? visitFrequencyDays,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ClassSettingsCompanion(
      className: className ?? this.className,
      defaultCreditLimitPaise:
          defaultCreditLimitPaise ?? this.defaultCreditLimitPaise,
      creditDays: creditDays ?? this.creditDays,
      visitFrequencyDays: visitFrequencyDays ?? this.visitFrequencyDays,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (className.present) {
      map['class_name'] = Variable<String>(className.value);
    }
    if (defaultCreditLimitPaise.present) {
      map['default_credit_limit_paise'] = Variable<int>(
        defaultCreditLimitPaise.value,
      );
    }
    if (creditDays.present) {
      map['credit_days'] = Variable<int>(creditDays.value);
    }
    if (visitFrequencyDays.present) {
      map['visit_frequency_days'] = Variable<int>(visitFrequencyDays.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassSettingsCompanion(')
          ..write('className: $className, ')
          ..write('defaultCreditLimitPaise: $defaultCreditLimitPaise, ')
          ..write('creditDays: $creditDays, ')
          ..write('visitFrequencyDays: $visitFrequencyDays, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductUnitsTable extends ProductUnits
    with TableInfo<$ProductUnitsTable, ProductUnitEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductUnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _unitNameMeta = const VerificationMeta(
    'unitName',
  );
  @override
  late final GeneratedColumn<String> unitName = GeneratedColumn<String>(
    'unit_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _multiplierToBaseMeta = const VerificationMeta(
    'multiplierToBase',
  );
  @override
  late final GeneratedColumn<int> multiplierToBase = GeneratedColumn<int>(
    'multiplier_to_base',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBaseUnitMeta = const VerificationMeta(
    'isBaseUnit',
  );
  @override
  late final GeneratedColumn<bool> isBaseUnit = GeneratedColumn<bool>(
    'is_base_unit',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_base_unit" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _allowLooseSaleMeta = const VerificationMeta(
    'allowLooseSale',
  );
  @override
  late final GeneratedColumn<bool> allowLooseSale = GeneratedColumn<bool>(
    'allow_loose_sale',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_loose_sale" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    unitName,
    multiplierToBase,
    isBaseUnit,
    allowLooseSale,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_units';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductUnitEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('unit_name')) {
      context.handle(
        _unitNameMeta,
        unitName.isAcceptableOrUnknown(data['unit_name']!, _unitNameMeta),
      );
    } else if (isInserting) {
      context.missing(_unitNameMeta);
    }
    if (data.containsKey('multiplier_to_base')) {
      context.handle(
        _multiplierToBaseMeta,
        multiplierToBase.isAcceptableOrUnknown(
          data['multiplier_to_base']!,
          _multiplierToBaseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_multiplierToBaseMeta);
    }
    if (data.containsKey('is_base_unit')) {
      context.handle(
        _isBaseUnitMeta,
        isBaseUnit.isAcceptableOrUnknown(
          data['is_base_unit']!,
          _isBaseUnitMeta,
        ),
      );
    }
    if (data.containsKey('allow_loose_sale')) {
      context.handle(
        _allowLooseSaleMeta,
        allowLooseSale.isAcceptableOrUnknown(
          data['allow_loose_sale']!,
          _allowLooseSaleMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductUnitEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductUnitEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      unitName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_name'],
      )!,
      multiplierToBase: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}multiplier_to_base'],
      )!,
      isBaseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_base_unit'],
      )!,
      allowLooseSale: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_loose_sale'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProductUnitsTable createAlias(String alias) {
    return $ProductUnitsTable(attachedDatabase, alias);
  }
}

class ProductUnitEntry extends DataClass
    implements Insertable<ProductUnitEntry> {
  final String id;
  final String productId;
  final String unitName;
  final int multiplierToBase;
  final bool isBaseUnit;
  final bool allowLooseSale;
  final DateTime createdAt;
  const ProductUnitEntry({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.multiplierToBase,
    required this.isBaseUnit,
    required this.allowLooseSale,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['unit_name'] = Variable<String>(unitName);
    map['multiplier_to_base'] = Variable<int>(multiplierToBase);
    map['is_base_unit'] = Variable<bool>(isBaseUnit);
    map['allow_loose_sale'] = Variable<bool>(allowLooseSale);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProductUnitsCompanion toCompanion(bool nullToAbsent) {
    return ProductUnitsCompanion(
      id: Value(id),
      productId: Value(productId),
      unitName: Value(unitName),
      multiplierToBase: Value(multiplierToBase),
      isBaseUnit: Value(isBaseUnit),
      allowLooseSale: Value(allowLooseSale),
      createdAt: Value(createdAt),
    );
  }

  factory ProductUnitEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductUnitEntry(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      unitName: serializer.fromJson<String>(json['unitName']),
      multiplierToBase: serializer.fromJson<int>(json['multiplierToBase']),
      isBaseUnit: serializer.fromJson<bool>(json['isBaseUnit']),
      allowLooseSale: serializer.fromJson<bool>(json['allowLooseSale']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'unitName': serializer.toJson<String>(unitName),
      'multiplierToBase': serializer.toJson<int>(multiplierToBase),
      'isBaseUnit': serializer.toJson<bool>(isBaseUnit),
      'allowLooseSale': serializer.toJson<bool>(allowLooseSale),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProductUnitEntry copyWith({
    String? id,
    String? productId,
    String? unitName,
    int? multiplierToBase,
    bool? isBaseUnit,
    bool? allowLooseSale,
    DateTime? createdAt,
  }) => ProductUnitEntry(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    unitName: unitName ?? this.unitName,
    multiplierToBase: multiplierToBase ?? this.multiplierToBase,
    isBaseUnit: isBaseUnit ?? this.isBaseUnit,
    allowLooseSale: allowLooseSale ?? this.allowLooseSale,
    createdAt: createdAt ?? this.createdAt,
  );
  ProductUnitEntry copyWithCompanion(ProductUnitsCompanion data) {
    return ProductUnitEntry(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      unitName: data.unitName.present ? data.unitName.value : this.unitName,
      multiplierToBase: data.multiplierToBase.present
          ? data.multiplierToBase.value
          : this.multiplierToBase,
      isBaseUnit: data.isBaseUnit.present
          ? data.isBaseUnit.value
          : this.isBaseUnit,
      allowLooseSale: data.allowLooseSale.present
          ? data.allowLooseSale.value
          : this.allowLooseSale,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductUnitEntry(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('unitName: $unitName, ')
          ..write('multiplierToBase: $multiplierToBase, ')
          ..write('isBaseUnit: $isBaseUnit, ')
          ..write('allowLooseSale: $allowLooseSale, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    unitName,
    multiplierToBase,
    isBaseUnit,
    allowLooseSale,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductUnitEntry &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.unitName == this.unitName &&
          other.multiplierToBase == this.multiplierToBase &&
          other.isBaseUnit == this.isBaseUnit &&
          other.allowLooseSale == this.allowLooseSale &&
          other.createdAt == this.createdAt);
}

class ProductUnitsCompanion extends UpdateCompanion<ProductUnitEntry> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> unitName;
  final Value<int> multiplierToBase;
  final Value<bool> isBaseUnit;
  final Value<bool> allowLooseSale;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProductUnitsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.unitName = const Value.absent(),
    this.multiplierToBase = const Value.absent(),
    this.isBaseUnit = const Value.absent(),
    this.allowLooseSale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductUnitsCompanion.insert({
    required String id,
    required String productId,
    required String unitName,
    required int multiplierToBase,
    this.isBaseUnit = const Value.absent(),
    this.allowLooseSale = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       unitName = Value(unitName),
       multiplierToBase = Value(multiplierToBase),
       createdAt = Value(createdAt);
  static Insertable<ProductUnitEntry> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? unitName,
    Expression<int>? multiplierToBase,
    Expression<bool>? isBaseUnit,
    Expression<bool>? allowLooseSale,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (unitName != null) 'unit_name': unitName,
      if (multiplierToBase != null) 'multiplier_to_base': multiplierToBase,
      if (isBaseUnit != null) 'is_base_unit': isBaseUnit,
      if (allowLooseSale != null) 'allow_loose_sale': allowLooseSale,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductUnitsCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<String>? unitName,
    Value<int>? multiplierToBase,
    Value<bool>? isBaseUnit,
    Value<bool>? allowLooseSale,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProductUnitsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      multiplierToBase: multiplierToBase ?? this.multiplierToBase,
      isBaseUnit: isBaseUnit ?? this.isBaseUnit,
      allowLooseSale: allowLooseSale ?? this.allowLooseSale,
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
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (unitName.present) {
      map['unit_name'] = Variable<String>(unitName.value);
    }
    if (multiplierToBase.present) {
      map['multiplier_to_base'] = Variable<int>(multiplierToBase.value);
    }
    if (isBaseUnit.present) {
      map['is_base_unit'] = Variable<bool>(isBaseUnit.value);
    }
    if (allowLooseSale.present) {
      map['allow_loose_sale'] = Variable<bool>(allowLooseSale.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductUnitsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('unitName: $unitName, ')
          ..write('multiplierToBase: $multiplierToBase, ')
          ..write('isBaseUnit: $isBaseUnit, ')
          ..write('allowLooseSale: $allowLooseSale, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnitPricesTable extends UnitPrices
    with TableInfo<$UnitPricesTable, UnitPriceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnitPricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _unitNameMeta = const VerificationMeta(
    'unitName',
  );
  @override
  late final GeneratedColumn<String> unitName = GeneratedColumn<String>(
    'unit_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wholesalePricePaiseMeta =
      const VerificationMeta('wholesalePricePaise');
  @override
  late final GeneratedColumn<int> wholesalePricePaise = GeneratedColumn<int>(
    'wholesale_price_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mrpPaiseMeta = const VerificationMeta(
    'mrpPaise',
  );
  @override
  late final GeneratedColumn<int> mrpPaise = GeneratedColumn<int>(
    'mrp_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minOrderQtyMeta = const VerificationMeta(
    'minOrderQty',
  );
  @override
  late final GeneratedColumn<int> minOrderQty = GeneratedColumn<int>(
    'min_order_qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    unitName,
    wholesalePricePaise,
    mrpPaise,
    minOrderQty,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unit_prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnitPriceEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('unit_name')) {
      context.handle(
        _unitNameMeta,
        unitName.isAcceptableOrUnknown(data['unit_name']!, _unitNameMeta),
      );
    } else if (isInserting) {
      context.missing(_unitNameMeta);
    }
    if (data.containsKey('wholesale_price_paise')) {
      context.handle(
        _wholesalePricePaiseMeta,
        wholesalePricePaise.isAcceptableOrUnknown(
          data['wholesale_price_paise']!,
          _wholesalePricePaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wholesalePricePaiseMeta);
    }
    if (data.containsKey('mrp_paise')) {
      context.handle(
        _mrpPaiseMeta,
        mrpPaise.isAcceptableOrUnknown(data['mrp_paise']!, _mrpPaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_mrpPaiseMeta);
    }
    if (data.containsKey('min_order_qty')) {
      context.handle(
        _minOrderQtyMeta,
        minOrderQty.isAcceptableOrUnknown(
          data['min_order_qty']!,
          _minOrderQtyMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnitPriceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnitPriceEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      unitName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_name'],
      )!,
      wholesalePricePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wholesale_price_paise'],
      )!,
      mrpPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mrp_paise'],
      )!,
      minOrderQty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_order_qty'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UnitPricesTable createAlias(String alias) {
    return $UnitPricesTable(attachedDatabase, alias);
  }
}

class UnitPriceEntry extends DataClass implements Insertable<UnitPriceEntry> {
  final String id;
  final String productId;
  final String unitName;
  final int wholesalePricePaise;
  final int mrpPaise;
  final int minOrderQty;
  final DateTime updatedAt;
  const UnitPriceEntry({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.wholesalePricePaise,
    required this.mrpPaise,
    required this.minOrderQty,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['unit_name'] = Variable<String>(unitName);
    map['wholesale_price_paise'] = Variable<int>(wholesalePricePaise);
    map['mrp_paise'] = Variable<int>(mrpPaise);
    map['min_order_qty'] = Variable<int>(minOrderQty);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UnitPricesCompanion toCompanion(bool nullToAbsent) {
    return UnitPricesCompanion(
      id: Value(id),
      productId: Value(productId),
      unitName: Value(unitName),
      wholesalePricePaise: Value(wholesalePricePaise),
      mrpPaise: Value(mrpPaise),
      minOrderQty: Value(minOrderQty),
      updatedAt: Value(updatedAt),
    );
  }

  factory UnitPriceEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnitPriceEntry(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      unitName: serializer.fromJson<String>(json['unitName']),
      wholesalePricePaise: serializer.fromJson<int>(
        json['wholesalePricePaise'],
      ),
      mrpPaise: serializer.fromJson<int>(json['mrpPaise']),
      minOrderQty: serializer.fromJson<int>(json['minOrderQty']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'unitName': serializer.toJson<String>(unitName),
      'wholesalePricePaise': serializer.toJson<int>(wholesalePricePaise),
      'mrpPaise': serializer.toJson<int>(mrpPaise),
      'minOrderQty': serializer.toJson<int>(minOrderQty),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UnitPriceEntry copyWith({
    String? id,
    String? productId,
    String? unitName,
    int? wholesalePricePaise,
    int? mrpPaise,
    int? minOrderQty,
    DateTime? updatedAt,
  }) => UnitPriceEntry(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    unitName: unitName ?? this.unitName,
    wholesalePricePaise: wholesalePricePaise ?? this.wholesalePricePaise,
    mrpPaise: mrpPaise ?? this.mrpPaise,
    minOrderQty: minOrderQty ?? this.minOrderQty,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UnitPriceEntry copyWithCompanion(UnitPricesCompanion data) {
    return UnitPriceEntry(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      unitName: data.unitName.present ? data.unitName.value : this.unitName,
      wholesalePricePaise: data.wholesalePricePaise.present
          ? data.wholesalePricePaise.value
          : this.wholesalePricePaise,
      mrpPaise: data.mrpPaise.present ? data.mrpPaise.value : this.mrpPaise,
      minOrderQty: data.minOrderQty.present
          ? data.minOrderQty.value
          : this.minOrderQty,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnitPriceEntry(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('unitName: $unitName, ')
          ..write('wholesalePricePaise: $wholesalePricePaise, ')
          ..write('mrpPaise: $mrpPaise, ')
          ..write('minOrderQty: $minOrderQty, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    unitName,
    wholesalePricePaise,
    mrpPaise,
    minOrderQty,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnitPriceEntry &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.unitName == this.unitName &&
          other.wholesalePricePaise == this.wholesalePricePaise &&
          other.mrpPaise == this.mrpPaise &&
          other.minOrderQty == this.minOrderQty &&
          other.updatedAt == this.updatedAt);
}

class UnitPricesCompanion extends UpdateCompanion<UnitPriceEntry> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> unitName;
  final Value<int> wholesalePricePaise;
  final Value<int> mrpPaise;
  final Value<int> minOrderQty;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UnitPricesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.unitName = const Value.absent(),
    this.wholesalePricePaise = const Value.absent(),
    this.mrpPaise = const Value.absent(),
    this.minOrderQty = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnitPricesCompanion.insert({
    required String id,
    required String productId,
    required String unitName,
    required int wholesalePricePaise,
    required int mrpPaise,
    this.minOrderQty = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       unitName = Value(unitName),
       wholesalePricePaise = Value(wholesalePricePaise),
       mrpPaise = Value(mrpPaise),
       updatedAt = Value(updatedAt);
  static Insertable<UnitPriceEntry> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? unitName,
    Expression<int>? wholesalePricePaise,
    Expression<int>? mrpPaise,
    Expression<int>? minOrderQty,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (unitName != null) 'unit_name': unitName,
      if (wholesalePricePaise != null)
        'wholesale_price_paise': wholesalePricePaise,
      if (mrpPaise != null) 'mrp_paise': mrpPaise,
      if (minOrderQty != null) 'min_order_qty': minOrderQty,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnitPricesCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<String>? unitName,
    Value<int>? wholesalePricePaise,
    Value<int>? mrpPaise,
    Value<int>? minOrderQty,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UnitPricesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      wholesalePricePaise: wholesalePricePaise ?? this.wholesalePricePaise,
      mrpPaise: mrpPaise ?? this.mrpPaise,
      minOrderQty: minOrderQty ?? this.minOrderQty,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (unitName.present) {
      map['unit_name'] = Variable<String>(unitName.value);
    }
    if (wholesalePricePaise.present) {
      map['wholesale_price_paise'] = Variable<int>(wholesalePricePaise.value);
    }
    if (mrpPaise.present) {
      map['mrp_paise'] = Variable<int>(mrpPaise.value);
    }
    if (minOrderQty.present) {
      map['min_order_qty'] = Variable<int>(minOrderQty.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnitPricesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('unitName: $unitName, ')
          ..write('wholesalePricePaise: $wholesalePricePaise, ')
          ..write('mrpPaise: $mrpPaise, ')
          ..write('minOrderQty: $minOrderQty, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocationsTable extends Locations
    with TableInfo<$LocationsTable, LocationEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationTypeMeta = const VerificationMeta(
    'locationType',
  );
  @override
  late final GeneratedColumn<String> locationType = GeneratedColumn<String>(
    'location_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, locationType, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('location_type')) {
      context.handle(
        _locationTypeMeta,
        locationType.isAcceptableOrUnknown(
          data['location_type']!,
          _locationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locationTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      locationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }
}

class LocationEntry extends DataClass implements Insertable<LocationEntry> {
  final String id;
  final String name;
  final String locationType;
  final DateTime createdAt;
  const LocationEntry({
    required this.id,
    required this.name,
    required this.locationType,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['location_type'] = Variable<String>(locationType);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      name: Value(name),
      locationType: Value(locationType),
      createdAt: Value(createdAt),
    );
  }

  factory LocationEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      locationType: serializer.fromJson<String>(json['locationType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'locationType': serializer.toJson<String>(locationType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocationEntry copyWith({
    String? id,
    String? name,
    String? locationType,
    DateTime? createdAt,
  }) => LocationEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    locationType: locationType ?? this.locationType,
    createdAt: createdAt ?? this.createdAt,
  );
  LocationEntry copyWithCompanion(LocationsCompanion data) {
    return LocationEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      locationType: data.locationType.present
          ? data.locationType.value
          : this.locationType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('locationType: $locationType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, locationType, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.locationType == this.locationType &&
          other.createdAt == this.createdAt);
}

class LocationsCompanion extends UpdateCompanion<LocationEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> locationType;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.locationType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocationsCompanion.insert({
    required String id,
    required String name,
    required String locationType,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       locationType = Value(locationType),
       createdAt = Value(createdAt);
  static Insertable<LocationEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? locationType,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (locationType != null) 'location_type': locationType,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? locationType,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      locationType: locationType ?? this.locationType,
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
    if (locationType.present) {
      map['location_type'] = Variable<String>(locationType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('locationType: $locationType, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CartDraftsTable extends CartDrafts
    with TableInfo<$CartDraftsTable, CartDraftEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CartDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _retailerIdMeta = const VerificationMeta(
    'retailerId',
  );
  @override
  late final GeneratedColumn<String> retailerId = GeneratedColumn<String>(
    'retailer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [retailerId, itemsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cart_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CartDraftEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('retailer_id')) {
      context.handle(
        _retailerIdMeta,
        retailerId.isAcceptableOrUnknown(data['retailer_id']!, _retailerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_retailerIdMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {retailerId};
  @override
  CartDraftEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CartDraftEntry(
      retailerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}retailer_id'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CartDraftsTable createAlias(String alias) {
    return $CartDraftsTable(attachedDatabase, alias);
  }
}

class CartDraftEntry extends DataClass implements Insertable<CartDraftEntry> {
  final String retailerId;
  final String itemsJson;
  final DateTime updatedAt;
  const CartDraftEntry({
    required this.retailerId,
    required this.itemsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['retailer_id'] = Variable<String>(retailerId);
    map['items_json'] = Variable<String>(itemsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CartDraftsCompanion toCompanion(bool nullToAbsent) {
    return CartDraftsCompanion(
      retailerId: Value(retailerId),
      itemsJson: Value(itemsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory CartDraftEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CartDraftEntry(
      retailerId: serializer.fromJson<String>(json['retailerId']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'retailerId': serializer.toJson<String>(retailerId),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CartDraftEntry copyWith({
    String? retailerId,
    String? itemsJson,
    DateTime? updatedAt,
  }) => CartDraftEntry(
    retailerId: retailerId ?? this.retailerId,
    itemsJson: itemsJson ?? this.itemsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CartDraftEntry copyWithCompanion(CartDraftsCompanion data) {
    return CartDraftEntry(
      retailerId: data.retailerId.present
          ? data.retailerId.value
          : this.retailerId,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CartDraftEntry(')
          ..write('retailerId: $retailerId, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(retailerId, itemsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartDraftEntry &&
          other.retailerId == this.retailerId &&
          other.itemsJson == this.itemsJson &&
          other.updatedAt == this.updatedAt);
}

class CartDraftsCompanion extends UpdateCompanion<CartDraftEntry> {
  final Value<String> retailerId;
  final Value<String> itemsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CartDraftsCompanion({
    this.retailerId = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CartDraftsCompanion.insert({
    required String retailerId,
    required String itemsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : retailerId = Value(retailerId),
       itemsJson = Value(itemsJson),
       updatedAt = Value(updatedAt);
  static Insertable<CartDraftEntry> custom({
    Expression<String>? retailerId,
    Expression<String>? itemsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (retailerId != null) 'retailer_id': retailerId,
      if (itemsJson != null) 'items_json': itemsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CartDraftsCompanion copyWith({
    Value<String>? retailerId,
    Value<String>? itemsJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CartDraftsCompanion(
      retailerId: retailerId ?? this.retailerId,
      itemsJson: itemsJson ?? this.itemsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (retailerId.present) {
      map['retailer_id'] = Variable<String>(retailerId.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CartDraftsCompanion(')
          ..write('retailerId: $retailerId, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitsTable extends Visits with TableInfo<$VisitsTable, VisitEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retailerIdMeta = const VerificationMeta(
    'retailerId',
  );
  @override
  late final GeneratedColumn<String> retailerId = GeneratedColumn<String>(
    'retailer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES retailers (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    retailerId,
    userId,
    startTime,
    endTime,
    outcome,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('retailer_id')) {
      context.handle(
        _retailerIdMeta,
        retailerId.isAcceptableOrUnknown(data['retailer_id']!, _retailerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_retailerIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisitEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      retailerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}retailer_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VisitsTable createAlias(String alias) {
    return $VisitsTable(attachedDatabase, alias);
  }
}

class VisitEntry extends DataClass implements Insertable<VisitEntry> {
  final String id;
  final String retailerId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String outcome;
  final String notes;
  final DateTime createdAt;
  const VisitEntry({
    required this.id,
    required this.retailerId,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.outcome,
    required this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['retailer_id'] = Variable<String>(retailerId);
    map['user_id'] = Variable<String>(userId);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['outcome'] = Variable<String>(outcome);
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VisitsCompanion toCompanion(bool nullToAbsent) {
    return VisitsCompanion(
      id: Value(id),
      retailerId: Value(retailerId),
      userId: Value(userId),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      outcome: Value(outcome),
      notes: Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory VisitEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitEntry(
      id: serializer.fromJson<String>(json['id']),
      retailerId: serializer.fromJson<String>(json['retailerId']),
      userId: serializer.fromJson<String>(json['userId']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      outcome: serializer.fromJson<String>(json['outcome']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'retailerId': serializer.toJson<String>(retailerId),
      'userId': serializer.toJson<String>(userId),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'outcome': serializer.toJson<String>(outcome),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VisitEntry copyWith({
    String? id,
    String? retailerId,
    String? userId,
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
    String? outcome,
    String? notes,
    DateTime? createdAt,
  }) => VisitEntry(
    id: id ?? this.id,
    retailerId: retailerId ?? this.retailerId,
    userId: userId ?? this.userId,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    outcome: outcome ?? this.outcome,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  VisitEntry copyWithCompanion(VisitsCompanion data) {
    return VisitEntry(
      id: data.id.present ? data.id.value : this.id,
      retailerId: data.retailerId.present
          ? data.retailerId.value
          : this.retailerId,
      userId: data.userId.present ? data.userId.value : this.userId,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitEntry(')
          ..write('id: $id, ')
          ..write('retailerId: $retailerId, ')
          ..write('userId: $userId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('outcome: $outcome, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    retailerId,
    userId,
    startTime,
    endTime,
    outcome,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitEntry &&
          other.id == this.id &&
          other.retailerId == this.retailerId &&
          other.userId == this.userId &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.outcome == this.outcome &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class VisitsCompanion extends UpdateCompanion<VisitEntry> {
  final Value<String> id;
  final Value<String> retailerId;
  final Value<String> userId;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<String> outcome;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VisitsCompanion({
    this.id = const Value.absent(),
    this.retailerId = const Value.absent(),
    this.userId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.outcome = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitsCompanion.insert({
    required String id,
    required String retailerId,
    required String userId,
    required DateTime startTime,
    this.endTime = const Value.absent(),
    required String outcome,
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       retailerId = Value(retailerId),
       userId = Value(userId),
       startTime = Value(startTime),
       outcome = Value(outcome),
       createdAt = Value(createdAt);
  static Insertable<VisitEntry> custom({
    Expression<String>? id,
    Expression<String>? retailerId,
    Expression<String>? userId,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<String>? outcome,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (retailerId != null) 'retailer_id': retailerId,
      if (userId != null) 'user_id': userId,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (outcome != null) 'outcome': outcome,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitsCompanion copyWith({
    Value<String>? id,
    Value<String>? retailerId,
    Value<String>? userId,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<String>? outcome,
    Value<String>? notes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VisitsCompanion(
      id: id ?? this.id,
      retailerId: retailerId ?? this.retailerId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      outcome: outcome ?? this.outcome,
      notes: notes ?? this.notes,
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
    if (retailerId.present) {
      map['retailer_id'] = Variable<String>(retailerId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitsCompanion(')
          ..write('id: $id, ')
          ..write('retailerId: $retailerId, ')
          ..write('userId: $userId, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('outcome: $outcome, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $RetailersTable retailers = $RetailersTable(this);
  late final $InventorySnapshotsTable inventorySnapshots =
      $InventorySnapshotsTable(this);
  late final $InventoryMovementsTable inventoryMovements =
      $InventoryMovementsTable(this);
  late final $DatabaseMetadataTable databaseMetadata = $DatabaseMetadataTable(
    this,
  );
  late final $OutboxMutationsTable outboxMutations = $OutboxMutationsTable(
    this,
  );
  late final $WarehouseHubsTable warehouseHubs = $WarehouseHubsTable(this);
  late final $RoutesTable routes = $RoutesTable(this);
  late final $RouteStopsTable routeStops = $RouteStopsTable(this);
  late final $ClassSettingsTable classSettings = $ClassSettingsTable(this);
  late final $ProductUnitsTable productUnits = $ProductUnitsTable(this);
  late final $UnitPricesTable unitPrices = $UnitPricesTable(this);
  late final $LocationsTable locations = $LocationsTable(this);
  late final $CartDraftsTable cartDrafts = $CartDraftsTable(this);
  late final $VisitsTable visits = $VisitsTable(this);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    products,
    retailers,
    inventorySnapshots,
    inventoryMovements,
    databaseMetadata,
    outboxMutations,
    warehouseHubs,
    routes,
    routeStops,
    classSettings,
    productUnits,
    unitPrices,
    locations,
    cartDrafts,
    visits,
  ];
}

typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      required String id,
      required String name,
      required String hindiName,
      required String category,
      required double mrpRupees,
      Value<int> mrpPaise,
      required int piecePricePaise,
      required int stripQty,
      required int boxQty,
      Value<double> gstRate,
      Value<String> badge,
      Value<String> imageUrl,
      Value<bool> isArchived,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> hindiName,
      Value<String> category,
      Value<double> mrpRupees,
      Value<int> mrpPaise,
      Value<int> piecePricePaise,
      Value<int> stripQty,
      Value<int> boxQty,
      Value<double> gstRate,
      Value<String> badge,
      Value<String> imageUrl,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, ProductEntry> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $InventorySnapshotsTable,
    List<InventorySnapshotEntry>
  >
  _inventorySnapshotsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.inventorySnapshots,
        aliasName: 'products__id__inventory_snapshots__product_id',
      );

  $$InventorySnapshotsTableProcessedTableManager get inventorySnapshotsRefs {
    final manager = $$InventorySnapshotsTableTableManager(
      $_db,
      $_db.inventorySnapshots,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _inventorySnapshotsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $InventoryMovementsTable,
    List<InventoryMovementEntry>
  >
  _inventoryMovementsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.inventoryMovements,
        aliasName: 'products__id__inventory_movements__product_id',
      );

  $$InventoryMovementsTableProcessedTableManager get inventoryMovementsRefs {
    final manager = $$InventoryMovementsTableTableManager(
      $_db,
      $_db.inventoryMovements,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _inventoryMovementsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProductUnitsTable, List<ProductUnitEntry>>
  _productUnitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productUnits,
    aliasName: 'products__id__product_units__product_id',
  );

  $$ProductUnitsTableProcessedTableManager get productUnitsRefs {
    final manager = $$ProductUnitsTableTableManager(
      $_db,
      $_db.productUnits,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_productUnitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UnitPricesTable, List<UnitPriceEntry>>
  _unitPricesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.unitPrices,
    aliasName: 'products__id__unit_prices__product_id',
  );

  $$UnitPricesTableProcessedTableManager get unitPricesRefs {
    final manager = $$UnitPricesTableTableManager(
      $_db,
      $_db.unitPrices,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_unitPricesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hindiName => $composableBuilder(
    column: $table.hindiName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mrpRupees => $composableBuilder(
    column: $table.mrpRupees,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mrpPaise => $composableBuilder(
    column: $table.mrpPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get piecePricePaise => $composableBuilder(
    column: $table.piecePricePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stripQty => $composableBuilder(
    column: $table.stripQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get boxQty => $composableBuilder(
    column: $table.boxQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gstRate => $composableBuilder(
    column: $table.gstRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get badge => $composableBuilder(
    column: $table.badge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> inventorySnapshotsRefs(
    Expression<bool> Function($$InventorySnapshotsTableFilterComposer f) f,
  ) {
    final $$InventorySnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inventorySnapshots,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InventorySnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.inventorySnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> inventoryMovementsRefs(
    Expression<bool> Function($$InventoryMovementsTableFilterComposer f) f,
  ) {
    final $$InventoryMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inventoryMovements,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InventoryMovementsTableFilterComposer(
            $db: $db,
            $table: $db.inventoryMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> productUnitsRefs(
    Expression<bool> Function($$ProductUnitsTableFilterComposer f) f,
  ) {
    final $$ProductUnitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productUnits,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductUnitsTableFilterComposer(
            $db: $db,
            $table: $db.productUnits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> unitPricesRefs(
    Expression<bool> Function($$UnitPricesTableFilterComposer f) f,
  ) {
    final $$UnitPricesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.unitPrices,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitPricesTableFilterComposer(
            $db: $db,
            $table: $db.unitPrices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hindiName => $composableBuilder(
    column: $table.hindiName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mrpRupees => $composableBuilder(
    column: $table.mrpRupees,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mrpPaise => $composableBuilder(
    column: $table.mrpPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get piecePricePaise => $composableBuilder(
    column: $table.piecePricePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stripQty => $composableBuilder(
    column: $table.stripQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get boxQty => $composableBuilder(
    column: $table.boxQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gstRate => $composableBuilder(
    column: $table.gstRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get badge => $composableBuilder(
    column: $table.badge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
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

  GeneratedColumn<String> get hindiName =>
      $composableBuilder(column: $table.hindiName, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get mrpRupees =>
      $composableBuilder(column: $table.mrpRupees, builder: (column) => column);

  GeneratedColumn<int> get mrpPaise =>
      $composableBuilder(column: $table.mrpPaise, builder: (column) => column);

  GeneratedColumn<int> get piecePricePaise => $composableBuilder(
    column: $table.piecePricePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stripQty =>
      $composableBuilder(column: $table.stripQty, builder: (column) => column);

  GeneratedColumn<int> get boxQty =>
      $composableBuilder(column: $table.boxQty, builder: (column) => column);

  GeneratedColumn<double> get gstRate =>
      $composableBuilder(column: $table.gstRate, builder: (column) => column);

  GeneratedColumn<String> get badge =>
      $composableBuilder(column: $table.badge, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> inventorySnapshotsRefs<T extends Object>(
    Expression<T> Function($$InventorySnapshotsTableAnnotationComposer a) f,
  ) {
    final $$InventorySnapshotsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.inventorySnapshots,
          getReferencedColumn: (t) => t.productId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InventorySnapshotsTableAnnotationComposer(
                $db: $db,
                $table: $db.inventorySnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> inventoryMovementsRefs<T extends Object>(
    Expression<T> Function($$InventoryMovementsTableAnnotationComposer a) f,
  ) {
    final $$InventoryMovementsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.inventoryMovements,
          getReferencedColumn: (t) => t.productId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InventoryMovementsTableAnnotationComposer(
                $db: $db,
                $table: $db.inventoryMovements,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> productUnitsRefs<T extends Object>(
    Expression<T> Function($$ProductUnitsTableAnnotationComposer a) f,
  ) {
    final $$ProductUnitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productUnits,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductUnitsTableAnnotationComposer(
            $db: $db,
            $table: $db.productUnits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> unitPricesRefs<T extends Object>(
    Expression<T> Function($$UnitPricesTableAnnotationComposer a) f,
  ) {
    final $$UnitPricesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.unitPrices,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitPricesTableAnnotationComposer(
            $db: $db,
            $table: $db.unitPrices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          ProductEntry,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (ProductEntry, $$ProductsTableReferences),
          ProductEntry,
          PrefetchHooks Function({
            bool inventorySnapshotsRefs,
            bool inventoryMovementsRefs,
            bool productUnitsRefs,
            bool unitPricesRefs,
          })
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> hindiName = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double> mrpRupees = const Value.absent(),
                Value<int> mrpPaise = const Value.absent(),
                Value<int> piecePricePaise = const Value.absent(),
                Value<int> stripQty = const Value.absent(),
                Value<int> boxQty = const Value.absent(),
                Value<double> gstRate = const Value.absent(),
                Value<String> badge = const Value.absent(),
                Value<String> imageUrl = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                name: name,
                hindiName: hindiName,
                category: category,
                mrpRupees: mrpRupees,
                mrpPaise: mrpPaise,
                piecePricePaise: piecePricePaise,
                stripQty: stripQty,
                boxQty: boxQty,
                gstRate: gstRate,
                badge: badge,
                imageUrl: imageUrl,
                isArchived: isArchived,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String hindiName,
                required String category,
                required double mrpRupees,
                Value<int> mrpPaise = const Value.absent(),
                required int piecePricePaise,
                required int stripQty,
                required int boxQty,
                Value<double> gstRate = const Value.absent(),
                Value<String> badge = const Value.absent(),
                Value<String> imageUrl = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                name: name,
                hindiName: hindiName,
                category: category,
                mrpRupees: mrpRupees,
                mrpPaise: mrpPaise,
                piecePricePaise: piecePricePaise,
                stripQty: stripQty,
                boxQty: boxQty,
                gstRate: gstRate,
                badge: badge,
                imageUrl: imageUrl,
                isArchived: isArchived,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductsTable, ProductEntry>(table),
                  $$ProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                inventorySnapshotsRefs = false,
                inventoryMovementsRefs = false,
                productUnitsRefs = false,
                unitPricesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (inventorySnapshotsRefs) db.inventorySnapshots,
                    if (inventoryMovementsRefs) db.inventoryMovements,
                    if (productUnitsRefs) db.productUnits,
                    if (unitPricesRefs) db.unitPrices,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (inventorySnapshotsRefs)
                        await $_getPrefetchedDataByColumns<
                          ProductEntry,
                          $ProductsTable,
                          InventorySnapshotEntry,
                          $InventorySnapshotsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._inventorySnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).inventorySnapshotsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'product_id',
                          typedResults: items,
                        ),
                      if (inventoryMovementsRefs)
                        await $_getPrefetchedDataByColumns<
                          ProductEntry,
                          $ProductsTable,
                          InventoryMovementEntry,
                          $InventoryMovementsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._inventoryMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).inventoryMovementsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'product_id',
                          typedResults: items,
                        ),
                      if (productUnitsRefs)
                        await $_getPrefetchedDataByColumns<
                          ProductEntry,
                          $ProductsTable,
                          ProductUnitEntry,
                          $ProductUnitsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._productUnitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).productUnitsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'product_id',
                          typedResults: items,
                        ),
                      if (unitPricesRefs)
                        await $_getPrefetchedDataByColumns<
                          ProductEntry,
                          $ProductsTable,
                          UnitPriceEntry,
                          $UnitPricesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._unitPricesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).unitPricesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'product_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      ProductEntry,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (ProductEntry, $$ProductsTableReferences),
      ProductEntry,
      PrefetchHooks Function({
        bool inventorySnapshotsRefs,
        bool inventoryMovementsRefs,
        bool productUnitsRefs,
        bool unitPricesRefs,
      })
    >;
typedef $$RetailersTableCreateCompanionBuilder =
    RetailersCompanion Function({
      required String id,
      required String name,
      required String ownerName,
      required String phone,
      required String address,
      required String area,
      required int creditLimitPaise,
      required int outstandingPaise,
      Value<bool> visitedToday,
      Value<int> totalTimeSpentSeconds,
      Value<int> visitCountToday,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String> classType,
      Value<String> classSource,
      Value<String?> routeId,
      Value<String> shopType,
      Value<String?> gstin,
      Value<String?> pincode,
      Value<String?> landmark,
      Value<String> status,
      Value<String?> createdByUserId,
      Value<double?> locationAccuracyMeters,
      Value<String> syncStatus,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RetailersTableUpdateCompanionBuilder =
    RetailersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> ownerName,
      Value<String> phone,
      Value<String> address,
      Value<String> area,
      Value<int> creditLimitPaise,
      Value<int> outstandingPaise,
      Value<bool> visitedToday,
      Value<int> totalTimeSpentSeconds,
      Value<int> visitCountToday,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String> classType,
      Value<String> classSource,
      Value<String?> routeId,
      Value<String> shopType,
      Value<String?> gstin,
      Value<String?> pincode,
      Value<String?> landmark,
      Value<String> status,
      Value<String?> createdByUserId,
      Value<double?> locationAccuracyMeters,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$RetailersTableReferences
    extends BaseReferences<_$AppDatabase, $RetailersTable, RetailerEntry> {
  $$RetailersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RouteStopsTable, List<RouteStopEntry>>
  _routeStopsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.routeStops,
    aliasName: 'retailers__id__route_stops__retailer_id',
  );

  $$RouteStopsTableProcessedTableManager get routeStopsRefs {
    final manager = $$RouteStopsTableTableManager(
      $_db,
      $_db.routeStops,
    ).filter((f) => f.retailerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_routeStopsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VisitsTable, List<VisitEntry>> _visitsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.visits,
    aliasName: 'retailers__id__visits__retailer_id',
  );

  $$VisitsTableProcessedTableManager get visitsRefs {
    final manager = $$VisitsTableTableManager(
      $_db,
      $_db.visits,
    ).filter((f) => f.retailerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_visitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RetailersTableFilterComposer
    extends Composer<_$AppDatabase, $RetailersTable> {
  $$RetailersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditLimitPaise => $composableBuilder(
    column: $table.creditLimitPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outstandingPaise => $composableBuilder(
    column: $table.outstandingPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get visitedToday => $composableBuilder(
    column: $table.visitedToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalTimeSpentSeconds => $composableBuilder(
    column: $table.totalTimeSpentSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visitCountToday => $composableBuilder(
    column: $table.visitCountToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classType => $composableBuilder(
    column: $table.classType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classSource => $composableBuilder(
    column: $table.classSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shopType => $composableBuilder(
    column: $table.shopType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pincode => $composableBuilder(
    column: $table.pincode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get landmark => $composableBuilder(
    column: $table.landmark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByUserId => $composableBuilder(
    column: $table.createdByUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get locationAccuracyMeters => $composableBuilder(
    column: $table.locationAccuracyMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> routeStopsRefs(
    Expression<bool> Function($$RouteStopsTableFilterComposer f) f,
  ) {
    final $$RouteStopsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routeStops,
      getReferencedColumn: (t) => t.retailerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RouteStopsTableFilterComposer(
            $db: $db,
            $table: $db.routeStops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> visitsRefs(
    Expression<bool> Function($$VisitsTableFilterComposer f) f,
  ) {
    final $$VisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.retailerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableFilterComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RetailersTableOrderingComposer
    extends Composer<_$AppDatabase, $RetailersTable> {
  $$RetailersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditLimitPaise => $composableBuilder(
    column: $table.creditLimitPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outstandingPaise => $composableBuilder(
    column: $table.outstandingPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get visitedToday => $composableBuilder(
    column: $table.visitedToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalTimeSpentSeconds => $composableBuilder(
    column: $table.totalTimeSpentSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visitCountToday => $composableBuilder(
    column: $table.visitCountToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classType => $composableBuilder(
    column: $table.classType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classSource => $composableBuilder(
    column: $table.classSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shopType => $composableBuilder(
    column: $table.shopType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pincode => $composableBuilder(
    column: $table.pincode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get landmark => $composableBuilder(
    column: $table.landmark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByUserId => $composableBuilder(
    column: $table.createdByUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get locationAccuracyMeters => $composableBuilder(
    column: $table.locationAccuracyMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RetailersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RetailersTable> {
  $$RetailersTableAnnotationComposer({
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

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<int> get creditLimitPaise => $composableBuilder(
    column: $table.creditLimitPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outstandingPaise => $composableBuilder(
    column: $table.outstandingPaise,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get visitedToday => $composableBuilder(
    column: $table.visitedToday,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalTimeSpentSeconds => $composableBuilder(
    column: $table.totalTimeSpentSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get visitCountToday => $composableBuilder(
    column: $table.visitCountToday,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get classType =>
      $composableBuilder(column: $table.classType, builder: (column) => column);

  GeneratedColumn<String> get classSource => $composableBuilder(
    column: $table.classSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get routeId =>
      $composableBuilder(column: $table.routeId, builder: (column) => column);

  GeneratedColumn<String> get shopType =>
      $composableBuilder(column: $table.shopType, builder: (column) => column);

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<String> get pincode =>
      $composableBuilder(column: $table.pincode, builder: (column) => column);

  GeneratedColumn<String> get landmark =>
      $composableBuilder(column: $table.landmark, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdByUserId => $composableBuilder(
    column: $table.createdByUserId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get locationAccuracyMeters => $composableBuilder(
    column: $table.locationAccuracyMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> routeStopsRefs<T extends Object>(
    Expression<T> Function($$RouteStopsTableAnnotationComposer a) f,
  ) {
    final $$RouteStopsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routeStops,
      getReferencedColumn: (t) => t.retailerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RouteStopsTableAnnotationComposer(
            $db: $db,
            $table: $db.routeStops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> visitsRefs<T extends Object>(
    Expression<T> Function($$VisitsTableAnnotationComposer a) f,
  ) {
    final $$VisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.visits,
      getReferencedColumn: (t) => t.retailerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.visits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RetailersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RetailersTable,
          RetailerEntry,
          $$RetailersTableFilterComposer,
          $$RetailersTableOrderingComposer,
          $$RetailersTableAnnotationComposer,
          $$RetailersTableCreateCompanionBuilder,
          $$RetailersTableUpdateCompanionBuilder,
          (RetailerEntry, $$RetailersTableReferences),
          RetailerEntry,
          PrefetchHooks Function({bool routeStopsRefs, bool visitsRefs})
        > {
  $$RetailersTableTableManager(_$AppDatabase db, $RetailersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RetailersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RetailersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RetailersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ownerName = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> area = const Value.absent(),
                Value<int> creditLimitPaise = const Value.absent(),
                Value<int> outstandingPaise = const Value.absent(),
                Value<bool> visitedToday = const Value.absent(),
                Value<int> totalTimeSpentSeconds = const Value.absent(),
                Value<int> visitCountToday = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String> classType = const Value.absent(),
                Value<String> classSource = const Value.absent(),
                Value<String?> routeId = const Value.absent(),
                Value<String> shopType = const Value.absent(),
                Value<String?> gstin = const Value.absent(),
                Value<String?> pincode = const Value.absent(),
                Value<String?> landmark = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> createdByUserId = const Value.absent(),
                Value<double?> locationAccuracyMeters = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RetailersCompanion(
                id: id,
                name: name,
                ownerName: ownerName,
                phone: phone,
                address: address,
                area: area,
                creditLimitPaise: creditLimitPaise,
                outstandingPaise: outstandingPaise,
                visitedToday: visitedToday,
                totalTimeSpentSeconds: totalTimeSpentSeconds,
                visitCountToday: visitCountToday,
                latitude: latitude,
                longitude: longitude,
                classType: classType,
                classSource: classSource,
                routeId: routeId,
                shopType: shopType,
                gstin: gstin,
                pincode: pincode,
                landmark: landmark,
                status: status,
                createdByUserId: createdByUserId,
                locationAccuracyMeters: locationAccuracyMeters,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String ownerName,
                required String phone,
                required String address,
                required String area,
                required int creditLimitPaise,
                required int outstandingPaise,
                Value<bool> visitedToday = const Value.absent(),
                Value<int> totalTimeSpentSeconds = const Value.absent(),
                Value<int> visitCountToday = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String> classType = const Value.absent(),
                Value<String> classSource = const Value.absent(),
                Value<String?> routeId = const Value.absent(),
                Value<String> shopType = const Value.absent(),
                Value<String?> gstin = const Value.absent(),
                Value<String?> pincode = const Value.absent(),
                Value<String?> landmark = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> createdByUserId = const Value.absent(),
                Value<double?> locationAccuracyMeters = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RetailersCompanion.insert(
                id: id,
                name: name,
                ownerName: ownerName,
                phone: phone,
                address: address,
                area: area,
                creditLimitPaise: creditLimitPaise,
                outstandingPaise: outstandingPaise,
                visitedToday: visitedToday,
                totalTimeSpentSeconds: totalTimeSpentSeconds,
                visitCountToday: visitCountToday,
                latitude: latitude,
                longitude: longitude,
                classType: classType,
                classSource: classSource,
                routeId: routeId,
                shopType: shopType,
                gstin: gstin,
                pincode: pincode,
                landmark: landmark,
                status: status,
                createdByUserId: createdByUserId,
                locationAccuracyMeters: locationAccuracyMeters,
                syncStatus: syncStatus,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RetailersTable, RetailerEntry>(table),
                  $$RetailersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({routeStopsRefs = false, visitsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (routeStopsRefs) db.routeStops,
                    if (visitsRefs) db.visits,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (routeStopsRefs)
                        await $_getPrefetchedDataByColumns<
                          RetailerEntry,
                          $RetailersTable,
                          RouteStopEntry,
                          $RouteStopsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RetailersTableReferences
                              ._routeStopsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RetailersTableReferences(
                                db,
                                table,
                                p0,
                              ).routeStopsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'retailer_id',
                          typedResults: items,
                        ),
                      if (visitsRefs)
                        await $_getPrefetchedDataByColumns<
                          RetailerEntry,
                          $RetailersTable,
                          VisitEntry,
                          $VisitsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RetailersTableReferences
                              ._visitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RetailersTableReferences(
                                db,
                                table,
                                p0,
                              ).visitsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'retailer_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RetailersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RetailersTable,
      RetailerEntry,
      $$RetailersTableFilterComposer,
      $$RetailersTableOrderingComposer,
      $$RetailersTableAnnotationComposer,
      $$RetailersTableCreateCompanionBuilder,
      $$RetailersTableUpdateCompanionBuilder,
      (RetailerEntry, $$RetailersTableReferences),
      RetailerEntry,
      PrefetchHooks Function({bool routeStopsRefs, bool visitsRefs})
    >;
typedef $$InventorySnapshotsTableCreateCompanionBuilder =
    InventorySnapshotsCompanion Function({
      required String productId,
      Value<int> godownCartons,
      Value<int> godownLoosePieces,
      Value<int> carCartons,
      Value<int> carLoosePieces,
      Value<int> damagedCartons,
      Value<int> damagedLoosePieces,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$InventorySnapshotsTableUpdateCompanionBuilder =
    InventorySnapshotsCompanion Function({
      Value<String> productId,
      Value<int> godownCartons,
      Value<int> godownLoosePieces,
      Value<int> carCartons,
      Value<int> carLoosePieces,
      Value<int> damagedCartons,
      Value<int> damagedLoosePieces,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$InventorySnapshotsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $InventorySnapshotsTable,
          InventorySnapshotEntry
        > {
  $$InventorySnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('inventory_snapshots__product_id__products__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InventorySnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $InventorySnapshotsTable> {
  $$InventorySnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get godownCartons => $composableBuilder(
    column: $table.godownCartons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get godownLoosePieces => $composableBuilder(
    column: $table.godownLoosePieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carCartons => $composableBuilder(
    column: $table.carCartons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carLoosePieces => $composableBuilder(
    column: $table.carLoosePieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get damagedCartons => $composableBuilder(
    column: $table.damagedCartons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get damagedLoosePieces => $composableBuilder(
    column: $table.damagedLoosePieces,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventorySnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventorySnapshotsTable> {
  $$InventorySnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get godownCartons => $composableBuilder(
    column: $table.godownCartons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get godownLoosePieces => $composableBuilder(
    column: $table.godownLoosePieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carCartons => $composableBuilder(
    column: $table.carCartons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carLoosePieces => $composableBuilder(
    column: $table.carLoosePieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get damagedCartons => $composableBuilder(
    column: $table.damagedCartons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get damagedLoosePieces => $composableBuilder(
    column: $table.damagedLoosePieces,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventorySnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventorySnapshotsTable> {
  $$InventorySnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get godownCartons => $composableBuilder(
    column: $table.godownCartons,
    builder: (column) => column,
  );

  GeneratedColumn<int> get godownLoosePieces => $composableBuilder(
    column: $table.godownLoosePieces,
    builder: (column) => column,
  );

  GeneratedColumn<int> get carCartons => $composableBuilder(
    column: $table.carCartons,
    builder: (column) => column,
  );

  GeneratedColumn<int> get carLoosePieces => $composableBuilder(
    column: $table.carLoosePieces,
    builder: (column) => column,
  );

  GeneratedColumn<int> get damagedCartons => $composableBuilder(
    column: $table.damagedCartons,
    builder: (column) => column,
  );

  GeneratedColumn<int> get damagedLoosePieces => $composableBuilder(
    column: $table.damagedLoosePieces,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventorySnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InventorySnapshotsTable,
          InventorySnapshotEntry,
          $$InventorySnapshotsTableFilterComposer,
          $$InventorySnapshotsTableOrderingComposer,
          $$InventorySnapshotsTableAnnotationComposer,
          $$InventorySnapshotsTableCreateCompanionBuilder,
          $$InventorySnapshotsTableUpdateCompanionBuilder,
          (InventorySnapshotEntry, $$InventorySnapshotsTableReferences),
          InventorySnapshotEntry,
          PrefetchHooks Function({bool productId})
        > {
  $$InventorySnapshotsTableTableManager(
    _$AppDatabase db,
    $InventorySnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventorySnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventorySnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventorySnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> productId = const Value.absent(),
                Value<int> godownCartons = const Value.absent(),
                Value<int> godownLoosePieces = const Value.absent(),
                Value<int> carCartons = const Value.absent(),
                Value<int> carLoosePieces = const Value.absent(),
                Value<int> damagedCartons = const Value.absent(),
                Value<int> damagedLoosePieces = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventorySnapshotsCompanion(
                productId: productId,
                godownCartons: godownCartons,
                godownLoosePieces: godownLoosePieces,
                carCartons: carCartons,
                carLoosePieces: carLoosePieces,
                damagedCartons: damagedCartons,
                damagedLoosePieces: damagedLoosePieces,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String productId,
                Value<int> godownCartons = const Value.absent(),
                Value<int> godownLoosePieces = const Value.absent(),
                Value<int> carCartons = const Value.absent(),
                Value<int> carLoosePieces = const Value.absent(),
                Value<int> damagedCartons = const Value.absent(),
                Value<int> damagedLoosePieces = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => InventorySnapshotsCompanion.insert(
                productId: productId,
                godownCartons: godownCartons,
                godownLoosePieces: godownLoosePieces,
                carCartons: carCartons,
                carLoosePieces: carLoosePieces,
                damagedCartons: damagedCartons,
                damagedLoosePieces: damagedLoosePieces,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InventorySnapshotsTable, InventorySnapshotEntry>(
                    table,
                  ),
                  $$InventorySnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
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
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable:
                                    $$InventorySnapshotsTableReferences
                                        ._productIdTable(db),
                                referencedColumn:
                                    $$InventorySnapshotsTableReferences
                                        ._productIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$InventorySnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InventorySnapshotsTable,
      InventorySnapshotEntry,
      $$InventorySnapshotsTableFilterComposer,
      $$InventorySnapshotsTableOrderingComposer,
      $$InventorySnapshotsTableAnnotationComposer,
      $$InventorySnapshotsTableCreateCompanionBuilder,
      $$InventorySnapshotsTableUpdateCompanionBuilder,
      (InventorySnapshotEntry, $$InventorySnapshotsTableReferences),
      InventorySnapshotEntry,
      PrefetchHooks Function({bool productId})
    >;
typedef $$InventoryMovementsTableCreateCompanionBuilder =
    InventoryMovementsCompanion Function({
      required String id,
      required String productId,
      required String movementType,
      required int cartonDelta,
      required int loosePieceDelta,
      Value<String> reason,
      Value<String?> locationId,
      Value<String?> invoiceNumber,
      Value<String?> batchNumber,
      Value<String?> supplierName,
      Value<String?> idempotencyKey,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$InventoryMovementsTableUpdateCompanionBuilder =
    InventoryMovementsCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<String> movementType,
      Value<int> cartonDelta,
      Value<int> loosePieceDelta,
      Value<String> reason,
      Value<String?> locationId,
      Value<String?> invoiceNumber,
      Value<String?> batchNumber,
      Value<String?> supplierName,
      Value<String?> idempotencyKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$InventoryMovementsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $InventoryMovementsTable,
          InventoryMovementEntry
        > {
  $$InventoryMovementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('inventory_movements__product_id__products__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InventoryMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get movementType => $composableBuilder(
    column: $table.movementType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cartonDelta => $composableBuilder(
    column: $table.cartonDelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loosePieceDelta => $composableBuilder(
    column: $table.loosePieceDelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get batchNumber => $composableBuilder(
    column: $table.batchNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get movementType => $composableBuilder(
    column: $table.movementType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cartonDelta => $composableBuilder(
    column: $table.cartonDelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loosePieceDelta => $composableBuilder(
    column: $table.loosePieceDelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get batchNumber => $composableBuilder(
    column: $table.batchNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get movementType => $composableBuilder(
    column: $table.movementType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cartonDelta => $composableBuilder(
    column: $table.cartonDelta,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loosePieceDelta => $composableBuilder(
    column: $table.loosePieceDelta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get batchNumber => $composableBuilder(
    column: $table.batchNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InventoryMovementsTable,
          InventoryMovementEntry,
          $$InventoryMovementsTableFilterComposer,
          $$InventoryMovementsTableOrderingComposer,
          $$InventoryMovementsTableAnnotationComposer,
          $$InventoryMovementsTableCreateCompanionBuilder,
          $$InventoryMovementsTableUpdateCompanionBuilder,
          (InventoryMovementEntry, $$InventoryMovementsTableReferences),
          InventoryMovementEntry,
          PrefetchHooks Function({bool productId})
        > {
  $$InventoryMovementsTableTableManager(
    _$AppDatabase db,
    $InventoryMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryMovementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> movementType = const Value.absent(),
                Value<int> cartonDelta = const Value.absent(),
                Value<int> loosePieceDelta = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<String?> invoiceNumber = const Value.absent(),
                Value<String?> batchNumber = const Value.absent(),
                Value<String?> supplierName = const Value.absent(),
                Value<String?> idempotencyKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventoryMovementsCompanion(
                id: id,
                productId: productId,
                movementType: movementType,
                cartonDelta: cartonDelta,
                loosePieceDelta: loosePieceDelta,
                reason: reason,
                locationId: locationId,
                invoiceNumber: invoiceNumber,
                batchNumber: batchNumber,
                supplierName: supplierName,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                required String movementType,
                required int cartonDelta,
                required int loosePieceDelta,
                Value<String> reason = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<String?> invoiceNumber = const Value.absent(),
                Value<String?> batchNumber = const Value.absent(),
                Value<String?> supplierName = const Value.absent(),
                Value<String?> idempotencyKey = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => InventoryMovementsCompanion.insert(
                id: id,
                productId: productId,
                movementType: movementType,
                cartonDelta: cartonDelta,
                loosePieceDelta: loosePieceDelta,
                reason: reason,
                locationId: locationId,
                invoiceNumber: invoiceNumber,
                batchNumber: batchNumber,
                supplierName: supplierName,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InventoryMovementsTable, InventoryMovementEntry>(
                    table,
                  ),
                  $$InventoryMovementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
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
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable:
                                    $$InventoryMovementsTableReferences
                                        ._productIdTable(db),
                                referencedColumn:
                                    $$InventoryMovementsTableReferences
                                        ._productIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$InventoryMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InventoryMovementsTable,
      InventoryMovementEntry,
      $$InventoryMovementsTableFilterComposer,
      $$InventoryMovementsTableOrderingComposer,
      $$InventoryMovementsTableAnnotationComposer,
      $$InventoryMovementsTableCreateCompanionBuilder,
      $$InventoryMovementsTableUpdateCompanionBuilder,
      (InventoryMovementEntry, $$InventoryMovementsTableReferences),
      InventoryMovementEntry,
      PrefetchHooks Function({bool productId})
    >;
typedef $$DatabaseMetadataTableCreateCompanionBuilder =
    DatabaseMetadataCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DatabaseMetadataTableUpdateCompanionBuilder =
    DatabaseMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DatabaseMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $DatabaseMetadataTable> {
  $$DatabaseMetadataTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DatabaseMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $DatabaseMetadataTable> {
  $$DatabaseMetadataTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatabaseMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $DatabaseMetadataTable> {
  $$DatabaseMetadataTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DatabaseMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DatabaseMetadataTable,
          DatabaseMetadataEntry,
          $$DatabaseMetadataTableFilterComposer,
          $$DatabaseMetadataTableOrderingComposer,
          $$DatabaseMetadataTableAnnotationComposer,
          $$DatabaseMetadataTableCreateCompanionBuilder,
          $$DatabaseMetadataTableUpdateCompanionBuilder,
          (
            DatabaseMetadataEntry,
            BaseReferences<
              _$AppDatabase,
              $DatabaseMetadataTable,
              DatabaseMetadataEntry
            >,
          ),
          DatabaseMetadataEntry,
          PrefetchHooks Function()
        > {
  $$DatabaseMetadataTableTableManager(
    _$AppDatabase db,
    $DatabaseMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatabaseMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatabaseMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatabaseMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatabaseMetadataCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DatabaseMetadataCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DatabaseMetadataTable, DatabaseMetadataEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $DatabaseMetadataTable,
                    DatabaseMetadataEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DatabaseMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DatabaseMetadataTable,
      DatabaseMetadataEntry,
      $$DatabaseMetadataTableFilterComposer,
      $$DatabaseMetadataTableOrderingComposer,
      $$DatabaseMetadataTableAnnotationComposer,
      $$DatabaseMetadataTableCreateCompanionBuilder,
      $$DatabaseMetadataTableUpdateCompanionBuilder,
      (
        DatabaseMetadataEntry,
        BaseReferences<
          _$AppDatabase,
          $DatabaseMetadataTable,
          DatabaseMetadataEntry
        >,
      ),
      DatabaseMetadataEntry,
      PrefetchHooks Function()
    >;
typedef $$OutboxMutationsTableCreateCompanionBuilder =
    OutboxMutationsCompanion Function({
      required String id,
      required String organizationId,
      required String userId,
      required String idempotencyKey,
      required String mutationType,
      required String payloadJson,
      required int sequenceOrder,
      Value<String> syncStatus,
      Value<String?> provisionalBusinessId,
      Value<String?> leaseToken,
      Value<int> leaseGeneration,
      Value<int?> leaseExpiresAtMs,
      Value<int> attemptCount,
      Value<String?> lastErrorCode,
      Value<int?> nextRetryAtMs,
      required int createdAtEpochMs,
      Value<int?> syncedAtEpochMs,
      Value<int> rowid,
    });
typedef $$OutboxMutationsTableUpdateCompanionBuilder =
    OutboxMutationsCompanion Function({
      Value<String> id,
      Value<String> organizationId,
      Value<String> userId,
      Value<String> idempotencyKey,
      Value<String> mutationType,
      Value<String> payloadJson,
      Value<int> sequenceOrder,
      Value<String> syncStatus,
      Value<String?> provisionalBusinessId,
      Value<String?> leaseToken,
      Value<int> leaseGeneration,
      Value<int?> leaseExpiresAtMs,
      Value<int> attemptCount,
      Value<String?> lastErrorCode,
      Value<int?> nextRetryAtMs,
      Value<int> createdAtEpochMs,
      Value<int?> syncedAtEpochMs,
      Value<int> rowid,
    });

class $$OutboxMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxMutationsTable> {
  $$OutboxMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationType => $composableBuilder(
    column: $table.mutationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceOrder => $composableBuilder(
    column: $table.sequenceOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provisionalBusinessId => $composableBuilder(
    column: $table.provisionalBusinessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseToken => $composableBuilder(
    column: $table.leaseToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseGeneration => $composableBuilder(
    column: $table.leaseGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseExpiresAtMs => $composableBuilder(
    column: $table.leaseExpiresAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAtMs => $composableBuilder(
    column: $table.nextRetryAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAtEpochMs => $composableBuilder(
    column: $table.syncedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxMutationsTable> {
  $$OutboxMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationType => $composableBuilder(
    column: $table.mutationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceOrder => $composableBuilder(
    column: $table.sequenceOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provisionalBusinessId => $composableBuilder(
    column: $table.provisionalBusinessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseToken => $composableBuilder(
    column: $table.leaseToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseGeneration => $composableBuilder(
    column: $table.leaseGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseExpiresAtMs => $composableBuilder(
    column: $table.leaseExpiresAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAtMs => $composableBuilder(
    column: $table.nextRetryAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAtEpochMs => $composableBuilder(
    column: $table.syncedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxMutationsTable> {
  $$OutboxMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mutationType => $composableBuilder(
    column: $table.mutationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequenceOrder => $composableBuilder(
    column: $table.sequenceOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provisionalBusinessId => $composableBuilder(
    column: $table.provisionalBusinessId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leaseToken => $composableBuilder(
    column: $table.leaseToken,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseGeneration => $composableBuilder(
    column: $table.leaseGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseExpiresAtMs => $composableBuilder(
    column: $table.leaseExpiresAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextRetryAtMs => $composableBuilder(
    column: $table.nextRetryAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncedAtEpochMs => $composableBuilder(
    column: $table.syncedAtEpochMs,
    builder: (column) => column,
  );
}

class $$OutboxMutationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxMutationsTable,
          OutboxMutationEntry,
          $$OutboxMutationsTableFilterComposer,
          $$OutboxMutationsTableOrderingComposer,
          $$OutboxMutationsTableAnnotationComposer,
          $$OutboxMutationsTableCreateCompanionBuilder,
          $$OutboxMutationsTableUpdateCompanionBuilder,
          (
            OutboxMutationEntry,
            BaseReferences<
              _$AppDatabase,
              $OutboxMutationsTable,
              OutboxMutationEntry
            >,
          ),
          OutboxMutationEntry,
          PrefetchHooks Function()
        > {
  $$OutboxMutationsTableTableManager(
    _$AppDatabase db,
    $OutboxMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> organizationId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> mutationType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> sequenceOrder = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> provisionalBusinessId = const Value.absent(),
                Value<String?> leaseToken = const Value.absent(),
                Value<int> leaseGeneration = const Value.absent(),
                Value<int?> leaseExpiresAtMs = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int?> nextRetryAtMs = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int?> syncedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxMutationsCompanion(
                id: id,
                organizationId: organizationId,
                userId: userId,
                idempotencyKey: idempotencyKey,
                mutationType: mutationType,
                payloadJson: payloadJson,
                sequenceOrder: sequenceOrder,
                syncStatus: syncStatus,
                provisionalBusinessId: provisionalBusinessId,
                leaseToken: leaseToken,
                leaseGeneration: leaseGeneration,
                leaseExpiresAtMs: leaseExpiresAtMs,
                attemptCount: attemptCount,
                lastErrorCode: lastErrorCode,
                nextRetryAtMs: nextRetryAtMs,
                createdAtEpochMs: createdAtEpochMs,
                syncedAtEpochMs: syncedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String organizationId,
                required String userId,
                required String idempotencyKey,
                required String mutationType,
                required String payloadJson,
                required int sequenceOrder,
                Value<String> syncStatus = const Value.absent(),
                Value<String?> provisionalBusinessId = const Value.absent(),
                Value<String?> leaseToken = const Value.absent(),
                Value<int> leaseGeneration = const Value.absent(),
                Value<int?> leaseExpiresAtMs = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int?> nextRetryAtMs = const Value.absent(),
                required int createdAtEpochMs,
                Value<int?> syncedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxMutationsCompanion.insert(
                id: id,
                organizationId: organizationId,
                userId: userId,
                idempotencyKey: idempotencyKey,
                mutationType: mutationType,
                payloadJson: payloadJson,
                sequenceOrder: sequenceOrder,
                syncStatus: syncStatus,
                provisionalBusinessId: provisionalBusinessId,
                leaseToken: leaseToken,
                leaseGeneration: leaseGeneration,
                leaseExpiresAtMs: leaseExpiresAtMs,
                attemptCount: attemptCount,
                lastErrorCode: lastErrorCode,
                nextRetryAtMs: nextRetryAtMs,
                createdAtEpochMs: createdAtEpochMs,
                syncedAtEpochMs: syncedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxMutationsTable, OutboxMutationEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $OutboxMutationsTable,
                    OutboxMutationEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxMutationsTable,
      OutboxMutationEntry,
      $$OutboxMutationsTableFilterComposer,
      $$OutboxMutationsTableOrderingComposer,
      $$OutboxMutationsTableAnnotationComposer,
      $$OutboxMutationsTableCreateCompanionBuilder,
      $$OutboxMutationsTableUpdateCompanionBuilder,
      (
        OutboxMutationEntry,
        BaseReferences<
          _$AppDatabase,
          $OutboxMutationsTable,
          OutboxMutationEntry
        >,
      ),
      OutboxMutationEntry,
      PrefetchHooks Function()
    >;
typedef $$WarehouseHubsTableCreateCompanionBuilder =
    WarehouseHubsCompanion Function({
      required String id,
      required String name,
      required String code,
      required String address,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int> capacityBoxes,
      Value<int> activeStaffCount,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WarehouseHubsTableUpdateCompanionBuilder =
    WarehouseHubsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> code,
      Value<String> address,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int> capacityBoxes,
      Value<int> activeStaffCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$WarehouseHubsTableFilterComposer
    extends Composer<_$AppDatabase, $WarehouseHubsTable> {
  $$WarehouseHubsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capacityBoxes => $composableBuilder(
    column: $table.capacityBoxes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeStaffCount => $composableBuilder(
    column: $table.activeStaffCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WarehouseHubsTableOrderingComposer
    extends Composer<_$AppDatabase, $WarehouseHubsTable> {
  $$WarehouseHubsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capacityBoxes => $composableBuilder(
    column: $table.capacityBoxes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeStaffCount => $composableBuilder(
    column: $table.activeStaffCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WarehouseHubsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WarehouseHubsTable> {
  $$WarehouseHubsTableAnnotationComposer({
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

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get capacityBoxes => $composableBuilder(
    column: $table.capacityBoxes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeStaffCount => $composableBuilder(
    column: $table.activeStaffCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WarehouseHubsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WarehouseHubsTable,
          WarehouseHubEntry,
          $$WarehouseHubsTableFilterComposer,
          $$WarehouseHubsTableOrderingComposer,
          $$WarehouseHubsTableAnnotationComposer,
          $$WarehouseHubsTableCreateCompanionBuilder,
          $$WarehouseHubsTableUpdateCompanionBuilder,
          (
            WarehouseHubEntry,
            BaseReferences<
              _$AppDatabase,
              $WarehouseHubsTable,
              WarehouseHubEntry
            >,
          ),
          WarehouseHubEntry,
          PrefetchHooks Function()
        > {
  $$WarehouseHubsTableTableManager(_$AppDatabase db, $WarehouseHubsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WarehouseHubsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WarehouseHubsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WarehouseHubsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int> capacityBoxes = const Value.absent(),
                Value<int> activeStaffCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WarehouseHubsCompanion(
                id: id,
                name: name,
                code: code,
                address: address,
                latitude: latitude,
                longitude: longitude,
                capacityBoxes: capacityBoxes,
                activeStaffCount: activeStaffCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String code,
                required String address,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int> capacityBoxes = const Value.absent(),
                Value<int> activeStaffCount = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WarehouseHubsCompanion.insert(
                id: id,
                name: name,
                code: code,
                address: address,
                latitude: latitude,
                longitude: longitude,
                capacityBoxes: capacityBoxes,
                activeStaffCount: activeStaffCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WarehouseHubsTable, WarehouseHubEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WarehouseHubsTable,
                    WarehouseHubEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WarehouseHubsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WarehouseHubsTable,
      WarehouseHubEntry,
      $$WarehouseHubsTableFilterComposer,
      $$WarehouseHubsTableOrderingComposer,
      $$WarehouseHubsTableAnnotationComposer,
      $$WarehouseHubsTableCreateCompanionBuilder,
      $$WarehouseHubsTableUpdateCompanionBuilder,
      (
        WarehouseHubEntry,
        BaseReferences<_$AppDatabase, $WarehouseHubsTable, WarehouseHubEntry>,
      ),
      WarehouseHubEntry,
      PrefetchHooks Function()
    >;
typedef $$RoutesTableCreateCompanionBuilder =
    RoutesCompanion Function({
      required String id,
      required String name,
      required String code,
      required String dayOfWeek,
      Value<bool> isActive,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RoutesTableUpdateCompanionBuilder =
    RoutesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> code,
      Value<String> dayOfWeek,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$RoutesTableReferences
    extends BaseReferences<_$AppDatabase, $RoutesTable, RouteEntry> {
  $$RoutesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RouteStopsTable, List<RouteStopEntry>>
  _routeStopsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.routeStops,
    aliasName: 'routes__id__route_stops__route_id',
  );

  $$RouteStopsTableProcessedTableManager get routeStopsRefs {
    final manager = $$RouteStopsTableTableManager(
      $_db,
      $_db.routeStops,
    ).filter((f) => f.routeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_routeStopsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoutesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> routeStopsRefs(
    Expression<bool> Function($$RouteStopsTableFilterComposer f) f,
  ) {
    final $$RouteStopsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routeStops,
      getReferencedColumn: (t) => t.routeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RouteStopsTableFilterComposer(
            $db: $db,
            $table: $db.routeStops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableAnnotationComposer({
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

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> routeStopsRefs<T extends Object>(
    Expression<T> Function($$RouteStopsTableAnnotationComposer a) f,
  ) {
    final $$RouteStopsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routeStops,
      getReferencedColumn: (t) => t.routeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RouteStopsTableAnnotationComposer(
            $db: $db,
            $table: $db.routeStops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutesTable,
          RouteEntry,
          $$RoutesTableFilterComposer,
          $$RoutesTableOrderingComposer,
          $$RoutesTableAnnotationComposer,
          $$RoutesTableCreateCompanionBuilder,
          $$RoutesTableUpdateCompanionBuilder,
          (RouteEntry, $$RoutesTableReferences),
          RouteEntry,
          PrefetchHooks Function({bool routeStopsRefs})
        > {
  $$RoutesTableTableManager(_$AppDatabase db, $RoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> dayOfWeek = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutesCompanion(
                id: id,
                name: name,
                code: code,
                dayOfWeek: dayOfWeek,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String code,
                required String dayOfWeek,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RoutesCompanion.insert(
                id: id,
                name: name,
                code: code,
                dayOfWeek: dayOfWeek,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RoutesTable, RouteEntry>(table),
                  $$RoutesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({routeStopsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (routeStopsRefs) db.routeStops],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (routeStopsRefs)
                    await $_getPrefetchedDataByColumns<
                      RouteEntry,
                      $RoutesTable,
                      RouteStopEntry,
                      $RouteStopsTable
                    >(
                      currentTable: table,
                      referencedTable: $$RoutesTableReferences
                          ._routeStopsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RoutesTableReferences(db, table, p0).routeStopsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'route_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutesTable,
      RouteEntry,
      $$RoutesTableFilterComposer,
      $$RoutesTableOrderingComposer,
      $$RoutesTableAnnotationComposer,
      $$RoutesTableCreateCompanionBuilder,
      $$RoutesTableUpdateCompanionBuilder,
      (RouteEntry, $$RoutesTableReferences),
      RouteEntry,
      PrefetchHooks Function({bool routeStopsRefs})
    >;
typedef $$RouteStopsTableCreateCompanionBuilder =
    RouteStopsCompanion Function({
      required String id,
      required String routeId,
      required String retailerId,
      required int stopSequence,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RouteStopsTableUpdateCompanionBuilder =
    RouteStopsCompanion Function({
      Value<String> id,
      Value<String> routeId,
      Value<String> retailerId,
      Value<int> stopSequence,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$RouteStopsTableReferences
    extends BaseReferences<_$AppDatabase, $RouteStopsTable, RouteStopEntry> {
  $$RouteStopsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoutesTable _routeIdTable(_$AppDatabase db) =>
      db.routes.createAlias('route_stops__route_id__routes__id');

  $$RoutesTableProcessedTableManager get routeId {
    final $_column = $_itemColumn<String>('route_id')!;

    final manager = $$RoutesTableTableManager(
      $_db,
      $_db.routes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RetailersTable _retailerIdTable(_$AppDatabase db) =>
      db.retailers.createAlias('route_stops__retailer_id__retailers__id');

  $$RetailersTableProcessedTableManager get retailerId {
    final $_column = $_itemColumn<String>('retailer_id')!;

    final manager = $$RetailersTableTableManager(
      $_db,
      $_db.retailers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_retailerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RouteStopsTableFilterComposer
    extends Composer<_$AppDatabase, $RouteStopsTable> {
  $$RouteStopsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stopSequence => $composableBuilder(
    column: $table.stopSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutesTableFilterComposer get routeId {
    final $$RoutesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routeId,
      referencedTable: $db.routes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutesTableFilterComposer(
            $db: $db,
            $table: $db.routes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RetailersTableFilterComposer get retailerId {
    final $$RetailersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.retailerId,
      referencedTable: $db.retailers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetailersTableFilterComposer(
            $db: $db,
            $table: $db.retailers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RouteStopsTableOrderingComposer
    extends Composer<_$AppDatabase, $RouteStopsTable> {
  $$RouteStopsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stopSequence => $composableBuilder(
    column: $table.stopSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutesTableOrderingComposer get routeId {
    final $$RoutesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routeId,
      referencedTable: $db.routes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutesTableOrderingComposer(
            $db: $db,
            $table: $db.routes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RetailersTableOrderingComposer get retailerId {
    final $$RetailersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.retailerId,
      referencedTable: $db.retailers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetailersTableOrderingComposer(
            $db: $db,
            $table: $db.retailers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RouteStopsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RouteStopsTable> {
  $$RouteStopsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get stopSequence => $composableBuilder(
    column: $table.stopSequence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RoutesTableAnnotationComposer get routeId {
    final $$RoutesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routeId,
      referencedTable: $db.routes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutesTableAnnotationComposer(
            $db: $db,
            $table: $db.routes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RetailersTableAnnotationComposer get retailerId {
    final $$RetailersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.retailerId,
      referencedTable: $db.retailers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetailersTableAnnotationComposer(
            $db: $db,
            $table: $db.retailers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RouteStopsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RouteStopsTable,
          RouteStopEntry,
          $$RouteStopsTableFilterComposer,
          $$RouteStopsTableOrderingComposer,
          $$RouteStopsTableAnnotationComposer,
          $$RouteStopsTableCreateCompanionBuilder,
          $$RouteStopsTableUpdateCompanionBuilder,
          (RouteStopEntry, $$RouteStopsTableReferences),
          RouteStopEntry,
          PrefetchHooks Function({bool routeId, bool retailerId})
        > {
  $$RouteStopsTableTableManager(_$AppDatabase db, $RouteStopsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RouteStopsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RouteStopsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RouteStopsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routeId = const Value.absent(),
                Value<String> retailerId = const Value.absent(),
                Value<int> stopSequence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RouteStopsCompanion(
                id: id,
                routeId: routeId,
                retailerId: retailerId,
                stopSequence: stopSequence,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routeId,
                required String retailerId,
                required int stopSequence,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RouteStopsCompanion.insert(
                id: id,
                routeId: routeId,
                retailerId: retailerId,
                stopSequence: stopSequence,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RouteStopsTable, RouteStopEntry>(table),
                  $$RouteStopsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({routeId = false, retailerId = false}) {
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
                    if (routeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.routeId,
                                referencedTable: $$RouteStopsTableReferences
                                    ._routeIdTable(db),
                                referencedColumn: $$RouteStopsTableReferences
                                    ._routeIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (retailerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.retailerId,
                                referencedTable: $$RouteStopsTableReferences
                                    ._retailerIdTable(db),
                                referencedColumn: $$RouteStopsTableReferences
                                    ._retailerIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$RouteStopsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RouteStopsTable,
      RouteStopEntry,
      $$RouteStopsTableFilterComposer,
      $$RouteStopsTableOrderingComposer,
      $$RouteStopsTableAnnotationComposer,
      $$RouteStopsTableCreateCompanionBuilder,
      $$RouteStopsTableUpdateCompanionBuilder,
      (RouteStopEntry, $$RouteStopsTableReferences),
      RouteStopEntry,
      PrefetchHooks Function({bool routeId, bool retailerId})
    >;
typedef $$ClassSettingsTableCreateCompanionBuilder =
    ClassSettingsCompanion Function({
      required String className,
      required int defaultCreditLimitPaise,
      required int creditDays,
      required int visitFrequencyDays,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ClassSettingsTableUpdateCompanionBuilder =
    ClassSettingsCompanion Function({
      Value<String> className,
      Value<int> defaultCreditLimitPaise,
      Value<int> creditDays,
      Value<int> visitFrequencyDays,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ClassSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ClassSettingsTable> {
  $$ClassSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultCreditLimitPaise => $composableBuilder(
    column: $table.defaultCreditLimitPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditDays => $composableBuilder(
    column: $table.creditDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visitFrequencyDays => $composableBuilder(
    column: $table.visitFrequencyDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClassSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassSettingsTable> {
  $$ClassSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get className => $composableBuilder(
    column: $table.className,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultCreditLimitPaise => $composableBuilder(
    column: $table.defaultCreditLimitPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditDays => $composableBuilder(
    column: $table.creditDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visitFrequencyDays => $composableBuilder(
    column: $table.visitFrequencyDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClassSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassSettingsTable> {
  $$ClassSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get className =>
      $composableBuilder(column: $table.className, builder: (column) => column);

  GeneratedColumn<int> get defaultCreditLimitPaise => $composableBuilder(
    column: $table.defaultCreditLimitPaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditDays => $composableBuilder(
    column: $table.creditDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get visitFrequencyDays => $composableBuilder(
    column: $table.visitFrequencyDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ClassSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassSettingsTable,
          ClassSettingEntry,
          $$ClassSettingsTableFilterComposer,
          $$ClassSettingsTableOrderingComposer,
          $$ClassSettingsTableAnnotationComposer,
          $$ClassSettingsTableCreateCompanionBuilder,
          $$ClassSettingsTableUpdateCompanionBuilder,
          (
            ClassSettingEntry,
            BaseReferences<
              _$AppDatabase,
              $ClassSettingsTable,
              ClassSettingEntry
            >,
          ),
          ClassSettingEntry,
          PrefetchHooks Function()
        > {
  $$ClassSettingsTableTableManager(_$AppDatabase db, $ClassSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClassSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> className = const Value.absent(),
                Value<int> defaultCreditLimitPaise = const Value.absent(),
                Value<int> creditDays = const Value.absent(),
                Value<int> visitFrequencyDays = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClassSettingsCompanion(
                className: className,
                defaultCreditLimitPaise: defaultCreditLimitPaise,
                creditDays: creditDays,
                visitFrequencyDays: visitFrequencyDays,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String className,
                required int defaultCreditLimitPaise,
                required int creditDays,
                required int visitFrequencyDays,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ClassSettingsCompanion.insert(
                className: className,
                defaultCreditLimitPaise: defaultCreditLimitPaise,
                creditDays: creditDays,
                visitFrequencyDays: visitFrequencyDays,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClassSettingsTable, ClassSettingEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ClassSettingsTable,
                    ClassSettingEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClassSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassSettingsTable,
      ClassSettingEntry,
      $$ClassSettingsTableFilterComposer,
      $$ClassSettingsTableOrderingComposer,
      $$ClassSettingsTableAnnotationComposer,
      $$ClassSettingsTableCreateCompanionBuilder,
      $$ClassSettingsTableUpdateCompanionBuilder,
      (
        ClassSettingEntry,
        BaseReferences<_$AppDatabase, $ClassSettingsTable, ClassSettingEntry>,
      ),
      ClassSettingEntry,
      PrefetchHooks Function()
    >;
typedef $$ProductUnitsTableCreateCompanionBuilder =
    ProductUnitsCompanion Function({
      required String id,
      required String productId,
      required String unitName,
      required int multiplierToBase,
      Value<bool> isBaseUnit,
      Value<bool> allowLooseSale,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ProductUnitsTableUpdateCompanionBuilder =
    ProductUnitsCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<String> unitName,
      Value<int> multiplierToBase,
      Value<bool> isBaseUnit,
      Value<bool> allowLooseSale,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProductUnitsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductUnitsTable, ProductUnitEntry> {
  $$ProductUnitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('product_units__product_id__products__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProductUnitsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductUnitsTable> {
  $$ProductUnitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitName => $composableBuilder(
    column: $table.unitName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get multiplierToBase => $composableBuilder(
    column: $table.multiplierToBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBaseUnit => $composableBuilder(
    column: $table.isBaseUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowLooseSale => $composableBuilder(
    column: $table.allowLooseSale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductUnitsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductUnitsTable> {
  $$ProductUnitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitName => $composableBuilder(
    column: $table.unitName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get multiplierToBase => $composableBuilder(
    column: $table.multiplierToBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBaseUnit => $composableBuilder(
    column: $table.isBaseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowLooseSale => $composableBuilder(
    column: $table.allowLooseSale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductUnitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductUnitsTable> {
  $$ProductUnitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unitName =>
      $composableBuilder(column: $table.unitName, builder: (column) => column);

  GeneratedColumn<int> get multiplierToBase => $composableBuilder(
    column: $table.multiplierToBase,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBaseUnit => $composableBuilder(
    column: $table.isBaseUnit,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowLooseSale => $composableBuilder(
    column: $table.allowLooseSale,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductUnitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductUnitsTable,
          ProductUnitEntry,
          $$ProductUnitsTableFilterComposer,
          $$ProductUnitsTableOrderingComposer,
          $$ProductUnitsTableAnnotationComposer,
          $$ProductUnitsTableCreateCompanionBuilder,
          $$ProductUnitsTableUpdateCompanionBuilder,
          (ProductUnitEntry, $$ProductUnitsTableReferences),
          ProductUnitEntry,
          PrefetchHooks Function({bool productId})
        > {
  $$ProductUnitsTableTableManager(_$AppDatabase db, $ProductUnitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductUnitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductUnitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductUnitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> unitName = const Value.absent(),
                Value<int> multiplierToBase = const Value.absent(),
                Value<bool> isBaseUnit = const Value.absent(),
                Value<bool> allowLooseSale = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductUnitsCompanion(
                id: id,
                productId: productId,
                unitName: unitName,
                multiplierToBase: multiplierToBase,
                isBaseUnit: isBaseUnit,
                allowLooseSale: allowLooseSale,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                required String unitName,
                required int multiplierToBase,
                Value<bool> isBaseUnit = const Value.absent(),
                Value<bool> allowLooseSale = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductUnitsCompanion.insert(
                id: id,
                productId: productId,
                unitName: unitName,
                multiplierToBase: multiplierToBase,
                isBaseUnit: isBaseUnit,
                allowLooseSale: allowLooseSale,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductUnitsTable, ProductUnitEntry>(table),
                  $$ProductUnitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
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
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable: $$ProductUnitsTableReferences
                                    ._productIdTable(db),
                                referencedColumn: $$ProductUnitsTableReferences
                                    ._productIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$ProductUnitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductUnitsTable,
      ProductUnitEntry,
      $$ProductUnitsTableFilterComposer,
      $$ProductUnitsTableOrderingComposer,
      $$ProductUnitsTableAnnotationComposer,
      $$ProductUnitsTableCreateCompanionBuilder,
      $$ProductUnitsTableUpdateCompanionBuilder,
      (ProductUnitEntry, $$ProductUnitsTableReferences),
      ProductUnitEntry,
      PrefetchHooks Function({bool productId})
    >;
typedef $$UnitPricesTableCreateCompanionBuilder =
    UnitPricesCompanion Function({
      required String id,
      required String productId,
      required String unitName,
      required int wholesalePricePaise,
      required int mrpPaise,
      Value<int> minOrderQty,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UnitPricesTableUpdateCompanionBuilder =
    UnitPricesCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<String> unitName,
      Value<int> wholesalePricePaise,
      Value<int> mrpPaise,
      Value<int> minOrderQty,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$UnitPricesTableReferences
    extends BaseReferences<_$AppDatabase, $UnitPricesTable, UnitPriceEntry> {
  $$UnitPricesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('unit_prices__product_id__products__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UnitPricesTableFilterComposer
    extends Composer<_$AppDatabase, $UnitPricesTable> {
  $$UnitPricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitName => $composableBuilder(
    column: $table.unitName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wholesalePricePaise => $composableBuilder(
    column: $table.wholesalePricePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mrpPaise => $composableBuilder(
    column: $table.mrpPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minOrderQty => $composableBuilder(
    column: $table.minOrderQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UnitPricesTableOrderingComposer
    extends Composer<_$AppDatabase, $UnitPricesTable> {
  $$UnitPricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitName => $composableBuilder(
    column: $table.unitName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wholesalePricePaise => $composableBuilder(
    column: $table.wholesalePricePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mrpPaise => $composableBuilder(
    column: $table.mrpPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minOrderQty => $composableBuilder(
    column: $table.minOrderQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UnitPricesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnitPricesTable> {
  $$UnitPricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unitName =>
      $composableBuilder(column: $table.unitName, builder: (column) => column);

  GeneratedColumn<int> get wholesalePricePaise => $composableBuilder(
    column: $table.wholesalePricePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mrpPaise =>
      $composableBuilder(column: $table.mrpPaise, builder: (column) => column);

  GeneratedColumn<int> get minOrderQty => $composableBuilder(
    column: $table.minOrderQty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UnitPricesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UnitPricesTable,
          UnitPriceEntry,
          $$UnitPricesTableFilterComposer,
          $$UnitPricesTableOrderingComposer,
          $$UnitPricesTableAnnotationComposer,
          $$UnitPricesTableCreateCompanionBuilder,
          $$UnitPricesTableUpdateCompanionBuilder,
          (UnitPriceEntry, $$UnitPricesTableReferences),
          UnitPriceEntry,
          PrefetchHooks Function({bool productId})
        > {
  $$UnitPricesTableTableManager(_$AppDatabase db, $UnitPricesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnitPricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnitPricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnitPricesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> unitName = const Value.absent(),
                Value<int> wholesalePricePaise = const Value.absent(),
                Value<int> mrpPaise = const Value.absent(),
                Value<int> minOrderQty = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnitPricesCompanion(
                id: id,
                productId: productId,
                unitName: unitName,
                wholesalePricePaise: wholesalePricePaise,
                mrpPaise: mrpPaise,
                minOrderQty: minOrderQty,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                required String unitName,
                required int wholesalePricePaise,
                required int mrpPaise,
                Value<int> minOrderQty = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UnitPricesCompanion.insert(
                id: id,
                productId: productId,
                unitName: unitName,
                wholesalePricePaise: wholesalePricePaise,
                mrpPaise: mrpPaise,
                minOrderQty: minOrderQty,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UnitPricesTable, UnitPriceEntry>(table),
                  $$UnitPricesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
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
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable: $$UnitPricesTableReferences
                                    ._productIdTable(db),
                                referencedColumn: $$UnitPricesTableReferences
                                    ._productIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$UnitPricesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UnitPricesTable,
      UnitPriceEntry,
      $$UnitPricesTableFilterComposer,
      $$UnitPricesTableOrderingComposer,
      $$UnitPricesTableAnnotationComposer,
      $$UnitPricesTableCreateCompanionBuilder,
      $$UnitPricesTableUpdateCompanionBuilder,
      (UnitPriceEntry, $$UnitPricesTableReferences),
      UnitPriceEntry,
      PrefetchHooks Function({bool productId})
    >;
typedef $$LocationsTableCreateCompanionBuilder =
    LocationsCompanion Function({
      required String id,
      required String name,
      required String locationType,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocationsTableUpdateCompanionBuilder =
    LocationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> locationType,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationType => $composableBuilder(
    column: $table.locationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationType => $composableBuilder(
    column: $table.locationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
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

  GeneratedColumn<String> get locationType => $composableBuilder(
    column: $table.locationType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationsTable,
          LocationEntry,
          $$LocationsTableFilterComposer,
          $$LocationsTableOrderingComposer,
          $$LocationsTableAnnotationComposer,
          $$LocationsTableCreateCompanionBuilder,
          $$LocationsTableUpdateCompanionBuilder,
          (
            LocationEntry,
            BaseReferences<_$AppDatabase, $LocationsTable, LocationEntry>,
          ),
          LocationEntry,
          PrefetchHooks Function()
        > {
  $$LocationsTableTableManager(_$AppDatabase db, $LocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> locationType = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion(
                id: id,
                name: name,
                locationType: locationType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String locationType,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion.insert(
                id: id,
                name: name,
                locationType: locationType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocationsTable, LocationEntry>(table),
                  BaseReferences<_$AppDatabase, $LocationsTable, LocationEntry>(
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

typedef $$LocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationsTable,
      LocationEntry,
      $$LocationsTableFilterComposer,
      $$LocationsTableOrderingComposer,
      $$LocationsTableAnnotationComposer,
      $$LocationsTableCreateCompanionBuilder,
      $$LocationsTableUpdateCompanionBuilder,
      (
        LocationEntry,
        BaseReferences<_$AppDatabase, $LocationsTable, LocationEntry>,
      ),
      LocationEntry,
      PrefetchHooks Function()
    >;
typedef $$CartDraftsTableCreateCompanionBuilder =
    CartDraftsCompanion Function({
      required String retailerId,
      required String itemsJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CartDraftsTableUpdateCompanionBuilder =
    CartDraftsCompanion Function({
      Value<String> retailerId,
      Value<String> itemsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CartDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $CartDraftsTable> {
  $$CartDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get retailerId => $composableBuilder(
    column: $table.retailerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CartDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $CartDraftsTable> {
  $$CartDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get retailerId => $composableBuilder(
    column: $table.retailerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CartDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CartDraftsTable> {
  $$CartDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get retailerId => $composableBuilder(
    column: $table.retailerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CartDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CartDraftsTable,
          CartDraftEntry,
          $$CartDraftsTableFilterComposer,
          $$CartDraftsTableOrderingComposer,
          $$CartDraftsTableAnnotationComposer,
          $$CartDraftsTableCreateCompanionBuilder,
          $$CartDraftsTableUpdateCompanionBuilder,
          (
            CartDraftEntry,
            BaseReferences<_$AppDatabase, $CartDraftsTable, CartDraftEntry>,
          ),
          CartDraftEntry,
          PrefetchHooks Function()
        > {
  $$CartDraftsTableTableManager(_$AppDatabase db, $CartDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CartDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CartDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CartDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> retailerId = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CartDraftsCompanion(
                retailerId: retailerId,
                itemsJson: itemsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String retailerId,
                required String itemsJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CartDraftsCompanion.insert(
                retailerId: retailerId,
                itemsJson: itemsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CartDraftsTable, CartDraftEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CartDraftsTable,
                    CartDraftEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CartDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CartDraftsTable,
      CartDraftEntry,
      $$CartDraftsTableFilterComposer,
      $$CartDraftsTableOrderingComposer,
      $$CartDraftsTableAnnotationComposer,
      $$CartDraftsTableCreateCompanionBuilder,
      $$CartDraftsTableUpdateCompanionBuilder,
      (
        CartDraftEntry,
        BaseReferences<_$AppDatabase, $CartDraftsTable, CartDraftEntry>,
      ),
      CartDraftEntry,
      PrefetchHooks Function()
    >;
typedef $$VisitsTableCreateCompanionBuilder =
    VisitsCompanion Function({
      required String id,
      required String retailerId,
      required String userId,
      required DateTime startTime,
      Value<DateTime?> endTime,
      required String outcome,
      Value<String> notes,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$VisitsTableUpdateCompanionBuilder =
    VisitsCompanion Function({
      Value<String> id,
      Value<String> retailerId,
      Value<String> userId,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<String> outcome,
      Value<String> notes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$VisitsTableReferences
    extends BaseReferences<_$AppDatabase, $VisitsTable, VisitEntry> {
  $$VisitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RetailersTable _retailerIdTable(_$AppDatabase db) =>
      db.retailers.createAlias('visits__retailer_id__retailers__id');

  $$RetailersTableProcessedTableManager get retailerId {
    final $_column = $_itemColumn<String>('retailer_id')!;

    final manager = $$RetailersTableTableManager(
      $_db,
      $_db.retailers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_retailerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VisitsTableFilterComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RetailersTableFilterComposer get retailerId {
    final $$RetailersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.retailerId,
      referencedTable: $db.retailers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetailersTableFilterComposer(
            $db: $db,
            $table: $db.retailers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RetailersTableOrderingComposer get retailerId {
    final $$RetailersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.retailerId,
      referencedTable: $db.retailers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetailersTableOrderingComposer(
            $db: $db,
            $table: $db.retailers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisitsTable> {
  $$VisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RetailersTableAnnotationComposer get retailerId {
    final $$RetailersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.retailerId,
      referencedTable: $db.retailers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RetailersTableAnnotationComposer(
            $db: $db,
            $table: $db.retailers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VisitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisitsTable,
          VisitEntry,
          $$VisitsTableFilterComposer,
          $$VisitsTableOrderingComposer,
          $$VisitsTableAnnotationComposer,
          $$VisitsTableCreateCompanionBuilder,
          $$VisitsTableUpdateCompanionBuilder,
          (VisitEntry, $$VisitsTableReferences),
          VisitEntry,
          PrefetchHooks Function({bool retailerId})
        > {
  $$VisitsTableTableManager(_$AppDatabase db, $VisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> retailerId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion(
                id: id,
                retailerId: retailerId,
                userId: userId,
                startTime: startTime,
                endTime: endTime,
                outcome: outcome,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String retailerId,
                required String userId,
                required DateTime startTime,
                Value<DateTime?> endTime = const Value.absent(),
                required String outcome,
                Value<String> notes = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VisitsCompanion.insert(
                id: id,
                retailerId: retailerId,
                userId: userId,
                startTime: startTime,
                endTime: endTime,
                outcome: outcome,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VisitsTable, VisitEntry>(table),
                  $$VisitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({retailerId = false}) {
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
                    if (retailerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.retailerId,
                                referencedTable: $$VisitsTableReferences
                                    ._retailerIdTable(db),
                                referencedColumn: $$VisitsTableReferences
                                    ._retailerIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$VisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisitsTable,
      VisitEntry,
      $$VisitsTableFilterComposer,
      $$VisitsTableOrderingComposer,
      $$VisitsTableAnnotationComposer,
      $$VisitsTableCreateCompanionBuilder,
      $$VisitsTableUpdateCompanionBuilder,
      (VisitEntry, $$VisitsTableReferences),
      VisitEntry,
      PrefetchHooks Function({bool retailerId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$RetailersTableTableManager get retailers =>
      $$RetailersTableTableManager(_db, _db.retailers);
  $$InventorySnapshotsTableTableManager get inventorySnapshots =>
      $$InventorySnapshotsTableTableManager(_db, _db.inventorySnapshots);
  $$InventoryMovementsTableTableManager get inventoryMovements =>
      $$InventoryMovementsTableTableManager(_db, _db.inventoryMovements);
  $$DatabaseMetadataTableTableManager get databaseMetadata =>
      $$DatabaseMetadataTableTableManager(_db, _db.databaseMetadata);
  $$OutboxMutationsTableTableManager get outboxMutations =>
      $$OutboxMutationsTableTableManager(_db, _db.outboxMutations);
  $$WarehouseHubsTableTableManager get warehouseHubs =>
      $$WarehouseHubsTableTableManager(_db, _db.warehouseHubs);
  $$RoutesTableTableManager get routes =>
      $$RoutesTableTableManager(_db, _db.routes);
  $$RouteStopsTableTableManager get routeStops =>
      $$RouteStopsTableTableManager(_db, _db.routeStops);
  $$ClassSettingsTableTableManager get classSettings =>
      $$ClassSettingsTableTableManager(_db, _db.classSettings);
  $$ProductUnitsTableTableManager get productUnits =>
      $$ProductUnitsTableTableManager(_db, _db.productUnits);
  $$UnitPricesTableTableManager get unitPrices =>
      $$UnitPricesTableTableManager(_db, _db.unitPrices);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db, _db.locations);
  $$CartDraftsTableTableManager get cartDrafts =>
      $$CartDraftsTableTableManager(_db, _db.cartDrafts);
  $$VisitsTableTableManager get visits =>
      $$VisitsTableTableManager(_db, _db.visits);
}
