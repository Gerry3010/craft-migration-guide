# Craft 5 to Craft 6: pitfalls and findings

Written against Craft CMS 6.0.0-beta.1, craftcms/yii2-adapter 6.0.0-beta.1,
craftcms/ckeditor 6.0.0-beta.1 and craftcms/craft6-revamp 1.3.3, on PHP 8.5
and MariaDB 11.8. The site was a Craft 5.10 portfolio with a Matrix content
builder, CKEditor, Link fields, two local asset filesystems, one global set,
two custom Yii modules and a handful of content migrations.

The official upgrade guide explains the intended path. This file covers what
it doesn't say, or says in a place that is easy to miss. Each entry describes
what you see, why it happens and what fixed it.

## Before the upgrade

### Requirements moved

Craft 6 needs PHP 8.5, MySQL 8.0.17+ (or MariaDB 10.4.6+, or PostgreSQL 13+)
and Composer 2. Under the hood it is a Laravel 13 application. If your host
or Docker image is still on PHP 8.3 or 8.4, that is the first thing to change.

### Get to the latest 5.x first

The revamp tool expects the newest Craft 5 release. Update, run `craft up`,
and commit that state on its own. If something goes wrong later, you want to
know whether it came from 5.x or from 6.

### Plugins

Check every plugin's `composer.json` for a `craftcms/cms` constraint that
allows `^6`. On this site only CKEditor had a 6.0 beta release; the other
two plugins required `^5.0.0`. Such a plugin blocks `composer update`
entirely, so remove it on the
upgrade branch (and keep a note of what it did). Porting your own plugin
means requiring `craftcms/yii2-adapter`, bumping the constraint and fixing
the changed signatures in `craft\base\Plugin`.

Craft 6 ships features that used to need plugins, among them a dark mode for
the control panel and a built-in MCP server (off by default). Check whether
you still need the plugin before you port it.

### Global sets, categories and tags

Craft 6 keeps global sets, categories and tags only as legacy elements that
run through the yii2-adapter. Convert them to entries while you are still on
Craft 5:

```bash
php craft entrify/global-set footer
```

The command is interactive. Run without a terminal it failed with "Entry Type
cannot be blank" and "--section option is required", so run it in a real
shell and answer the prompts. The element ID, content, slug and relations stay the same; only
the title changes, because the new entry gets one. With `preloadSingles`
enabled, the new Single is available under the same Twig variable name the
global set had, so templates keep working.

Every other environment needs the same conversion after you deploy the
project config change.

## Running the revamp tool

```bash
composer global require craftcms/craft6-revamp
"$(composer global config bin-dir --absolute)/craft6-revamp" /path/to/project
```

It uses Laravel Prompts and asks questions as it goes, so it needs an
interactive terminal. It moves `web/` to `public/`, `templates/` to
`resources/views/` and `config/` to `config/craft/`, adds `artisan` and
`bootstrap/app.php`, renames `CRAFT_DB_*` variables to Laravel's `DB_*`, and
adds `craftcms/yii2-adapter` so Yii modules and plugins keep loading.

It does not touch your front-end build. Fix these by hand:

- CSS and JS output paths (`web/assets` becomes `public/assets`)
- Tailwind `content` globs that point at `templates/`
- `.gitignore` entries for build output and for `/public/vendor`
- deploy scripts and CI that copy `web/` or `templates/`

With DDEV, switch the project type to `laravel`. DDEV then manages `.env`
itself and rewrites values you edited by hand; put overrides in
`.ddev/.env.web` instead.

## Database migrations

Run `php artisan craft:up`. Always start from a fresh copy of the
pre-upgrade database. If a migration fails halfway, restore the snapshot and
run the whole upgrade again rather than continuing from a half-migrated
state.

### `remove_craft_filesystems` fails

Craft 6 replaces Craft filesystems with Laravel disks. The migration stops
unless `config/filesystems.php` defines a disk for every filesystem handle
you had in Craft 5. The array key has to be the old handle:

```php
'disks' => [
    'uploads' => [
        'driver' => 'local',
        'root' => public_path('uploads'),
        'url' => rtrim((string) env('APP_URL'), '/').'/uploads',
        'visibility' => 'public',
        'throw' => false,
        'report' => false,
    ],
],
```

### `add_image_type_column_to_assets` fails on MariaDB

With `DB_CONNECTION=mysql` against MariaDB, Laravel builds the JSON operator
`->>`, which MariaDB doesn't support, and the migration aborts with a syntax
error. Set `DB_CONNECTION=mariadb`, restore the snapshot and start over.

### What changes in the data on purpose

