// Shared plumbing for runtime methods: results, protocol failures, the
// per-connection call context, the method wrapper, and a tiny param-schema
// validator (object() + checks) that rejects unknown keys.

import { ErrorCode } from "../shared/protocol";

export type Result<T> = { ok: true; value: T } | { ok: false; message: string };
export const ok = <T>(value: T): Result<T> => ({ ok: true, value });
export const err = <T = never>(message: string): Result<T> => ({ ok: false, message });

export const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/** Throw to answer a call with a specific protocol error. */
export class RpcFailure extends Error {
  constructor(
    readonly code: number,
    message: string,
    readonly data?: unknown,
  ) {
    super(message);
  }
}

export const fail = {
  invalid: (message: string) => new RpcFailure(ErrorCode.INVALID_PARAMS, message),
  notFound: (message: string) => new RpcFailure(ErrorCode.NOT_FOUND, message),
  forbidden: (message: string) => new RpcFailure(ErrorCode.FORBIDDEN, message),
  conflict: (message: string) => new RpcFailure(ErrorCode.CONFLICT, message),
  limit: (message: string) => new RpcFailure(ErrorCode.RESOURCE_LIMIT, message),
  io: (message: string, errno?: string) =>
    new RpcFailure(ErrorCode.IO_ERROR, message, errno === undefined ? undefined : { errno }),
};

/** Per-connection state the dispatcher hands to every call. */
export interface CallContext {
  readonly sessionId: string;
  readonly helloed: boolean;
  markHello(): void;
}

export interface AnyMethod {
  readonly requiresHello: boolean;
  handle(params: unknown, ctx: CallContext): Promise<unknown>;
}

/** Wraps a handler with param validation (missing params count as {}). */
export function method<P>(
  requiresHello: boolean,
  validate: (v: unknown) => Result<P>,
  run: (params: P, ctx: CallContext) => unknown,
): AnyMethod {
  return {
    requiresHello,
    async handle(raw, ctx) {
      const parsed = validate(raw === undefined ? {} : raw);
      if (!parsed.ok) throw fail.invalid(parsed.message);
      return run(parsed.value, ctx);
    },
  };
}

// ---- param schema ---------------------------------------------------------

export type Check<T> = (v: unknown, key: string) => Result<T>;
type Infer<C> = C extends Check<infer T> ? T : never;

export const str =
  (o: { min?: number; max?: number; allowNul?: boolean } = {}): Check<string> =>
  (v, key) => {
    const min = o.min ?? 0;
    const max = o.max ?? 4096;
    if (typeof v !== "string") return err(`${key} must be a string`);
    if (v.length < min || v.length > max) return err(`${key} must be ${min}-${max} characters`);
    if (!o.allowNul && v.includes("\0")) return err(`${key} must not contain NUL`);
    return ok(v);
  };

export const int =
  (min: number, max: number): Check<number> =>
  (v, key) =>
    Number.isSafeInteger(v) && (v as number) >= min && (v as number) <= max
      ? ok(v as number)
      : err(`${key} must be an integer from ${min} to ${max}`);

export const num: Check<number> = (v, key) =>
  typeof v === "number" && Number.isFinite(v) ? ok(v) : err(`${key} must be a finite number`);

export const bool: Check<boolean> = (v, key) => (typeof v === "boolean" ? ok(v) : err(`${key} must be a boolean`));

export const oneOf =
  <T extends string>(...values: T[]): Check<T> =>
  (v, key) =>
    typeof v === "string" && (values as string[]).includes(v) ? ok(v as T) : err(`${key} must be one of: ${values.join(", ")}`);

export const optional =
  <T>(check: Check<T>): Check<T | undefined> =>
  (v, key) =>
    v === undefined ? ok(undefined) : check(v, key);

/** An id issued by this runtime (uuid). */
export const id = str({ min: 1, max: 128 });

/** Validates an object against `spec`; unknown keys are rejected. */
export function object<S extends Record<string, Check<unknown>>>(spec: S) {
  return (v: unknown): Result<{ [K in keyof S]: Infer<S[K]> }> => {
    if (!isRecord(v)) return err("params must be an object");
    for (const key of Object.keys(v)) {
      if (!Object.hasOwn(spec, key)) return err(`unknown param "${key}"`);
    }
    const out: Record<string, unknown> = {};
    for (const [key, check] of Object.entries(spec)) {
      const r = check(v[key], key);
      if (!r.ok) return err(r.message);
      if (r.value !== undefined) out[key] = r.value;
    }
    return ok(out as { [K in keyof S]: Infer<S[K]> });
  };
}

/** An array of at most `max` values that each pass `item`. */
export const list =
  <T>(item: Check<T>, max: number): Check<T[]> =>
  (v, key) => {
    if (!Array.isArray(v)) return err(`${key} must be a list`);
    if (v.length > max) return err(`${key} can have at most ${max} entries`);
    const out: T[] = [];
    for (let i = 0; i < v.length; i++) {
      const r = item(v[i], `${key}[${i}]`);
      if (!r.ok) return r as Result<T[]>;
      out.push(r.value);
    }
    return ok(out);
  };
