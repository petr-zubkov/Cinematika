#!/bin/bash

# Cinematika Installer - Полный скрипт установки
# Аналог официального установщика Cinematika
# Использование: bash Cinematika-installer.sh [опция]

set -e

# Цвета для вывода
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[1;34m'
B='\033[0;36m'
S='\033[0;90m'
NC='\033[0m'

# Переменные
OPTION=${1:-}
GIT_SERVER="github.com"
CP_VER="6.0.0"
PRC_=0

# Переменные окружения
CP_DOMAIN=${CP_DOMAIN:-}
CP_LANG=${CP_LANG:-}
CP_THEME=${CP_THEME:-}
CP_PASSWD=${CP_PASSWD:-}
CP_MIRROR=${CP_MIRROR:-}
CP_KEY=${CP_KEY:-}
CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL:-}
CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY:-}
MEGA_EMAIL=${MEGA_EMAIL:-}
MEGA_PASSWORD=${MEGA_PASSWORD:-}
FTP_USERNAME=${FTP_USERNAME:-}
FTP_PASSWORD=${FTP_PASSWORD:-}
FTP_HOSTNAME=${FTP_HOSTNAME:-}
FTP_NAME=${FTP_NAME:-}

# Очистка домена для использования в именах
CP_DOMAIN_=$(echo "${CP_DOMAIN}" | sed -r "s/[^A-Za-z0-9]/_/g")
CP_MIRROR_=$(echo "${CP_DOMAIN}" | sed -r "s/[^A-Za-z0-9]/_/g")

CP_SPB=""
CP_IP="domain"
EXTERNAL_PORT=""
EXTERNAL_DOCKER=""

# Определение ОС
CP_OS="`awk '/^ID=/' /etc/*os-release 2>/dev/null | awk -F'=' '{ print tolower($2) }' || echo 'unknown'`"

# Определение памяти
CP_MEM=$(free -m | grep -oP '\d+' | sed '1!d' 2>/dev/null || echo "1024")
if echo "${CP_MEM}" | grep -qE '^[0-9]+$'; then
    DOCKER_MEM=("--memory" "$(( CP_MEM / 2 ))m")
else
    DOCKER_MEM=()
fi

# Функции для вывода
log_info() {
    echo -e "${G}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${Y}[WARN]${NC} $1"
}

log_error() {
    echo -e "${R}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${C}[STEP]${NC} $1"
}

# Функции для отрисовки элементов
_line() {
    printf "${C}"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    printf "${NC}"
}

_logo() {
    clear
    _line
    printf "${G}"
    cat << 'EOF'
    ███████╗ ██╗ ███    ██╗ ███████╗ ███      ███╗    █████╗ ███████╗  ██╗ ██╗  ███╗    █████╗  
    ██╔════╝ ██║ ██║█   ██║ ██╔════╝ ██║█   █ ██║    ██╔██║     ██╔═╝  ██║ ██║ ██╔═╝    ██╔██║ 
    ██║        ██║ ██║ █  ██║ █████╗    ██║ █ █  ██║   ██████║    ██║     ██║ ████╔╝       ██████║ 
    ██║        ██║ ██║  █ ██║ ██╔══╝    ██║  █   ██║   ██╔═██║     ██║     ██║ ██╔██╗      ██╔═██║ 
    ███████╗ ██║ ██║   ███║ ███████╗ ██║       ██║  ██║  ██║     ██║     ██║ ██╗  ██║   ██║   ██║
     ╚═════╝ ╚═╝ ╚═╝     ╚═╝ ╚══════╝ ╚═╝       ╚═╝  ╚═╝  ╚═╝     ╚═╝     ╚═╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝
EOF
    printf "${NC}"
    _line
}

_header() {
    printf "${C}"
    printf "%*s\n" "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    printf "%*s\n" "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    printf "                   $1                    \n"
    printf "%*s\n" "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    printf "%*s\n" "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    printf "${NC}"
}

_content() {
    if [ -n "$1" ]; then
        printf "  $1\n"
    else
        printf "\n"
    fi
}

_br() {
    printf "\n"
}

_s() {
    if [ "$1" != "no" ]; then
        sleep 0.5
    fi
}

sh_progress() {
    local progress=${1:-0}
    local width=50
    local filled=$((width * progress / 100))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %d%%" $progress
}

