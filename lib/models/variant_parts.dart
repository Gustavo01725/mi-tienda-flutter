/// Talla y color de una variante, como los devuelve ProductStock::describeVariant() de la web.
class VariantParts {
  final String? size, sizeLabel, color, colorLabel, colorHex;
  final String text;

  const VariantParts({this.size, this.sizeLabel, this.color, this.colorLabel, this.colorHex, this.text = ''});

  factory VariantParts.fromJson(dynamic j) {
    if (j is! Map) return const VariantParts();
    return VariantParts(
      size: j['size'],
      sizeLabel: j['size_label'],
      color: j['color'],
      colorLabel: j['color_label'],
      colorHex: j['color_hex'],
      text: j['text'] ?? '',
    );
  }

  bool get isEmpty => size == null && color == null;
}
