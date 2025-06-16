#!/bin/bash
set -e

echo "🚀 WordPress Migration Script"
echo "============================="

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функція для виводу кольорових повідомлень
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Перевірка наявності необхідних файлів
check_requirements() {
    print_status "Перевірка вимог..."
    
    if [ ! -f .env ]; then
        print_error "Файл .env не знайдено!"
        exit 1
    fi
    
    if [ ! -f docker-compose.yml ]; then
        print_error "Файл docker-compose.yml не знайдено!"
        exit 1
    fi
    
    if [ ! -d wp-content ]; then
        print_error "Директорія wp-content не знайдена!"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker не встановлено!"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose не встановлено!"
        exit 1
    fi
    
    # Перевіряємо наявність архіваторів
    if command -v zip &> /dev/null; then
        print_success "ZIP архіватор доступний"
    elif command -v tar &> /dev/null; then
        print_warning "ZIP недоступний, буде використано TAR.GZ"
    else
        print_error "Жоден архіватор не знайдено (zip або tar)!"
        exit 1
    fi
    
    print_success "Всі вимоги виконано"
}

# Завантаження змінних середовища
load_env() {
    print_status "Завантаження змінних середовища..."
    export $(cat .env | grep -v '^#' | xargs)
    print_success "Змінні середовища завантажено"
}

