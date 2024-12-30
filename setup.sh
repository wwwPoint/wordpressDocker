#!/bin/bash
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

# Створюємо .env файл
cat > .env << EOF
MYSQL_ROOT_PASSWORD=${root_password}
MYSQL_DATABASE=${database}
MYSQL_USER=${user}
MYSQL_PASSWORD=${password}
EOF

echo "Файл .env успішно створено!"
echo "============================"
echo "Запускаємо docker-compose..."

# Запускаємо docker-compose
docker-compose up -d
