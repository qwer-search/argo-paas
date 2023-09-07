#!/usr/bin/env bash

# 默认各参数值，请自行修改.(注意:伪装路径不需要 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
PORT=${PORT:-'8080'}
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
WSPATH=${WSPATH:-'argo'}

# 生成 Xray 配置文件
cat > config.json << EOF
{
    "log":{
        "access":"/dev/null",
        "error":"/dev/null",
        "loglevel":"none"
    },
    "inbounds":[
        {
            "port":PORT,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"UUID",
                        "flow":"xtls-rprx-direct"
                    }
                ],
                "decryption":"none",
                "fallbacks":[
                    {
                        "dest":3001
                    },
                    {
                        "path":"/WSPATH-vless",
                        "dest":3002
                    },
                    {
                        "path":"/WSPATH-vmess",
                        "dest":3003
                    },
                    {
                        "path":"/WSPATH-trojan",
                        "dest":3004
                    },
                    {
                        "path":"/WSPATH-shadowsocks",
                        "dest":3005
                    }
                ]
            },
            "streamSettings":{
                "network":"tcp"
            }
        },
        {
            "port":3001,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"UUID"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none"
            }
        },
        {
            "port":3002,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"UUID",
                        "level":0,
                        "email":"argo@xray"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/WSPATH-vless"
                }
            }
        },
        {
            "port":3003,
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"UUID",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/WSPATH-vmess"
                }
            }
        },
        {
            "port":3004,
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"UUID"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/WSPATH-trojan"
                }
            }
        },
        {
            "port":3005,
            "listen":"127.0.0.1",
            "protocol":"shadowsocks",
            "settings":{
                "clients":[
                    {
                        "method":"chacha20-ietf-poly1305",
                        "password":"UUID"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/WSPATH-shadowsocks"
                }
            }
        }
    ],
    "dns":{
        "servers":[
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds":[
        {
            "protocol":"freedom"
        }
    ]
}
EOF

# 下载并运行 Argo
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
./cloudflared-linux-amd64 tunnel --url http://localhost:${PORT} --no-autoupdate > argo.log 2>&1 &

# 下载 Xray，并伪装 xray 执行文件
RANDOM_NAME=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
wget -O temp.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip temp.zip xray geosite.dat geoip.dat
mv xray ${RANDOM_NAME}
rm -f temp.zip
sed -i "s#UUID#$UUID#g;s#WSPATH#${WSPATH}#g;s#PORT#${PORT}#g" config.json

# 如果有设置哪吒探针三个变量,会安装。如果不填或者不全,则不会安装
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh && echo '0' | ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY}

# 显示节点信息
ARGO=$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##")
cat > list << EOF
vless://${UUID}@www.digitalocean.com:443?encryption=none&security=tls&type=ws&host=${ARGO}&path=/${WSPATH}-vless&sni=${ARGO}#Argo-Vless

vmess://$(echo "none:${UUID}@www.digitalocean.com:443" | base64 -w 0)?remarks=Argo-Vmess&obfsParam=${ARGO}&path=/${WSPATH}-vmess&obfs=websocket&tls=1&peer=${ARGO}&alterId=0

trojan://${UUID}@www.digitalocean.com:443?peer=${ARGO}&plugin=obfs-local;obfs=websocket;obfs-host=${ARGO};obfs-uri=/${WSPATH}-trojan#Argo-Trojan

ss://$(echo "chacha20-ietf-poly1305:${UUID}@www.digitalocean.com:443" | base64 -w 0)?v2ray-plugin=$(echo '{"peer":"'${ARGO}'","path":"/'${WSPATH}'-shadowsocks","host":"'${ARGO}'","mode":"websocket","tls":true}' | base64 -w 0)#Argo-Shadowsocks

EOF

echo -e "\n↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓\n"
cat list
echo -e "\n 节点保存在文件: /app/list \n"
echo -e "\n↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑\n"

# 运行 xray
./${RANDOM_NAME} run -config config.json