# Отримання нового домену від користувача
get_new_domain() {
    while true; do
        read -p "🌐 Введіть новий домен (наприклад: candyshop.com або example.ex): " NEW_DOMAIN
        
        if [ -z "$NEW_DOMAIN" ]; then
            print_error "Домен не може бути пустим! Спробуйте ще раз."
            continue
        fi
        
        # Очищуємо введення від пробілів та протоколів (якщо користувач випадково ввів)
        NEW_DOMAIN=$(echo "$NEW_DOMAIN" | xargs | sed -E 's|^https?://||' | sed 's|/$||')
        
        # Перевіряємо формат домену (підтримка піддоменів)
        if [[ "$NEW_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] && [[ "$NEW_DOMAIN" == *.* ]]; then
            break
        else
            print_error "Невірний формат домену! Приклади правильних доменів:"
            print_error "  - candyshop.com"
            print_error "  - subdomain.example.com"
            print_error "  - my-site.co.uk"
        fi
    done
    
    OLD_DOMAIN="localhost"
    
    print_success "Домен встановлено:"
    print_success "  Старий: $OLD_DOMAIN"
    print_success "  Новий:  $NEW_DOMAIN"
}

# Перевірка статусу контейнерів
check_containers() {
    print_status "Перевірка статусу контейнерів..."
    
    if ! docker-compose ps | grep -q "Up"; then
        print_warning "Контейнери не запущені. Запускаємо..."
        docker-compose up -d
        sleep 10
    fi
    
    # Перевірка, чи MySQL готовий
    print_status "Очікування готовності MySQL..."
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if docker-compose exec -T mysql mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD &>/dev/null; then
            print_success "MySQL готовий"
            return 0
        fi
        print_status "MySQL ще не готовий, очікуємо... (спроба $((attempts+1))/$max_attempts)"
        sleep 2
        attempts=$((attempts+1))
    done
    
    print_error "MySQL не відповідає після $max_attempts спроб"
    exit 1
}

# Створення резервної копії бази даних
backup_database() {
    print_status "Створення резервної копії бази даних..."
    
    local backup_dir="migration-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    docker-compose exec -T mysql mysqldump \
        -u root -p$MYSQL_ROOT_PASSWORD \
        --single-transaction \
        --routines \
        --triggers \
        $MYSQL_DATABASE > "$backup_dir/database_original.sql"
    
    if [ $? -eq 0 ]; then
        print_success "Резервна копія створена: $backup_dir/database_original.sql"
        echo "$backup_dir" > .migration_backup_dir
    else
        print_error "Помилка створення резервної копії!"
        exit 1
    fi
}

# Оновлення домену в базі даних
update_domain_in_database() {
    print_status "Оновлення домену в базі даних..."
    
    local backup_dir=$(cat .migration_backup_dir)
    
    # Створюємо SQL скрипт для оновлення домену
    cat > "$backup_dir/update_domain.sql" << EOF
-- Оновлення основних опцій WordPress
UPDATE ${WORDPRESS_TABLE_PREFIX}options 
SET option_value = 'https://$NEW_DOMAIN' 
WHERE option_name IN ('home', 'siteurl');

-- Оновлення контенту в постах
UPDATE ${WORDPRESS_TABLE_PREFIX}posts 
SET post_content = REPLACE(post_content, 'http://localhost', 'https://$NEW_DOMAIN');

UPDATE ${WORDPRESS_TABLE_PREFIX}posts 
SET post_content = REPLACE(post_content, 'https://localhost', 'https://$NEW_DOMAIN');

UPDATE ${WORDPRESS_TABLE_PREFIX}posts 
SET post_content = REPLACE(post_content, '//localhost', '//$NEW_DOMAIN');

-- Оновлення коментарів
UPDATE ${WORDPRESS_TABLE_PREFIX}comments 
SET comment_content = REPLACE(comment_content, 'http://localhost', 'https://$NEW_DOMAIN');

UPDATE ${WORDPRESS_TABLE_PREFIX}comments 
SET comment_content = REPLACE(comment_content, 'https://localhost', 'https://$NEW_DOMAIN');

UPDATE ${WORDPRESS_TABLE_PREFIX}comments 
SET comment_content = REPLACE(comment_content, '//localhost', '//$NEW_DOMAIN');

-- Оновлення мета-даних постів
UPDATE ${WORDPRESS_TABLE_PREFIX}postmeta 
SET meta_value = REPLACE(meta_value, 'http://localhost', 'https://$NEW_DOMAIN')
WHERE meta_value LIKE '%localhost%';

UPDATE ${WORDPRESS_TABLE_PREFIX}postmeta 
SET meta_value = REPLACE(meta_value, 'https://localhost', 'https://$NEW_DOMAIN')
WHERE meta_value LIKE '%localhost%';

UPDATE ${WORDPRESS_TABLE_PREFIX}postmeta 
SET meta_value = REPLACE(meta_value, '//localhost', '//$NEW_DOMAIN')
WHERE meta_value LIKE '%localhost%';

-- Оновлення користувацьких опцій
UPDATE ${WORDPRESS_TABLE_PREFIX}usermeta 
SET meta_value = REPLACE(meta_value, 'http://localhost', 'https://$NEW_DOMAIN')
WHERE meta_value LIKE '%localhost%';

UPDATE ${WORDPRESS_TABLE_PREFIX}usermeta 
SET meta_value = REPLACE(meta_value, 'https://localhost', 'https://$NEW_DOMAIN')
WHERE meta_value LIKE '%localhost%';

UPDATE ${WORDPRESS_TABLE_PREFIX}usermeta 
SET meta_value = REPLACE(meta_value, '//localhost', '//$NEW_DOMAIN')
WHERE meta_value LIKE '%localhost%';

-- Оновлення серіалізованих даних
UPDATE ${WORDPRESS_TABLE_PREFIX}options 
SET option_value = REPLACE(option_value, 's:9:"localhost"', 's:${#NEW_DOMAIN}:"$NEW_DOMAIN"')
WHERE option_value LIKE '%s:9:"localhost"%';

-- Оновлення серіалізованих URL (повних)
UPDATE ${WORDPRESS_TABLE_PREFIX}options 
SET option_value = REPLACE(option_value, 's:17:"https://localhost"', 's:$((${#NEW_DOMAIN}+8)):"https://$NEW_DOMAIN"')
WHERE option_value LIKE '%s:17:"https://localhost"%';

UPDATE ${WORDPRESS_TABLE_PREFIX}options 
SET option_value = REPLACE(option_value, 's:16:"http://localhost"', 's:$((${#NEW_DOMAIN}+8)):"https://$NEW_DOMAIN"')
WHERE option_value LIKE '%s:16:"http://localhost"%';

-- Показуємо результат
SELECT 'Updated URLs:' as Info;
SELECT option_name, option_value 
FROM ${WORDPRESS_TABLE_PREFIX}options 
WHERE option_name IN ('home', 'siteurl');
EOF

    # Виконуємо SQL скрипт
    docker-compose exec -T mysql mysql \
        -u root -p$MYSQL_ROOT_PASSWORD \
        $MYSQL_DATABASE < "$backup_dir/update_domain.sql"
    
    if [ $? -eq 0 ]; then
        print_success "Домен оновлено в базі даних"
    else
        print_error "Помилка оновлення домену в базі даних!"
        exit 1
    fi
}

# Створення дампу оновленої бази даних
create_production_database_dump() {
    print_status "Створення дампу оновленої бази даних..."
    
    local backup_dir=$(cat .migration_backup_dir)
    
    docker-compose exec -T mysql mysqldump \
        -u root -p$MYSQL_ROOT_PASSWORD \
        --single-transaction \
        --routines \
        --triggers \
        $MYSQL_DATABASE > "$backup_dir/database_production.sql"
    
    if [ $? -eq 0 ]; then
        print_success "Продакшн дамп створено: $backup_dir/database_production.sql"
    else
        print_error "Помилка створення продакшн дампу!"
        exit 1
    fi
}

# Архівування wp-content
archive_wp_content() {
    print_status "Архівування wp-content..."
    
    local backup_dir=$(cat .migration_backup_dir)
    local archive_name="wp-content-$NEW_DOMAIN-$(date +%Y%m%d_%H%M%S)"
    
    # Перевіряємо наявність zip
    if command -v zip &> /dev/null; then
        print_status "Використовуємо ZIP архівацію..."
        cd wp-content
        zip -r "../$backup_dir/${archive_name}.zip" . -x "*.DS_Store" "*/.*"
        cd ..
        local final_archive="${archive_name}.zip"
    else
        print_warning "ZIP не знайдено, використовуємо TAR.GZ..."
        tar -czf "$backup_dir/${archive_name}.tar.gz" wp-content/
        local final_archive="${archive_name}.tar.gz"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "wp-content заархівовано: $backup_dir/$final_archive"
        echo "$final_archive" > "$backup_dir/wp_content_archive_name.txt"
    else
        print_error "Помилка архівування wp-content!"
        exit 1
    fi
}

# Створення інструкцій для розгортання
create_deployment_instructions() {
    local backup_dir=$(cat .migration_backup_dir)
    local archive_name=$(cat "$backup_dir/wp_content_archive_name.txt")
    
    cat > "$backup_dir/DEPLOYMENT_INSTRUCTIONS.txt" << EOF
🚀 ІНСТРУКЦІЇ З РОЗГОРТАННЯ WORDPRESS НА ПРОДАКШН СЕРВЕРІ
=======================================================

📁 Файли для завантаження:
- $archive_name (wp-content архів)
- database_production.sql (база даних з оновленим доменом)

🔧 КРОКИ РОЗГОРТАННЯ:

1. Встановіть WordPress на новому сервері ($NEW_DOMAIN)

2. Завантажте файли:
   - Розпакуйте $archive_name в корінь WordPress
   $(if [[ "$archive_name" == *.zip ]]; then echo "   unzip $archive_name"; else echo "   tar -xzf $archive_name"; fi)

3. Імпортуйте базу даних:
   mysql -u username -p database_name < database_production.sql

4. Оновіть wp-config.php з новими налаштуваннями БД

5. Встановіть правильні дозволи:
   chmod -R 755 wp-content/
   chmod -R 644 wp-content/uploads/

6. Оновіть .htaccess (якщо потрібно)

7. Перевірте налаштування кешування та плагінів

📋 ДАНІ МІГРАЦІЇ:
- Оригінальний домен: localhost
- Новий домен: $NEW_DOMAIN
- Дата міграції: $(date)
- Таблиці префікс: $WORDPRESS_TABLE_PREFIX

⚠️  ВАЖЛИВО:
- Перевірте всі URL в контенті після розгортання
- Оновіть налаштування плагінів, що зберігають URL
- Протестуйте функціональність сайту
- Налаштуйте SSL сертифікат для HTTPS

🔒 БЕЗПЕКА:
- Змініть паролі доступу до БД
- Оновіть WordPress salt ключі в wp-config.php
- Встановіть останні версії WordPress та плагінів
EOF

    print_success "Інструкції створено: $backup_dir/DEPLOYMENT_INSTRUCTIONS.txt"
}

# Відкат змін (якщо потрібно)
restore_original_database() {
    print_status "Відкат до оригінальної бази даних..."
    
    local backup_dir=$(cat .migration_backup_dir)
    
    if [ -f "$backup_dir/database_original.sql" ]; then
        docker-compose exec -T mysql mysql \
            -u root -p$MYSQL_ROOT_PASSWORD \
            $MYSQL_DATABASE < "$backup_dir/database_original.sql"
        
        print_success "База даних відновлена до оригінального стану"
    else
        print_error "Оригінальна резервна копія не знайдена!"
    fi
}

# Головна функція
main() {
    echo ""
    print_status "Початок процесу міграції..."
    
    check_requirements
    load_env
    get_new_domain
    
    echo ""
    print_warning "УВАГА: Цей скрипт змінить домен в базі даних!"
    print_warning "Переконайтеся, що у вас є резервна копія!"
    echo ""
    read -p "Продовжити? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Операцію скасовано користувачем"
        exit 0
    fi
    
    check_containers
    backup_database
    update_domain_in_database
    create_production_database_dump
    archive_wp_content
    create_deployment_instructions
    
    local backup_dir=$(cat .migration_backup_dir)
    
    echo ""
    print_success "🎉 МІГРАЦІЯ ЗАВЕРШЕНА УСПІШНО!"
    echo ""
    print_status "📁 Всі файли збережено в: $backup_dir"
    print_status "📋 Прочитайте DEPLOYMENT_INSTRUCTIONS.txt для інструкцій"
    echo ""
    print_warning "💡 Для відкату змін запустіть:"
    echo "   ./migrate-to-production.sh --restore"
    
    # Очищення тимчасових файлів
    rm -f .migration_backup_dir
}

# Функція відкату
restore() {
    print_status "Режим відкату..."
    
    if [ ! -f .env ]; then
        print_error "Файл .env не знайдено!"
        exit 1
    fi
    
    load_env
    check_containers
    
    # Знаходимо останню резервну копію
    local latest_backup=$(ls -1d migration-backup-* 2>/dev/null | tail -1)
    
    if [ -z "$latest_backup" ]; then
        print_error "Резервні копії не знайдено!"
        exit 1
    fi
    
    echo "$latest_backup" > .migration_backup_dir
    restore_original_database
    rm -f .migration_backup_dir
    
    print_success "Відкат завершено!"
}

# Обробка аргументів командного рядка
case "${1:-}" in
    --restore)
        restore
        ;;
    --help|-h)
        echo "Використання: $0 [ОПЦІЇ]"
        echo ""
        echo "ОПЦІЇ:"
        echo "  --restore    Відкат до оригінальної бази даних"
        echo "  --help, -h   Показати цю довідку"
        echo ""
        echo "Без параметрів: запустити процес міграції"
        ;;
    *)
        main
        ;;
esac