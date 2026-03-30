## MTProxy
Простой прокси для MTProto.

[Русский](https://github.com/d0m-1k/MTProxy/blob/master/README.RU.md) | [English](https://github.com/d0m-1k/MTProxy/blob/master/README.md)

### Сборка
Установите зависимости. Вам понадобятся стандартные инструменты для сборки из исходников, а также пакеты разработки для `openssl` и `zlib`.

Debian/Ubuntu:
```bash
apt install git curl build-essential libssl-dev zlib1g-dev
```
CentOS/RHEL:
```bash
yum install openssl-devel zlib-devel
yum groupinstall "Development Tools"
```

Клонируйте репозиторий:
```bash
git clone https://github.com/TelegramMessenger/MTProxy
cd MTProxy
```

Для сборки выполните `make`. Бинарный файл будет в `objs/bin/mtproto-proxy`:
```bash
make && cd objs/bin
```

Если сборка не удалась, перед повторной попыткой выполните `make clean`.

### Запуск
1. Получите секрет для подключения к серверам Telegram:
```bash
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
```
2. Получите текущую конфигурацию Telegram. Она может меняться, поэтому рекомендуется обновлять её раз в сутки:
```bash
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
```
3. Сгенерируйте секрет, который будут использовать клиенты для подключения к вашему прокси:
```bash
head -c 16 /dev/urandom | xxd -ps
```
4. Запустите `mtproto-proxy`:
```bash
./mtproto-proxy -u nobody -p 8888 -H 443 -S <secret> --aes-pwd proxy-secret proxy-multi.conf -M 1
```
Где:
- `nobody` – имя пользователя, от которого будет работать процесс (прокси вызывает `setuid()` для сброса привилегий).
- `443` – порт, используемый клиентами для подключения.
- `8888` – локальный порт для получения статистики (например, `wget localhost:8888/stats`). Доступен только через loopback.
- `<secret>` – секрет, сгенерированный на шаге 3. Можно указать несколько секретов: `-S <secret1> -S <secret2>`.
- `proxy-secret` и `proxy-multi.conf` – файлы, полученные на шагах 1 и 2.
- `1` – количество рабочих процессов. Можно увеличить, если у вас мощный сервер.

Дополнительные параметры можно посмотреть с помощью `mtproto-proxy --help`.

5. Сформируйте ссылку для подключения: `tg://proxy?server=SERVER_NAME&port=PORT&secret=SECRET` (или попросите официального бота сгенерировать её).
6. Зарегистрируйте прокси в боте [@MTProxybot](https://t.me/MTProxybot) в Telegram.
7. Укажите полученный тег в аргументах: `-P <proxy tag>`.
8. Пользуйтесь.

### Случайное заполнение (random padding)
Некоторые провайдеры детектят MTProxy по размерам пакетов. Для обхода можно включить добавление случайного заполнения.

Эта опция включается только для клиентов, которые её запрашивают. Добавьте префикс `dd` к секрету (`cafe...babe` => `ddcafe...babe`), чтобы включить этот режим на стороне клиента.

### Пример конфигурации для systemd
1. Создайте файл службы systemd (путь может отличаться в зависимости от дистрибутива):
```bash
nano /etc/systemd/system/MTProxy.service
```
2. Пример базовой службы (подставьте свои пути и параметры):
```ini
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/MTProxy
ExecStart=/opt/MTProxy/mtproto-proxy -u nobody -p 8888 -H 443 -S <secret> -P <proxy tag> <other params>
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
3. Перезагрузите systemd:
```bash
systemctl daemon-reload
```
4. Проверьте работоспособность:
```bash
systemctl restart MTProxy.service
systemctl status MTProxy.service
```
5. Включите автозапуск:
```bash
systemctl enable MTProxy.service
```

### Docker (.env + автообновление config)

В этом репозитории `Dockerfile` и `docker-compose.yaml` запускают MTProxy через `.env`.

#### Подготовка
1. Создайте `.env` из шаблона:
```bash
cp .env.example .env
```
2. Укажите `MT_SECRET` (16 байт hex), например:
```bash
head -c 16 /dev/urandom | xxd -ps
```
3. При необходимости измените порты/интервал обновления:
- `MT_PORT` — порт для клиентов (по умолчанию `1443`).
- `MT_STATS_PORT` — локальный порт статистики (по умолчанию `8888`).
- `MT_CONFIG_UPDATE_INTERVAL` — как часто обновлять `proxy-multi.conf`, в секундах (по умолчанию `86400`, т.е. 24 часа).

#### Что контейнер делает при старте
- Загружает `proxy-secret`, если его нет в `./data/proxy-secret`.
- Загружает `proxy-multi.conf`, если его нет в `./data/proxy-multi.conf`.
- Запускает фоновое периодическое обновление `proxy-multi.conf` по `MT_CONFIG_UPDATE_INTERVAL`.

Файлы рантайма сохраняются в `./data`, поэтому после перезапуска контейнера они не теряются.

#### Запуск
```bash
docker compose up -d --build
```

Прокси будет доступен на порту из `MT_PORT`.
Статистика доступна только локально на `127.0.0.1:MT_STATS_PORT`.

#### Остановка
```bash
docker compose down
```

#### Принудительно обновить конфиг Telegram
```bash
rm -f data/proxy-multi.conf && docker compose restart mtproxy
```

> **Примечание:** старый официальный образ (`telegrammessenger/proxy`) устарел и не содержит исправления для больших PID.
