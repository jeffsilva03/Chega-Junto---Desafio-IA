# APK Android demonstrativo 0.7.0

Data: 13/10/2026. Entrega complementar à V7, sem alteração das tags V1–V7.

## Entrega pública

- [Download direto](https://github.com/jeffsilva03/Chega-Junto-Android/releases/download/android-v0.7.0/chega-junto-0.7.0.apk).
- [Release android-v0.7.0](https://github.com/jeffsilva03/Chega-Junto-Android/releases/tag/android-v0.7.0), ID `411615046`, publicado como pré-release demonstrativo.
- [Checksum](https://github.com/jeffsilva03/Chega-Junto-Android/releases/download/android-v0.7.0/chega-junto-0.7.0.apk.sha256).

O usuário autorizou a criação do repositório público separado `Chega-Junto-Android`. A raiz contém somente README; o release contém somente APK e checksum. O repositório do código foi consultado novamente após a publicação e continua privado. Nenhuma credencial, código-fonte ou dado de paciente foi enviado ao novo repositório.

## Build e alteração necessária

Única alteração funcional: inclusão de `android.permission.INTERNET` no manifesto principal Android. Essa permissão já existia nos manifestos de desenvolvimento; o APK release precisa dela para acessar a API pública.

Comando, na pasta `chega_junto_app`:

```powershell
flutter build apk --release --build-name=0.7.0 --build-number=7001 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
```

Flutter 3.41.4 / Dart 3.11.1. Artefato em `build/app/outputs/flutter-apk/app-release.apk`, com cópia de entrega em `.local/android-downloads/chega-junto-0.7.0.apk`; ambas as pastas permanecem ignoradas pelo Git.

| Propriedade | Valor |
| --- | --- |
| Versão / código | 0.7.0 / 7001 |
| applicationId | br.com.chegajunto.chega_junto_app |
| Tamanho | 57.748.801 bytes, aproximadamente 55,1 MiB |
| Android mínimo | API 24 / Android 7.0 |
| Target SDK | 36 |
| Arquiteturas | arm64-v8a, armeabi-v7a, x86_64 |
| API | https://chega-junto-api.onrender.com |
| Assinatura | Chave Android de teste existente; APK Signature Scheme v2 válido |
| SHA-256 | 6da3a3a0ef8da83748b6f56489d784472f9c07541e0a0dc294783bd8e4f639f9 |

A primeira compilação falhou por referência gerada ao plugin de teste; a repetição sem ferramentas Flutter concorrentes concluiu corretamente. Não houve edição manual do registrador gerado ou inclusão do plugin de testes no APK final.

## Verificação

- `flutter analyze`: aprovado, sem problemas.
- Build release AOT concluído; `aapt` confirmou versão, arquiteturas, SDK mínimo, permissão INTERNET e ausência de `application-debuggable`.
- `apksigner verify --verbose --print-certs`: assinatura v2 válida.
- Auditoria dos 73 arquivos do APK: nenhuma ocorrência dos quatro valores privados locais verificados, de credenciais, chaves privadas ou plugin `integration_test`. URL HTTPS pública presente nas três bibliotecas AOT do aplicativo.
- Download anônimo completo do release: HTTP 200, MIME `application/vnd.android.package-archive`, 57.748.801 bytes e SHA-256 idêntico ao arquivo local. Checksum público também conferido.
- Repositório público e seus arquivos conferidos pela API; repositório do código confirmado como privado.

Nenhum dispositivo Android estava conectado nesta entrega. Instalação e fluxo em aparelho físico deste APK ainda dependem do teste do usuário; a validação acima cobre build, configuração, assinatura, auditoria e download. O login Android relatado na V5 e o fluxo Web/iPhone validado na V7 pertencem aos respectivos checkpoints anteriores.

## Instalação e limites

Abra o download no Android, permita a instalação pelo navegador se solicitado e instale o Chega Junto. Use a conta demonstrativa de paciente do Web ou cadastre dados fictícios. A conta de operador é exclusiva do Portal. É necessário acesso à internet; não é necessário manter computador ligado ou compartilhar a mesma rede. Encerrar o aplicativo pode exigir novo login porque o token fica somente em memória.

O APK usa build release com chave de teste, para demonstração por instalação direta. A publicação em loja requer assinatura própria. Permanecem os limites demonstrativos da V7: dados fictícios, sistema não oficial, sem integração com SUS ou IA real.

A tentativa inicial de hospedar o APK no Firebase foi bloqueada antes da publicação: o [plano Spark proíbe APK e outros executáveis](https://firebase.google.com/support/faq#hosting-exe-restrictions). A configuração temporária foi revertida, os arquivos extras removidos do diretório de publicação e os sites existentes permaneceram publicados. Não houve ativação de cobrança ou mudança de plano. A alternativa autorizada utiliza [GitHub Releases](https://docs.github.com/en/rest/releases/releases#create-a-release).
