import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models/variant_parts.dart';
import '../theme.dart';

String money(num v) => '\$${v.toStringAsFixed(2)}';

/// Abre una página de la web (políticas, recuperar contraseña, recargar billetera...).
Future<void> openWeb(BuildContext context, String path) async {
  final ok = await launchUrl(Uri.parse('$apiUrl$path'), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el navegador.')));
  }
}

/// Imagen remota con el mismo placeholder gris de la web (assets/img/placeholder.jpg).
class NetImg extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const NetImg(this.url, {super.key, this.fit = BoxFit.cover});

  static const _placeholder = 'assets/img/placeholder.jpg';

  @override
  Widget build(BuildContext context) {
    final u = url;
    // uploaded_asset() devuelve este placeholder cuando el producto no tiene imagen.
    if (u == null || u.isEmpty || u.endsWith('/assets/img/placeholder.jpg')) {
      return Image.asset(_placeholder, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      placeholder: (_, _) => Image.asset(_placeholder, fit: BoxFit.cover),
      errorWidget: (_, _, _) => Image.asset(_placeholder, fit: BoxFit.cover),
    );
  }
}

/// Caja blanca con radio 4 y la sombra suave de la web (.bg-white.shadow-sm.rounded).
class GuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  const GuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.fromLTRB(15, 0, 15, 16),
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius), boxShadow: cardShadow),
        child: child,
      );
}

/// Título de sección de la portada: 20px negrita con subrayado verde y línea gris (h3 + border-bottom).
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Stack(children: [
        const Positioned(left: 0, right: 0, bottom: 0, child: Divider(height: 1)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 2))),
            child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          if (trailing != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: trailing!),
        ]),
      ]),
    );
  }
}

/// Estrellas de valoración. [outline]: estilo del listado (amarillas, contorno); si no, grises rellenas.
class Stars extends StatelessWidget {
  final double rating;
  final double size;
  final bool outline;
  const Stars(this.rating, {super.key, this.size = 13, this.outline = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            i <= rating.round() || !outline ? LineAwesomeIcons.star_solid : LineAwesomeIcons.star,
            size: size,
            color: i <= rating.round() ? AppColors.star : (outline ? AppColors.star : const Color(0xFFCCCCCC)),
          ),
        ),
    ]);
  }
}

/// Insignia redondeada (estado de pago/entrega, "-10%").
class Pill extends StatelessWidget {
  final String text;
  final Color color, background;
  final double fontSize;
  const Pill(this.text, {super.key, required this.color, required this.background, this.fontSize = 11.5});

  factory Pill.status(String text, {required bool ok, bool warn = false}) => Pill(
        text,
        color: ok ? AppColors.primary : (warn ? const Color(0xFFB7791F) : AppColors.danger),
        background: ok ? AppColors.softPrimary : (warn ? const Color(0xFFFFF4DB) : AppColors.dangerSoft),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w700)),
      );
}

/// Campo con la etiqueta encima, como los formularios de la web (label.fw-600 + .form-control).
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final List<String>? autofill;
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboard,
    this.validator,
    this.suffix,
    this.autofill,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            validator: validator,
            autofillHints: autofill,
            style: const TextStyle(fontSize: 14, color: Color(0xFF495057)),
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ]),
      );
}

/// Migas de pan: "Inicio / Ropa / Camiseta" (enlaces verdes, el último en negrita).
class Breadcrumb extends StatelessWidget {
  final List<(String, VoidCallback?)> items;
  const Breadcrumb(this.items, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(15, 18, 15, 12),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: TextStyle(color: AppColors.muted3))),
            GestureDetector(
              onTap: items[i].$2,
              child: Text(
                items[i].$1,
                style: TextStyle(
                  fontSize: 13,
                  color: i == items.length - 1 ? AppColors.text : AppColors.primary,
                  fontWeight: i == items.length - 1 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ]),
      );
}

/// Selector − [n] + de la ficha y el carrito.
class QtyStepper extends StatelessWidget {
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int>? onChanged;
  const QtyStepper({super.key, required this.value, this.min = 1, this.max, this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.field,
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 16, color: onTap == null ? AppColors.strike : AppColors.text),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(LineAwesomeIcons.minus_solid, onChanged != null && value > min ? () => onChanged!(value - 1) : null),
      Container(
        width: 44,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFDDDDDD))),
        ),
        child: Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      btn(LineAwesomeIcons.plus_solid, onChanged != null && (max == null || value < max!) ? () => onChanged!(value + 1) : null),
    ]);
  }
}

/// "Talla M · ● Negro" como en el carrito de la web.
class VariantChips extends StatelessWidget {
  final VariantParts parts;
  final String fallback;
  const VariantChips(this.parts, {super.key, this.fallback = ''});

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return fallback.isEmpty ? const SizedBox.shrink() : Text(fallback, style: const TextStyle(fontSize: 12, color: AppColors.muted));
    }
    return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (parts.size != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(20)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${parts.sizeLabel ?? 'Talla'} ', style: const TextStyle(color: AppColors.muted2, fontSize: 12)),
            TextSpan(text: parts.size, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ])),
        ),
      if (parts.color != null)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _hex(parts.colorHex) ?? AppColors.muted2,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x22000000)),
            ),
          ),
          const SizedBox(width: 4),
          Text(parts.colorLabel ?? parts.color!, style: const TextStyle(fontSize: 12)),
        ]),
    ]);
  }

  static Color? _hex(String? h) {
    if (h == null) return null;
    final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}

/// Mensaje centrado para listas vacías o errores.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(children: [
          Icon(icon, size: 56, color: AppColors.muted3),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Fila "Etiqueta ........ valor" de los resúmenes (carrito, pedido).
class SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold, green, big;
  const SummaryRow(this.label, this.value, {super.key, this.bold = false, this.green = false, this.big = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                fontSize: big ? 17 : 13,
                fontWeight: big || bold ? FontWeight.w700 : FontWeight.w400,
                color: big ? AppColors.text : AppColors.muted,
              )),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: big ? 19 : 13,
                fontWeight: bold || big || green ? FontWeight.w700 : FontWeight.w400,
                color: green ? AppColors.primary : const Color(0xFF212529),
              )),
        ]),
      );
}
