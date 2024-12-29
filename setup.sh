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

echo "Success!"