sh_yes() {
    if [ "$1" != "no" ]; then
        read -p "Продолжить? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Установка отменена"
            exit 1
        fi
    fi
}

# Функция пост-установочных команд
post_commands() {
    local LOCAL_DOMAIN=${1:-${CP_DOMAIN}}
    local LOCAL_DOMAIN_=$(echo "${LOCAL_DOMAIN}" | sed -r "s/[^A-Za-z0-9]/_/g")

    # Настройка автозапуска
    if [ "$(grep "${LOCAL_DOMAIN}_autostart" /etc/crontab 2>/dev/null)" = "" ] \
    && [ -f "/home/${LOCAL_DOMAIN}/process.json" ] \
    && [ -f "/home/${LOCAL_DOMAIN}/app.js" ]; then
        echo -e "\n" >>/etc/crontab
        echo "# ----- ${LOCAL_DOMAIN}_autostart --------------------------------------" >>/etc/crontab
        echo "@reboot root /usr/bin/Cinematika autostart \"${LOCAL_DOMAIN}\" >>\"/home/${LOCAL_DOMAIN}/log/autostart_\$(date '+%d_%m_%Y').log\" 2>&1" >>/etc/crontab
        echo "# ----- ${LOCAL_DOMAIN}_autostart --------------------------------------" >>/etc/crontab
    fi

    # Настройка обновления SSL
    if [ "$(grep "${LOCAL_DOMAIN}_renew" /etc/crontab 2>/dev/null)" = "" ] \
    && [ -d "/home/${LOCAL_DOMAIN}/config/production/nginx/ssl.d/live/${LOCAL_DOMAIN}/" ]; then
        sed -i "s/.*${LOCAL_DOMAIN}_ssl.*//g" /etc/crontab &> /dev/null
        sed -i "s/.*${LOCAL_DOMAIN}\/config\/production\/nginx\/ssl\.d.*//g" /etc/crontab &> /dev/null
        echo -e "\n" >>/etc/crontab
        echo "# ----- ${LOCAL_DOMAIN}_renew --------------------------------------" >>/etc/crontab
        echo "0 23 * * * root /usr/bin/Cinematika renew \"${LOCAL_DOMAIN}\" >>\"/home/${LOCAL_DOMAIN}/log/renew_\$(date '+%d_%m_%Y').log\" 2>&1" >>/etc/crontab
        echo "# ----- ${LOCAL_DOMAIN}_renew --------------------------------------" >>/etc/crontab
    fi
}

