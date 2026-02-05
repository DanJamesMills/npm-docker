#!/usr/bin/env bash
set -euo pipefail

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

ENV_FILE=".env"

# Check for existing installation - either .env or data folders
if [[ -f "$ENV_FILE" ]] || [[ -d "./data" ]] || [[ -d "./mysql" ]] || [[ -d "./letsencrypt" ]]; then
  clear
  echo -e "${BOLD}${RED}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${RED}║   ⚠️  WARNING: Existing Installation Found    ║${NC}"
  echo -e "${BOLD}${RED}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  
  if [[ -f "$ENV_FILE" ]]; then
    echo -e "${YELLOW}.env configuration file already exists.${NC}"
  fi
  if [[ -d "./data" ]] || [[ -d "./mysql" ]] || [[ -d "./letsencrypt" ]]; then
    echo -e "${YELLOW}Existing data folders detected:${NC}"
    [[ -d "./data" ]] && echo -e "${YELLOW}  • ./data (NPM configuration and logs)${NC}"
    [[ -d "./mysql" ]] && echo -e "${YELLOW}  • ./mysql (database)${NC}"
    [[ -d "./letsencrypt" ]] && echo -e "${YELLOW}  • ./letsencrypt (SSL certificates)${NC}"
    [[ -d "./goaccess" ]] && echo -e "${YELLOW}  • ./goaccess (analytics)${NC}"
  fi
  echo ""
  echo -e "${RED}${BOLD}If you continue, the following will happen:${NC}"
  echo -e "${RED}  • Existing .env file will be DELETED${NC}"
  echo -e "${RED}  • All database credentials will be LOST${NC}"
  echo -e "${RED}  • You may lose access to existing proxy configurations${NC}"
  echo ""
  echo -e "${YELLOW}You can also optionally remove existing Docker data:${NC}"
  echo -e "${YELLOW}  • Stop and remove all containers${NC}"
  echo -e "${YELLOW}  • Delete all volumes (database, configs, certificates)${NC}"
  echo ""
  read -r -p "$(echo -e ${RED}${BOLD})Do you want to proceed? [y/N]: $(echo -e ${NC})" PROCEED
  
  if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Setup cancelled. Your existing installation is safe.${NC}"
    exit 0
  fi
  
  echo ""
  echo -e "${YELLOW}Do you want to remove Docker containers and volumes?${NC}"
  echo -e "${RED}This will DELETE all NPM data, configurations, and certificates!${NC}"
  read -r -p "$(echo -e ${YELLOW})Remove Docker data? [y/N]: $(echo -e ${NC})" REMOVE_DOCKER
  
  if [[ "$REMOVE_DOCKER" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${RED}${BOLD}⚠️  FINAL WARNING ⚠️${NC}"
    echo -e "${RED}This action CANNOT be undone!${NC}"
    echo -e "${RED}All data will be permanently deleted.${NC}"
    echo ""
    read -r -p "$(echo -e ${RED}${BOLD})Type 'DELETE' in capitals to confirm: $(echo -e ${NC})" CONFIRM
    
    if [[ "$CONFIRM" == "DELETE" ]]; then
      echo ""
      echo -e "${CYAN}Stopping and removing containers...${NC}"
      docker compose down 2>/dev/null || true
      docker compose --profile analytics down 2>/dev/null || true
      
      echo -e "${CYAN}Removing volumes...${NC}"
      rm -rf ./data ./letsencrypt ./mysql ./goaccess 2>/dev/null || true
      
      echo -e "${GREEN}✓ Docker containers and volumes removed${NC}"
    else
      echo ""
      echo -e "${RED}Incorrect confirmation. Nothing was deleted.${NC}"
      echo -e "${YELLOW}Existing data folders remain intact.${NC}"
      echo -e "${YELLOW}To start fresh, run this script again and type 'DELETE' exactly.${NC}"
      echo ""
      echo -e "${GREEN}Exiting safely. Your data is preserved.${NC}"
      exit 0
    fi
  fi
  
  echo ""
  echo -e "${CYAN}Removing old .env file...${NC}"
  rm -f "$ENV_FILE"
  echo -e "${GREEN}✓ Old .env file removed${NC}"
  echo ""
  sleep 1
fi

clear
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║   Nginx Proxy Manager - Setup Wizard          ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}This wizard will help you configure Nginx Proxy Manager with${NC}"
echo -e "${CYAN}secure random credentials and customizable settings.${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: Press Enter to accept defaults shown in [brackets]${NC}"
echo ""
read -r -p "Press Enter to continue..."
echo ""

echo -e "${BOLD}${GREEN}━━━ Port Configuration ━━━${NC}"
echo ""
echo -e "${CYAN}Admin Web Interface Port${NC}"
echo -e "  • What: The port to access NPM's admin dashboard"
echo -e "  • Why: Using 8181 instead of default 81 is more secure"
echo -e "  • Example: http://localhost:8181"
read -r -p "$(echo -e ${YELLOW}❯${NC}) Port [8181]: " ADMIN_PORT
ADMIN_PORT=${ADMIN_PORT:-8181}

echo ""
echo -e "${BOLD}${GREEN}━━━ System Configuration ━━━${NC}"
echo ""
echo -e "${CYAN}Timezone${NC}"
echo -e "  • What: Controls timestamps in logs and scheduled tasks"
echo -e "  • Format: Region/City (e.g., America/New_York, Asia/Tokyo)"
echo -e "  • Current system: $(date +%Z)"
read -r -p "$(echo -e ${YELLOW}❯${NC}) Timezone [Europe/London]: " TZ
TZ=${TZ:-Europe/London}

rand_str() {
  LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c "$1" || true
}

DB_NAME_DEFAULT="npm_db"
DB_USER_DEFAULT="npm_usr"

echo ""
echo -e "${BOLD}${GREEN}━━━ Database Configuration ━━━${NC}"
echo ""
echo -e "${CYAN}Database Settings${NC}"
echo -e "  • What: MariaDB database name and user for NPM"
echo -e "  • Why: Separate user provides better security than using root"
echo -e "  • Note: Passwords will be auto-generated (32+ random characters)"
echo ""
read -r -p "$(echo -e ${YELLOW}❯${NC}) Database name [${DB_NAME_DEFAULT}]: " DB_NAME
DB_NAME=${DB_NAME:-$DB_NAME_DEFAULT}

read -r -p "$(echo -e ${YELLOW}❯${NC}) Database user [${DB_USER_DEFAULT}]: " DB_USER
DB_USER=${DB_USER:-$DB_USER_DEFAULT}

echo ""
echo -e "${CYAN}🔐 Generating secure random passwords...${NC}"
DB_PASSWORD="$(rand_str 24)"
DB_ROOT_PASSWORD="$(rand_str 32)"

cat > "$ENV_FILE" <<EOF
# Nginx Proxy Manager + MariaDB credentials
TZ=${TZ}
NPM_HTTP_PORT=80
NPM_HTTPS_PORT=443
NPM_ADMIN_PORT=${ADMIN_PORT}
NPM_DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
NPM_DB_NAME=${DB_NAME}
NPM_DB_USER=${DB_USER}
NPM_DB_PASSWORD=${DB_PASSWORD}
EOF

echo ""
echo -e "${GREEN}✓ Configuration file created successfully!${NC}"
echo ""
echo -e "${BOLD}${GREEN}━━━ Optional Features ━━━${NC}"
echo ""
echo -e "${CYAN}GoAccess - Real-time Web Log Analyzer${NC}"
echo -e "  • What: Visual analytics dashboard for your web traffic"
echo -e "  • Shows: Visitors, requests, bandwidth, top URLs, browsers, etc."
echo -e "  • Access: Through NPM proxy (secure with SSL + authentication)"
echo -e "  • Container: Accessible at goaccess:7880 (internal network only)"
echo -e "  • Note: Requires some traffic to generate meaningful data"
read -r -p "$(echo -e ${YELLOW}❯${NC}) Enable GoAccess? [y/N]: " ENABLE_GOACCESS
ENABLE_GOACCESS=${ENABLE_GOACCESS:-N}

echo ""
read -r -p "$(echo -e ${YELLOW}❯${NC}) Start Docker containers now? [Y/n]: " START_NOW
START_NOW=${START_NOW:-Y}

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
  echo ""
  echo -e "${CYAN}Starting Docker containers...${NC}"
  if [[ "$ENABLE_GOACCESS" =~ ^[Yy]$ ]]; then
    docker compose --profile analytics up -d
  else
    docker compose up -d
  fi
  echo ""
  echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║   ✓ Installation Complete!                    ║${NC}"
  echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}${CYAN}📋 Default Admin Credentials:${NC}"
  echo -e "${YELLOW}   Email:    ${BOLD}admin@example.com${NC}"
  echo -e "${YELLOW}   Password: ${BOLD}changeme${NC}"
  echo ""
  echo -e "${BOLD}${CYAN}🌐 Access NPM Admin UI:${NC}"
  echo -e "${GREEN}   → http://localhost:${ADMIN_PORT}${NC}"
  echo -e "${CYAN}   📚 Documentation: https://nginxproxymanager.com/guide/${NC}"
  echo ""
  echo -e "${RED}${BOLD}⚠️  IMPORTANT:${NC} ${RED}Change the default password immediately after first login!${NC}"
  if [[ "$ENABLE_GOACCESS" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BOLD}${CYAN}📊 GoAccess Analytics - Let's Set It Up!${NC}"
    echo ""
    echo -e "${GREEN}✨ Time for your first NPM proxy configuration!${NC}"
    echo ""
    echo -e "${CYAN}Follow these steps in the NPM Admin UI:${NC}"
    echo -e "${YELLOW}   1.${NC} Go to ${BOLD}Hosts → Proxy Hosts → Add Proxy Host${NC}"
    echo -e "${YELLOW}   2.${NC} Domain Names: ${BOLD}webtraffic.yourdomain.com${NC} (or analytics, stats, etc.)"  
    echo -e "${YELLOW}   3.${NC} Forward Hostname: ${BOLD}goaccess${NC}  Port: ${BOLD}7880${NC}"
    echo -e "${YELLOW}   4.${NC} Enable ${BOLD}SSL${NC} with Let's Encrypt"
    echo -e "${YELLOW}   5.${NC} Create an ${BOLD}Access List${NC} to secure it with authentication"
    echo ""
    echo -e "${CYAN}🔐 Pro tip:${NC} Access Lists let you add username/password protection!"
    echo -e "${CYAN}📚 Guide:${NC} ${GREEN}https://nginxproxymanager.com/guide/#access-lists${NC}"
    echo ""
    echo -e "${BOLD}Once configured, you'll have beautiful real-time analytics! 📈${NC}"
  fi
  echo ""
else
  echo ""
  echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║   ✓ Configuration Complete!                   ║${NC}"
  echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}${CYAN}To start containers:${NC}"
  if [[ "$ENABLE_GOACCESS" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}   docker compose --profile analytics up -d${NC}"
  else
    echo -e "${YELLOW}   docker compose up -d${NC}"
  fi
  echo ""
  echo -e "${BOLD}${CYAN}After starting, access admin UI:${NC}"
  echo -e "${GREEN}   → http://localhost:${ADMIN_PORT}${NC}"
  echo -e "${CYAN}   📚 Documentation: https://nginxproxymanager.com/guide/${NC}"
  echo ""
  echo -e "${BOLD}${CYAN}📋 Default Admin Credentials:${NC}"
  echo -e "${YELLOW}   Email:    ${BOLD}admin@example.com${NC}"
  echo -e "${YELLOW}   Password: ${BOLD}changeme${NC}"
  echo ""
  if [[ "$ENABLE_GOACCESS" =~ ^[Yy]$ ]]; then
    echo -e "${BOLD}${CYAN}📊 GoAccess Analytics (after starting):${NC}"
    echo -e "${GREEN}   → http://localhost:${GOACCESS_PORT:-7890}${NC}"
    echo -e "${CYAN}   📚 Documentation: https://goaccess.io/man${NC}"
    echo ""
  fi
fi
