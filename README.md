# Visconde - Next.js + Flutter

Monorepo com:

- `./` aplicacao Next.js (web + API + Prisma)
- `./viscondeApp` app Flutter

## Pre-requisitos

- Node.js 20+ e npm
- PostgreSQL acessivel pelo `DATABASE_URL`
- Flutter SDK com Dart `^3.11.0` (veja `viscondeApp/pubspec.yaml`)
- Android Studio (Android) e/ou Xcode (iOS/macOS), conforme plataforma alvo

## Estrutura

- `app/`: rotas e interface Next.js
- `prisma/`: schema, migracoes e seeds
- `viscondeApp/`: cliente Flutter

## Setup rapido (primeira execucao)

1. Instale dependencias do Next.js na raiz:

```bash
npm install
```

2. Configure variaveis de ambiente:

```bash
cp .env.exemple .env
```

3. Ajuste o `.env` com seus valores reais (principalmente banco e secrets).

4. Aplique migracoes e seed inicial:

```bash
npx prisma migrate dev
npm run seed
```

5. Suba o Next.js:

```bash
npm run dev
```

App/API local: [http://localhost:3000](http://localhost:3000)

## Como rodar o projeto (Next.js)

Na raiz do repositorio:

```bash
npm run dev
```

Scripts uteis:

- `npm run build`: build de producao
- `npm run start`: sobe build de producao
- `npm run lint`: lint do projeto
- `npm run prisma:migrate`: atalho para `prisma migrate dev`
- `npm run prisma:studio`: abre Prisma Studio

## Como rodar o projeto (Flutter)

Com o Next.js rodando em paralelo, abra outro terminal:

```bash
cd viscondeApp
flutter pub get
```

Use o `API_BASE_URL` conforme ambiente:

- iOS Simulator / macOS / Flutter Web:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1/
```

- Android Emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1/
```

- Dispositivo fisico (troque pelo IP local da sua maquina):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000/api/v1/
```

## Flags de desenvolvimento no Flutter

- `DEV_AUTO_LOGIN=true`: login automatico (debug)
- `DEV_LOGIN_PREFILL=true`: preenche login automaticamente
- `STORY_GAME_ROOM_ENABLED=true`: habilita fluxo de game room

Exemplo completo:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1/ \
  --dart-define=DEV_AUTO_LOGIN=true \
  --dart-define=DEV_LOGIN_PREFILL=true \
  --dart-define=STORY_GAME_ROOM_ENABLED=true
```

## Reset + Seed QA completo

Reset destrutivo do banco atual no `.env`, aplicacao de migracoes, seed QA, backfill e verificacao:

```bash
DB_RESET_CONFIRM=RESET_VISCONDE npm run db:reset:seed:qa
```

Comandos auxiliares:

```bash
npm run db:reset
npm run db:seed:qa
```

Credenciais demo seedadas:

- demo: `demo@visconde.app / demo123`
- PIN demo: `123456`
