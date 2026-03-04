This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.

## Seed admin (dev)

Cria/atualiza o usuario de desenvolvimento:

- email: `admin@visconde.app`
- senha: `admin123`

```bash
npm run seed:admin
```

## Auto-login dev no Flutter

O app Flutter aceita auto-login somente em debug com flag explicita:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1 \
  --dart-define=DEV_AUTO_LOGIN=true
```

Opcionalmente, sobrescreva credenciais:

- `DEV_ADMIN_EMAIL`
- `DEV_ADMIN_PASSWORD`

## Reset + Seed QA completo

Comando unico para reset destrutivo do banco atual no `.env`, migracoes, seed QA, backfill e verificacao:

```bash
DB_RESET_CONFIRM=RESET_VISCONDE npm run db:reset:seed:qa
```

Comandos auxiliares:

```bash
npm run db:reset
npm run db:seed:qa
```

Credenciais demo seedadas:

- admin: `admin@visconde.app / admin123`
- demo: `demo@visconde.app / demo123`
- PIN demo: `123456`

Flags uteis no Flutter para validacao rapida:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1 \
  --dart-define=DEV_AUTO_LOGIN=true \
  --dart-define=DEV_ADMIN_EMAIL=demo@visconde.app \
  --dart-define=DEV_ADMIN_PASSWORD=demo123 \
  --dart-define=STORY_GAME_ROOM_ENABLED=true
```

## Sala remota (multiplayer)

Backend exposto em `/api/v1` com endpoints de sala remota:

- `POST /story-sessions/:id/remote/open`
- `POST /story-sessions/:id/remote/close`
- `POST /story-sessions/:id/remote/code/regenerate`
- `GET /story-sessions/:id/remote/state`
- `POST /story-sessions/remote/join`
- `POST /story-sessions/:id/remote/steps`
- `POST /story-sessions/:id/remote/chat`
- `POST /story-sessions/:id/remote/reactions`
- `GET /stories/:id/interactions`

As variáveis de ambiente para gateway realtime e ICE estão em `.env.exemple`.
