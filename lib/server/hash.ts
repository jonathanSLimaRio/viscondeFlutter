import { hash, verify } from "@node-rs/argon2";
import { createHash } from "node:crypto";

const HASH_OPTIONS = {
  algorithm: 2,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
};

export async function hashSecret(secret: string) {
  return hash(secret, HASH_OPTIONS);
}

export async function verifySecret(hashValue: string, input: string) {
  return verify(hashValue, input, HASH_OPTIONS);
}

export function hashLookupToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}
