// legal.ts — public Privacy Policy, KVKK, Terms of Use pages served by the
// proxy so the App Store metadata can point at functional, always-live links
// (App Review Guideline 3.1.2 requires these for auto-renewable subscriptions).

const SUPPORT_EMAIL = "gokcerodop@gmail.com";
const LAST_UPDATED = "12 Temmuz 2026 / 12 July 2026";

function page(title: string, bodyHtml: string): Response {
  const html = `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · VisaRadar Travel</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.7 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; color: #1c2a3f; background: #fff; }
  @media (prefers-color-scheme: dark){ body{ background:#0B1120; color:#e6edf6 } a{ color:#00D4AA } }
  h1 { font-size: 26px; } h2 { font-size: 19px; margin-top: 32px; color: #00A884; }
  h3 { font-size: 16px; margin-top: 20px; }
  a { color: #00A884; } .muted { opacity: .7; font-size: 14px; }
  hr { border: none; border-top: 1px solid rgba(127,127,127,.25); margin: 40px 0; }
  .badge { display:inline-block; background:#00A884; color:#fff; border-radius:4px; padding:2px 8px; font-size:13px; font-weight:600; margin-left:8px; }
</style>
</head>
<body>${bodyHtml}
<hr>
<p class="muted">VisaRadar Travel · İletişim / Contact: <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> · Son güncelleme / Last updated: ${LAST_UPDATED}</p>
</body></html>`;
  return new Response(html, {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=3600" },
  });
}

