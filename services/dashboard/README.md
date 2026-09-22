# Dashboard

Local landing page listing every service in the stack.

| File | Role | Project-specific? |
| --- | --- | --- |
| `dashboard.json` | All config: page title, rows, links, logos, icons, ports | **Yes** — this is the only file you edit |
| `template.html` | Page shell + repeating fragments | No |
| `server.mjs` | Renderer | No — copy between projects unchanged |
| `public/` | `styles.css`, `favicon.ico`, `logos/` — served as static files | logos only |
| `public/vendor/` | Vendored Font Awesome 6 Free (CSS + woff2) | No |

## Static mounts

`static` in `dashboard.json` maps a URL prefix to a directory; first matching
prefix wins, so put `/` last. `dir` is relative to the service folder unless
absolute.

    "static": [
      { "prefix": "/certs/", "dir": "${DASHBOARD_CERTS_DIR}",
        "allow": ["mkcert.pfx", "rootCA.pem"], "download": true },
      { "prefix": "/vendor/", "dir": "public/vendor",
        "cache": "public, max-age=31536000, immutable" },
      { "prefix": "/", "dir": "public" }
    ]

- `allow` — serve **only** these filenames. The certs directory also holds
  `mkcert.key` and `rootCA-key.pem`; without the whitelist those private keys
  would be downloadable. Do not remove it.
- `download` — sends `Content-Disposition: attachment` and renders the button
  with the `download` partial instead of `button`.
- `cache` — the mount's `Cache-Control`. Without it a mount is served
  `no-store`, so an edited stylesheet or logo shows on the next reload instead
  of an hour later. Only `/vendor/` sets a long cache, because its contents are
  a pinned Font Awesome release.
- A mount whose `dir` has an unresolved `${VAR}` is skipped, and its links then
  404 rather than breaking the page.

Compose bind-mounts the Traefik certs read-only at `/app/certs`
(`${CERTS_HOST_PATH}`), which is why `DASHBOARD_CERTS_DIR` is `certs`. To run
outside Docker, set `DASHBOARD_CERTS_DIR=../traefik/certs`.

No build step, no `package.json`, no `node_modules`, no Ruby.

`dashboard.json`, `template.html` and `styles.css` are read per request, so
editing those shows on the next refresh. **`server.mjs` is only read at process
start** — after changing it, `docker compose restart dashboard`. Editing it
without restarting can leave a stale renderer against new templates, which
shows up as empty `src=""` images or missing fragments.

## dashboard.json

    {
      "page":     { "title": "${DASHBOARD_TITLE}", "subtitle": "...", "logo": "site.png" },
      "defaults": { "DASHBOARD_TITLE": "AEM Project Services" },
      "lists":    { "delimiter": "|", "separator": ",",
                    "fields": ["path", "title", "icon", "sub"] },
      "brandIcons": ["adobe", "git", "..."],
      "iconAliases": { "fa-adobe": "fa-cloud" },
      "rows": [ ... ]
    }

- `defaults` — fallback for any `${VAR}` not set in the environment.
- `lists` — how the `.env` link lists are split, and what `{field}` names a row
  may use in an `href`.
- `brandIcons` — icon names that need Font Awesome's `fa-brands` style rather
  than `fa-solid`. Values like `GIT_REPO_ICON="fa-git"` carry no style class, so
  it is inferred from this list.
- `iconAliases` — remaps icon names the free set does not ship. `fa-adobe` is
  Font Awesome **Pro** only, so every `fa-adobe` in `.env` rendered an invisible
  empty box; it is aliased to `fa-solid fa-cloud`. Add an entry here rather than
  editing `.env` when an icon comes up blank.

### A row

    {
      "name": "Author",
      "logo": "aem-design.png",          // or "glyph": "fa-globe" for an icon
      "desc": "Local AEM author",
      "buttons": [
        { "label": "Open", "icon": "fa-arrow-up-right-from-square",
          "href": "${AUTHOR_URL}" },
        { "label": "CRX", "kind": "secondary", "href": "${AUTHOR_URL}/crx/de" }
      ],
      "groups": [
        { "label": "Pages", "source": "PAGE_LINKS",
          "href": "${AUTHOR_URL}{path}?wcmmode=disabled" }
      ],
      "ports": [
        { "label": "${AUTHOR_PORT}", "href": "${LOCALHOST_URL}:${AUTHOR_PORT}" },
        "${AUTHOR_DEBUG_PORT}"
      ]
    }

- `${VAR}` reads the environment (then `defaults`); `{field}` reads a field of
  the current link-list entry.
- `kind` is `primary` (default), `secondary` or `accent`.
- **An `href` with an unresolved `${VAR}` drops that button or group entirely** —
  that is how an unset variable avoids rendering as a dead button.
- `groups` pull their entries from an `.env` list named by `source`, and take
  each entry's own icon unless the group sets `"icon"`.

## template.html

The page shell, plus fragments marked `<!-- @partial name -->` …
`<!-- @endpartial -->`: `row`, `button`, `download`, `group`, `icon`, `logo`,
`port`, `empty`. Placeholders are `{{name}}`; unknown ones render empty.
Anything outside a partial is the shell.

Font Awesome **Free** 6.5.2 is vendored under `public/vendor/fontawesome`
(CSS plus the solid, regular, brands and v4-compat woff2 files, ~430 KB) and
served from `/vendor/`, so the stack renders with no network at all. It used to
load from cdnjs, which meant no icons offline or behind a restrictive proxy.
(The original page used Font Awesome *Pro*, which was never licensed, so no
icon ever rendered.) Labels are always text, so a missing icon costs polish,
not usability.

To bump the version, replace the files under `public/vendor/fontawesome` from
the `@fortawesome/fontawesome-free` npm tarball and keep the `../webfonts/`
relative paths in `all.min.css`.

## Theme

A `System / Light / Dark` toggle sits top right. The choice is kept in
`localStorage` under `dashboard-theme`; `System` clears the key and hands
control back to `prefers-color-scheme`, so the OS setting never overrides an
explicit pick. An inline script in `<head>` applies the saved theme before
first paint, so a dark-mode user gets no white flash. With JavaScript off the
toggle is hidden and the `prefers-color-scheme` block in `styles.css` still
tracks the OS.

Colour tokens live at the top of `styles.css`. `#0083be` and `#fdb000` are the
brand colours; `#0083be` is specified as a non-text colour, so the button and
link shade is darkened in light mode (`#00719f`) and lightened with dark text
in dark mode (`#5cb8e2`) to clear WCAG AA 4.5:1 at the size the buttons use.
Third-party logos are near-black on transparent, so on a dark table they get a
light pad rather than an invert, which would wreck the brand colours.

## Run

    docker compose up -d dashboard

Or directly: set `DASHBOARD_PORT` and the URL variables in your shell, then
`node services\dashboard\server.mjs`.

`GET /healthz` returns `{"status":"ok"}`. A malformed `dashboard.json` returns
500 with the parse error rather than a blank page.
