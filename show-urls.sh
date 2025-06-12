#!/bin/bash

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Емодзі
GLOBE="🌐"
DATABASE="🗄️"
EMAIL="📧"
TOOLS="🛠️"
INFO="ℹ️"
SUCCESS="✅"
WARNING="⚠️"
ROCKET="🚀"

# Завантажуємо змінні з .env файлу
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | grep '=' | xargs) 2>/dev/null
fi

# Функція для перевірки доступності порту
check_port() {
    local port=$1
    local host=${2:-localhost}
    timeout 3 bash -c "</dev/tcp/$host/$port" &>/dev/null
    return $?
}

# Функція для перевірки статусу контейнера
check_container() {
    local container_name=$1
    docker-compose ps -q $container_name 2>/dev/null | xargs docker inspect -f '{{.State.Status}}' 2>/dev/null
}

# Заголовок
echo -e "${WHITE}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${ROCKET} WordPress Docker Environment - Service URLs${NC}"
echo -e "${WHITE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Перевірка чи запущені контейнери
echo -e "${BLUE}${INFO} Статус контейнерів:${NC}"
echo "─────────────────────────────────"

services=("mysql" "wordpress" "caddy" "redis" "adminer" "mailhog")
all_running=true

for service in "${services[@]}"; do
    status=$(check_container $service)
    if [ "$status" = "running" ]; then
        echo -e "  ${GREEN}${SUCCESS} $service${NC} - запущено"
    else
        echo -e "  ${RED}${WARNING} $service${NC} - не запущено"
        all_running=false
    fi
done

echo ""

if [ "$all_running" = false ]; then
    echo -e "${YELLOW}${WARNING} Деякі сервіси не запущені. Запустіть: ${WHITE}docker-compose up -d${NC}"
    echo ""
fi

# Основні сервіси
echo -e "${BLUE}${GLOBE} Веб-сервіси:${NC}"
echo "─────────────────────────────────"

# WordPress
if check_port 443; then
    echo -e "  ${GREEN}WordPress (HTTPS):${NC} https://localhost"
    echo -e "  ${GREEN}WordPress (HTTP):${NC}  http://localhost ${YELLOW}(перенаправлення на HTTPS)${NC}"
else
    echo -e "  ${RED}WordPress:${NC} https://localhost ${RED}(недоступно)${NC}"
fi

echo ""

# Інструменти адміністрування
echo -e "${BLUE}${DATABASE} Адміністрування:${NC}"
echo "─────────────────────────────────"

# Adminer
if check_port 8080; then
    echo -e "  ${GREEN}Adminer (База даних):${NC} http://localhost:8080"
    echo -e "    ${CYAN}├─ Сервер:${NC} mysql"
    echo -e "    ${CYAN}├─ Користувач:${NC} ${MYSQL_USER:-wp_user}"
    echo -e "    ${CYAN}├─ База даних:${NC} ${MYSQL_DATABASE:-wordpress_db}"
    echo -e "    ${CYAN}└─ Пароль:${NC} (з .env файлу)"
else
    echo -e "  ${RED}Adminer:${NC} http://localhost:8080 ${RED}(недоступно)${NC}"
fi

echo ""

# MailHog
echo -e "${BLUE}${EMAIL} Тестування пошти:${NC}"
echo "─────────────────────────────────"

if check_port 8025; then
    echo -e "  ${GREEN}MailHog (Веб-інтерфейс):${NC} http://localhost:8025"
    echo -e "  ${GREEN}SMTP сервер:${NC} localhost:1025"
    echo -e "    ${CYAN}└─ Для WordPress плагінів:${NC} Host: localhost, Port: 1025"
else
    echo -e "  ${RED}MailHog:${NC} http://localhost:8025 ${RED}(недоступно)${NC}"
fi

echo ""

# MySQL прямий доступ
echo -e "${BLUE}${DATABASE} Пряме підключення до MySQL:${NC}"
echo "─────────────────────────────────"

if check_port 3307; then
    echo -e "  ${GREEN}MySQL:${NC} localhost:3307"
    echo -e "    ${CYAN}├─ Root пароль:${NC} ${MYSQL_ROOT_PASSWORD:-'(з .env файлу)'}"
    echo -e "    ${CYAN}├─ Користувач:${NC} ${MYSQL_USER:-wp_user}"
    echo -e "    ${CYAN}├─ База даних:${NC} ${MYSQL_DATABASE:-wordpress_db}"
    echo -e "    ${CYAN}└─ Команда підключення:${NC} mysql -h localhost -P 3307 -u ${MYSQL_USER:-wp_user} -p"
else
    echo -e "  ${RED}MySQL:${NC} localhost:3307 ${RED}(недоступно)${NC}"
fi

echo ""