# Функция установки Docker
docker_install() {
    if [ "${CP_OS}" != "alpine" ] && [ "${CP_OS}" != "\"alpine\"" ]; then
        if [ "`basename \"${0}\"`" != "Cinematika" ] || [ "${1}" != "" ]; then
            echo ""; echo -n "☐ Downloading Cinematika.sh ...";
            wget -qO /usr/bin/Cinematika https://raw.githubusercontent.com/Cinematika/Cinematika/master/Cinematika.sh -o /dev/null && \
            chmod +x /usr/bin/Cinematika
            echo -e "\\r${G}✓ Downloading Cinematika.sh ...${NC}"
            echo -n "☐ Installing packages ..."
            
            # Установка пакетов в зависимости от ОС
            case "${CP_OS}" in
                "debian"|"\"debian\"")
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq update >>/var/log/docker_install_"$(date '+%d_%m_%Y')".log 2>&1
                    for package in sudo wget curl nano htop lsb-release ca-certificates git-core openssl net-tools netcat cron zip gzip bzip2 unzip gcc make libssl-dev locales lsof; do
                        DEBIAN_FRONTEND=noninteractive apt-get -y -qq install $package >>/var/log/docker_install_"$(date '+%d_%m_%Y')".log 2>&1
                    done
                    ;;
                "ubuntu"|"\"ubuntu\"")
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq update >>/var/log/docker_install_"$(date '+%d_%m_%Y')".log 2>&1
                    for package in sudo wget curl nano htop lsb-release ca-certificates git-core openssl netcat net-tools cron zip gzip bzip2 unzip gcc make libssl-dev locales lsof syslog-ng; do
                        DEBIAN_FRONTEND=noninteractive apt-get -y -qq install $package >>/var/log/docker_install_"$(date '+%d_%m_%Y')".log 2>&1
                    done
                    ;;
                "fedora"|"\"fedora\"")
                    for package in sudo wget curl nano htop lsb-release ca-certificates git-core openssl netcat cron zip gzip bzip2 unzip gcc make libssl-dev locales lsof; do
                        dnf -y install $package >>/var/log/docker_install_"$(date '+%d_%m_%Y')".log 2>&1
                    done
                    ;;
                "centos"|"\"centos\"")
                    yum install -y epel-release >>/var/log/docker_install_"$(date '+%d_%m_%Y')".log 2>&1
                    for package in sudo wget curl nano htop lsb-release ca-certificates git-core openssl netcat net-tools cron zip gzip bzip2 unzip gcc make libssl-dev locales lsof; do
                        yum install -y $package >>/var/log/docker_install_"$(date '+%d_%m_%Y')".log 2>&1
                    done
                    ;;
            esac
            
            echo -e "\\r${G}✓ Installing packages ...${NC}"
            echo ""
        fi
        
        # Установка Docker
        if [ "$(docker -v 2>/dev/null)" = "" ]; then
            clear
            _line
            _logo
            _header "DOCKER"
            _content
            _content "Installing Docker ..."
            _content
            _s
            
            # Настройка SSH
            sed -Ei "s/#SyslogFacility AUTH/SyslogFacility AUTH/g" /etc/ssh/sshd_config >/dev/null
            sed -Ei "s/#LogLevel INFO/LogLevel ERROR/g" /etc/ssh/sshd_config >/dev/null
            sed -Ei "s/#MaxAuthTries 6/MaxAuthTries 3/g" /etc/ssh/sshd_config >/dev/null
            sed -Ei "s/#ClientAliveCountMax 3/ClientAliveCountMax 99999/g" /etc/ssh/sshd_config >/dev/null
            sed -Ei "s/#ClientAliveInterval 0/ClientAliveInterval 20/g" /etc/ssh/sshd_config >/dev/null
            
            # Установка Docker в зависимости от ОС
            case "${CP_OS}" in
                "debian"|"\"debian\"")
                    CP_ARCH="`dpkg --print-architecture`"
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq remove docker docker-engine docker.io containerd runc
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq update
                    for package in apt-transport-https ca-certificates curl gnupg2 software-properties-common; do
                        DEBIAN_FRONTEND=noninteractive apt-get -y -qq install $package
                    done
                    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                    
                    # Определение архитектуры
                    if [ "${CP_ARCH}" = "amd64" ] || [ "${CP_ARCH}" = "x86_64" ] || [ "${CP_ARCH}" = "i386" ]; then
                        CP_ARCH="amd64"
                    elif [ "${CP_ARCH}" = "armhf" ] || [ "${CP_ARCH}" = "armel" ]; then
                        CP_ARCH="armhf"
                    elif [ "${CP_ARCH}" = "arm64" ]; then
                        CP_ARCH="arm64"
                    fi
                    
                    sed -i "s~.*docker.com.*~~g" /etc/apt/sources.list &> /dev/null
                    echo "deb [arch=${CP_ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq update
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq install docker-ce docker-ce-cli containerd.io docker-compose-plugin
                    ;;
                "ubuntu"|"\"ubuntu\"")
                    CP_ARCH="`dpkg --print-architecture`"
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq remove docker docker-engine docker.io containerd runc
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq update
                    for package in apt-transport-https ca-certificates curl gnupg2 software-properties-common; do
                        DEBIAN_FRONTEND=noninteractive apt-get -y -qq install $package
                    done
                    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                    
                    # Определение архитектуры
                    if [ "${CP_ARCH}" = "amd64" ] || [ "${CP_ARCH}" = "x86_64" ] || [ "${CP_ARCH}" = "i386" ]; then
                        CP_ARCH="amd64"
                    elif [ "${CP_ARCH}" = "armhf" ] || [ "${CP_ARCH}" = "armel" ]; then
                        CP_ARCH="armhf"
                    elif [ "${CP_ARCH}" = "arm64" ]; then
                        CP_ARCH="arm64"
                    fi
                    
                    sed -i "s~.*docker.com.*~~g" /etc/apt/sources.list &> /dev/null
                    echo "deb [arch=${CP_ARCH} signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq update
                    DEBIAN_FRONTEND=noninteractive apt-get -y -qq install docker-ce docker-ce-cli containerd.io docker-compose-plugin
                    ;;
                "fedora"|"\"fedora\"")
                    dnf -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
                    dnf -y install dnf-plugins-core
                    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                    dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
                    ;;
                "centos"|"\"centos\"")
                    yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
                    yum install -y yum-utils
                    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                    ;;
            esac
            
            # Запуск Docker
            systemctl start docker
            systemctl enable docker
            
            # Установка Docker Compose
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            
            echo -e "${G}✓ Docker installed successfully${NC}"
        fi
    fi
}

