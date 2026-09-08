import 'package:flutter/material.dart';

/// Scrolls [header] off under the [AppBar], then scrolls [body].
///
/// Dragging down at the top of [body] brings [header] back.
class CollapsingHeaderScrollView extends StatelessWidget {
  const CollapsingHeaderScrollView({
    super.key,
    required this.header,
    required this.body,
  });

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(child: header),
        ];
      },
      body: body,
    );
  }
}
