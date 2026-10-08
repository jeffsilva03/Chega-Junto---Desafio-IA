import 'package:flutter/material.dart';
import '../state/profile_controller.dart';
import '../state/speech_controller.dart';

class AppReadingTools extends StatefulWidget {
  const AppReadingTools({
    super.key,
    required this.child,
    required this.profile,
    required this.speech,
  });
  final Widget child;
  final ProfileController profile;
  final SpeechController speech;
  @override
  State<AppReadingTools> createState() => _AppReadingToolsState();
}

class _AppReadingToolsState extends State<AppReadingTools> {
  final _content = GlobalKey();
  Future<void> _read() async {
    if (widget.speech.speaking) {
      await widget.speech.stop();
      return;
    }
    final parts = <String>[];
    void visit(Element element) {
      if (element.widget case Offstage(offstage: true)) return;
      final current = element.widget;
      if (current is Text && current.data != null) parts.add(current.data!);
      if (current is Semantics &&
          current.properties.image == true &&
          widget.profile.accessibility.descriptions &&
          current.properties.label != null) {
        parts.add(current.properties.label!);
      }
      element.visitChildren(visit);
    }

    _content.currentContext?.visitChildElements(visit);
    final text = parts.join('. ');
    if (text.isNotEmpty) await widget.speech.speak(text);
    if (!mounted) return;
    final error = widget.speech.error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      KeyedSubtree(key: _content, child: widget.child),
      if (widget.profile.accessibility.speech)
        Positioned(
          right: 16,
          bottom: 100 + MediaQuery.paddingOf(context).bottom,
          child: ListenableBuilder(
            listenable: widget.speech,
            builder: (context, _) => Semantics(
              container: true,
              button: true,
              label: widget.speech.speaking
                  ? 'Parar leitura'
                  : 'Ouvir esta tela',
              excludeSemantics: true,
              child: SizedBox.square(
                key: const ValueKey('page-reader'),
                dimension: 48,
                child: Material(
                  color: Theme.of(context).colorScheme.primary,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  child: InkWell(
                    onTap: _read,
                    child: Icon(
                      widget.speech.speaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_outlined,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
