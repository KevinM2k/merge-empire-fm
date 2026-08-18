// Reference output from the JS i18n runtime.
//
// The interesting behaviour is all in the failure cases: a key missing from the
// active catalog falls back to English, a key missing everywhere renders as
// itself, a param with no placeholder is ignored, and a placeholder with no
// param is left standing. None of them throw, and every one of them is a thing
// a screen will hit.
//
//   node tool/dump_i18n_reference.mjs > test/fixtures/i18n_reference.json

const i18n = await import('../../merge-empire-fc/src/i18n/index.js');

const out = { resolve: [], tName: [], locale: [] };

const resolve = (label, locale, key, params) => {
  i18n.setLocale(locale);
  out.resolve.push({
    label,
    locale,
    key,
    params: params ?? null,
    value: params === undefined ? i18n.t(key) : i18n.t(key, params),
  });
};

resolve('plain', 'en', 'nav.squad');
resolve('plain translated', 'fr', 'nav.squad');
resolve('one param', 'en', 'gems.toast.season', { n: 5 });
resolve('two params', 'en', 'toast.cup_gems', { n: 3, cup: 'The Cup' });
// {s} exists in en and not in es — the extra param must be dropped silently.
resolve('param with no placeholder', 'es', 'event.news.after.missed', { n: 2, s: 's' });
resolve('placeholder with no param', 'en', 'gems.toast.season', {});
resolve('no params at all', 'en', 'gems.toast.season');
resolve('numeric param', 'en', 'gems.toast.tutorial', { n: 10 });
resolve('missing everywhere', 'en', 'no.such.key.anywhere');
resolve('missing everywhere, translated locale', 'ja', 'no.such.key.anywhere');
resolve('unknown locale falls back to en', 'xx', 'nav.squad');
resolve('rtl catalogue', 'ar', 'nav.shop');
resolve('key with a space', 'en', 'event.wc2026.fact.Bosnia and Herzegovina.0');
resolve('key with a diacritic', 'en', 'event.wc2026.fact.Türkiye.0');

i18n.setLocale('en');
out.tName.push({ label: 'by id', value: i18n.tName('nav', 'squad') });
out.tName.push({
  label: 'by object',
  value: i18n.tName('nav', { id: 'squad', name: 'Fallback' }),
});
out.tName.push({
  label: 'unknown id falls back to name',
  value: i18n.tName('nav', { id: 'nope', name: 'Fallback' }),
});
out.tName.push({
  label: 'unknown id, no name, falls back to id',
  value: i18n.tName('nav', 'nope'),
});
out.tName.push({
  label: 'unknown id, object with no name',
  value: i18n.tName('nav', { id: 'nope' }),
});

for (const id of ['en', 'fr', 'ar', 'xx', '']) {
  i18n.setLocale(id);
  out.locale.push({ set: id, got: i18n.getLocale() });
}

out.locales = i18n.LOCALES;

process.stdout.write(JSON.stringify(out, null, 2));
