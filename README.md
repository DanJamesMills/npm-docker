# Nginx Proxy Manager (Docker)

A simple Docker Compose setup for running [Nginx Proxy Manager](https://nginxproxymanager.com/) with MariaDB, featuring secure defaults and optional analytics.

## What is Nginx Proxy Manager?

**Nginx Proxy Manager** (NPM) is a user-friendly web interface for managing Nginx proxy hosts with SSL certificate automation. It enables you to:

- **Expose web services** from your home network or server to the internet
- **SSL/TLS certificates** with automatic Let's Encrypt integration (free HTTPS)
- **Access Lists** to restrict access to certain sites
- **Custom SSL certificates** for internal/private services
- **404 hosts** to redirect invalid domains
- **Stream forwarding** for TCP/UDP services

Perfect for hosting multiple websites/apps on a single server with individual domain names.

## What is GoAccess? (Optional)

**GoAccess** is a real-time web log analyzer that provides visual analytics dashboards. It processes NPM's access logs to show:

- Visitors, requests, bandwidth usage
- Top URLs, referring sites, and user agents
- Operating systems and browsers
- HTTP status codes (errors, successes)
- Geolocation data (countries)

The analytics run entirely locally - no data sent to third parties.

## Getting started

### Quick setup (recommended)

Run the interactive setup script to configure NPM with secure credentials:

```bash
./setup.sh
```

The script will:
- Generate random secure database passwords
- Configure timezone and admin port
- Optionally enable GoAccess analytics
- Start Docker containers automatically

After setup completes, access the admin UI at `http://localhost:8181` (or your configured port).

**Default credentials:**
- Email: `admin@example.com`
- Password: `changeme`

⚠️ **Change the password immediately after first login!**

### Manual setup

If you prefer manual configuration:

1. Copy `.env.example` to `.env`
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and update all placeholder values:
   - Database passwords
   - Admin port (default: 8181)
   - Timezone
   - HTTP/HTTPS ports if needed

3. Start the containers:
   ```bash
   docker compose up -d
   ```

4. Access admin UI: `http://localhost:8181`

## Optional: GoAccess analytics

This repo includes an optional GoAccess service for real-time web log analysis.
The setup script can enable it for you. It uses a specialized Docker image pre-configured for NPM's log format.

GoAccess runs as an internal service and should be accessed **through NPM** for security.

### Setup steps

1. Start with analytics profile:
   ```bash
   docker compose --profile analytics up -d
   ```

2. **Configure your first NPM proxy!** In NPM admin UI, create a new Proxy Host:
   - **Domain Names:** `webtraffic.yourdomain.com` (or analytics, stats, logs, etc.)
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `goaccess`
   - **Forward Port:** `7880`
   - **Cache Assets:** ✅ Enable
   - **Block Common Exploits:** ✅ Enable
   - **WebSockets Support:** ✅ **Enable (required for real-time updates)**
   - **SSL:** ✅ Enable with Let's Encrypt certificate
   - **Access List:** ✅ Create and assign one for authentication
   
   📚 [How to create Access Lists](https://nginxproxymanager.com/guide/#access-lists)

3. Access your analytics at: `https://webtraffic.yourdomain.com`

🎉 **Congratulations!** You've just secured your analytics dashboard with SSL and authentication!

### Why proxy through NPM?

- **SSL/TLS encryption** for secure access
- **Authentication** via NPM Access Lists
- **Single entry point** - no extra ports to expose
- **Same security model** as your other services

⚠️ **Important:** Make sure **WebSockets Support** is enabled in the NPM proxy host settings for real-time updates to work!

The dashboard updates automatically every 5 seconds and shows:
- Unique visitors and requests
- Bandwidth usage
- Top URLs and referrers
- HTTP status codes
- Browsers and operating systems
- Geolocation data (countries)

## Documentation & Resources

- **NPM Official Guide:** https://nginxproxymanager.com/guide/
- **NPM Access Lists (Authentication):** https://nginxproxymanager.com/guide/#access-lists
- **NPM Advanced Config:** https://nginxproxymanager.com/advanced-config/
- **GoAccess Manual:** https://goaccess.io/man
- **Docker Compose Docs:** https://docs.docker.com/compose/
- **This Repo:** https://github.com/DanJamesMills/npm-docker (⭐ Star if helpful!)

## Resetting the admin password (database access)

If you lose access to the admin UI, you can reset the password directly in the
MariaDB database.

### Steps

1. Generate a new bcrypt password hash (cost 10):

```bash
htpasswd -bnBC 10 "" "YourNewPassword" | tr -d ':\n'
```

2. Connect to the database container:

```bash
docker exec -it npm-db mysql -u root -p
```

Enter the root password from your `.env` file (`NPM_DB_ROOT_PASSWORD`).

3. Update the admin user password:

```sql
USE npm;
UPDATE user SET password='PASTE_BCRYPT_HASH_HERE' WHERE id=1;
EXIT;
```

4. Restart the app container:

```bash
docker compose restart app
```

You can now log in with your new password.

## Notes

- **Database data:** Stored in `./mysql`
- **NPM data:** Stored in `./data` (configs, logs)
- **SSL certificates:** Stored in `./letsencrypt`
- **Log rotation:** Enabled in Docker Compose (10MB max, 3 files)
- **Health checks:** All services include health monitoring
- **Ports:** HTTP (80), HTTPS (443), and Admin (8181) are configurable via `.env`
- **GoAccess:** Not exposed externally - access through NPM proxy for security

## Troubleshooting

### Port already in use

If you see "port is already allocated" errors during startup:

1. Edit `.env` and change conflicting ports:
   ```env
   NPM_HTTP_PORT=8080      # instead of 80
   NPM_HTTPS_PORT=8443     # instead of 443
   NPM_ADMIN_PORT=8181     # already non-standard
   ```

2. Restart containers:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Reset everything

To completely remove and start fresh, run the setup script:

```bash
./setup.sh
```

The script will detect the existing installation and offer to safely remove everything.

Or manually:

```bash
docker compose down
rm -rf .env data letsencrypt mysql goaccess
./setup.sh
```
