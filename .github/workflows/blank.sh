#!/bin/bash

clear
mkdir -p ~/.cloudshell && touch ~/.cloudshell/no-apt-get-warning
echo "Установка зависимостей..."

# Определение дистрибутива и установка необходимых пакетов
if [ -x "$(command -v apt-get)" ]; then
    echo "Дистрибутив Debian/Ubuntu"
    sudo apt-get update -y --fix-missing
    sudo apt-get install -y --fix-missing wireguard-tools jq curl
elif [ -x "$(command -v apk)" ]; then
    echo "Дистрибутив Alpine Linux"
    sudo apk update
    sudo apk add wireguard-tools jq curl
elif [ -x "$(command -v pacman)" ]; then
    echo "Дистрибутив Arch Linux"
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm wireguard-tools jq curl
else
    echo "Не поддерживаемый дистрибутив. Установите зависимости вручную."
    exit 1
fi

# Генерация ключей WireGuard
priv="${1:-$(wg genkey)}"
pub="${2:-$(echo "${priv}" | wg pubkey)}"
api="https://api.cloudflareclient.com/v0i1909051800"

# Функции для взаимодействия с API
ins() { curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; }
sec() { ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; }

# Регистрация и получение данных
response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"ios\",\"locale\":\"en_US\"}")

id=$(echo "$response" | jq -r '.result.id')
token=$(echo "$response" | jq -r '.result.token')
response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')
peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key')
peer_endpoint=$(echo "$response" | jq -r '.result.config.peers[0].endpoint.host')
client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4')
client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6')
port=$(echo "$peer_endpoint" | sed 's/.*:\([0-9]*\)$/\1/')
peer_endpoint=$(echo "$peer_endpoint" | sed 's/\(.*\):[0-9]*/162.159.193.5/')

# Создание конфигурационного файла WireGuard
conf=$(cat <<-EOM
[Interface]
PrivateKey = ${priv}
S1 = 0
S2 = 0
Jc = 120
Jmin = 23
Jmax = 911
H1 = 1
H2 = 2
H3 = 3
H4 = 4
Address = ${client_ipv4}, ${client_ipv6}
DNS = 1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001

[Peer]
PublicKey = ${peer_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${peer_endpoint}:${port}
EOM
)

clear
echo -e "\n\n\n"
[ -t 1 ] && echo "########## НАЧАЛО КОНФИГА ##########"
echo "${conf}"
[ -t 1 ] && echo "########### КОНЕЦ КОНФИГА ###########"

# Преобразование конфигурации в base64
conf_base64=$(echo -n "${conf}" | base64 -w 0)
echo "Скачать конфиг файлом: https://immalware.github.io/downloader.html?filename=WARP.conf&content=${conf_base64}"
