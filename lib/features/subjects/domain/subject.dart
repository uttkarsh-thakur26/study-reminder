/// A study subject (Physics, Maths, ...) with its colour.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.color,
    this.sortOrder = 0,
    this.deleted = false,
  });

  final String id;
  final String name;

  /// ARGB colour value.
  final int color;
  final int sortOrder;
  final bool deleted;

  Subject copyWith({String? name, int? color, int? sortOrder, bool? deleted}) =>
      Subject(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        deleted: deleted ?? this.deleted,
      );

  Map<String, Object?> toFields() => {
    'name': name,
    'color': color,
    'sort_order': sortOrder,
    'deleted': deleted,
  };

  factory Subject.fromFields(String id, Map<String, Object?> f) => Subject(
    id: id,
    name: f['name'] as String? ?? '',
    color: ((f['color'] as num?) ?? 0xFF6366F1).toInt(),
    sortOrder: ((f['sort_order'] as num?) ?? 0).toInt(),
    deleted: f['deleted'] as bool? ?? false,
  );
}

/// Subject colours offered in the picker, tuned to read well in light and
/// dark themes.
const subjectPalette = <int>[
  0xFF6366F1, // indigo
  0xFF0EA5E9, // sky
  0xFF14B8A6, // teal
  0xFF22C55E, // green
  0xFFEAB308, // amber
  0xFFF97316, // orange
  0xFFEF4444, // red
  0xFFEC4899, // pink
  0xFFA855F7, // purple
  0xFF64748B, // slate
];