# Корисні команди
echo -e "${BLUE}${TOOLS} Корисні команди:${NC}"
echo "─────────────────────────────────"
echo -e "  ${CYAN}Логи всіх сервісів:${NC}     docker-compose logs -f"
echo -e "  ${CYAN}Логи конкретного сервісу:${NC} docker-compose logs -f wordpress"
echo -e "  ${CYAN}Перезапуск:${NC}             docker-compose restart"
echo -e "  ${CYAN}Зупинка:${NC}                docker-compose down"
echo -e "  ${CYAN}Повний перезапуск:${NC}      docker-compose down && docker-compose up -d"
echo -e "  ${CYAN}Очистка volume:${NC}         docker-compose down -v"
echo -e "  ${CYAN}Оновлення образів:${NC}      docker-compose pull && docker-compose up -d"

echo ""

# Інформація про файли
echo -e "${BLUE}${INFO} Директорії проекту:${NC}"
echo "─────────────────────────────────"
echo -e "  ${CYAN}wp-content/${NC}           - Весь контент WordPress"
echo -e "  ${CYAN}wp-content/themes/${NC}    - Кастомні теми WordPress"
echo -e "  ${CYAN}wp-content/plugins/${NC}   - Кастомні плагіни WordPress"
echo -e "  ${CYAN}wp-content/uploads/${NC}   - Завантажені медіафайли"
echo -e "  ${CYAN}.data/${NC}               - Дані контейнерів (БД, файли WP, кеш)"
echo -e "  ${CYAN}.env${NC}                 - Змінні середовища"
echo -e "  ${CYAN}Caddyfile${NC}            - Конфігурація веб-сервера"

echo ""

# Налаштування WordPress
echo -e "${BLUE}${INFO} Налаштування WordPress:${NC}"
echo "─────────────────────────────────"
echo -e "  ${CYAN}URL сайту:${NC}              https://localhost"
echo -e "  ${CYAN}Префікс таблиць:${NC}        ${WORDPRESS_TABLE_PREFIX:-wp_}"
echo -e "  ${CYAN}Debug режим:${NC}            ${WORDPRESS_DEBUG:-0}"
echo -e "  ${CYAN}Redis кеш:${NC}              Увімкнено"
echo -e "  ${CYAN}Файли WordPress:${NC}        .data/wordpress/"
echo -e "  ${CYAN}Кастомний контент:${NC}      wp-content/"

echo ""

# Перевірка структури файлів
echo -e "${BLUE}${INFO} Структура wp-content:${NC}"
echo "─────────────────────────────────"
if [ -d "wp-content" ]; then
    themes_count=$(find wp-content/themes -maxdepth 1 -type d 2>/dev/null | wc -l)
    plugins_count=$(find wp-content/plugins -maxdepth 1 -type d 2>/dev/null | wc -l)
    uploads_size=$(du -sh wp-content/uploads 2>/dev/null | cut -f1 || echo "0")
    
    echo -e "  ${GREEN}${SUCCESS} wp-content створено${NC}"
    echo -e "  ${CYAN}├─ Теми:${NC} $((themes_count-1)) папок"
    echo -e "  ${CYAN}├─ Плагіни:${NC} $((plugins_count-1)) папок"
    echo -e "  ${CYAN}└─ Завантаження:${NC} ${uploads_size}"
else
    echo -e "  ${RED}${WARNING} wp-content не знайдено${NC}"
    echo -e "  ${YELLOW}Запустіть setup.sh або створіть вручну${NC}"
fi

echo ""

# Безпека
if [[ "${MYSQL_ROOT_PASSWORD}" == "12345" ]] || [[ "${MYSQL_PASSWORD}" == "123" ]]; then
    echo -e "${RED}${WARNING} УВАГА: Використовуються небезпечні паролі за замовчуванням!${NC}"
    echo -e "${YELLOW}  Змініть паролі в .env файлі для продакшену${NC}"
    echo ""
fi

# SSL інформація
echo -e "${BLUE}${INFO} SSL сертифікат:${NC}"
echo "─────────────────────────────────"
if [[ "${DOMAIN:-localhost}" == "localhost" ]]; then
    echo -e "  ${YELLOW}Самопідписний сертифікат для розробки${NC}"
    echo -e "  ${CYAN}Для продакшену:${NC} замініть 'localhost' в Caddyfile на ваш домен"
    echo -e "  ${CYAN}Caddy автоматично отримає SSL від Let's Encrypt${NC}"
else
    echo -e "  ${GREEN}Домен:${NC} ${DOMAIN}"
    echo -e "  ${CYAN}Caddy автоматично керує SSL сертифікатом${NC}"
fi

echo ""
echo -e "${WHITE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${SUCCESS} Готово до роботи! Відкрийте https://localhost для початку${NC}"
echo -e "${WHITE}════════════════════════════════════════════════════════════${NC}"