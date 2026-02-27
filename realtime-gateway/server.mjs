import { createServer } from "node:http";
import { jwtVerify } from "jose";
import { WebSocketServer } from "ws";

const port = Number(process.env.PORT ?? 8787);
const internalSecret = process.env.REALTIME_GATEWAY_INTERNAL_SECRET ?? "";
const jwtSecret = process.env.JWT_SECRET ?? "";

if (!internalSecret) {
  console.error("REALTIME_GATEWAY_INTERNAL_SECRET is required");
  process.exit(1);
}

if (!jwtSecret) {
  console.error("JWT_SECRET is required");
  process.exit(1);
}

const jwtKey = new TextEncoder().encode(jwtSecret);

/** @type {Map<string, Set<import('ws').WebSocket>>} */
const socketsByRoom = new Map();

/** @type {WeakMap<import('ws').WebSocket, {roomId:string, storyId:string, participantId:string, role:string, clientId:string|null}>} */
const socketMeta = new WeakMap();

function isAuthorizedRequest(req) {
  return req.headers["x-realtime-secret"] === internalSecret;
}

function json(res, status, payload) {
  res.writeHead(status, {
    "content-type": "application/json",
  });
  res.end(JSON.stringify(payload));
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 2_000_000) {
        reject(new Error("payload too large"));
      }
    });
    req.on("end", () => {
      if (!raw) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error("invalid json"));
      }
    });
    req.on("error", reject);
  });
}

function safeSend(socket, message) {
  if (socket.readyState !== socket.OPEN) {
    return;
  }

  socket.send(JSON.stringify(message));
}

function roomSockets(roomId) {
  const set = socketsByRoom.get(roomId);
  if (!set) {
    return [];
  }

  return [...set.values()];
}

function publishToRoom(roomId, event, payload) {
  const sockets = roomSockets(roomId);
  for (const socket of sockets) {
    safeSend(socket, { event, payload });
  }
}

function closeRoomSockets(roomId, code, reason) {
  const sockets = roomSockets(roomId);
  for (const socket of sockets) {
    try {
      socket.close(code, reason);
    } catch {
      // no-op
    }
  }
}

function publishPresence(roomId) {
  const sockets = roomSockets(roomId);
  const participants = sockets
    .map((socket) => socketMeta.get(socket))
    .filter(Boolean)
    .map((meta) => ({
      participantId: meta.participantId,
      role: meta.role,
      clientId: meta.clientId,
      connected: true,
    }));

  publishToRoom(roomId, "presence.updated", {
    participants,
    onlineCount: participants.length,
    ts: Date.now(),
  });
}

async function verifyParticipantToken(token) {
  const { payload } = await jwtVerify(token, jwtKey, {
    algorithms: ["HS256"],
  });

  if (
    payload.typ !== "remote_participant" ||
    typeof payload.sub !== "string" ||
    typeof payload.rid !== "string" ||
    typeof payload.pid !== "string" ||
    (payload.role !== "HOST_PARENT" && payload.role !== "GUEST_CHILD")
  ) {
    throw new Error("invalid participant token");
  }

  return {
    storyId: payload.sub,
    roomId: payload.rid,
    participantId: payload.pid,
    role: payload.role,
  };
}

function relayRtc(socket, parsed) {
  const meta = socketMeta.get(socket);
  if (!meta) {
    safeSend(socket, {
      event: "error",
      payload: { code: "UNAUTHORIZED", message: "Join required." },
    });
    return;
  }

  const event = parsed.event;
  const payload = parsed.payload && typeof parsed.payload === "object" ? parsed.payload : {};
  const toParticipantId = typeof payload.toParticipantId === "string" ? payload.toParticipantId : null;

  const sockets = roomSockets(meta.roomId);
  for (const peerSocket of sockets) {
    if (peerSocket === socket) {
      continue;
    }

    const peerMeta = socketMeta.get(peerSocket);
    if (!peerMeta) {
      continue;
    }

    if (toParticipantId && peerMeta.participantId !== toParticipantId) {
      continue;
    }

    safeSend(peerSocket, {
      event,
      payload: {
        ...payload,
        fromParticipantId: meta.participantId,
      },
    });
  }
}

