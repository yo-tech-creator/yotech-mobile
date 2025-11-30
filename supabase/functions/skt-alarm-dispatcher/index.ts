let serviceAccountKeyPromise: Promise<CryptoKey> | null = null;

async function getGoogleAccessToken() {
  if (googleAccessToken && googleAccessToken.expiresAt > Date.now() + 60_000) {
    return googleAccessToken.token;
  }

  const privateKey = GOOGLE_PRIVATE_KEY.replace(/\\n/g, "\n");
  if (!serviceAccountKeyPromise) {
    serviceAccountKeyPromise = importPKCS8(privateKey, "RS256");
  }

  const key = await serviceAccountKeyPromise;
  const now = Math.floor(Date.now() / 1000);
  const audience = "https://oauth2.googleapis.com/token";

  const assertion = await new SignJWT({
    iss: GOOGLE_CLIENT_EMAIL,
    sub: GOOGLE_CLIENT_EMAIL,
    aud: audience,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    iat: now,
    exp: now + 3600,
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .sign(key);

  const params = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });

  const response = await fetch(audience, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Google OAuth token alınamadı: ${text || `HTTP ${response.status}`}`);
  }

  const json = await response.json();
  const accessToken = json.access_token as string;
  const expiresIn = Number(json.expires_in ?? 3600);

  googleAccessToken = {
    token: accessToken,
    expiresAt: Date.now() + (expiresIn - 60) * 1000,
  };

  return accessToken;
}

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.6";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.3.0";

type AlarmStage = "day_before" | "expiry_day";

type RecordRow = {
  id: string;
  tenant_id: string;
  user_id: string;
  branch_id: string | null;
  product_id: string;
  expiry_date: string | null;
  alarm_date: string | null;
  alarm_days_before: number | null;
  quantity: number | null;
  alarm_sent: boolean | null;
  products?: {
    name?: string | null;
    barcode?: string | null;
  } | null;
  branches?: {
    name?: string | null;
  } | null;
};

type PushPayload = {
  notification: {
    title: string;
    body: string;
  };
  data: Record<string, string>;
};

type DispatchJob = {
  stage: AlarmStage;
  record: RecordRow;
};

type DispatchResult = {
  recordId: string;
  stage: AlarmStage;
  status: "sent" | "skipped_no_tokens" | "already_sent" | "push_failed";
  message?: string;
  successCount?: number;
  failureCount?: number;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID");
const GOOGLE_CLIENT_EMAIL = Deno.env.get("GOOGLE_CLIENT_EMAIL");
const GOOGLE_PRIVATE_KEY = Deno.env.get("GOOGLE_PRIVATE_KEY");
const DISPATCHER_SECRET = Deno.env.get("SKT_DISPATCHER_SECRET") ?? Deno.env.get("DISPATCHER_SECRET");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Supabase Edge Function: SUPABASE_URL veya SERVICE_ROLE anahtarı eksik.");
}

if (!FIREBASE_PROJECT_ID || !GOOGLE_CLIENT_EMAIL || !GOOGLE_PRIVATE_KEY) {
  throw new Error("Supabase Edge Function: Firebase HTTP v1 için FIREBASE_PROJECT_ID, GOOGLE_CLIENT_EMAIL ve GOOGLE_PRIVATE_KEY zorunlu.");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const tokenCache = new Map<string, string[]>();
let googleAccessToken: { token: string; expiresAt: number } | null = null;

serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Method Not Allowed" });
  }

  if (!isDispatcherRequestAuthorized(req)) {
    return jsonResponse(401, { ok: false, error: "Unauthorized" });
  }

  try {
    const summary = await dispatchPendingNotifications();
    return jsonResponse(200, { ok: true, ...summary });
  } catch (error) {
    console.error("SKT alarm dispatcher failed", error);
    return jsonResponse(500, { ok: false, error: (error as Error).message });
  }
});

function isDispatcherRequestAuthorized(req: Request) {
  if (!DISPATCHER_SECRET) {
    return true;
  }

  const headerCandidates = [
    req.headers.get("authorization") ?? "",
    req.headers.get("x-skt-dispatcher-secret") ?? "",
    req.headers.get("x-dispatcher-secret") ?? "",
  ];

  for (const raw of headerCandidates) {
    if (!raw) continue;
    const normalized = raw.startsWith("Bearer ") ? raw.slice(7).trim() : raw.trim();
    if (normalized === DISPATCHER_SECRET) {
      return true;
    }
  }

  return false;
}

async function dispatchPendingNotifications() {
  const todayISO = new Date().toISOString().slice(0, 10);

  const [dayBefore, expired] = await Promise.all([
    fetchDayBeforeCandidates(todayISO),
    fetchExpiredCandidates(todayISO),
  ]);

  const expiryIds = expired.map((record) => record.id);
  const sentMap = await fetchSentStages(expiryIds);

  const jobs: DispatchJob[] = [];
  for (const record of dayBefore) {
    jobs.push({ record, stage: "day_before" });
  }

  for (const record of expired) {
    if (hasStage(sentMap, record.id, "expiry_day")) {
      continue;
    }
    jobs.push({ record, stage: "expiry_day" });
  }

  const results: DispatchResult[] = [];
  for (const job of jobs) {
    try {
      const tokens = await getTokens(job.record.user_id);
      if (tokens.length === 0) {
        results.push({
          recordId: job.record.id,
          stage: job.stage,
          status: "skipped_no_tokens",
          message: "Aktif cihaz tokenı bulunamadı",
        });
        continue;
      }

      const payload = buildPayload(job.record, job.stage);
      const pushResult = await sendFcm(tokens, payload);

      if (pushResult.successCount === 0) {
        results.push({
          recordId: job.record.id,
          stage: job.stage,
          status: "push_failed",
          message: pushResult.errors.at(0)?.error ?? "FCM push başarısız",
          successCount: 0,
          failureCount: pushResult.failureCount,
        });
        continue;
      }

      await logNotification(job, payload, pushResult);
      if (job.stage === "day_before" && !job.record.alarm_sent) {
        await supabase
          .from("skt_records")
          .update({ alarm_sent: true, updated_at: new Date().toISOString() })
          .eq("id", job.record.id);
      }

      results.push({
        recordId: job.record.id,
        stage: job.stage,
        status: "sent",
        successCount: pushResult.successCount,
        failureCount: pushResult.failureCount,
      });
    } catch (error) {
      console.error("SKT alarm job failed", job, error);
      results.push({
        recordId: job.record.id,
        stage: job.stage,
        status: "push_failed",
        message: (error as Error).message,
      });
    }
  }

  const sent = results.filter((r) => r.status === "sent");
  const skipped = results.filter((r) => r.status === "skipped_no_tokens");
  const failed = results.filter((r) => r.status === "push_failed");

  return {
    total: results.length,
    sent: sent.length,
    skipped: skipped.length,
    failed: failed.length,
    results,
  };
}

async function fetchDayBeforeCandidates(todayISO: string) {
  const { data, error } = await supabase
    .from("skt_records")
    .select(
      `id, tenant_id, user_id, branch_id, product_id, expiry_date, alarm_date, alarm_days_before, quantity, alarm_sent,
       products:products(id, name, barcode),
       branches:branches(id, name)`
    )
    .eq("alarm_sent", false)
    .lte("alarm_date", todayISO)
    .in("status", ["yaklasan", "gecmis"]);

  if (error) {
    throw new Error(`Alarm verileri okunamadı (day_before): ${error.message}`);
  }

  return (data ?? []) as RecordRow[];
}

async function fetchExpiredCandidates(todayISO: string) {
  const { data, error } = await supabase
    .from("skt_records")
    .select(
      `id, tenant_id, user_id, branch_id, product_id, expiry_date, alarm_date, alarm_days_before, quantity, alarm_sent,
       products:products(id, name, barcode),
       branches:branches(id, name)`
    )
    .lte("expiry_date", todayISO)
    .in("status", ["gecmis"]);

  if (error) {
    throw new Error(`Alarm verileri okunamadı (expiry_day): ${error.message}`);
  }

  return (data ?? []) as RecordRow[];
}

async function fetchSentStages(recordIds: string[]) {
  const map = new Map<string, Set<AlarmStage>>();
  if (recordIds.length === 0) {
    return map;
  }

  const { data, error } = await supabase
    .from("skt_alarm_notifications")
    .select("record_id, alarm_stage")
    .in("record_id", recordIds);

  if (error) {
    throw new Error(`Gönderilmiş bildirimler okunamadı: ${error.message}`);
  }

  for (const row of data ?? []) {
    const key = row.record_id as string;
    const stage = row.alarm_stage as AlarmStage;
    if (!map.has(key)) {
      map.set(key, new Set());
    }
    map.get(key)!.add(stage);
  }

  return map;
}

function hasStage(map: Map<string, Set<AlarmStage>>, recordId: string, stage: AlarmStage) {
  return map.get(recordId)?.has(stage) ?? false;
}

async function getTokens(userId: string) {
  if (tokenCache.has(userId)) {
    return tokenCache.get(userId)!;
  }

  const { data, error } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", userId);

  if (error) {
    throw new Error(`Token sorgusu başarısız: ${error.message}`);
  }

  const tokens = (data ?? [])
    .map((row) => row.token as string | null)
    .filter((token): token is string => Boolean(token));

  tokenCache.set(userId, tokens);
  return tokens;
}

function buildPayload(record: RecordRow, stage: AlarmStage): PushPayload {
  const productName = record.products?.name?.trim() || "SKT Alarmı";
  const branchName = record.branches?.name?.trim() || "Depo";
  const expiry = record.expiry_date ?? "";
  const days = record.alarm_days_before ?? 1;

  const title = stage === "day_before"
    ? `${productName} için SKT uyarısı`
    : `${productName} için SKT süresi doldu`;

  const body = stage === "day_before"
    ? `${branchName} stoğundaki ürün ${expiry} tarihinde dolacak. ${days} gün kala hatırlatılıyor.`
    : `${branchName} stoğundaki ürünün SKT tarihi geçti (${expiry}). Acil aksiyon alın.`;

  const dataPayload: Record<string, string> = {
    alarmStage: stage,
    recordId: record.id,
    productId: record.product_id ?? "",
    tenantId: record.tenant_id ?? "",
    expiresOn: expiry,
    alarmDate: record.alarm_date ?? "",
    quantity: String(record.quantity ?? ""),
    productName,
    branchName,
    barcode: record.products?.barcode ?? "",
  };

  return {
    notification: { title, body },
    data: dataPayload,
  };
}

async function logNotification(job: DispatchJob, payload: PushPayload, pushResult: { successCount: number; failureCount: number; errors: { token: string; error: string }[] }) {
  const { error } = await supabase
    .from("skt_alarm_notifications")
    .upsert(
      {
        record_id: job.record.id,
        user_id: job.record.user_id,
        tenant_id: job.record.tenant_id,
        alarm_stage: job.stage,
        alarm_date: job.record.alarm_date,
        expires_on: job.record.expiry_date,
        alarm_days_before: job.record.alarm_days_before,
        payload,
        push_result: pushResult,
        sent_at: new Date().toISOString(),
      },
      { onConflict: "record_id, alarm_stage" }
    );

  if (error) {
    throw new Error(`Bildirim kaydedilemedi: ${error.message}`);
  }
}

async function sendFcm(tokens: string[], payload: PushPayload) {
  const errors: { token: string; error: string }[] = [];
  let successCount = 0;
  let failureCount = 0;
  const url = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;

  for (const token of tokens) {
    const messageBody = JSON.stringify({
      message: {
        token,
        notification: payload.notification,
        data: payload.data,
      },
    });

    let accessToken = await getGoogleAccessToken();
    let response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: messageBody,
    });

    if (response.status === 401 || response.status === 403) {
      googleAccessToken = null;
      accessToken = await getGoogleAccessToken();
      response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: messageBody,
      });
    }

    if (!response.ok) {
      const text = await response.text();
      failureCount += 1;
      errors.push({ token, error: text || `HTTP ${response.status}` });
      continue;
    }

    successCount += 1;
  }

  return { successCount, failureCount, errors };
}

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
