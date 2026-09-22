// Generic service dashboard.
//
// Project-agnostic: every label, link, logo, row and icon lives in
// dashboard.json, and every scrap of markup lives in template.html /
// styles.css. This file is the renderer only — copy it between projects
// unchanged.
//
// Zero dependencies, Node built-ins only. No build step, no package.json.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, extname, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = fileURLToPath(new URL('.', import.meta.url));
const CONFIG_FILE = join(HERE, 'dashboard.json');
const TEMPLATE_FILE = join(HERE, 'template.html');
const PORT = Number(process.env.DASHBOARD_PORT || 3000);

const MIME = {
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.html': 'text/html; charset=utf-8',
  '.htm': 'text/html; charset=utf-8',
  '.map': 'application/json',
  '.json': 'application/json',
  '.txt': 'text/plain; charset=utf-8',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf',
  '.eot': 'application/vnd.ms-fontobject',
  '.pfx': 'application/x-pkcs12',
  '.p12': 'application/x-pkcs12',
  '.pem': 'application/x-pem-file',
  '.crt': 'application/x-x509-ca-cert',
  '.cer': 'application/x-x509-ca-cert',
};

const ENTITIES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
const esc = (value) => String(value).replace(/[&<>"']/g, (c) => ENTITIES[c]);

// ---------------------------------------------------------------- templates
// template.html is the page shell plus repeating fragments marked with
// <!-- @partial name --> ... <!-- @endpartial -->. Whatever sits outside a
// partial is the shell. Placeholders are {{name}}; unknown ones render empty.

const PARTIAL_RE = /<!--\s*@partial\s+([\w-]+)\s*-->([\s\S]*?)<!--\s*@endpartial\s*-->/g;

function parseTemplate(source) {
  const partials = {};
  const shell = source
    .replace(PARTIAL_RE, (_, name, body) => {
      partials[name] = body.trim();
      return '';
    })
    .trim();
  return { shell, partials };
}

const fill = (template, vars) =>
  String(template ?? '').replace(/\{\{(\w+)\}\}/g, (_, key) => String(vars[key] ?? ''));

// ------------------------------------------------------------------ scoping
// Config strings carry ${ENV_VAR} and {linkField} placeholders. An unresolved
// ${ENV_VAR} marks the string incomplete, which is how a link whose variable
// is unset gets dropped instead of rendering as a dead button.

const PLACEHOLDER_RE = /\$\{(\w+)\}|\{(\w+)\}/g;

function expand(input, config, fields = {}) {
  let complete = true;
  const text = String(input ?? '').replace(PLACEHOLDER_RE, (_, envKey, fieldKey) => {
    const value = envKey
      ? String(process.env[envKey] ?? config.defaults?.[envKey] ?? '').trim()
      : String(fields[fieldKey] ?? '').trim();
    if (!value) complete = false;
    return value;
  });
  return { text, complete };
}

// Loose expansion for decorative text: blanks are fine, nothing is dropped.
const soft = (input, config, fields) => expand(input, config, fields).text;

// Strict expansion for hrefs: null means "a variable was missing, drop this".
const hard = (input, config, fields) => {
  const { text, complete } = expand(input, config, fields);
  return complete && text ? text : null;
};

// -------------------------------------------------------------------- icons
// Icon values come from config or from .env (e.g. GIT_REPO_ICON="fa-git").
// Font Awesome 6 needs a style class alongside the name, and our values do not
// always carry one, so brand names are inferred from config.brandIcons.

function renderIcon(raw, config, partials) {
  const tokens = String(raw ?? '').trim().split(/\s+/).filter(Boolean);
  const found = tokens.find((token) => token.startsWith('fa-') && token.length > 3);
  if (!found) return '';
  // config.iconAliases remaps names the icon set does not ship, so a value like
  // fa-adobe (Pro only) renders something instead of an invisible empty box.
  const name = config.iconAliases?.[found] ?? found;
  const brands = new Set(config.brandIcons ?? []);
  const isBrand =
    (tokens.includes('fab') || tokens.includes('fa-brands') || brands.has(found.slice(3))) &&
    brands.has(name.slice(3));
  return fill(partials.icon, {
    style: isBrand ? 'fa-brands' : 'fa-solid',
    name: esc(name),
  });
}

// -------------------------------------------------------------------- logos
// A row's `logo` may be a bare filename in public/logos ("site.png"), a path
// relative to the document root ("logos/foo.svg", as ELASTIC_IMAGE_SRC gives
// it), an absolute path, or a full URL. Normalise all four to one src.

function logoSrc(value) {
  const src = String(value ?? '').trim();
  if (!src) return '';
  if (/^(https?:)?\/\//.test(src) || src.startsWith('data:') || src.startsWith('/')) return src;
  return src.includes('/') ? `/${src}` : `/logos/${src}`;
}

// --------------------------------------------------------------- link lists
// An .env list is "<field>|<field>|...", entries separated by a comma. The
// field names, and therefore what {placeholders} a row's href may use, come
// from config.lists.fields.

function readList(key, config) {
  const { delimiter = '|', separator = ',', fields = [] } = config.lists ?? {};
  return String(process.env[key] ?? '')
    .split(separator)
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const parts = entry.split(delimiter).map((part) => part.trim());
      return Object.fromEntries(fields.map((field, index) => [field, parts[index] ?? '']));
    });
}

// ----------------------------------------------------------------- renderer

function renderButton(spec, config, partials, fields = {}) {
  const href = hard(spec.href, config, fields);
  if (!href) return '';
  const label = soft(spec.label, config, fields) || href;
  const shape = spec.download === true ? partials.download : partials.button;
  return fill(shape, {
    href: esc(href),
    label: esc(label),
    kind: esc(spec.kind ?? 'primary'),
    icon: renderIcon(soft(spec.icon, config, fields), config, partials),
  });
}

function renderGroup(spec, config, partials) {
  const entries = readList(spec.source, config);
  const buttons = entries
    .map((fields) =>
      renderButton(
        { href: spec.href, label: spec.label_field ? `{${spec.label_field}}` : '{title}', kind: spec.kind ?? 'accent', icon: spec.icon ?? '{icon}' },
        config,
        partials,
        fields,
      ),
    )
    .join('');
  if (!buttons) return '';
  return fill(partials.group, { label: esc(soft(spec.label, config)), buttons });
}

function renderPorts(specs, config, partials) {
  return (specs ?? [])
    .map((spec) => {
      if (typeof spec === 'string') {
        const label = hard(spec, config);
        return label ? esc(label) : '';
      }
      const label = hard(spec.label, config);
      if (!label) return '';
      const href = hard(spec.href, config);
      return href
        ? fill(partials.port, { href: esc(href), label: esc(label) })
        : esc(label);
    })
    .filter(Boolean)
    .join(', ');
}

function renderRow(spec, config, partials) {
  const body =
    (spec.buttons ?? []).map((b) => renderButton(b, config, partials)).join('') +
    (spec.groups ?? []).map((g) => renderGroup(g, config, partials)).join('');

  return fill(partials.row, {
    icon: spec.logo
      ? fill(partials.logo, { src: esc(logoSrc(soft(spec.logo, config))) })
      : renderIcon(spec.glyph, config, partials),
    name: esc(soft(spec.name, config)),
    desc: esc(soft(spec.desc, config)),
    body: body || partials.empty || '',
    ports: renderPorts(spec.ports, config, partials),
  });
}

function renderPage(config, template) {
  const { shell, partials } = template;
  const page = config.page ?? {};
  return fill(shell, {
    title: esc(soft(page.title, config)),
    subtitle: esc(soft(page.subtitle, config)),
    logo: page.logo ? fill(partials.logo, { src: esc(logoSrc(soft(page.logo, config))) }) : '',
    rows: (config.rows ?? []).map((row) => renderRow(row, config, partials)).join(''),
    generated: new Date().toISOString(),
  });
}

// Read config and template per request: both are tiny, and it means editing
// dashboard.json or template.html needs no container restart.
async function load() {
  const [configRaw, templateRaw] = await Promise.all([
    readFile(CONFIG_FILE, 'utf8'),
    readFile(TEMPLATE_FILE, 'utf8'),
  ]);
  return { config: JSON.parse(configRaw), template: parseTemplate(templateRaw) };
}

// ------------------------------------------------------------ static mounts
// config.static maps a URL prefix to a directory. `dir` is resolved relative
// to this folder unless absolute. An `allow` list restricts a mount to exactly
// those filenames — used for the certs mount, whose directory also holds
// private keys that must never be served. `download` sends the file as an
// attachment rather than letting the browser try to display it. `cache` sets
// the mount's Cache-Control; without it a mount is served no-store, so an
// edited asset shows up on the next reload instead of an hour later.

function mounts(config) {
  return (config.static ?? [])
    .map((mount) => {
      const dir = hard(mount.dir, config);
      if (!dir) return null;
      return {
        prefix: mount.prefix ?? '/',
        root: normalize(dir.startsWith('/') || /^[A-Za-z]:/.test(dir) ? dir : join(HERE, dir)),
        allow: mount.allow ?? null,
        download: mount.download === true,
        cache: mount.cache ?? null,
      };
    })
    .filter(Boolean);
}

async function serveStatic(pathname, config, res) {
  const decoded = decodeURIComponent(pathname);
  const mount = mounts(config).find((m) => decoded.startsWith(m.prefix));

  if (mount) {
    const rel = normalize(decoded.slice(mount.prefix.length)).replace(/^([/\\.]+)/, '');
    const file = join(mount.root, rel);
    const name = rel.split(/[/\\]/).pop();

    // startsWith on its own would let /app/publicX through a /app/public
    // mount, so the match has to land on a separator (or be the root itself).
    const inside = file === mount.root || file.startsWith(mount.root + sep);

    if (inside && (!mount.allow || mount.allow.includes(name))) {
      try {
        const body = await readFile(file);
        const headers = {
          'content-type': MIME[extname(file).toLowerCase()] || 'application/octet-stream',
          'cache-control': mount.download ? 'no-store' : mount.cache ?? 'no-store',
        };
        if (mount.download) headers['content-disposition'] = `attachment; filename="${name}"`;
        res.writeHead(200, headers).end(body);
        return;
      } catch {
        /* fall through to 404 */
      }
    }
  }

  res.writeHead(404, { 'content-type': 'text/plain' }).end('Not found');
}

// -------------------------------------------------------------------- server

createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://dashboard');

  if (pathname === '/healthz') {
    res.writeHead(200, { 'content-type': 'application/json' }).end('{"status":"ok"}');
    return;
  }

  try {
    const { config, template } = await load();

    if (pathname === '/' || pathname === '/index.html') {
      res.writeHead(200, {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store',
      }).end(renderPage(config, template));
      return;
    }

    await serveStatic(pathname, config, res);
  } catch (error) {
    console.error('request failed:', error);
    res.writeHead(500, { 'content-type': 'text/plain' }).end(`Dashboard config error:\n${error.message}\n`);
  }
}).listen(PORT, '0.0.0.0', () => {
  console.log(`dashboard listening on http://0.0.0.0:${PORT}`);
});
