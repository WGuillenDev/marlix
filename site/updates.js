// Live list of releases from GitHub. Everything from the API is untrusted: it is only
// ever written with textContent, and links are kept only if they point at this repository.
(() => {
  const REPO = 'WGuillenDev/marlix';
  const API = `https://api.github.com/repos/${REPO}/releases?per_page=10`;
  const PAGE_PREFIX = `https://github.com/${REPO}/releases/`;
  const DOWNLOAD_PREFIX = `https://github.com/${REPO}/releases/download/`;
  const CACHE_KEY = 'marlix-releases';
  const CACHE_MS = 10 * 60 * 1000;

  const list = document.getElementById('releases');
  const badges = document.querySelectorAll('[data-latest]');
  if (!list && badges.length === 0) return;

  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  const safeLink = (url, prefix, label, className) => {
    if (typeof url !== 'string' || !url.startsWith(prefix)) return null;
    const a = el('a', className, label);
    a.href = url;
    a.rel = 'noopener noreferrer';
    return a;
  };

  const formatDate = (iso) => {
    const date = new Date(iso);
    return Number.isNaN(date.getTime())
      ? ''
      : date.toLocaleDateString('es-CR', { year: 'numeric', month: 'long', day: 'numeric' });
  };

  const formatSize = (bytes) => (Number.isFinite(bytes) ? `${(bytes / 1048576).toFixed(0)} MB` : '');

  const apkOf = (release) =>
    (Array.isArray(release.assets) ? release.assets : []).find((a) => typeof a.name === 'string' && a.name.endsWith('.apk'));

  const notes = (body) => {
    const box = el('div', 'notes');
    const lines = String(body || '')
      .replace(/\r/g, '')
      .split('\n')
      .map((line) => line.replace(/^#+\s*/, '').replace(/[*_`]/g, '').trim())
      .filter(Boolean)
      .slice(0, 12);
    if (lines.length === 0) return box;
    box.appendChild(el('p', '', lines[0]));
    if (lines.length === 1) return box;

    const more = el('details');
    more.appendChild(el('summary', '', 'Ver las notas completas'));
    let ul = null;
    for (const line of lines.slice(1)) {
      if (/^[-•]\s+/.test(line)) {
        if (!ul) { ul = el('ul'); more.appendChild(ul); }
        ul.appendChild(el('li', '', line.replace(/^[-•]\s+/, '')));
      } else {
        ul = null;
        more.appendChild(el('p', '', line));
      }
    }
    box.appendChild(more);
    return box;
  };

  const renderBadges = (latest) => {
    badges.forEach((badge) => {
      badge.textContent = '';
      if (!latest) {
        badge.appendChild(el('span', '', 'Todavía no hay una versión publicada.'));
        return;
      }
      badge.appendChild(el('span', 'tag', latest.tag_name));
      const link = safeLink(latest.html_url, PAGE_PREFIX, 'Ver novedades', '');
      if (link) badge.appendChild(link);
    });
  };

  const renderReleases = (releases) => {
    if (!list) return;
    list.textContent = '';
    if (releases.length === 0) {
      list.appendChild(el('p', 'muted', 'Todavía no hay versiones publicadas.'));
      return;
    }
    releases.forEach((release, index) => {
      const card = el('article', 'card release');
      const head = el('div', 'release-head');
      head.appendChild(el('h3', '', String(release.name || release.tag_name)));
      if (index === 0) head.appendChild(el('span', 'tag latest', 'Más reciente'));
      if (release.prerelease) head.appendChild(el('span', 'tag', 'Prueba'));
      card.appendChild(head);
      const date = formatDate(release.published_at);
      if (date) card.appendChild(el('p', 'muted', `Publicada el ${date}`));
      card.appendChild(notes(release.body));

      const actions = el('div', 'buttons left');
      const apk = apkOf(release);
      if (apk) {
        const size = formatSize(apk.size);
        const download = safeLink(apk.browser_download_url, DOWNLOAD_PREFIX, `Descargar APK${size ? ` (${size})` : ''}`, 'btn primary');
        if (download) actions.appendChild(download);
      }
      const page = safeLink(release.html_url, PAGE_PREFIX, 'Ver en GitHub', 'btn ghost');
      if (page) actions.appendChild(page);
      card.appendChild(actions);
      list.appendChild(card);
    });
  };

  const fail = () => {
    badges.forEach((badge) => {
      badge.textContent = '';
      badge.appendChild(el('span', '', 'No se pudo consultar las versiones.'));
    });
    if (!list) return;
    list.textContent = '';
    const card = el('div', 'card');
    card.appendChild(el('p', '', 'No se pudieron cargar las versiones en este momento. Puedes verlas directamente en GitHub.'));
    const link = safeLink(PAGE_PREFIX.replace(/\/$/, ''), PAGE_PREFIX.replace(/\/$/, ''), 'Abrir las versiones en GitHub', 'btn primary');
    if (link) card.appendChild(link);
    list.appendChild(card);
  };

  const show = (releases) => {
    const published = releases.filter((r) => r && !r.draft);
    renderBadges(published.find((r) => !r.prerelease) || null);
    renderReleases(published);
  };

  const read = () => {
    try {
      const cached = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null');
      if (cached && Date.now() - cached.at < CACHE_MS && Array.isArray(cached.releases)) return cached.releases;
    } catch { /* storage unavailable */ }
    return null;
  };

  const cached = read();
  if (cached) { show(cached); return; }

  fetch(API, { headers: { Accept: 'application/vnd.github+json' }, referrerPolicy: 'no-referrer' })
    .then((response) => {
      if (!response.ok) throw new Error(String(response.status));
      return response.json();
    })
    .then((releases) => {
      if (!Array.isArray(releases)) throw new Error('unexpected response');
      try { sessionStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), releases })); } catch { /* ignore */ }
      show(releases);
    })
    .catch(fail);
})();
