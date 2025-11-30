# skt-alarm-dispatcher

Supabase Edge Function that scans SKT kayıtları, tetiklenmesi gereken alarm aşamalarını belirler ve Firebase Cloud Messaging (FCM) üzerinden push bildirimi gönderir. Ayrıca gönderilen bildirimleri `skt_alarm_notifications` tablosunda loglayarak aynı aşamanın tekrar gönderilmesini engeller.

## Çevresel değişkenler

```text
SUPABASE_URL=...               # Project URL
SUPABASE_SERVICE_ROLE_KEY=...  # Service key (yalnızca Edge Functions için)
FIREBASE_PROJECT_ID=...        # Firebase project ID (örn: my-app)
GOOGLE_CLIENT_EMAIL=...        # Service account client_email
GOOGLE_PRIVATE_KEY=...         # Service account private_key (\n ile kaçışlı)
SKT_DISPATCHER_SECRET=...      # (Opsiyonel) Cron job ile paylaşacağınız Bearer anahtarı
```

CLI üzerinden tanımlamak için:

```bash
supabase secrets set \
  SUPABASE_URL="https://...supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="..." \
  FIREBASE_PROJECT_ID="my-firebase-project" \
  GOOGLE_CLIENT_EMAIL="firebase-adminsdk@my-firebase-project.iam.gserviceaccount.com" \
  GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n" \
  SKT_DISPATCHER_SECRET="your-secret"
```

## Çalıştırma

```bash
# Lokal geliştirme (hot reload)
supabase functions serve skt-alarm-dispatcher --env-file supabase/.env.local

# Prod deploy
supabase functions deploy skt-alarm-dispatcher --no-verify-jwt
```

## Cron job

Fonksiyon yalnızca `POST` isteği kabul eder ve (opsiyonel) Bearer doğrulaması yapar. Supabase Dashboard → Project Settings → Cron üzerinden şu ayarda job oluşturabilirsiniz:

- Method: POST
- URL: `https://<project>.supabase.co/functions/v1/skt-alarm-dispatcher`
- Headers: `Authorization: Bearer <SKT_DISPATCHER_SECRET>`
- Schedule: `*/30 * * * *` (30 dakikada bir)
