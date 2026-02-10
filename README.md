# MTProto Helper

Скрипт для автоматической установки Telegram MTProxy (MTProto), генерации секрета и запуска через `systemd`.

Важно: скрипт настраивает `kernel.pid_max=65535`, так как текущий MTProxy падает на высоких PID (assert в `common/pid.c`).

## Что делает скрипт

- устанавливает зависимости на Debian/Ubuntu;
- скачивает и собирает `TelegramMessenger/MTProxy`;
- загружает актуальные файлы `proxy-secret` и `proxy-multi.conf`;
- генерирует секрет MTProto только при первом запуске (дальше переиспользует, если не задан `ROTATE_SECRET=1`);
- создает и запускает `systemd`-сервис `mtproxy`;
- поддерживает `PROXY_TAG` (можно добавить/обновить позже без смены секрета);
- выводит готовую ссылку подключения и секрет.

## Быстрый запуск

```bash
sudo bash install_mtproto.sh
```

Опционально можно переопределить порты/воркеры:

```bash
sudo PROXY_PORT=443 STATS_PORT=8888 WORKERS=2 bash install_mtproto.sh
```

Добавить/обновить `PROXY_TAG` после регистрации прокси (секрет сохранится):

```bash
sudo PROXY_TAG=0123456789abcdef bash install_mtproto.sh
```

Принудительно сменить секрет:

```bash
sudo ROTATE_SECRET=1 bash install_mtproto.sh
```

Очистить `PROXY_TAG`:

```bash
sudo CLEAR_PROXY_TAG=1 bash install_mtproto.sh
```

## Результат

После завершения скрипт печатает:

- `Secret` — ваш сгенерированный MTProto секрет;
- `Telegram link` — ссылка вида `https://t.me/proxy?...`;
- `Direct tg:// link` — ссылка вида `tg://proxy?...`.
- `Proxy tag` — текущий прокси-тег (если задан).

## Файлы и сервис

- Конфиг: `/etc/mtproxy/mtproxy.env`
- Результат (секрет + ссылки): `/etc/mtproxy/connection.txt`
- Sysctl fix: `/etc/sysctl.d/99-mtproxy.conf`
- Unit: `/etc/systemd/system/mtproxy.service`
- Запуск: `systemctl status mtproxy`

`/etc/mtproxy/mtproxy.env` читается самим `systemd` (через `EnvironmentFile`), поэтому права `600` для него корректны.
