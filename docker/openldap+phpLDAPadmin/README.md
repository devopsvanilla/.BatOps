# OpenLDAP + phpLDAPadmin (Docker Compose)

This stack runs OpenLDAP with persistent storage and the phpLDAPadmin web UI for browser-based administration.

## Quick start

1) Copy `.env-sample` to `.env` and adjust values:

```bash
cp .env-sample .env
nano .env
```

2) Start the stack:

```bash
docker compose up -d
```

3) Access the UI:

- URL: `http://localhost:8080`
- Login DN: `cn=admin,dc=example,dc=com` (matches `LDAP_ADMIN_DN`)
- Password: `admin` (matches `LDAP_ADMIN_PASSWORD`)

4) Verify LDAP responds:

```bash
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=com -D cn=admin,dc=example,dc=com -w admin -s base
```

## Configuration

All settings are controlled via `.env`. Key variables:

- `LDAP_ORGANISATION`, `LDAP_DOMAIN`, `LDAP_BASE_DN`: directory identity
- `LDAP_ADMIN_PASSWORD`, `LDAP_ADMIN_DN`: admin bind DN and password
- `LDAP_READONLY_USER`, `LDAP_READONLY_USER_*`: optional readonly account
- `LDAP_TLS`: set to `true` to enable LDAPS (port 636)
- Ports are mapped by `LDAP_PORT_389`, `LDAP_PORT_636`, `PHPLDAPADMIN_HTTP_PORT`, `PHPLDAPADMIN_HTTPS_PORT`

phpLDAPadmin connects to the container name specified by `PHPLDAPADMIN_LDAP_HOSTS` (default `openldap` service DNS inside the compose network).

## Persistence

Data persists under:

- `./data/slapd/database` → `/var/lib/ldap`
- `./data/slapd/config` → `/etc/ldap/slapd.d`

Create these directories before first run (Compose does it automatically, but you can pre-create if you want to set permissions manually).

## Bootstrap LDIFs (optional)

To seed your directory with organizational units, users, or groups, place `.ldif` files under `./bootstrap`. They are automatically applied on first container start.

Example `./bootstrap/00-base.ldif`:

```ldif
dn: ou=People,dc=example,dc=com
objectClass: organizationalUnit
ou: People

dn: ou=Groups,dc=example,dc=com
objectClass: organizationalUnit
ou: Groups
```

Recreate the container to re-apply bootstrap (note: bootstrap runs only when config is new):

```bash
docker compose down
rm -rf data/slapd/config data/slapd/database
docker compose up -d
```

## Enabling TLS (LDAPS)

1) Set `LDAP_TLS=true` in `.env`.
2) Put certificates in `./certs` with filenames `ca.crt`, `tls.crt`, `tls.key`.
3) Restart:

```bash
docker compose up -d
```

4) Connect UI via HTTPS if desired: set `PHPLDAPADMIN_HTTPS=true` and browse to `https://localhost:8443`.

5) For LDP/clients, use `ldaps://localhost:636`.

## Health checks

- OpenLDAP: simple `ldapsearch` bind against base DN.
- phpLDAPadmin: checks for UI content on port 80.

View status:

```bash
docker compose ps
docker compose logs -f openldap
docker compose logs -f phpldapadmin
```

## Common operations

- Stop/Start:

```bash
docker compose stop
docker compose start
```

- Recreate without losing data:

```bash
docker compose up -d --force-recreate
```

- Remove everything (including data):

```bash
docker compose down
rm -rf data/slapd database data/slapd/config
```

## Troubleshooting

- Bind DN mismatch: ensure `LDAP_ADMIN_DN` matches your `LDAP_BASE_DN` (e.g., `cn=admin,dc=example,dc=com`).
- Bootstrap doesn’t apply: remove `data/slapd/config` and `data/slapd/database` to reinitialize (will wipe data).
- TLS fails: verify `ca.crt`, `tls.crt`, `tls.key` are valid, readable, and correspond to your hostnames.
- UI cannot connect: check `PHPLDAPADMIN_LDAP_HOSTS` equals `openldap` (the service name). Inspect with `docker compose logs phpldapadmin`.

## Security notes

- Change all default passwords in `.env` for any non-lab usage.
- Prefer TLS (`LDAP_TLS=true`) for production.
- Restrict exposed ports or bind to specific addresses using Docker `ports` syntax (e.g., `127.0.0.1:389:389`).

## Structure

```
docker/openldap+phpLDAPadmin/
├── docker-compose.yml
├── .env-sample
├── README.md
├── data/
│   ├── slapd/
│   │   ├── database/
│   │   └── config/
├── bootstrap/         # optional LDIFs
├── certs/             # optional TLS certs
└── pla/
    ├── config/
    └── apache2/
```

## Try it

```bash
cd /home/devopsvanilla/.BatOps/docker/openldap+phpLDAPadmin
cp .env-sample .env
docker compose up -d
xdg-open "http://localhost:8080" 2>/dev/null || echo "Open http://localhost:8080"
```

Happy directory wrangling!