const server = createServer(async (req, res) => {
  if (!req.url) {
    json(res, 404, { error: "not found" });
    return;
  }

  if (req.method === "GET" && req.url === "/internal/health") {
    if (!isAuthorizedRequest(req)) {
      json(res, 401, { error: "unauthorized" });
      return;
    }

    json(res, 200, { ok: true });
    return;
  }

  if (req.method === "POST" && req.url === "/internal/publish") {
    if (!isAuthorizedRequest(req)) {
      json(res, 401, { error: "unauthorized" });
      return;
    }

    try {
      const body = await parseBody(req);
      const roomId = typeof body.remoteRoomId === "string" ? body.remoteRoomId : null;
      const event = typeof body.event === "string" ? body.event : null;
      const payload = body.payload;

      if (!roomId || !event) {
        json(res, 400, { error: "invalid payload" });
        return;
      }

      publishToRoom(roomId, event, payload);
      if (event === "remote.closed") {
        closeRoomSockets(roomId, 1000, "remote.closed");
      }
      json(res, 200, { ok: true, delivered: roomSockets(roomId).length });
    } catch {
      json(res, 400, { error: "invalid body" });
    }
    return;
  }

  json(res, 404, { error: "not found" });
});

const wsServer = new WebSocketServer({
  server,
  path: "/ws",
});

wsServer.on("connection", (socket) => {
  safeSend(socket, {
    event: "system.ready",
    payload: {
      ts: Date.now(),
    },
  });

  socket.on("message", async (buffer) => {
    let parsed;

    try {
      parsed = JSON.parse(buffer.toString("utf8"));
    } catch {
      safeSend(socket, {
        event: "error",
        payload: { code: "BAD_JSON", message: "Invalid JSON payload." },
      });
      return;
    }

    if (!parsed || typeof parsed !== "object" || typeof parsed.event !== "string") {
      safeSend(socket, {
        event: "error",
        payload: { code: "BAD_EVENT", message: "Invalid event envelope." },
      });
      return;
    }

    const event = parsed.event;

    if (event === "auth.join") {
      try {
        const token = parsed.payload?.participantToken;
        const clientId = parsed.payload?.clientId;

        if (typeof token !== "string" || !token) {
          throw new Error("missing token");
        }

        const verified = await verifyParticipantToken(token);

        const roomSet = socketsByRoom.get(verified.roomId) ?? new Set();
        roomSet.add(socket);
        socketsByRoom.set(verified.roomId, roomSet);

        socketMeta.set(socket, {
          roomId: verified.roomId,
          storyId: verified.storyId,
          participantId: verified.participantId,
          role: verified.role,
          clientId: typeof clientId === "string" ? clientId : null,
        });

        safeSend(socket, {
          event: "auth.joined",
          payload: {
            roomId: verified.roomId,
            storyId: verified.storyId,
            participantId: verified.participantId,
            role: verified.role,
          },
        });

        publishPresence(verified.roomId);
      } catch {
        safeSend(socket, {
          event: "error",
          payload: {
            code: "UNAUTHORIZED",
            message: "participantToken invalid or expired",
          },
        });
        socket.close(1008, "unauthorized");
      }
      return;
    }

    if (event === "presence.ping") {
      const meta = socketMeta.get(socket);
      if (!meta) {
        safeSend(socket, {
          event: "error",
          payload: { code: "UNAUTHORIZED", message: "Join required." },
        });
        return;
      }

      safeSend(socket, {
        event: "presence.pong",
        payload: { ts: Date.now() },
      });
      return;
    }

    if (event === "call.mode.set") {
      const meta = socketMeta.get(socket);
      if (!meta) {
        safeSend(socket, {
          event: "error",
          payload: { code: "UNAUTHORIZED", message: "Join required." },
        });
        return;
      }

      publishToRoom(meta.roomId, "call.mode.changed", {
        mode: parsed.payload?.mode,
        fromParticipantId: meta.participantId,
      });
      return;
    }

    if (
      event === "rtc.offer" ||
      event === "rtc.answer" ||
      event === "rtc.ice" ||
      event === "rtc.hangup"
    ) {
      relayRtc(socket, parsed);
      return;
    }

    safeSend(socket, {
      event: "error",
      payload: { code: "UNKNOWN_EVENT", message: `Unknown event: ${event}` },
    });
  });

  socket.on("close", () => {
    const meta = socketMeta.get(socket);
    if (!meta) {
      return;
    }

    const roomSet = socketsByRoom.get(meta.roomId);
    if (roomSet) {
      roomSet.delete(socket);
      if (roomSet.size === 0) {
        socketsByRoom.delete(meta.roomId);
      }
    }

    publishPresence(meta.roomId);
  });
});

server.listen(port, () => {
  console.log(`Realtime gateway listening on :${port}`);
});
