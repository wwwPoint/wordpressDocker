# WordPress Docker Environment 🚀

Повнофункціональне середовище розробки WordPress з Docker, Caddy веб-сервером, MySQL, Redis кешуванням та інструментами для розробки.

## ✨ Особливості

- **WordPress** з PHP-FPM на Alpine Linux
- **Caddy** веб-сервер з автоматичним SSL
- **MySQL 8.0** база даних
- **Redis** для кешування
- **Adminer** для управління базою даних
- **MailHog** для тестування електронної пошти
- **Автоматична міграція** на продакшн сервер
- **Оптимізована** конфігурація для розробки

## 📋 Вимоги

- Docker 20.10+
- Docker Compose 2.0+
- Bash (для скриптів)

## 🚀 Швидкий старт

### 1. Клонування репозиторію

```bash
git clone <your-repo-url>
cd wordpress-docker-environment
```

### 2. Запуск встановлення

```bash
chmod +x setup.sh
./setup.sh
```

Скрипт автоматично:
- Створить необхідні директорії
- Налаштує змінні середовища
- Створить конфігураційні файли
- Запустить Docker контейнери

### 3. Доступ до сервісів

## 🌐 Доступні сервіси

| Сервіс | URL | Опис |
|--------|-----|------|
| **WordPress** | https://localhost | Основний сайт |
| **Adminer** | http://localhost:8080 | Управління БД |
| **MailHog** | http://localhost:8025 | Тестування пошти |
| **MySQL** | localhost:3307 | Пряме підключення до БД |

## 📁 Структура проекту

```
.
├── docker-compose.yml          # Конфігурація Docker Compose
├── setup.sh                   # Скрипт встановлення
├── show-urls.sh               # Показує URL всіх сервісів
├── migrate-to-production.sh   # Скрипт міграції на продакшн
├── Caddyfile                  # Конфігурація Caddy веб-сервера
├── .env                       # Змінні середовища (створюється при встановленні)
├── wp-content/                # WordPress контент
│   ├── themes/               # Кастомні теми
│   ├── plugins/              # Кастомні плагіни
│   └── uploads/              # Завантажені файли
└── .data/                    # Дані контейнерів
    ├── mysql/               # Дані MySQL
    ├── wordpress/           # Файли WordPress
    ├── redis/               # Дані Redis
    └── caddy/               # Дані Caddy (SSL сертифікати)
```

## ⚙️ Конфігурація

### Змінні середовища (.env)

```env
# MySQL налаштування
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wp_user
MYSQL_PASSWORD=your_user_password

# WordPress налаштування
WORDPRESS_TABLE_PREFIX=wp_
WORDPRESS_DEBUG=0
```

### Налаштування домену

Для розробки використовується `localhost`. Для зміни домену відредагуйте `Caddyfile`:

```caddyfile
your-domain.com {
    tls internal
    # ... решта конфігурації
}
```

## 🐳 Docker сервіси

| Сервіс    | Порт  | Опис                          |
|-----------|-------|-------------------------------|
| WordPress | 80,443| WordPress сайт                |
| MySQL     | 3307  | База даних                    |
| Adminer   | 8080  | Веб-інтерфейс для БД          |
| MailHog   | 8025  | Веб-інтерфейс для пошти       |
| MailHog   | 1025  | SMTP сервер                   |
| Redis     | -     | Кеш (внутрішня мережа)        |

## 📊 Корисні команди

### Перегляд статусу та URL

```bash
chmod +x show-urls.sh
./show-urls.sh
```

### Управління контейнерами

```bash
# Запуск всіх сервісів
docker-compose up -d

# Зупинка всіх сервісів
docker-compose down

# Перезапуск конкретного сервісу
docker-compose restart wordpress

# Перегляд логів
docker-compose logs -f
docker-compose logs -f wordpress

# Оновлення образів
docker-compose pull
docker-compose up -d
```

### Робота з базою даних

