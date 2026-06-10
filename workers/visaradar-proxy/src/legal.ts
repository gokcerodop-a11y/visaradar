// legal.ts — public Privacy Policy and Terms of Use (EULA) pages served by the
// proxy so the App Store metadata can point at functional, always-live links
// (App Review Guideline 3.1.2 requires these for auto-renewable subscriptions).

const SUPPORT_EMAIL = "gokcerodop@gmail.com";
const LAST_UPDATED = "10 June 2026";

function page(title: string, bodyHtml: string): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · VisaRadar Travel</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; color: #1c2a3f; background: #fff; }
  @media (prefers-color-scheme: dark){ body{ background:#0B1120; color:#e6edf6 } a{ color:#00D4AA } }
  h1 { font-size: 26px; } h2 { font-size: 19px; margin-top: 32px; }
  a { color: #00A884; } .muted { opacity: .7; font-size: 14px; }
  hr { border: none; border-top: 1px solid rgba(127,127,127,.25); margin: 40px 0; }
</style>
</head>
<body>${bodyHtml}
<hr>
<p class="muted">VisaRadar Travel · Contact: <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> · Last updated: ${LAST_UPDATED}</p>
</body></html>`;
  return new Response(html, {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=3600" },
  });
}

export function privacyPage(): Response {
  return page("Privacy Policy", `
<h1>Privacy Policy</h1>
<p>VisaRadar Travel ("the app") helps travellers track visas, border crossings and Schengen 90/180 stay limits. This policy explains what data the app uses and how.</p>

<h2>Data the app uses</h2>
<ul>
  <li><strong>Location</strong> — used only on your device to detect which country/city you are in, so the app can show the right visa and stay information. Your location is processed for that purpose and is not sold.</li>
  <li><strong>Trips and profile</strong> — the trips, dates and traveller profile you enter are stored locally on your device.</li>
  <li><strong>AI assistant & document scanner</strong> — when you ask the assistant a question or scan a document, the relevant text/image is sent to our secure proxy and to Anthropic's Claude API to generate the answer. It is used only to produce your response and is not used to sell anything.</li>
  <li><strong>Purchases</strong> — purchase receipts are validated through Apple. We do not see your card details.</li>
</ul>

<h2>What we do not do</h2>
<ul>
  <li>We do not sell your personal data to third parties.</li>
  <li>We do not show third-party advertising.</li>
</ul>

<h2>Your rights (GDPR/KVKK)</h2>
<p>You can delete your local data at any time from within the app. For questions or data requests, contact us at the email below.</p>

<h2>Disclaimer</h2>
<p>VisaRadar Travel provides travel and visa information for general guidance only. Always verify entry, visa and stay requirements with official government sources before travelling.</p>
`);
}

export function termsPage(): Response {
  return page("Terms of Use", `
<h1>Terms of Use (EULA)</h1>
<p>By downloading or using VisaRadar Travel you agree to these terms and to Apple's standard
<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Licensed Application End User License Agreement</a>.</p>

<h2>Subscriptions and purchases</h2>
<p>VisaRadar Travel offers an optional <strong>VisaRadar Premium</strong> upgrade that unlocks the AI travel assistant, the document scanner and border mode:</p>
<ul>
  <li><strong>Monthly Premium</strong> — auto-renewable subscription, 1 month, USD 4.99 (price localised per region).</li>
  <li><strong>Annual Premium</strong> — auto-renewable subscription, 1 year, USD 34.99, with a 3-day free trial.</li>
  <li><strong>Lifetime Premium</strong> — one-time purchase, USD 59.99 (non-consumable).</li>
</ul>
<p>Payment is charged to your Apple Account at confirmation of purchase. Auto-renewable subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours before the period ends. Any unused portion of a free trial is forfeited when you buy a subscription. You can manage or cancel subscriptions in your Apple Account settings (Settings → your name → Subscriptions).</p>

<h2>Use of the app</h2>
<p>The information provided is for general guidance only and is not legal advice. Always confirm visa, entry and stay requirements with official government sources. You are responsible for your own travel decisions.</p>

<h2>Contact</h2>
<p>Questions about these terms can be sent to the contact email below.</p>
`);
}
