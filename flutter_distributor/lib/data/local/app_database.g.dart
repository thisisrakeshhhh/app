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
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
    createdAt,
  );
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
  final DateTime updatedAt;
  const InventorySnapshotEntry({
    required this.productId,
    required this.godownCartons,
    required this.godownLoosePieces,
    required this.carCartons,
    required this.carLoosePieces,
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
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InventorySnapshotEntry copyWith({
    String? productId,
    int? godownCartons,
    int? godownLoosePieces,
    int? carCartons,
    int? carLoosePieces,
    DateTime? updatedAt,
  }) => InventorySnapshotEntry(
    productId: productId ?? this.productId,
    godownCartons: godownCartons ?? this.godownCartons,
    godownLoosePieces: godownLoosePieces ?? this.godownLoosePieces,
    carCartons: carCartons ?? this.carCartons,
    carLoosePieces: carLoosePieces ?? this.carLoosePieces,
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
          other.updatedAt == this.updatedAt);
}

class InventorySnapshotsCompanion
    extends UpdateCompanion<InventorySnapshotEntry> {
  final Value<String> productId;
  final Value<int> godownCartons;
  final Value<int> godownLoosePieces;
  final Value<int> carCartons;
  final Value<int> carLoosePieces;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InventorySnapshotsCompanion({
    this.productId = const Value.absent(),
    this.godownCartons = const Value.absent(),
    this.godownLoosePieces = const Value.absent(),
    this.carCartons = const Value.absent(),
    this.carLoosePieces = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventorySnapshotsCompanion.insert({
    required String productId,
    this.godownCartons = const Value.absent(),
    this.godownLoosePieces = const Value.absent(),
    this.carCartons = const Value.absent(),
    this.carLoosePieces = const Value.absent(),
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
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (productId != null) 'product_id': productId,
      if (godownCartons != null) 'godown_cartons': godownCartons,
      if (godownLoosePieces != null) 'godown_loose_pieces': godownLoosePieces,
      if (carCartons != null) 'car_cartons': carCartons,
      if (carLoosePieces != null) 'car_loose_pieces': carLoosePieces,
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
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InventorySnapshotsCompanion(
      productId: productId ?? this.productId,
      godownCartons: godownCartons ?? this.godownCartons,
      godownLoosePieces: godownLoosePieces ?? this.godownLoosePieces,
      carCartons: carCartons ?? this.carCartons,
      carLoosePieces: carLoosePieces ?? this.carLoosePieces,
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
  final DateTime createdAt;
  const InventoryMovementEntry({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.cartonDelta,
    required this.loosePieceDelta,
    required this.reason,
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
    DateTime? createdAt,
  }) => InventoryMovementEntry(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    movementType: movementType ?? this.movementType,
    cartonDelta: cartonDelta ?? this.cartonDelta,
    loosePieceDelta: loosePieceDelta ?? this.loosePieceDelta,
    reason: reason ?? this.reason,
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
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const InventoryMovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.movementType = const Value.absent(),
    this.cartonDelta = const Value.absent(),
    this.loosePieceDelta = const Value.absent(),
    this.reason = const Value.absent(),
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
  ];
}

typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      required String id,
      required String name,
      required String hindiName,
      required String category,
      required double mrpRupees,
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
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (inventorySnapshotsRefs) db.inventorySnapshots,
                    if (inventoryMovementsRefs) db.inventoryMovements,
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
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
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
          (
            RetailerEntry,
            BaseReferences<_$AppDatabase, $RetailersTable, RetailerEntry>,
          ),
          RetailerEntry,
          PrefetchHooks Function()
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
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RetailersTable, RetailerEntry>(table),
                  BaseReferences<_$AppDatabase, $RetailersTable, RetailerEntry>(
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
      (
        RetailerEntry,
        BaseReferences<_$AppDatabase, $RetailersTable, RetailerEntry>,
      ),
      RetailerEntry,
      PrefetchHooks Function()
    >;
typedef $$InventorySnapshotsTableCreateCompanionBuilder =
    InventorySnapshotsCompanion Function({
      required String productId,
      Value<int> godownCartons,
      Value<int> godownLoosePieces,
      Value<int> carCartons,
      Value<int> carLoosePieces,
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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventorySnapshotsCompanion(
                productId: productId,
                godownCartons: godownCartons,
                godownLoosePieces: godownLoosePieces,
                carCartons: carCartons,
                carLoosePieces: carLoosePieces,
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
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => InventorySnapshotsCompanion.insert(
                productId: productId,
                godownCartons: godownCartons,
                godownLoosePieces: godownLoosePieces,
                carCartons: carCartons,
                carLoosePieces: carLoosePieces,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventoryMovementsCompanion(
                id: id,
                productId: productId,
                movementType: movementType,
                cartonDelta: cartonDelta,
                loosePieceDelta: loosePieceDelta,
                reason: reason,
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
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => InventoryMovementsCompanion.insert(
                id: id,
                productId: productId,
                movementType: movementType,
                cartonDelta: cartonDelta,
                loosePieceDelta: loosePieceDelta,
                reason: reason,
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
}
