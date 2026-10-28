import 'package:flutter/material.dart';

/// Keep tablet content readable while allowing every page to scroll in landscape.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  const PageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(22),
    this.physics,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView(padding: padding, physics: physics, children: children),
    ),
  );
}

/// Statistics need a full row when available width or larger system text demands it.
class AdaptivePair extends StatelessWidget {
  final Widget first;
  final Widget second;
  const AdaptivePair({super.key, required this.first, required this.second});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      return stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 14), second],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 14),
                Expanded(child: second),
              ],
            );
    },
  );
}