export function privacyPage(): Response {
  return page("Gizlilik Politikası & KVKK / Privacy Policy & GDPR", `
<h1>Gizlilik Politikası ve Kişisel Verilerin Korunması</h1>
<p><em>Privacy Policy &amp; Personal Data Protection (KVKK / GDPR)</em></p>
<p>VisaRadar Travel ("uygulama"), seyahatçilerin vize, sınır geçişleri ve Schengen 90/180 kalış sürelerini takip etmesine yardımcı olur. Bu politika, uygulamanın hangi verileri kullandığını ve nasıl işlediğini açıklamaktadır.</p>

<h2>1. Toplanan Veriler / Data We Collect</h2>

<h3>1.1 Konum Verisi (Location)</h3>
<p>Uygulama, yalnızca <strong>cihazınızda</strong> konumunuzu kullanır; hangi ülke/şehirde olduğunuzu belirleyerek size doğru vize ve kalış bilgisi sunar. Konum verisi üçüncü taraflara satılmaz ve yurt dışına aktarılmaz.</p>
<p><em>The app uses your location only on-device to detect which country/city you are in. Location data is not sold to third parties.</em></p>

<h3>1.2 Seyahat Profili ve Geziler (Travel Profile &amp; Trips)</h3>
<p>Girdiğiniz geziler, tarihler ve seyahatçi profil bilgileri <strong>yalnızca cihazınızda</strong> saklanır. Herhangi bir sunucuya gönderilmez.</p>

<h3>1.3 AI Asistan ve Belge Tarayıcı</h3>
<p>AI asistana soru sorduğunuzda veya bir belge/fotoğraf yüklediğinizde ilgili metin/görüntü, güvenli proxy sunucumuz aracılığıyla <strong>Anthropic Claude API</strong>'ye iletilir. Bu veriler yalnızca yanıt üretmek amacıyla kullanılır; reklam, profil oluşturma veya satış için kullanılmaz.</p>
<p><strong>Önemli uyarı:</strong> TC kimlik numarası, IBAN, banka bilgisi gibi hassas kişisel verileri AI asistana yazmayınız.</p>
<p><em>When you use the AI assistant or document scanner, your input is sent to our secure proxy and Anthropic's API solely to generate your answer. It is never used for advertising or profiling.</em></p>

<h3>1.4 Satın Alma (Purchases)</h3>
<p>Satın alma işlemleri Apple üzerinden doğrulanır. Kart bilgilerinize erişmiyoruz.</p>

<h2>2. Veri Güvenliği / Data Security</h2>
<ul>
  <li>Uygulama sunucu bağlantıları TLS/HTTPS ile şifrelenir.</li>
  <li>Apple fatura bilgileriniz Apple'ın güvenli altyapısında saklanır.</li>
  <li>Cloudflare Worker proxy, gelen istekleri doğrular ve rate-limit uygular.</li>
  <li>Cihaz üzerindeki veriler (geziler, profil) cihazın kendi şifreleme mekanizması ile korunur.</li>
</ul>

<h2>3. Kişisel Verilerin Korunması — KVKK (6698 Sayılı Kanun)</h2>
<p>Türkiye Cumhuriyeti 6698 Sayılı Kişisel Verilerin Korunması Kanunu kapsamında veri sahibi olarak aşağıdaki haklara sahipsiniz:</p>
<ul>
  <li>Kişisel verilerinizin işlenip işlenmediğini öğrenme,</li>
  <li>Kişisel verileriniz işlenmişse buna ilişkin bilgi talep etme,</li>
  <li>Kişisel verilerinizin işlenme amacını ve bunların amacına uygun kullanılıp kullanılmadığını öğrenme,</li>
  <li>Yurt içinde veya yurt dışında kişisel verilerinizin aktarıldığı üçüncü kişileri bilme,</li>
  <li>Kişisel verilerinizin eksik veya yanlış işlenmiş olması hâlinde bunların düzeltilmesini isteme,</li>
  <li>Kanun'un 7. maddesinde öngörülen şartlar çerçevesinde kişisel verilerinizin silinmesini veya yok edilmesini isteme,</li>
  <li>Kişisel verilerinizin münhasıran otomatik sistemler vasıtasıyla analiz edilmesi suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme.</li>
</ul>
<p>Bu haklarınızı kullanmak için <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> adresine başvurabilirsiniz.</p>

<h2>4. GDPR — Avrupa Birliği</h2>
<p>AB/AEA vatandaşları için GDPR kapsamında: işleme hukuki dayanağı <em>meşru menfaat</em> ve <em>sözleşme ifası</em>dır (abonelik hizmetinin sunulması). Verilerinize erişim, düzeltme, silme veya taşınabilirlik taleplerinizi e-posta yoluyla iletebilirsiniz. Şikâyetlerinizi yerel veri koruma otoritenize iletebilirsiniz.</p>

<h2>5. Üçüncü Taraf Hizmetler / Third-Party Services</h2>
<ul>
  <li><strong>Anthropic Claude API</strong> — AI yanıtları için. <a href="https://www.anthropic.com/privacy">Anthropic Gizlilik Politikası</a></li>
  <li><strong>Apple App Store / StoreKit</strong> — Satın alma doğrulaması.</li>
  <li><strong>Open-Meteo</strong> — Hava durumu verileri (anonim konum koordinatı).</li>
  <li><strong>ElevenLabs</strong> — Sesli anlatım (TTS); yalnızca AI yanıt metni iletilir.</li>
</ul>

<h2>6. Verinin Yurt Dışına Aktarımı</h2>
<p>AI asistanı kullandığınızda sorunuz, Anthropic'in sunucularına (ABD) iletilir. Bu aktarım, hizmetin sunulabilmesi için zorunludur ve yalnızca bu amaçla gerçekleştirilir.</p>

<h2>7. Yasal Uyarı / Disclaimer</h2>
<p>VisaRadar Travel, yalnızca genel bilgilendirme amaçlıdır; hukuki tavsiye niteliği taşımaz. Seyahat etmeden önce giriş, vize ve kalış koşullarını her zaman resmi hükümet kaynaklarından doğrulayınız.</p>
`);
}

