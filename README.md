# Litres Book Downloader

Обертка для скачивания книг с [Litres](https://www.litres.ru) по подписке. Использует [litres_audiobooks_downloader](https://github.com/fabrikant/litres_audiobooks_downloader) под капотом.

## Требования

- Windows 10/11
- [Python 3.10+](https://www.python.org/downloads/) (с галочкой **Add Python to PATH**)
- [Git](https://git-scm.com/download/win)
- Аккаунт Litres с активной подпиской
- Браузер Edge, Firefox или Chrome (для cookies)

## Установка

1. Склонируйте репозиторий:
   ```bat
   git clone https://github.com/AlesBan/litres-book-downloader.git
   cd litres-book-downloader
   ```

2. Запустите установку:
   ```bat
   install.bat
   ```
   Скрипт автоматически:
   - скачает загрузчик в папку `downloader/`
   - создаст виртуальное окружение Python
   - установит зависимости
   - создаст папки `books/` и `cookies/`

3. Настройте cookies (авторизация Litres):
   ```bat
   create_cookies.bat
   ```
   Или через логин/пароль:
   ```bat
   create_cookies.bat --login
   ```

## Использование

**Одна книга по ссылке:**
```bat
download.bat https://www.litres.ru/book/author/title-123456/
```

**Список книг из файла:**
```bat
download.bat book_list.txt
```

**Интерактивный режим:**
```bat
download.bat
```

Скачанные файлы сохраняются в папку `books/`.

## Формат book_list.txt

По одной ссылке на строку:
```
https://www.litres.ru/book/author/book-one-123/
https://www.litres.ru/book/author/book-two-456/
```

## Структура проекта

```
litres-book-downloader/
├── install.bat          # Установка зависимостей
├── create_cookies.bat   # Настройка авторизации
├── download.bat         # Скачивание книг
├── config.json          # Настройки путей
├── book_list.txt        # Пример списка книг
├── cookies/             # Файлы авторизации (не в git)
├── books/               # Скачанные книги (не в git)
└── downloader/          # Загрузчик (создается install.bat)
```

## Настройка (config.json)

| Параметр | Описание |
|----------|----------|
| `downloaderPath` | Папка загрузчика (по умолчанию `downloader`) |
| `downloaderRepo` | URL репозитория загрузчика |
| `outputDir` | Папка для скачанных книг |
| `cookiesFile` | Путь к файлу cookies |
| `defaultBookList` | Файл списка по умолчанию |