# Функция установки IP
ip_install() {
    if [ "${CP_IP}" = "domain" ]; then
        CP_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "localhost")
    fi
}

# Функция чтения домена
read_domain() {
    local domain=${1:-}
    
    if [ -z "${domain}" ]; then
        _line
        _logo
        _header "DOMAIN"
        _content
        _content "Please enter your domain name:"
        _content
        read -p "Domain (example.com): " domain
        _content
    fi
    
    # Валидация домена
    if [[ ! "${domain}" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: ${domain}"
        read_domain ""
        return
    fi
    
    CP_DOMAIN="${domain}"
    CP_DOMAIN_=$(echo "${CP_DOMAIN}" | sed -r "s/[^A-Za-z0-9]/_/g")
}

# Функция чтения языка
read_lang() {
    local lang=${1:-}
    
    if [ -z "${lang}" ]; then
        _content "Please select language:"
        _content "1. English (en)"
        _content "2. Русский (ru)"
        _content
        read -p "Language (1/2): " lang_choice
        
        case "${lang_choice}" in
            1) lang="en" ;;
            2) lang="ru" ;;
            *) lang="en" ;;
        esac
    fi
    
    CP_LANG="${lang}"
}

# Функция чтения темы
read_theme() {
    local theme=${1:-}
    
    if [ -z "${theme}" ]; then
        _content "Please select theme:"
        _content "1. Default"
        _content "2. Dark"
        _content "3. Modern"
        _content
        read -p "Theme (1/2/3): " theme_choice
        
        case "${theme_choice}" in
            1) theme="default" ;;
            2) theme="dark" ;;
            3) theme="modern" ;;
            *) theme="default" ;;
        esac
    fi
    
    CP_THEME="${theme}"
}

