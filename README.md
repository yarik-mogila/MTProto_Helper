# MTProto Helper

Скрипт для автоматической установки Telegram MTProxy (MTProto), генерации секрета и запуска через `systemd`.

## Что делает скрипт

- устанавливает зависимости на Debian/Ubuntu;
- скачивает и собирает `TelegramMessenger/MTProxy`;
- загружает актуальные файлы `proxy-secret` и `proxy-multi.conf`;
- генерирует случайный секрет MTProto;
- создает и запускает `systemd`-сервис `mtproxy`;
- выводит готовую ссылку подключения и секрет.

## Быстрый запуск

```bash
sudo bash install_mtproto.sh
```

Опционально можно переопределить порты/воркеры:

```bash
sudo PROXY_PORT=443 STATS_PORT=8888 WORKERS=2 bash install_mtproto.sh
```

## Результат

После завершения скрипт печатает:

- `Secret` — ваш сгенерированный MTProto секрет;
- `Telegram link` — ссылка вида `https://t.me/proxy?...`;
- `Direct tg:// link` — ссылка вида `tg://proxy?...`.

## Файлы и сервис

- Конфиг: `/etc/mtproxy/mtproxy.env`
- Результат (секрет + ссылки): `/etc/mtproxy/connection.txt`
- Unit: `/etc/systemd/system/mtproxy.service`
- Запуск: `systemctl status mtproxy`

`/etc/mtproxy/mtproxy.env` читается самим `systemd` (через `EnvironmentFile`), поэтому права `600` для него корректны.
