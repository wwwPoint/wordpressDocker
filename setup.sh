#!/bin/bash
set -e  # Зупиняти скрипт при помилках

# Функція для перевірки доступності порту
check_port() {
    local port=$1
    timeout 1 bash -c "</dev/tcp/localhost/$port" &>/dev/null
    return $?
}

# Завантажуємо змінні з .env файлу
if [ -f .env ]; then
    echo "Знайдено .env файл"
    export $(cat .env | grep -v '#' | awk '/=/ {print $1}')
    
    # Додаємо діагностичний вивід
    echo "Завантажені змінні з .env:"
    echo "DOMAIN_NAME = ${DOMAIN_NAME}"
    echo "MYSQL_USER = ${MYSQL_USER}"
    echo "MYSQL_DATABASE = ${MYSQL_DATABASE}"
fi

# Додати перевірку наявності Docker
if ! command -v docker &> /dev/null; then
    echo "Docker не встановлено. Будь ласка, встановіть Docker спочатку."
    exit 1
fi

# Додати функцію очистки при виході
cleanup() {
    if [ $? -ne 0 ]; then
        echo "Сталася помилка. Очищення..."
        rm -rf .srv nginx themes plugins 2>/dev/null
    fi
}
trap cleanup EXIT

# Додати перевірку наявності SSL сертифікатів
if [ ! -f "nginx/ssl/cert.pem" ] || [ ! -f "nginx/ssl/key.pem" ]; then
    echo "Генерування self-signed SSL сертифікатів..."
    mkdir -p nginx/ssl
    
    # Виправлена команда для localhost
    MSYS_NO_PATHCONV=1 openssl req -x509 \
        -nodes \
        -days 365 \
        -newkey rsa:2048 \
        -keyout nginx/ssl/key.pem \
        -out nginx/ssl/cert.pem \
        -subj "/C=UA/ST=State/L=City/O=Organization/CN=localhost" \
        -addext "subjectAltName=DNS:localhost"
fi

# Створення необхідних директорій
mkdir -p .srv/database
mkdir -p .srv/wordpress
mkdir -p nginx/conf.d
mkdir -p nginx/ssl
mkdir -p nginx/logs
mkdir -p themes
mkdir -p plugins

# Створення конфігурації Nginx
cat > nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
EOF

echo "Налаштування MySQL параметрів"
echo "----------------------------"

# Функція для валідації введених даних
validate_input() {
    if [ -z "$1" ]; then
        echo "Помилка: значення не може бути пустим"
        exit 1
    fi
}

# Запитуємо значення з валідацією
while true; do
    read -p "Введіть ПАРОЛЬ для root користувача MySQL: " root_password
    validate_input "$root_password"
    if [ $? -eq 0 ]; then break; fi
done

while true; do
    read -p "Введіть НАЗВУ БАЗИ даних: " database
    validate_input "$database"
    if [ $? -eq 0 ]; then break; fi
done

while true; do
    read -p "Введіть ІМ'Я користувача MySQL: " user
    validate_input "$user"
    if [ $? -eq 0 ]; then break; fi
done

while true; do
    read -p "Введіть ПАРОЛЬ для користувача MySQL: " password
    validate_input "$password"
    if [ $? -eq 0 ]; then break; fi
done

# Додані нові цикли
while true; do
    read -p "Введіть ПРЕФІКС таблиць WordPress (wp_): " table_prefix
    table_prefix=${table_prefix:-wp_}
    validate_input "$table_prefix"
    if [ $? -eq 0 ]; then break; fi
done

while true; do
    read -p "Введіть режим налагодження WordPress (0/1): " debug_mode
    debug_mode=${debug_mode:-0}
    if [[ "$debug_mode" =~ ^[0-1]$ ]]; then break; fi
    echo "Помилка: введіть 0 або 1"
done

# Створюємо .env файл
cat > .env << EOF
MYSQL_ROOT_PASSWORD=${root_password}
MYSQL_DATABASE=${database}
MYSQL_USER=${user}
MYSQL_PASSWORD=${password}
WORDPRESS_TABLE_PREFIX=${table_prefix}
WORDPRESS_DEBUG=${debug_mode}
EOF

# Перезавантажуємо змінні з нового .env файлу
export $(cat .env | grep -v '#' | awk '/=/ {print $1}')

echo "Файл .env успішно створено!"
echo "============================"
echo "Запускаємо docker-compose..."

# Запускаємо docker-compose
docker-compose up -d

# Очікуємо поки всі сервіси запустяться
echo "Очікуємо запуску сервісів..."
sleep 10

# Виводимо інформацію про доступні сервіси
echo ""
echo "=== Доступні сервіси ==="
echo "WordPress:"
echo "🌐 http://localhost"
echo "🔒 https://localhost"

if check_port 8080; then
    echo ""
    echo "Adminer (управління базою даних):"
    echo "🗄️  http://localhost:8080"
    echo "   Сервер: mysql"
    echo "   Користувач: ${MYSQL_USER}"
    echo "   База даних: ${MYSQL_DATABASE}"
fi

if check_port 8025; then
    echo ""
    echo "MailHog (тестування пошти):"
    echo "📧 http://localhost:8025"
    echo "   SMTP: localhost:1025"
fi

echo ""
echo "✅ Всі сервіси запущено успішно!"