# Функция чтения пароля
read_password() {
    local password=${1:-}
    
    if [ -z "${password}" ]; then
        _content "Please enter admin password:"
        read -s -p "Password: " password
        _content
        read -s -p "Confirm password: " password_confirm
        _content
        
        if [ "${password}" != "${password_confirm}" ]; then
            log_error "Passwords do not match"
            read_password ""
            return
        fi
        
        if [ ${#password} -lt 6 ]; then
            log_error "Password must be at least 6 characters"
            read_password ""
            return
        fi
    fi
    
    CP_PASSWD="${password}"
}

# Функция чтения ключа
read_key() {
    local key=${1:-}
    
    if [ -z "${key}" ]; then
        _content "Please enter your Cinematika key:"
        _content "(Leave empty for demo version)"
        read -p "Key: " key
    fi
    
    CP_KEY="${key}"
}

# Функция чтения зеркала
read_mirror() {
    local mirror=${1:-}
    
    if [ -z "${mirror}" ]; then
        _content "Please enter mirror domain:"
        _content "(Leave empty if no mirror)"
        read -p "Mirror domain: " mirror
    fi
    
    CP_MIRROR="${mirror}"
    CP_MIRROR_=$(echo "${CP_MIRROR}" | sed -r "s/[^A-Za-z0-9]/_/g")
}

# Функция чтения email для Cloudflare
read_cloudflare_email() {
    local email=${1:-}
    
    if [ -z "${email}" ]; then
        _content "Please enter Cloudflare email:"
        _content "(Leave empty if not using Cloudflare)"
        read -p "Email: " email
    fi
    
    CLOUDFLARE_EMAIL="${email}"
}

# Функция чтения API ключа Cloudflare
read_cloudflare_api_key() {
    local api_key=${1:-}
    
    if [ -z "${api_key}" ]; then
        _content "Please enter Cloudflare API key:"
        _content "(Leave empty if not using Cloudflare)"
        read -s -p "API Key: " api_key
        _content
    fi
    
    CLOUDFLARE_API_KEY="${api_key}"
}

# Функция установки
1_install() {
    local domain=${1:-}
    local lang=${2:-}
    local theme=${3:-}
    local password=${4:-}
    
    log_step "Starting installation for ${domain}"
    
    # Создание директорий
    mkdir -p "/home/${domain}"
    cd "/home/${domain}"
    
    # Клонирование репозитория
    log_info "Cloning Cinematika repository..."
    git clone https://github.com/Cinematika/Cinematika.git . || {
        log_error "Failed to clone repository"
        exit 1
    }
    
    # Создание конфигурации
    log_info "Creating configuration..."
    cat > config.js << EOF
module.exports = {
    domain: '${domain}',
    language: '${lang}',
    theme: '${theme}',
    password: '${password}',
    key: '${CP_KEY}',
    version: '${CP_VER}'
};
EOF
    
    # Создание docker-compose.yml
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    image: Cinematika/app:latest
    container_name: ${CP_DOMAIN_}_app
    restart: always
    environment:
      - NODE_ENV=production
      - DOMAIN=${domain}
      - LANGUAGE=${lang}
      - THEME=${theme}
    volumes:
      - ./config:/app/config
      - ./data:/app/data
      - ./logs:/app/logs
    ports:
      - "3000:3000"
    networks:
      - Cinematika_network

  nginx:
    image: Cinematika/nginx:latest
    container_name: ${CP_DOMAIN_}_nginx
    restart: always
    depends_on:
      - app
    environment:
      - DOMAIN=${domain}
    volumes:
      - ./config/nginx:/etc/nginx/conf.d
      - ./ssl:/etc/nginx/ssl
      - ./logs/nginx:/var/log/nginx
    ports:
      - "80:80"
      - "443:443"
    networks:
      - Cinematika_network

  database:
    image: mongo:latest
    container_name: ${CP_DOMAIN_}_database
    restart: always
    volumes:
      - ./data/mongo:/data/db
    networks:
      - Cinematika_network

networks:
  Cinematika_network:
    driver: bridge
EOF
    
    # Запуск контейнеров
    log_info "Starting containers..."
    docker-compose up -d
    
    # Ожидание запуска
    log_info "Waiting for services to start..."
    sleep 30
    
    # Проверка статуса
    log_info "Checking service status..."
    docker-compose ps
    
    log_info "Installation completed successfully!"
    log_info "Your site is available at: http://${domain}"
}

# Функция обновления
2_update() {
    local domain=${1:-}
    
    if [ -z "${domain}" ]; then
        log_error "Domain is required for update"
        exit 1
    fi
    
    log_step "Updating ${domain}"
    
    cd "/home/${domain}"
    
    # Обновление кода
    git pull origin master
    
    # Обновление контейнеров
    docker-compose pull
    docker-compose up -d
    
    log_info "Update completed!"
}

# Функция бэкапа
3_backup() {
    local domain=${1:-}
    local backup_type=${2:-full}
    
    if [ -z "${domain}" ]; then
        log_error "Domain is required for backup"
        exit 1
    fi
    
    log_step "Creating backup for ${domain}"
    
    cd "/home/${domain}"
    
    # Создание директории для бэкапов
    mkdir -p "backups"
    
    # Имя файла бэкапа
    local backup_file="backups/${domain}_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    # Создание бэкапа
    case "${backup_type}" in
        "full")
            tar -czf "${backup_file}" config data logs docker-compose.yml
            ;;
        "config")
            tar -czf "${backup_file}" config docker-compose.yml
            ;;
        "data")
            tar -czf "${backup_file}" data
            ;;
        *)
            log_error "Invalid backup type: ${backup_type}"
            exit 1
            ;;
    esac
    
    log_info "Backup created: ${backup_file}"
}

# Функция смены темы
4_theme() {
    local domain=${1:-}
    local new_theme=${2:-}
    
    if [ -z "${domain}" ] || [ -z "${new_theme}" ]; then
        log_error "Domain and theme are required"
        exit 1
    fi
    
    log_step "Changing theme for ${domain} to ${new_theme}"
    
    cd "/home/${domain}"
    
    # Обновление конфигурации
    sed -i "s/theme: .*/theme: '${new_theme}',/" config.js
    
    # Перезапуск контейнера
    docker-compose restart app
    
    log_info "Theme changed successfully!"
}