export function supportPage(): Response {
  return page("Destek / Support", `
<h1>VisaRadar Travel — Destek / Support</h1>
<p>Yardıma mı ihtiyacınız var? Memnuniyetle yardımcı oluruz. / Need help? We're happy to assist.</p>

<h2>İletişim / Contact</h2>
<p><a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> adresine e-posta gönderin; cihaz modelinizi ve iOS sürümünüzü belirtin.</p>

<h2>Sık Sorulan Sorular / FAQ</h2>
<ul>
  <li><strong>Otomatik takip nasıl çalışır?</strong> Uygulama, izninizle cihaz konumunuzu kullanarak hangi ülkede/şehirde olduğunuzu tespit eder ve Schengen 90/180 günlük kalışınızı otomatik hesaplar.</li>
  <li><strong>VisaRadar Premium:</strong> AI seyahat asistanı, belge tarayıcı, AI tur rehberi ve border modu içerir. Planlar: Aylık (4,99 USD), Yıllık (34,99 USD, 3 günlük deneme), Ömür boyu (59,99 USD). Ayarlar → Adınız → Abonelikler'den yönetip iptal edebilirsiniz.</li>
  <li><strong>Satın alma geri yükleme:</strong> Premium ekranında "Satın Almaları Geri Yükle" seçeneğine dokunun.</li>
</ul>

<h2>Yasal / Legal</h2>
<p><a href="/privacy">Gizlilik Politikası &amp; KVKK</a> · <a href="/terms">Kullanım Şartları</a></p>
`);
}

export function termsPage(): Response {
  return page("Kullanım Şartları / Terms of Use", `
<h1>Kullanım Şartları (EULA)</h1>
<p><em>End User License Agreement</em></p>
<p>VisaRadar Travel'ı indirerek veya kullanarak bu şartları ve Apple'ın standart
<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Lisanslı Uygulama Son Kullanıcı Lisans Sözleşmesi</a>'ni kabul etmiş olursunuz.</p>

<h2>Abonelikler ve Satın Almalar</h2>
<p>VisaRadar Travel, AI seyahat asistanı, belge tarayıcı, AI tur rehberi ve border modunu açan isteğe bağlı bir <strong>VisaRadar Premium</strong> yükseltmesi sunar:</p>
<ul>
  <li><strong>Aylık Premium</strong> — Otomatik yenilenen abonelik, 1 ay, 4,99 USD (bölgeye göre yerelleştirilmiş fiyat).</li>
  <li><strong>Yıllık Premium</strong> — Otomatik yenilenen abonelik, 1 yıl, 34,99 USD; 3 günlük deneme süresi ile.</li>
  <li><strong>Ömür Boyu Premium</strong> — Tek seferlik satın alma, 59,99 USD (tükenmeyen).</li>
</ul>
<p>Ödeme, satın alma onayında Apple Hesabınıza tahsil edilir. Mevcut dönem sona ermeden en az 24 saat önce iptal edilmediği takdirde otomatik yenilenen abonelikler otomatik olarak yenilenir; hesabınız mevcut dönem sona ermeden 24 saat içinde yenileme için tahsil edilir. Bir abonelik satın aldığınızda ücretsiz denemenin kullanılmamış kısmı iptal edilir. Abonelikleri Apple Hesabı ayarlarınızdan (Ayarlar → Adınız → Abonelikler) yönetebilir veya iptal edebilirsiniz.</p>

<h2>Uygulamanın Kullanımı</h2>
<p>Sağlanan bilgiler yalnızca genel rehberlik içindir ve hukuki tavsiye niteliği taşımaz. Vize, giriş ve kalış koşullarını her zaman resmi hükümet kaynaklarıyla teyit edin. Seyahat kararlarınızdan siz sorumlusunuz.</p>

<h2>Sorumluluk Sınırlandırması</h2>
<p>Uygulama "olduğu gibi" sunulmaktadır. VisaRadar Travel, yanlış veya eksik bilgiden kaynaklanabilecek doğrudan ya da dolaylı zararlardan sorumlu değildir.</p>

<h2>Değişiklikler</h2>
<p>Bu şartlar zaman zaman güncellenebilir. Önemli değişikliklerde uygulama içi bildirim veya e-posta ile bilgilendirme yapılacaktır.</p>

<h2>İletişim / Contact</h2>
<p>Bu şartlarla ilgili sorularınızı aşağıdaki iletişim adresine gönderebilirsiniz.</p>
`);
}