Diff your counts before and after (`scripts/counts.sql`) and expect these:

- Element type class names change, e.g. `craft\elements\Entry` becomes
  `CraftCms\Cms\Entry\Elements\Entry`. Raw SQL that filters on
  `elements.type` needs updating.
- Relation rows of Link fields are deleted. The link targets stay in the
  field content. The new `fieldreferences` table fills when an element is
  saved again, so it is empty right after the upgrade.
- Asset alt text moves into `assets_sites.alt`. Count the rows to make sure
  none went missing.
- The `restrictFiles` and `allowedKinds` settings of Assets fields become a
  file type condition rule. The project config diff shows the old keys as
  removed; that is expected.
- The queue moves to Laravel's `jobs` table and the old queue table is
  rebuilt. Let the Craft 5 queue run empty before you take the dump.

### Content migrations live somewhere else

Craft 6 reads content migrations from `database/migrations`. The old
`migrations/` folder is ignored completely: `craft:up` reports "No new
migrations found" even with an unapplied Craft 5 migration sitting there.
Migrations that already ran on Craft 5 are not affected.

A Craft 5 style migration (`craft\db\Migration`, `craft\elements\Entry`,
`Craft::$app->getElements()`) still runs through the adapter if you invoke
it by hand. `craft:exec:exec` takes a single statement, so put the calls in
a file and evaluate that:

```php
// /tmp/run-migration.php (no opening <?php tag)
require '/app/migrations/m261111_000001_example.php';
var_dump((new \craft\contentmigrations\m261111_000001_example())->up());
```

```bash
php artisan craft:exec:exec 'eval(file_get_contents("/tmp/run-migration.php"))'
```

It prints `bool(true)` when `safeUp()` succeeded.

For anything new, write a Laravel-style migration in `database/migrations`.

Two related traps: `laravel/tinker` is not installed, so use
`craft:exec:exec` for one-off PHP. The Yii-based `craft:migrate:new` command
failed on MariaDB at beta.1 because it sends the SQLite statement
`PRAGMA table_info(...)`.

## Templates

### Element queries are no longer iterable

In Craft 6 an element query is a Laravel query builder and Twig can't loop
over it. `{% for row in entry.matrixField %}` renders
nothing, with no error and no deprecation warning, while
`entry.matrixField|length` still returns the right number. On this site the
whole footer, built from three nested-entry fields, disappeared.

Append `.all()`:

```twig
{% for row in entry.matrixField.all() %}
```

`scripts/find-query-loops.py` reads the query-type field handles from the
project config and lists every loop that iterates one of them without a
fetch method. Loops over a variable that holds a query
(`{% set rows = entry.matrixField %}`) are not traced; check those by hand.

### Deprecations worth fixing right away

- `orderBy('postDate desc')` becomes `orderBy('postDate', 'desc')`.
- `asset.url(transform)` becomes `asset.transform(transform).url`.

### Markdown is CommonMark now

The `markdown` filter follows CommonMark. A `<br>` at the start of a line,
followed by Markdown, opens an HTML block, and everything up to the next
blank line is printed as raw Markdown. Adding a blank line after the `<br>`
fixed it:

```twig
{{ text|replace({"<br>\n": "<br>\n\n"})|markdown }}
```

### MIME types

Craft 6 reports MP4 files as `application/mp4`. Browsers won't play a
`<source type="application/mp4">`. Map it to `video/mp4` where you print the
type.

### Image transforms

Transform URLs point at `/actions/assets/generate-transform?transformId=N`
until the transform exists, and generated files land under a new path
inside the volume. HTML snapshots will differ in every image URL; mask them
when you compare. Transforms are generated by the queue, so they stay
missing until a worker runs.

### Forms and CSRF

The CSRF field is Laravel's `_token`. `{{ csrfInput() }}` handles that for
you. JavaScript that reads or posts `CRAFT_CSRF_TOKEN` by name gets a 419.

## Configuration

`config/general.php` is now `config/craft/general.php`.

- `enableTwigSandbox` and `omitScriptNameInUrls` no longer exist; remove
  them.
- `runQueueAutomatically` still exists. A middleware injects the queue
  runner into HTML responses when it is on.
- The `@webroot` alias should point at `public_path()`.
- `CRAFT_*` environment overrides such as `CRAFT_ALLOW_ADMIN_CHANGES` still
  work.
- Set `APP_NAME`. Laravel's default is "Laravel".

### Mail

Mail goes through Laravel's mail manager. `MAIL_MAILER` and the other
`MAIL_*` variables win; Craft's own email settings are only a fallback. A
Yii `mailer` component in `config/craft/app.php` is ignored.

