# Craft CMS migration guide

Notes, scripts and an agent skill for moving a Craft CMS site to the next major
version. Each upgrade path lives on its own branch:

| Branch | Path | Status |
|---|---|---|
| `craft-5-to-6` | Craft 5.x to Craft 6.0 | Written against 6.0.0-beta.1 (November 2026) |

Everything here comes from one real migration: a production Craft 5.10 site
(Matrix-heavy content builder, CKEditor, two custom Yii modules, a global set,
two asset filesystems) moved to Craft 6.0.0-beta.1 and run as a second instance
next to the live site. The guide lists what broke, how it showed up and what
fixed it. It does not repeat the official upgrade docs; read those first.

Craft 6 is a beta. Its own docs say it is not ready for production use, and
some of what is written here will change before 6.0 ships.

## What is in the branch

```
skills/craft-5-to-6/
  SKILL.md        the procedure, written for a coding agent
  GUIDE.md        pitfalls and findings, written for people
  scripts/        inventory, diff and snapshot helpers
  examples/docker a Docker Compose stack for running Craft 6 next to Craft 5
```

The scripts work without the skill:

| Script | What it does |
|---|---|
| `counts.sql` | Entries per section, nested entries per field, assets, users, relations. Run it before and after and diff the output. |
| `element-diff.sql` | Compares every canonical element with a pre-upgrade copy of the database. |
| `public-uris.sql` | Lists all live entry URIs for the HTML snapshot. |
| `snapshot.sh` | Fetches a list of paths and stores the HTML and status codes. |
| `compare-html.sh` | Diffs two snapshots page by page with tokens and cache busters masked. |
| `compare-project-config.py` | Structural diff of the old and new project config, flags fields that left a field layout. |
| `find-query-loops.py` | Finds Twig loops over element queries that render nothing in Craft 6. |

## Using it as a skill

The skill follows the Agent Skills format (a folder with a `SKILL.md`). For
Claude Code, copy the folder into your skills directory:

```bash
git clone -b craft-5-to-6 https://github.com/Gerry3010/craft-migration-guide.git
cp -r craft-migration-guide/skills/craft-5-to-6 ~/.claude/skills/
```

Then ask the agent to upgrade the project to Craft 6. It loads the skill when
the task matches its description.

## Contributing

Found another pitfall, or one that a later beta fixed? Open an issue or a pull
request against the branch for that upgrade path. Please include the Craft
version where you saw it.

## License

MIT, see [LICENSE](LICENSE).
