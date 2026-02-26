# Realtime Gateway

Servico dedicado de WebSocket + signaling usado pelo backend Next.

## Variaveis obrigatorias

- `PORT` (default `8787`)
- `REALTIME_GATEWAY_INTERNAL_SECRET`
- `JWT_SECRET`

## Endpoints internos

- `GET /internal/health` (header `x-realtime-secret`)
- `POST /internal/publish` (header `x-realtime-secret`)

## WebSocket

- URL: `ws://host:8787/ws`
- Evento de entrada: `auth.join` com `participantToken`
- Relay RTC: `rtc.offer`, `rtc.answer`, `rtc.ice`, `rtc.hangup`
