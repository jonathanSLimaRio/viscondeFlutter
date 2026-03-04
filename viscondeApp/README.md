# viscondeApp (Flutter)

Cliente Flutter do projeto Visconde.

## Pre-requisitos

- Flutter SDK com Dart `^3.11.0`
- Emulador Android/iOS ou dispositivo fisico
- Backend Next.js da raiz do monorepo rodando em paralelo

## Rodando localmente

1. Na raiz do monorepo, suba o backend:

```bash
npm run dev
```

2. Neste diretorio (`viscondeApp`), instale dependencias:

```bash
flutter pub get
```

3. Rode o app com a URL da API correta:

- iOS Simulator / macOS / Flutter Web:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1/
```

- Android Emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1/
```

- Dispositivo fisico:

```bash
flutter run --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:3000/api/v1/
```

## Flags de dev uteis

- `DEV_AUTO_LOGIN=true`
- `DEV_LOGIN_PREFILL=true`
- `DEV_ADMIN_EMAIL=admin@visconde.app`
- `DEV_ADMIN_PASSWORD=admin123`
- `STORY_GAME_ROOM_ENABLED=true`

Exemplo:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1/ \
  --dart-define=DEV_AUTO_LOGIN=true \
  --dart-define=DEV_LOGIN_PREFILL=true \
  --dart-define=DEV_ADMIN_EMAIL=demo@visconde.app \
  --dart-define=DEV_ADMIN_PASSWORD=demo123
```

Guia completo do projeto: [README da raiz](../README.md)
