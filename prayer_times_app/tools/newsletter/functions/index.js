
/* eslint-disable no-console */
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

/**
 * Secrets (configure with the Firebase CLI):
 *   firebase functions:secrets:set MC_API_KEY
 *   firebase functions:secrets:set MC_LIST_ID
 *
 * Keep both as Secrets (NOT in .env). If MC_LIST_ID is also present in .env,
 * remove it to avoid “Secret environment variable overlaps non secret environment variable”.
 */
const MC_API_KEY = defineSecret('MC_API_KEY'); // required
const MC_LIST_ID = defineSecret('MC_LIST_ID'); // optional audience filter

exports.latestNewsletter = onRequest(
  {
    region: 'us-central1',
    cors: true,
    invoker: 'public',                 // make the service publicly invokable (Cloud Run Invoker -> allUsers)
    secrets: [MC_API_KEY, MC_LIST_ID], // ensure secrets are injected at runtime
  },
  async (req, res) => {
    try {
      // --- Secrets at runtime
      const rawKey = MC_API_KEY.value && MC_API_KEY.value();
      if (!rawKey) {
        console.error('MC_API_KEY missing at runtime');
        return res.status(500).json({ error: 'missing_api_key' });
      }

      // Derive Mailchimp datacenter from key suffix (e.g., "...-us15")
      const apiKey = String(rawKey).trim();
      const dcMatch = apiKey.match(/-us\d+$/i);
      if (!dcMatch) {
        console.error('API key missing datacenter suffix (-usXX)');
        return res.status(500).json({ error: 'invalid_api_key_format' });
      }
      const dc = dcMatch[0].slice(1).trim(); // "us15"

      // Build campaigns URL
      const url = new URL(`https://${dc}.api.mailchimp.com/3.0/campaigns`);
      url.searchParams.set('status', 'sent');
      url.searchParams.set('sort_field', 'send_time');
      url.searchParams.set('sort_dir', 'DESC');
      url.searchParams.set('count', '1');

      // Optional audience filter (keep as Secret)
      const rawListId = MC_LIST_ID.value && MC_LIST_ID.value();
      const listId = rawListId ? String(rawListId).trim() : '';
      if (listId) url.searchParams.set('list_id', listId);

      // Call Mailchimp
      const resp = await fetch(url.toString(), {
        headers: { Authorization: `apikey ${apiKey}` },
      });

      if (!resp.ok) {
        const text = await resp.text().catch(() => '');
        console.error('Mailchimp API error', resp.status, text.slice(0, 300));
        return res.status(502).json({ error: 'mailchimp_failed', status: resp.status });
      }

      const data = await resp.json().catch((e) => {
        console.error('JSON parse error', e);
        throw e;
      });

      const campaign = (data.campaigns && data.campaigns[0]) || null;
      const latest = (campaign && (campaign.long_archive_url || campaign.archive_url)) || null;

      if (!latest) {
        console.warn('No sent campaigns found (check Audience ID or account)');
        return res.status(404).json({ error: 'no_campaigns' });
      }

      // Normalize &amp; → &
      const cleaned = latest.replace(/&amp;/g, '&');

      // Cache for 5 minutes to reduce API calls
      res.set('Cache-Control', 'public, max-age=300');
      return res.status(200).json({ url: cleaned });
    } catch (e) {
      console.error('Unhandled error', e);
      return res.status(500).json({ error: 'internal' });
    }
  }
);