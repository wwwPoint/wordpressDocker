#!/bin/bash

# Завантажуємо змінні з .env файлу
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | awk '/=/ {print $1}')
fi

# Далі той самий код для виведення посилань... 