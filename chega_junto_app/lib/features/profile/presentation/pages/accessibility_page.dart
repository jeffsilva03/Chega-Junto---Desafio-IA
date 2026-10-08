import 'package:flutter/material.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/state/speech_controller.dart';
import '../../../../data/models/profile_preferences.dart';
import '../widgets/profile_components.dart';

class AccessibilityPage extends StatelessWidget {
  const AccessibilityPage({
    super.key,
    required this.controller,
    required this.speech,
  });
  final ProfileController controller;
  final SpeechController speech;
  Future<void> _textSize(BuildContext context) async {
    final result = await showDialog<AppTextSize>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tamanho do texto'),
        children: [
          RadioGroup<AppTextSize>(
            groupValue: controller.accessibility.textSize,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final size in AppTextSize.values)
                  RadioListTile<AppTextSize>(
                    title: Text(size.label),
                    value: size,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (result != null) {
      controller.setAccessibility(
        controller.accessibility.copyWith(textSize: result),
      );
    }
  }

  Future<void> _appearance(BuildContext context) async {
    final result = await showDialog<AppAppearance>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tema do aplicativo'),
        children: [
          RadioGroup<AppAppearance>(
            groupValue: controller.accessibility.appearance,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final appearance in AppAppearance.values)
                  RadioListTile<AppAppearance>(
                    title: Text(appearance.label),
                    value: appearance,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (result != null) {
      controller.setAccessibility(
        controller.accessibility.copyWith(appearance: result),
      );
    }
  }

  Widget _option(
    AccessibilityOption option,
    IconData icon,
    String title,
    String description,
    bool value,
  ) => SettingsOptionTile(
    key: ValueKey('accessibility-${option.name}'),
    icon: icon,
    title: title,
    description: description,
    value: value,
    onChanged: (value) {
      controller.setAccessibility(
        controller.accessibility.change(option, value),
      );
      if (option == AccessibilityOption.speech && !value) speech.stop();
    },
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final prefs = controller.accessibility;
      return ProfileScaffold(
        title: 'Acessibilidade',
        subtitle:
            'Personalize o aplicativo para uma experiência mais confortável e inclusiva.',
        children: [
          Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ProfileSection(
            children: [
              SettingsOptionTile(
                icon: Icons.text_fields_rounded,
                title: 'Tamanho do texto',
                description: 'Ajuste o tamanho da fonte no aplicativo.',
                trailing: prefs.textSize.label,
                onTap: () => _textSize(context),
              ),
              const Divider(),
              SettingsOptionTile(
                icon: Icons.dark_mode_outlined,
                title: 'Tema do aplicativo',
                description: 'Escolha entre o tema claro ou escuro.',
                trailing: prefs.appearance.label,
                onTap: () => _appearance(context),
              ),
              const Divider(),
              _option(
                AccessibilityOption.contrast,
                Icons.contrast_rounded,
                'Alto contraste',
                'Aumente o contraste para facilitar a leitura.',
                prefs.highContrast,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Conteúdo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ProfileSection(
            children: [
              _option(
                AccessibilityOption.speech,
                Icons.volume_up_outlined,
                'Ler textos em voz alta',
                'Ative o botão de áudio para ouvir o conteúdo da tela.',
                prefs.speech,
              ),
              const Divider(),
              _option(
                AccessibilityOption.descriptions,
                Icons.closed_caption_outlined,
                'Legendas e descrições',
                'Inclua descrições de imagens na leitura em voz alta.',
                prefs.descriptions,
              ),
              const Divider(),
              _option(
                AccessibilityOption.simpleLanguage,
                Icons.article_outlined,
                'Usar linguagem simples',
                'Use explicações mais curtas nas telas de apoio.',
                prefs.simpleLanguage,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Navegação', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ProfileSection(
            children: [
              _option(
                AccessibilityOption.haptics,
                Icons.vibration_rounded,
                'Feedback tátil',
                'Vibração ao tocar nos controles, em aparelhos compatíveis.',
                prefs.haptics,
              ),
              const Divider(),
              _option(
                AccessibilityOption.reduceMotion,
                Icons.animation_rounded,
                'Reduzir animações',
                'Diminua os efeitos visuais durante a navegação.',
                prefs.reduceMotion,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ProfileInfo(
            'Preferências válidas nesta sessão. A leitura usa uma voz local em português disponível no aparelho.',
          ),
          if (prefs.speech)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () async {
                  await speech.speak(
                    'Chega Junto. Seu cuidado começa aqui. Você pode ouvir as informações das telas usando o botão de áudio.',
                  );
                  if (context.mounted && speech.error != null) {
                    profileMessage(context, speech.error!);
                  }
                },
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Ouvir exemplo'),
              ),
            ),
        ],
      );
    },
  );
}
