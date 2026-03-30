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

### Docker (исправленная версия)

В этом репозитории предоставлены `Dockerfile` и `docker-compose.yaml`, которые собирают прокси с удалённым `assert` для поддержки больших PID на современных ядрах Linux.

#### Подготовка файлов
Перед запуском создайте следующие файлы:
- `secret` – ваш секрет для клиентов (сгенерируйте командой `head -c 16 /dev/urandom | xxd -ps`).
- `proxy-secret` – секрет для подключения к серверам Telegram:
  `curl -s https://core.telegram.org/getProxySecret -o proxy-secret`
- `proxy-multi.conf` – текущая конфигурация Telegram:
  `curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf`

Все эти файлы должны находиться в одной папке с `docker-compose.yaml`.

#### Запуск
```bash
docker-compose up -d --build
```

Прокси будет доступен на порту `1443` (можно изменить в `docker-compose.yaml`).
Статистика – на порту `8888` (доступна только локально).

#### Остановка
```bash
docker-compose down
```

> **Примечание:** старый официальный образ (`telegrammessenger/proxy`) устарел и не содержит исправления для больших PID.---
