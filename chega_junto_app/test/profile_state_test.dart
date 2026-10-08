import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:chega_junto_app/app/theme/app_tokens.dart';
import 'package:chega_junto_app/core/state/profile_controller.dart';
import 'package:chega_junto_app/core/state/speech_controller.dart';
import 'package:chega_junto_app/core/services/speech_engine.dart';
import 'package:chega_junto_app/core/services/device_speech.dart' as device;
import 'package:chega_junto_app/data/mock/mock_profile_repository.dart';
import 'package:chega_junto_app/data/models/user_profile.dart';
import 'package:chega_junto_app/data/models/profile_preferences.dart';

class _FailingRepository extends MockProfileRepository {
  bool failLoad = true, failSave = true;
  @override
  Future<UserProfile> loadProfile() async {
    if (failLoad) throw StateError('load');
    return super.loadProfile();
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    if (failSave) throw StateError('save');
    return super.saveProfile(profile);
  }
}

class _FailingSpeech implements SpeechEngine {
  @override
  Future<void> speak(String text) async => throw StateError('no-voice');
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Carregamento permite retry e falha ao salvar preserva os dados anteriores',
    () async {
      final repo = _FailingRepository();
      final controller = ProfileController(repo);
      await controller.load();
      expect(controller.failed, true);
      repo.failLoad = false;
      await controller.load();
      expect(controller.failed, false);
      await expectLater(
        controller.saveProfile(
          controller.profile!.copyWith(fullName: 'Nome fictício'),
        ),
        throwsStateError,
      );
      expect(controller.profile!.fullName, 'Maria da Silva');
      repo.failSave = false;
      await controller.saveProfile(
        controller.profile!.copyWith(fullName: 'Nome fictício'),
      );
      expect(controller.profile!.fullName, 'Nome fictício');
      controller.dispose();
    },
  );
  test(
    'Preferências e leitura de avisos são mantidas no estado da sessão',
    () async {
      final controller = ProfileController(MockProfileRepository());
      await controller.load();
      controller.setNotification(NotificationOption.exams, false);
      controller.markRead('notification-exam');
      controller.setAccessibility(
        controller.accessibility.copyWith(
          appearance: AppAppearance.dark,
          textSize: AppTextSize.large,
          highContrast: true,
        ),
      );
      expect(controller.isRead('notification-exam'), true);
      expect(controller.notifications.enabled(NotificationOption.exams), false);
      await controller.load();
      expect(controller.accessibility.appearance, AppAppearance.dark);
      expect(controller.isRead('notification-exam'), true);
      controller.dispose();
    },
  );
  test(
    'Contraste alto mantém texto principal e secundário acima de 7 para 1',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
      }

      for (final dark in [false, true]) {
        final colors = AppPalette(dark: dark, highContrast: true);
        for (final bg in [colors.surface, colors.background, colors.blueSoft]) {
          expect(contrast(colors.ink, bg), greaterThanOrEqualTo(7));
          expect(contrast(colors.textSecondary, bg), greaterThanOrEqualTo(7));
        }
        expect(
          contrast(colors.onPrimary, colors.primary),
          greaterThanOrEqualTo(4.5),
        );
      }
    },
  );
  test(
    'Falha na leitura é comunicada sem fingir reprodução de áudio',
    () async {
      final controller = SpeechController(_FailingSpeech());
      await controller.speak('Conteúdo fictício.');
      expect(controller.speaking, false);
      expect(controller.error, contains('voz em português'));
      await controller.stop();
      controller.dispose();
    },
  );
  test(
    'Leitura nativa seleciona voz local e não usa voz que exige rede',
    () async {
      const channel = MethodChannel('flutter_tts');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getVoices') {
              return [
                {'name': 'remote', 'locale': 'pt-BR', 'network_required': '1'},
                {'name': 'local', 'locale': 'pt-BR', 'network_required': '0'},
              ];
            }
            return 1;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final engine = device.createSpeechEngine();
      await engine.speak('Texto fictício.');
      expect(
        (calls.singleWhere((c) => c.method == 'setVoice').arguments
            as Map)['name'],
        'local',
      );
      expect(calls.any((c) => c.method == 'speak'), true);
      await engine.stop();
    },
  );
}
