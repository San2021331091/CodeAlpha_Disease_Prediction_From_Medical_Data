import 'package:flutter/material.dart';

// Premium emerald scientific palette
const emeraldDarkest = Color(0xFF021B14);
const emeraldDarker = Color(0xFF032B20);
const emeraldDeep = Color(0xFF064E3B);
const emeraldMid = Color(0xFF047857);
const emeraldAccent = Color(0xFF10B981);
const emeraldBright = Color(0xFF34D399);
const emeraldMint = Color(0xFFA7F3D0);
const emeraldLight = Color(0xFFD1FAE5);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFD1FAE5);
const textMuted = Color(0xFF94A3B8);

const notice =
    'For education only. These models classify public medical datasets. They do not diagnose disease or provide clinical risk estimates.';

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0x33064E3B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x4034D399)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 20, color: emeraldBright),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            notice,
            style: TextStyle(color: emeraldLight, fontSize: 12.5, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

TextStyle eyebrow() => const TextStyle(
  color: emeraldBright,
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.6,
);

TextStyle heading() => const TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: textPrimary,
  letterSpacing: -0.3,
);

String title(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

String percent(dynamic value) =>
    '${((value as num) * 100).toStringAsFixed(1)}%';

String number(dynamic value) => (value as num).abs() < .01
    ? value.toStringAsPrecision(3)
    : value.toStringAsFixed(3);

String date(String value) {
  final d = DateTime.parse(value).toLocal();
  String two(int n) => '$n'.padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

Widget panel({required Widget child}) => Material(
  color: const Color(0xDD04251B),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: const BorderSide(color: Color(0x3334D399)),
  ),
  clipBehavior: Clip.antiAlias,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);

Widget stat(String value, String label, IconData icon) => panel(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x3310B981),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: emeraldBright, size: 20),
      ),
      const SizedBox(height: 16),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: textPrimary,
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: emeraldMint,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
);

Widget probability(String label, double value, Color color) => Column(
  children: [
    Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          percent(value),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value,
        color: color,
        backgroundColor: const Color(0x44000000),
        minHeight: 10,
      ),
    ),
  ],
);

Widget errorBox(String text) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0x33991B1B),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0x66EF4444)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.error_outline, color: Color(0xFFFCA5A5), size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFEE2E2),
            height: 1.5,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  ),
);
