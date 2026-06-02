# Django on AWS EC2 — Full Stack Deployment Guide

End-to-end guide covering: Terraform infra provisioning → Ansible hardening → Docker Compose deploy → GitHub Actions CI/CD → Prometheus/Grafana observability → SMTP email alerts.

---

## Architecture

```
GitHub Actions
  │
  ├─ [CI]   test → build Docker image → push to GHCR
  └─ [CD]   SSH to EC2 → pull image → rolling restart

EC2 Instance (Ubuntu 22.04)
  ├─ nginx (80/443)          — reverse proxy + TLS termination
  ├─ django/gunicorn (:8000) — application
  ├─ celery                  — async worker
  ├─ postgresql              — primary database
  ├─ redis                   — cache + celery broker
  ├─ node-exporter (:9100)   — host metrics
  ├─ prometheus (:9090)      — scrapes + evaluates alert rules
  ├─ alertmanager (:9093)    — routes alerts → SMTP email
  └─ grafana (:3000)         — dashboards (proxied via nginx /grafana/)
```

---

## Prerequisites

- AWS account with IAM credentials (`ec2:*`, `vpc:*`, `elasticip:*`)
- Terraform ≥ 1.8 and Ansible ≥ 2.15 installed locally
- Docker + Docker Compose v2 installed locally
- A domain or static IP for TLS
- An SMTP account (Gmail App Password, AWS SES, Mailgun, etc.)

---

## 1. Bootstrap AWS infrastructure

```bash
cd infra/terraform

# One-time: create S3 bucket and DynamoDB table for state
# (or remove the backend block from main.tf for local state)

terraform init

terraform apply \
  -var="trusted_ssh_cidr=YOUR.IP.HERE/32" \
  -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)"
```

Copy the `instance_public_ip` output — you'll need it below.


## 3. Configure GitHub Secrets

Go to `Settings → Secrets → Actions` in your repo and add:

| Secret | Value |
|--------|-------|
| `EC2_HOST` | EC2 Elastic IP or domain |
| `EC2_SSH_PRIVATE_KEY` | Your `~/.ssh/deployer_key` (private) |
| `EC2_SSH_PUBLIC_KEY` | Your `~/.ssh/deployer_key.pub` |
| `AWS_ACCESS_KEY_ID` | IAM deploy user key |
| `AWS_SECRET_ACCESS_KEY` | IAM deploy user secret |
| `AWS_REGION` | e.g. `ap-southeast-1` |
| `TRUSTED_SSH_CIDR` | Your IP + `/32` |
| `DJANGO_SECRET_KEY` | 50-char random string |
| `ALLOWED_HOSTS` | `yourdomain.com,www.yourdomain.com` |
| `POSTGRES_DB` | `appdb` |
| `POSTGRES_USER` | `postgres` |
| `POSTGRES_PASSWORD` | Strong password |
| `GRAFANA_USER` | `admin` |
| `GRAFANA_PASSWORD` | Strong password |
| `SMTP_HOST` | `smtp.gmail.com:587` |
| `SMTP_USER` | `alerts@yourdomain.com` |
| `SMTP_PASSWORD` | App password |
| `SMTP_FROM` | `alerts@yourdomain.com` |

---

## 4. TLS certificate

Place your certificate at:
```
nginx/ssl/fullchain.pem
nginx/ssl/privkey.pem
```

For Let's Encrypt (certbot):
```bash
sudo certbot certonly --standalone -d yourdomain.com
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem   nginx/ssl/
```

---

## 5. First deploy

Push to `main`. GitHub Actions will:

1. **test** — run Django tests against a fresh Postgres/Redis service
2. **build** — build Docker image, push to GHCR with `sha-xxxxxxx` tag
3. **deploy** — SSH to EC2, pull image, run migrations, rolling restart
4. **smoke-test** — verify `/api/health/` and `/api/ready/` return 200

---

## 6. Observability

| Service | URL | Notes |
|---------|-----|-------|
| Grafana | `https://yourdomain.com/grafana/` | Login with `GRAFANA_USER` / `GRAFANA_PASSWORD` |
| Prometheus | `localhost:9090` | Private (SSH tunnel or VPN only) |
| Alertmanager | `localhost:9093` | Private |

SSH tunnel to access Prometheus/Alertmanager locally:
```bash
ssh -L 9090:localhost:9090 -L 9093:localhost:9093 ubuntu@YOUR_EC2_IP
```

The **System Overview** dashboard is pre-provisioned with panels for:
- CPU usage (with 85%/95% thresholds)
- Memory usage (with 75%/90% thresholds)
- Disk usage gauge (root partition)
- Network in/out (bytes/s)
- Django request rate
- Django p95 latency
- Django 5xx error rate

---

## 7. Email alerts

Alertmanager sends emails via SMTP on:

| Alert | Threshold | Severity |
|-------|-----------|----------|
| `HighCPUUsage` | > 85% for 5 min | warning |
| `CriticalCPUUsage` | > 95% for 2 min | critical |
| `HighMemoryUsage` | > 85% for 5 min | warning |
| `CriticalMemoryUsage` | > 95% for 2 min | critical |
| `DiskSpaceWarning` | < 20% free | warning |
| `DiskSpaceCritical` | < 10% free | critical |
| `DiskIOSaturation` | > 90% busy for 5 min | warning |
| `HighNetworkErrors` | > 10 errors/s | warning |
| `InstanceDown` | unreachable for 1 min | critical |
| `HighSystemLoad` | 5-min load > 2× CPUs | warning |
| `DjangoHighRequestLatency` | p95 > 2s for 5 min | warning |
| `DjangoHighErrorRate` | 5xx rate > 5% for 2 min | critical |
| `DjangoAppDown` | no metrics for 2 min | critical |

Critical alerts → `oncall@yourdomain.com` + `lead@yourdomain.com` with 1h repeat.
Warning alerts → `oncall@yourdomain.com` with 4h repeat.

Edit `monitoring/alertmanager/alertmanager.yml` to update recipients.

---

## 8. Local development

```bash
cp app/.env.example app/.env
docker compose up -d
```

App at `http://localhost:8000` — hot-reloads on code changes.

---

## 9. Useful commands

```bash
# View logs
docker compose -f docker-compose.production.yml logs -f app

# Run Django management command
docker compose -f docker-compose.production.yml \
  exec app python manage.py createsuperuser

# Force a Prometheus config reload (no restart needed)
curl -X POST http://localhost:9090/-/reload

# Trigger a test alert from Alertmanager
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"}}]'
```