# Функция работы с базой данных
5_database() {
    local domain=${1:-}
    local action=${2:-}
    local key=${3:-}
    
    if [ -z "${domain}" ] || [ -z "${action}" ]; then
        log_error "Domain and action are required"
        exit 1
    fi
    
    log_step "Database operation: ${action} for ${domain}"
    
    cd "/home/${domain}"
    
    case "${action}" in
        "backup")
            docker-compose exec database mongodump --out /tmp/backup
            tar -czf "database_backup_$(date +%Y%m%d_%H%M%S).tar.gz" tmp/backup
            rm -rf tmp/backup
            log_info "Database backup created"
            ;;
        "restore")
            if [ -z "${key}" ]; then
                log_error "Backup file is required for restore"
                exit 1
            fi
            tar -xzf "${key}" -C /tmp
            docker-compose exec database mongorestore /tmp/backup
            rm -rf tmp/backup
            log_info "Database restored"
            ;;
        "reset")
            docker-compose exec database mongo --eval "use cinema; db.dropDatabase()"
            log_info "Database reset"
            ;;
        *)
            log_error "Invalid database action: ${action}"
            exit 1
            ;;
    esac
}

# Функция настройки HTTPS
6_https() {
    local domain=${1:-}
    local email=${2:-}
    local api_key=${3:-}
    local cloudflare=${4:-false}
    
    if [ -z "${domain}" ]; then
        log_error "Domain is required for HTTPS setup"
        exit 1
    fi
    
    log_step "Setting up HTTPS for ${domain}"
    
    cd "/home/${domain}"
    
    # Создание директории для SSL
    mkdir -p ssl
    
    if [ "${cloudflare}" = "true" ] && [ -n "${email}" ] && [ -n "${api_key}" ]; then
        # Настройка Cloudflare
        log_info "Configuring Cloudflare SSL..."
        
        # Создание конфигурации для Certbot с Cloudflare
        cat > cloudflare.ini << EOF
dns_cloudflare_email = ${email}
dns_cloudflare_api_key = ${api_key}
EOF
        chmod 600 cloudflare.ini
        
        # Запуск Certbot с Cloudflare plugin
        docker run --rm \
            -v "$(pwd)/ssl:/etc/letsencrypt" \
            -v "$(pwd)/cloudflare.ini:/cloudflare.ini" \
            certbot/dns-cloudflare \
            certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials /cloudflare.ini \
            --email ${email} \
            --agree-tos \
            --no-eff-email \
            -d ${domain} \
            -d www.${domain}
    else
        # Стандартная настройка Let's Encrypt
        log_info "Configuring Let's Encrypt SSL..."
        
        # Временная остановка Nginx
        docker-compose stop nginx
        
        # Запуск Certbot
        docker run --rm \
            -v "$(pwd)/ssl:/etc/letsencrypt" \
            -p 80:80 \
            certbot/certbot \
            certonly \
            --standalone \
            --email admin@${domain} \
            --agree-tos \
            --no-eff-email \
            -d ${domain} \
            -d www.${domain}
        
        # Запуск Nginx
        docker-compose start nginx
    fi
    
    # Обновление конфигурации Nginx для SSL
    cat > config/nginx/ssl.conf << EOF
server {
    listen 80;
    server_name ${domain} www.${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain} www.${domain};
    
    ssl_certificate /etc/nginx/ssl/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/${domain}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://app:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Перезапуск Nginx
    docker-compose restart nginx
    
    log_info "HTTPS configured successfully!"
}

# Функция создания зеркала
7_mirror() {
    local domain=${1:-}
    local mirror_domain=${2:-}
    
    if [ -z "${domain}" ] || [ -z "${mirror_domain}" ]; then
        log_error "Domain and mirror domain are required"
        exit 1
    fi
    
    log_step "Creating mirror: ${mirror_domain} for ${domain}"
    
    # Копирование конфигурации
    cp -r "/home/${domain}" "/home/${mirror_domain}"
    
    # Обновление конфигурации
    cd "/home/${mirror_domain}"
    sed -i "s/${domain}/${mirror_domain}/g" config.js docker-compose.yml config/nginx/*.conf
    
    # Обновление имен контейнеров
    local old_prefix=$(echo "${domain}" | sed -r "s/[^A-Za-z0-9]/_/g")
    local new_prefix=$(echo "${mirror_domain}" | sed -r "s/[^A-Za-z0-9]/_/g")
    sed -i "s/${old_prefix}/${new_prefix}/g" docker-compose.yml
    
    # Запуск зеркала
    docker-compose up -d
    
    log_info "Mirror created successfully!"
}

# Функция удаления
8_remove() {
    local domain=${1:-}
    local remove_data=${2:-false}
    
    if [ -z "${domain}" ]; then
        log_error "Domain is required for removal"
        exit 1
    fi
    
    log_step "Removing ${domain}"
    
    cd "/home/${domain}"
    
    # Остановка и удаление контейнеров
    docker-compose down
    
    # Удаление данных если нужно
    if [ "${remove_data}" = "true" ]; then
        docker-compose down -v
        log_info "Containers and volumes removed"
    else
        log_info "Containers removed, volumes preserved"
    fi
    
    # Удаление директории
    cd "/home"
    rm -rf "${domain}"
    
    # Удаление из crontab
    sed -i "/${domain}_autostart/d" /etc/crontab
    sed -i "/${domain}_renew/d" /etc/crontab
    
    log_info "Site removed successfully!"
}

# Функция показа помощи
show_help() {
    clear
    _line
    _logo
    _header "HELP"
    _br
    printf " ~# Cinematika [OPTION]"; _br; _br;
    printf " OPTIONS:"; _br; _br;
    printf " en        - Fast install EN website"; _br;
    printf " ru        - Fast install RU website"; _br;
    printf " passwd    - Change the password for access to the admin panel"; _br;
    printf " stop      - Stop website (docker container)"; _br;
    printf " start     - Start website (docker container)"; _br;
    printf " restart   - Restart website (docker container)"; _br;
    printf " reload    - Reload website (PM2)"; _br;
    printf " zero      - Delete all data from the automatic database"; _br;
    printf " zero_rt   - Delete all data from the realtime database"; _br;
    printf " logs      - Show all logs"; _br;
    printf " logs live - Show all logs realtime"; _br;
    printf " logs bot  - Show logs for fake and true bots"; _br;
    printf " live bot  - Show realtime logs for fake and true bots"; _br;
    printf " lbf       - Show logs for fake bots"; _br;
    printf " lbt       - Show logs for true bots"; _br;
    printf " lbb       - Show logs for bad bots"; _br;
    printf " crash     - Getting debug information after a site crash"; _br;
    printf " bench     - System info, I/O test and speedtest"; _br;
    printf " actual    - Updating data from an automatic database"; _br;
    printf "             to a manual database (year, list of actors, list"; _br;
    printf "             of genres, list of countries, list of directors,"; _br;
    printf "             premiere date, rating and number of votes)"; _br;
    printf " clear_vps - Complete deletion of all data on the VPS"; _br;
    printf " install|i - Install website"; _br;
    printf " update|u  - Update website"; _br;
    printf " backup|b  - Backup website"; _br;
    printf " theme|t   - Change theme"; _br;
    printf " database|d - Database operations"; _br;
    printf " https|h   - Setup HTTPS/SSL"; _br;
    printf " mirror|m  - Create mirror"; _br;
    printf " remove|r  - Remove website"; _br;
    printf " help|H    - Show this help"; _br;
    _br
    printf " EXAMPLES:"; _br; _br;
    printf " Cinematika install example.com en default mypassword"; _br;
    printf " Cinematika update example.com"; _br;
    printf " Cinematika backup example.com full"; _br;
    printf " Cinematika https example.com admin@example.com api_key"; _br;
    _br
    _line
    _br
}

# Функция успешной установки
success_install() {
    clear
    _line
    _logo
    _header "INSTALLATION COMPLETE"
    _content
    _content "${G}✓${NC} Cinematika has been successfully installed!"
    _content
    _content "${G}🌐${NC} Your website is available at:"
    _content "   http://${CP_DOMAIN}"
    _content
    _content "${G}🔐${NC} Admin panel:"
    _content "   http://${CP_DOMAIN}/admin"
    _content "   Login: admin"
    _content "   Password: ${CP_PASSWD}"
    _content
    _content "${G}📋${NC} Useful commands:"
    _content "   Cinematika start ${CP_DOMAIN}    - Start website"
    _content "   Cinematika stop ${CP_DOMAIN}     - Stop website"
    _content "   Cinematika restart ${CP_DOMAIN}  - Restart website"
    _content "   Cinematika logs ${CP_DOMAIN}     - View logs"
    _content
    _content "${G}📧${NC} Support:"
    _content "   https://Cinematika.com/support"
    _content
    _line
    _br
}

# Основной цикл
WHILE=0
while [ "${WHILE}" -lt "2" ]; do
    WHILE=$((${WHILE}+1))
    
    case ${OPTION} in
        "i"|"install"|1 )
            read_domain "${2}"
            sh_yes "${5}"
            read_lang "${3}"
            read_theme "${4}"
            read_password "${5}"
            _s "${5}"
            sh_progress
            docker_install
            ip_install
            1_install "${CP_DOMAIN}" "${CP_LANG}" "${CP_THEME}" "${CP_PASSWD}"
            sh_progress 100
            success_install
            post_commands
            exit 0
        ;;
        "u"|"update"|2 )
            read_domain "${2}"
            sh_not
            _s "${2}"
            sh_progress
            docker_install
            2_update "${CP_DOMAIN}" "${3}" "${4}" "${5}" "${6}"
            sh_progress 100
            post_commands
            exit 0
        ;;
        "b"|"backup"|3 )
            read_domain "${2}"
            sh_not
            _s "${2}"
            sh_progress
            3_backup "${CP_DOMAIN}" "${3}" "${4}" "${5}" "${6}" "${7}"
            sh_progress 100
            exit 0
        ;;
        "t"|"theme"|4 )
            read_domain "${2}"
            sh_not
            read_theme "${3}"
            _s "${3}"
            sh_progress
            4_theme "${CP_DOMAIN}" "${CP_THEME}" "${4}"
            sh_progress 100
            exit 0
        ;;
        "d"|"database"|5 )
            read_domain "${2}"
            sh_not
            read_key "${3}"
            _s "${3}"
            5_database "${CP_DOMAIN}" "${CP_KEY}"
            exit 0
        ;;
        "h"|"https"|6 )
            read_domain "${2}"
            sh_not
            read_cloudflare_email "${3}"
            read_cloudflare_api_key "${4}"
            _s "${4}"
            6_https "${CP_DOMAIN}" "${CLOUDFLARE_EMAIL}" "${CLOUDFLARE_API_KEY}" "${5}"
            post_commands
            exit 0
        ;;
        "m"|"mirror"|7 )
            read_domain "${2}"
            read_mirror "${3}"
            _s "${3}"
            sh_progress
            7_mirror "${CP_DOMAIN}" "${CP_MIRROR}"
            sh_progress 100
            exit 0
        ;;
        "r"|"rm"|"remove"|8 )
            read_domain "${2}"
            sh_not
            _s "${2}"
            sh_progress
            8_remove "${CP_DOMAIN}" "${3}" "${4}"
            sh_progress 100
            exit 0
        ;;
        "en"|"ru" )
            ip_install "${1}"
            exit 0
        ;;
        "passwd" )
            _br "${3}"
            read_domain "${2}"
            sh_not
            read_password "${3}"
            _s "${3}"
            sh_progress
            docker exec "${CP_DOMAIN_}" /usr/bin/Cinematika container "${1}" "${CP_PASSWD}" \
                >>/var/log/docker_passwd_"$(date '+%d_%m_%Y')".log 2>&1
            sh_progress
            docker exec nginx nginx -s reload \
                >>/var/log/docker_passwd_"$(date '+%d_%m_%Y')".log 2>&1
            sh_progress 100
            exit 0
        ;;
        "images" )
            _header "IMAGES"
            _content
            docker images | grep Cinematika
            _br
            exit 0
        ;;
        "ps" )
            _header "CONTAINERS"
            _content
            docker ps | grep Cinematika
            _br
            exit 0
        ;;
        "start" )
            read_domain "${2}"
            cd "/home/${CP_DOMAIN}"
            docker-compose start
            exit 0
        ;;
        "stop" )
            read_domain "${2}"
            cd "/home/${CP_DOMAIN}"
            docker-compose stop
            exit 0
        ;;
        "restart" )
            read_domain "${2}"
            cd "/home/${CP_DOMAIN}"
            docker-compose restart
            exit 0
        ;;
        "logs" )
            read_domain "${2}"
            if [ "${3}" = "live" ]; then
                cd "/home/${CP_DOMAIN}"
                docker-compose logs -f
            else
                cd "/home/${CP_DOMAIN}"
                docker-compose logs
            fi
            exit 0
        ;;
        "help"|"H"|"--help"|"-h"|"-H" )
            show_help
            exit 0
        ;;
        * )
            if [ "${WHILE}" -eq "1" ]; then
                show_help
                exit 1
            fi
            ;;
    esac
done