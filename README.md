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
   Откроется меню:
   - **1 — логин и пароль** (рекомендуется)
   - **2 — из браузера** (нужно полностью закрыть браузер)
   - **3 — SID вручную** (из DevTools, если другие способы не работают)

   Быстрые команды:
   ```bat
   create_cookies.bat -Login
   create_cookies.bat -BrowserMode
   create_cookies.bat -Manual
   create_cookies.bat -ValidateOnly
   ```

### Настройка cookies (подробно)

**Способ 1 — логин и пароль (рекомендуется)**
```bat
create_cookies.bat -Login
```
Введите email/телефон и пароль от Litres. Скрипт создаст файл `cookies/litres_cookies.json` и проверит авторизацию.

**Способ 2 — из браузера**
1. Войдите на [litres.ru](https://www.litres.ru) в Edge/Chrome/Firefox
2. **Полностью закройте браузер** — Edge/Chrome часто остаются в фоне (`msedge.exe`, `chrome.exe` в Диспетчере задач)
3. Запустите:
   ```bat
   create_cookies.bat -BrowserMode
   ```
   Скрипт предложит автоматически закрыть фоновые процессы браузера.

> Если способ 2 не работает — используйте **способ 1** (логин/пароль) или **способ 3** (SID вручную).

**Способ 3 — SID вручную**
1. Откройте [litres.ru](https://www.litres.ru) и войдите в аккаунт
2. Нажмите `F12` → вкладка **Application** → **Cookies** → `https://www.litres.ru`
3. Найдите cookie `SID` и скопируйте его значение
4. Запустите:
   ```bat
   create_cookies.bat -Manual
   ```

**Проверка cookies**
```bat
create_cookies.bat -ValidateOnly
```

4. Обновление (после `git clone` или когда вышла новая версия):
   ```bat
   update.bat
   ```
   Обновляет этот репозиторий, загрузчик в `downloader/` и Python-зависимости.

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
├── update.bat           # Обновление репозитория и зависимостей
├── create_cookies.bat   # Настройка авторизации
├── scripts/
│   └── setup_cookies.py # Логика создания cookies
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
