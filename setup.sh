#!/bin/bash
set -e

echo "🚀 WordPress Docker Setup з Caddy"
echo "=================================="

# Перевірка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не встановлено. Встановіть Docker спочатку."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose не встановлено."
    exit 1
fi

# Функція очистки
cleanup() {
    if [ $? -ne 0 ]; then
        echo "❌ Помилка встановлення. Очищення..."
        docker-compose down 2>/dev/null || true
        rm -rf .data wp-content 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Створення необхідних директорій
echo "📁 Створення директорій..."
mkdir -p .data/{mysql,wordpress,redis,caddy,caddy-config}
# ЗМІНЕНО: створюємо wp-content замість окремих themes/plugins
mkdir -p wp-content/{themes,plugins,uploads}

# Налаштування змінних середовища
if [ ! -f .env ]; then
    echo "⚙️  Налаштування змінних середовища..."
    
    # Функція для безпечного введення
    read_secure() {
        local prompt=$1
        local var_name=$2
        local default_val=$3
        
        if [ -n "$default_val" ]; then
            read -p "$prompt [$default_val]: " input
            eval "$var_name=\${input:-$default_val}"
        else
            while true; do
                read -p "$prompt: " input
                if [ -n "$input" ]; then
                    eval "$var_name=$input"
                    break
                else
                    echo "❌ Значення не може бути пустим!"
                fi
            done
        fi
    }
    
    # Збираємо дані
    read_secure "MySQL Root пароль" MYSQL_ROOT_PASSWORD
    read_secure "Назва бази даних" MYSQL_DATABASE "wordpress_db"
    read_secure "MySQL користувач" MYSQL_USER "wp_user"  
    read_secure "MySQL пароль користувача" MYSQL_PASSWORD
    read_secure "Префікс таблиць WordPress" WORDPRESS_TABLE_PREFIX "wp_"
    read_secure "WordPress Debug (0/1)" WORDPRESS_DEBUG "0"
    read_secure "Домен" DOMAIN "localhost"
    
    # Створюємо .env файл
    cat > .env << EOF
# MySQL налаштування
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

# WordPress налаштування
WORDPRESS_TABLE_PREFIX=$WORDPRESS_TABLE_PREFIX
WORDPRESS_DEBUG=$WORDPRESS_DEBUG

# Домен
DOMAIN=$DOMAIN
EOF
    
    echo "✅ Файл .env створено!"
fi

# Завантаження змінних
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Створення Caddyfile якщо не існує
if [ ! -f Caddyfile ]; then
    echo "📝 Створення Caddyfile..."
    cat > Caddyfile << 'EOF'
localhost {
    tls internal
    root * /var/www/html
    file_server
    php_fastcgi wordpress:9000 {
        index index.php
    }
    try_files {path} {path}/ /index.php?{query}
    
    @static {
        file
        path *.css *.js *.ico *.png *.jpg *.jpeg *.gif *.svg *.woff *.woff2 *.ttf *.eot
    }
    header @static Cache-Control "public, max-age=31536000"
    
    @forbidden {
        path /.* /wp-config.php /readme.html /license.txt
    }
    respond @forbidden 403
    
    header {
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
fi

# ДОДАНО: Створення базового .htaccess для WordPress
if [ ! -f wp-content/.htaccess ]; then
    echo "📝 Створення .htaccess..."
    cat > wp-content/.htaccess << 'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF
fi

# ДОДАНО: Створення індексного файлу для безпеки
echo "<?php // Silence is golden" > wp-content/index.php

# Запуск Docker Compose
echo "🐳 Запуск Docker контейнерів..."
docker-compose up -d

# Очікування запуску сервісів
echo "⏳ Очікування запуску сервісів..."
sleep 10

# Перевірка статусу
echo "🔍 Перевірка статусу сервісів..."
docker-compose ps

echo ""
echo "🎉 Встановлення завершено!"
echo "=========================="
echo ""
echo "📍 Доступні сервіси:"
echo "🌐 WordPress: https://localhost"
echo "🗄️  Adminer: http://localhost:8080"
echo "   - Сервер: mysql"
echo "   - Користувач: $MYSQL_USER"
echo "   - База даних: $MYSQL_DATABASE"
echo "📧 MailHog: http://localhost:8025"
echo "   - SMTP: localhost:1025"
echo ""
echo "🛠️  Корисні команди:"
echo "   docker-compose logs -f    # Перегляд логів"
echo "   docker-compose down       # Зупинка сервісів"
echo "   docker-compose restart    # Перезапуск"
echo ""
echo "📁 Директорії:"
echo "   wp-content/themes/   - Ваші теми WordPress"
echo "   wp-content/plugins/  - Ваші плагіни WordPress"
echo "   wp-content/uploads/  - Завантажені файли"
echo "   .data/               - Дані контейнерів"

# Зняття trap після успішного завершення
trap - EXIT