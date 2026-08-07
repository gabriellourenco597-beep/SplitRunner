# SplitRunner 1.1 — Overlay

Timer de speedrun para Android com overlay flutuante sobre outros aplicativos.

## Recursos
- Timer de centésimos.
- Start, pause, split e reset.
- Splits editáveis e reordenáveis.
- Salvamento local.
- Overlay flutuante sobre outros aplicativos.
- Timer, split atual e próximo split no overlay.
- Overlay arrastável pela tela.
- Serviço Android em primeiro plano para manter o overlay ativo.

## Compilação
flutter pub get
flutter build apk --release

APK: build/app/outputs/flutter-apk/app-release.apk

## Overlay
Ao tocar no ícone de camadas, o Android abre a permissão "Exibir sobre outros apps". Conceda a permissão e toque novamente no botão.
