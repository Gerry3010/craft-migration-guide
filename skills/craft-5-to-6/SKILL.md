---
name: craft-5-to-6
description: Upgrade a Craft CMS 5 project to Craft 6 (the Laravel-based release) without losing content. Use when asked to move a Craft 5 site to Craft 6 or the 6.0 beta, to run craftcms/craft6-revamp, or to debug a Craft 6 upgrade (empty Matrix loops, failing craft:up migrations, 500 on the control panel login, 419 on forms).
---

# Craft 5 to Craft 6

Craft 6 rebuilds Craft on Laravel. The official tool `craftcms/craft6-revamp`
moves the project into the Laravel layout, and `php artisan craft:up` migrates
the database. Most of the risk sits in the parts neither of them reports:
templates that silently render nothing, data the migrations change on purpose,
and a production setup that needs new pieces.

Read `GUIDE.md` in this folder before you start. It explains every pitfall
listed below with symptoms and fixes. The scripts in `scripts/` do the
before/after comparison.

## Ground rules

- Work on a branch. Never upgrade a production database in place; test
  against a fresh copy of it.
- Treat the production database as read-only. Take dumps, don't write.
- Keep an untouched copy of the pre-upgrade dump. If any migration fails,
  restore it and run the whole upgrade again from the start.
- Ask the owner before removing plugins, converting global sets, or changing
  anything the live site shares.

## Procedure

### 1. Inventory on Craft 5

1. Check requirements: PHP 8.5, MySQL 8.0.17+ / MariaDB 10.4.6+ /
   PostgreSQL 13+, Composer 2.
2. List plugins and check each for a `craftcms/cms` constraint that allows
   `^6`. Report the ones that don't and let the owner decide.
3. Update to the latest Craft 5 release, run `php craft up`, commit.
4. Let the queue run empty, then take a database dump and keep a copy of
   `config/project`.
5. Record the baseline:
   - `mysql -N <db> < scripts/counts.sql > counts-before.txt`
   - `mysql -N <db> < scripts/public-uris.sql > uris.txt`, add non-entry
     routes by hand
   - `scripts/snapshot.sh <base-url> uris.txt snap-before`

### 2. Convert legacy elements (still on Craft 5)

Global sets, categories and tags only survive as adapter-backed legacy
elements. With the owner's agreement, convert them:
`php craft entrify/global-set <handle>` (and `entrify/categories`,
`entrify/tags`). The command is interactive; run it in a terminal the owner
can see. With `preloadSingles` on, Twig variables keep their names. Re-run
the snapshot and compare before going further.

### 3. Revamp and update

1. Run `craft6-revamp <project-dir>` interactively (it uses Laravel
   Prompts).
2. Fix what it leaves alone: front-end build output paths, Tailwind content
   globs, `.gitignore` (`/public/vendor`, build output), deploy scripts.
3. Add a disk to `config/filesystems.php` for every Craft 5 filesystem
   handle, keyed by that handle.
4. On MariaDB set `DB_CONNECTION=mariadb`.
5. `composer update -W`, then `php artisan craft:up`.

### 4. Fix templates

1. Run `scripts/find-query-loops.py config/craft/project resources/views` and
   add `.all()` to every reported loop. Check `{% set x = entry.field %}`
   variables that are looped later by hand.
2. Replace `orderBy('x desc')` with `orderBy('x', 'desc')` and
   `asset.url(transform)` with `asset.transform(transform).url`.
3. Look for `|markdown` on text that starts lines with HTML, `mimeType`
   printed into `<source type>`, and JavaScript that posts
   `CRAFT_CSRF_TOKEN`. See GUIDE.md for each.

### 5. Verify

1. `counts.sql` again and diff. Expected differences: element type class
   names, fewer `relations` rows (Link fields), alt text now in
   `assets_sites`. Anything else is a finding.
2. Import the pre-upgrade dump as a second database `baseline` and run
   `scripts/element-diff.sql`. Every result set must be empty.
3. `php artisan craft:pc:write`, then
   `scripts/compare-project-config.py <old config/project> config/craft/project`.
   Lines starting with `!!` mean a field left a layout. Stop and report.
4. Snapshot again and run `scripts/compare-html.sh snap-before snap-after`.
   Open every page with a large diff. Empty sections, raw Markdown and
   missing images show up here and nowhere else.
5. Submit every form end to end and check the mails. Process the queue.

Report counts, diffs and anything unexplained to the owner before any
deploy.

### 6. Production setup

Use `examples/docker` as a reference. The parts that break if missing:

- a queue worker (`php artisan queue:work`); mails and image transforms
  depend on it
- `php artisan craft:setup:publish` after the database is reachable,
  otherwise plugin assets are missing and `/admin/login` returns 500
- trusted proxies in `bootstrap/app.php` when TLS ends at a proxy
- `icu-data-full` on Alpine, GD with WebP if the site uses WebP transforms
- content migrations moved to `database/migrations`; the old `migrations/`
  folder is no longer read

When deploying with rsync, anchor excludes (`/vendor`, not `vendor`) and do a
`--dry-run --itemize-changes` first.

## Known beta.1 issues

- `laravel/tinker` is not installed. Use
  `php artisan craft:exec:exec 'eval(file_get_contents("/tmp/x.php"))'`.
- `craft:migrate:new` fails on MariaDB with a SQLite `PRAGMA` statement.
- The queue worker crash-loops on an empty database; import first.