```bash
# Підключення до MySQL через Docker
docker-compose exec mysql mysql -u root -p

# Бекап бази даних
docker-compose exec mysql mysqldump -u root -p wordpress_db > backup.sql

# Відновлення з бекапу
docker-compose exec -T mysql mysql -u root -p wordpress_db < backup.sql
```

## 🔩 Додаткові налаштування

```php
// Додайте до wp-config.php
define('WP_CACHE', true);
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', 6379);
```


## 🚀 Міграція на продакшн

Для міграції сайту на продакшн сервер використовуйте спеціальний скрипт:

```bash
chmod +x migrate-to-production.sh
./migrate-to-production.sh
```

### Що робить скрипт міграції:

1. **Безпечна робота**: Не змінює локальну базу даних
2. **Створює тимчасову БД** з оновленими URL
3. **Генерує продакшн дамп** бази даних
4. **Архівує wp-content** (теми, плагіни, медіа)
5. **Створює інструкції** для розгортання
6. **Очищує тимчасові файли**

### Файли міграції:

- `database_production.sql` - БД з оновленими URL
- `wp-content-domain-date.zip/tar.gz` - Архів контенту
- `DEPLOYMENT_INSTRUCTIONS.txt` - Детальні інструкції

## 🔧 Налаштування WordPress

### Рекомендовані плагіни

- **Redis Object Cache** - для роботи з Redis
- **WP Super Cache** - додаткове кешування
- **Yoast SEO** - SEO оптимізація
- **Wordfence Security** - безпека

### Оптимізація продуктивності

Середовище вже налаштоване для оптимальної продуктивності:

- PHP-FPM з Alpine Linux
- Redis кешування
- Оптимізовані налаштування MySQL
- Gzip стиснення через Caddy
- Кешування статичних файлів

## 📧 Тестування електронної пошти

MailHog перехоплює всю вихідну пошту WordPress:

1. Відкрийте http://localhost:8025
2. WordPress автоматично використовує localhost:1025 як SMTP
3. Всі листи будуть відображатися в MailHog інтерфейсі

## 🔒 Безпека

### Для розробки:
- Самопідписні SSL сертифікати. 
Потріен `./.data/caddy/caddy/pki/authorities/local/root.crt`, Клік правою клавішою ➡️ інсталювати сертифікат ➡️ Локальний комп'ютер ➡️ Розташувати всі сертифікати в такому сховищі  ➡️ Довірені кореневі центри сертифікації
- Внутрішня мережа Docker
- Обмежений доступ до файлів

### Для продакшну:
- Змініть всі паролі в `.env`
- Оновіть WordPress salt ключі
- Налаштуйте фаєрвол
- Використовуйте реальні SSL сертифікати

## 🪲 Усунення проблем

### Порти зайняті

```bash
# Перевірити зайняті порти
sudo lsof -i :80,443,3307,8080,8025

# Зупинити інші веб-сервери
sudo systemctl stop apache2 nginx
```

### Проблеми з дозволами

```bash
# Налаштувати дозволи для wp-content
sudo chown -R $(whoami):$(whoami) wp-content/
chmod -R 755 wp-content/
```

### MySQL не запускається

```bash
# Очистити дані MySQL (УВАГА: видалить всі дані!)
docker-compose down
sudo rm -rf .data/mysql/
docker-compose up -d
```

### SSL сертифікат не працює

```bash
# Очистити дані Caddy
docker-compose down
sudo rm -rf .data/caddy/
docker-compose up -d
```

## 📚 Додаткові ресурси

- [WordPress Developer Handbook](https://developer.wordpress.org/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Caddy Web Server](https://caddyserver.com/docs/)
- [MySQL 8.0 Reference](https://dev.mysql.com/doc/refman/8.0/en/)

## 🤝 Підтримка

При виникненні проблем:

1. Перевірте логи: `docker-compose logs -f`
2. Переконайтеся, що всі порти вільні
3. Перевірте права доступу до файлів
4. Перезапустіть контейнери: `docker-compose restart`

## 📄 Ліцензія

Цей проект використовує MIT ліцензію. Детальніше див. файл LICENSE.

---

**Зроблено з ❤️ для WordPress розробників**