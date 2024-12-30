1. В "Git Bash" запустити скрипт для створення директорій:

```bash
./setup.sh

якщо не працює, то запустити в такому пордку:
a. chmod +x setup.sh
b. ./setup.sh
```

<!-- ============================================ -->

2. Запустити проект:

```bash
docker compose up -d

docker compose up -d --build # якщо потрібно перебудувати проект
docker compose up -d --build --force-recreate # якщо потрібно перебудувати проект і перезапустити контейнери
docker compose up -d --force-recreate # якщо потрібно перезапустити контейнери

docker compose up -d --build --force-recreate --remove-orphans # якщо потрібно перебудувати проект і перезапустити контейнери і видалити невикористовувані контейнери
```

    2.1. Зупинити проект:

    ```bash
    docker compose down
    ```

    2.2. Перезапустити проект:

    ```bash
    docker compose restart
    ```
