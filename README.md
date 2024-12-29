Запустити скрипт для створення директорій:

```
./setup.sh

якщо не працює, то запустити в такому пордку:
1. chmod +x setup.sh
2. ./setup.sh
```

Запустити проект:

```
docker compose up -d

docker compose up -d --build # якщо потрібно перебудувати проект
docker compose up -d --build --force-recreate # якщо потрібно перебудувати проект і перезапустити контейнери
docker compose up -d --force-recreate # якщо потрібно перезапустити контейнери

docker compose up -d --build --force-recreate --remove-orphans # якщо потрібно перебудувати проект і перезапустити контейнери і видалити невикористовувані контейнери
```

Зупинити проект:

```
docker compose down
```

Перезапустити проект:

```
docker compose restart
```
