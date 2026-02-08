// @ts-nocheck - Deno runtime, VS Code TypeScript can't resolve Deno modules
// Supabase Edge Function - Send Push Notifications via FCM
// This function processes pending notifications from notification_queue and sends them via Firebase Cloud Messaging

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface NotificationQueueItem {
  id: string;
  device_token_id: string;
  notification_id: string | null;
  title: string;
  body: string | null;
  data: Record<string, unknown>;
  status: string;
  device_token: {
    token: string;
    platform: string;
  };
}

interface FCMMessage {
  message: {
    token: string;
    notification: {
      title: string;
      body: string;
    };
    data?: Record<string, string>;
    android?: {
      priority: string;
      notification: {
        sound: string;
        click_action: string;
      };
    };
    apns?: {
      payload: {
        aps: {
          sound: string;
          badge: number;
        };
      };
    };
  };
}

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 3600;

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: exp,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encoder = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const signatureInput = encoder.encode(`${headerB64}.${payloadB64}`);

  // Import the private key
  const privateKeyPem = serviceAccount.private_key;
  const pemContents = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, signatureInput);
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${headerB64}.${payloadB64}.${signatureB64}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

async function sendFCMNotification(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, unknown>
): Promise<{ success: boolean; error?: string }> {
  const message: FCMMessage = {
    message: {
      token,
      notification: {
        title,
        body: body || "",
      },
      data: Object.fromEntries(
        Object.entries(data || {}).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: "high",
        notification: {
          sound: "default",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    },
  };

  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      return { success: false, error: JSON.stringify(errorData) };
    }

    return { success: true };
  } catch (error) {
    return { success: false, error: String(error) };
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get environment variables
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

    if (!firebaseServiceAccountJson) {
      return new Response(
        JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const serviceAccount = JSON.parse(firebaseServiceAccountJson);
    const projectId = serviceAccount.project_id;

    // Create Supabase client
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get pending notifications with device tokens
    const { data: pendingNotifications, error: fetchError } = await supabase
      .from("notification_queue")
      .select(`
        id,
        device_token_id,
        notification_id,
        title,
        body,
        data,
        status,
        device_token:device_tokens!device_token_id (
          token,
          platform
        )
      `)
      .eq("status", "pending")
      .limit(100);

    if (fetchError) {
      console.error("Error fetching notifications:", fetchError);
      return new Response(
        JSON.stringify({ error: fetchError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!pendingNotifications || pendingNotifications.length === 0) {
      return new Response(
        JSON.stringify({ message: "No pending notifications", sent: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get FCM access token
    const accessToken = await getAccessToken(serviceAccount);

    let sentCount = 0;
    let failedCount = 0;
    const errors: string[] = [];

    // Process each notification
    for (const notification of pendingNotifications as NotificationQueueItem[]) {
      const deviceToken = notification.device_token;
      
      if (!deviceToken?.token) {
        // Mark as failed - no device token
        await supabase
          .from("notification_queue")
          .update({ status: "failed", error_message: "No device token found" })
          .eq("id", notification.id);
        failedCount++;
        continue;
      }

      const result = await sendFCMNotification(
        accessToken,
        projectId,
        deviceToken.token,
        notification.title,
        notification.body || "",
        notification.data
      );

      if (result.success) {
        // Mark as sent
        await supabase
          .from("notification_queue")
          .update({ status: "sent", sent_at: new Date().toISOString() })
          .eq("id", notification.id);
        sentCount++;
      } else {
        // Mark as failed
        await supabase
          .from("notification_queue")
          .update({ status: "failed", error_message: result.error })
          .eq("id", notification.id);
        failedCount++;
        errors.push(result.error || "Unknown error");

        // If token is invalid, remove it
        if (result.error?.includes("UNREGISTERED") || result.error?.includes("INVALID_ARGUMENT")) {
          await supabase
            .from("device_tokens")
            .delete()
            .eq("id", notification.device_token_id);
        }
      }
    }

    return new Response(
      JSON.stringify({
        message: "Notifications processed",
        total: pendingNotifications.length,
        sent: sentCount,
        failed: failedCount,
        errors: errors.slice(0, 5), // Return first 5 errors
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
