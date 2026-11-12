# Docker example

A Compose stack for running a Craft 6 site, built for a test instance next
to a live Craft 5 site and usable as a starting point for production.

Copy the files into your project:

| File | Goes to |
|---|---|
| `Dockerfile` | `docker/Dockerfile` |
| `nginx.conf` | `docker/nginx.conf` |
| `compose.yml` | `compose.yml` |
| `dockerignore` | `.dockerignore` |
| `env.example` | `.env` (fill in the secrets) |
| `host-vhost.conf` | the host's nginx, if TLS ends there |

First start:

```bash
docker compose up -d db
docker compose exec -T db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' < dump.sql
docker compose up -d --build
docker compose exec -T -u www-data app php artisan craft:up
```

The order matters. `publish` and `queue` boot Craft, and Craft expects an
installed database. Both are explained in `../../GUIDE.md`.

Uploads are a bind mount under `data/uploads` so you can fill them with
rsync. Add more mounts for every other local disk in
`config/filesystems.php`.