### Behind a reverse proxy

Laravel doesn't trust `X-Forwarded-*` headers by default. Behind nginx or a
load balancer that terminates TLS it builds `http://` URLs. Trust the proxy
in `bootstrap/app.php`:

```php
->withMiddleware(function (Middleware $middleware): void {
    if ($proxies = env('TRUSTED_PROXIES')) {
        $middleware->trustProxies(at: $proxies === '*' ? '*' : explode(',', $proxies));
    }
})
```

Session cookies are marked secure when `APP_URL` is https. Testing forms
over plain http (a container port, `curl` without TLS) then fails with 419
because the browser or client never sends the cookie back.

## Running it in production

The `examples/docker` folder has a full stack. These are the parts that
were not obvious.

### Plugin assets need the database

`craft:setup:publish` (also run by `composer install` through
`post-autoload-dump`) only publishes plugin assets when Craft sees an
installed database. In a Docker build there is no database, so the
CKEditor build is missing and `/admin/login` returns 500 with "Vite manifest
not found at: .../public/vendor/craftcms/ckeditor/build/manifest.json".
Run `php artisan craft:setup:publish` again once the database is up. The
example compose file does it in a one-shot `publish` service that writes
into a volume the web server reads.

### A queue worker is mandatory

Mails and image transforms go through the Laravel queue. Without
`php artisan queue:work` they sit in the `jobs` table. On an empty
database the worker restarts in a loop, because the adapter checks the
migrations table on boot, so import the database before you start it.

### Image and PHP extensions

On Alpine, `icu-libs` brings only English ICU data. `intl` then formats
German dates with English month names. Install `icu-data-full`. If the site
generates WebP transforms, GD needs `--with-webp`, or the images come out
empty.

### Deploying with rsync

Two traps that hit this migration and apply to any rsync deploy of a
Craft 6 tree:

- An exclude without a leading slash matches at every level.
  `--exclude=vendor` also skips `public/assets/vendor`. Anchor the patterns:
  `--exclude=/vendor --exclude=/public/vendor`.
- If CSS or JS output is gitignored and you deploy with `--delete`, build
  before you sync. Otherwise the deploy deletes the compiled assets on the
  server.

Run `rsync --dry-run --itemize-changes` first and read the `*deleting`
lines.

### robots.txt

Craft can render `robots.txt` from a template, but DDEV's default nginx
config serves `/robots.txt` as a static file and returns 404 when there is
none. Route it to `index.php` when the file doesn't exist, as the example
nginx config does.

## The built-in MCP server

Craft 6 ships an MCP server. At beta.1 it has 50 tools: elements, drafts,
revisions, project config, caches, queue, user permissions, maintenance mode,
search and agent skills. If a Craft 5 MCP plugin did the same job, check
whether you still need it.

The HTTP server is off by default. It is switched on in the project config
(`mcp.enabled`, under Settings, Extend, MCP in the control panel). Without
public user registration the endpoint defaults to `/{cpTrigger}/mcp`, so
`/admin/mcp` on most sites. It authenticates through OAuth (Laravel
Passport): the MCP client registers and the user approves it in the control
panel. Personal access tokens can't be given MCP scopes.

The stdio server needs none of that and works with the HTTP server switched
off:

```bash
php artisan craft:mcp:serve --user=1
```

It acts as the given user (ID, username or email) without authenticating,
because whoever can run the command can already read the database. Over SSH
that gives an agent access to a remote instance without opening an HTTP
endpoint, which is handy for a staging site behind Basic-Auth, where the
OAuth flow would need exceptions in the proxy:

```bash
claude mcp add craft-staging -- ssh -T -o BatchMode=yes deploy@example.com \
  'cd /srv/site && docker compose exec -T -u www-data app php artisan craft:mcp:serve --user=1'
```

## How the upgrade was verified

The whole path ran twice from the same pre-upgrade snapshot with identical
results. Each run went through these checks:

1. `counts.sql` before and after: entries per section, nested entries per
   field, assets, alt texts, users, relations.
2. `element-diff.sql` against the untouched baseline database: no canonical
   element lost, title, slug, URI and content unchanged.
3. `compare-project-config.py` on the old and new project config: no
   section, entry type, field or volume gone, no field removed from a
   layout.
4. `public-uris.sql` plus `snapshot.sh` on Craft 5 and Craft 6, then
   `compare-html.sh`: every page renders, and each remaining difference
   has an explanation.
5. Forms submitted end to end, mails checked in Mailpit, queue drained.

The silent template failures (empty Matrix loops, raw Markdown) only showed
up in step 4. Counting rows does not catch them.
