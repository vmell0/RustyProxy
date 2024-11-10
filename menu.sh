#!/bin/bash

PORTS_FILE="/opt/rustyproxy/ports"

# Função para verificar se uma porta está em uso
is_port_in_use() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Função para abrir uma porta de proxy
add_proxy_port() {
    local port=$1
    local status=${2:-"WebSocket"}

    if is_port_in_use $port; then
        echo "A porta $port já está em uso."
        return
    fi

    local command="/opt/rustyproxy/proxyy --port $port --status $status"
    local service_file_path="/etc/systemd/system/proxyy${port}.service"
    local service_file_content="[Unit]
Description=RustyProxy${port}
After=network.target

[Service]
LimitNOFILE=infinity
LimitNPROC=infinity
LimitMEMLOCK=infinity
LimitSTACK=infinity
LimitCORE=infinity
LimitAS=infinity
LimitRSS=infinity
LimitCPU=infinity
LimitFSIZE=infinity
Type=simple
ExecStart=${command}
Restart=always

[Install]
WantedBy=multi-user.target"

    echo "$service_file_content" | sudo tee "$service_file_path" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "proxyy${port}.service"
    sudo systemctl start "proxyy${port}.service"

    # Salvar a porta no arquivo
    echo $port >> "$PORTS_FILE"
    echo "Porta $port aberta com sucesso."
}

# Função para fechar uma porta de proxy
del_proxy_port() {
    local port=$1

    sudo systemctl disable "proxyy${port}.service"
    sudo systemctl stop "proxyy${port}.service"
    sudo rm -f "/etc/systemd/system/proxyy${port}.service"
    sudo systemctl daemon-reload

    # Remover a porta do arquivo
    sed -i "/^$port$/d" "$PORTS_FILE"
    echo "Porta $port fechada com sucesso."
}

# Função para exibir o menu formatado
show_menu() {
    clear
    echo "------------------------------------------------"
    printf "                  %-28s\n" "PROXY-PRO"
    echo "------------------------------------------------"
    
    # Verifica se há portas ativas
    if [ ! -s "$PORTS_FILE" ]; then
        printf ""
    else
        active_ports=""
        while read -r port; do
            active_ports+=" $port"
        done < "$PORTS_FILE"
        printf "  Porta:%-35s\n" "$active_ports"
    echo "------------------------------------------------"
    fi
    printf "  %-45s\n" "1 - Abrir Porta"
    printf "  %-45s\n" "2 - Fechar Porta"
    printf "  %-45s\n" "0 - Voltar ao menu"
    echo "------------------------------------------------"
    read -p " --> OPÇÃO: " option

    case $option in
        1)
            read -p "Digite a porta: " port
            while ! [[ $port =~ ^[0-9]+$ ]]; do
                echo "Digite uma porta válida."
                read -p "Digite a porta: " port
            done
            read -p "Status: " status
            add_proxy_port $port "$status"
            echo "> Porta ativada com sucesso." 
            sleep 2.5s
            show_menu
            ;;
        2)
            read -p "Digite a porta: " port
            while ! [[ $port =~ ^[0-9]+$ ]]; do
                echo "Digite uma porta válida."
                read -p "Digite a porta: " port
            done
            del_proxy_port $port
            echo "> Porta ativada com sucesso." 
            sleep 2.5s
            show_menu
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Opção inválida. Pressione qualquer tecla para voltar ao menu."
            read -n 1 dummy
            ;;
    esac
}



# Verificar se o arquivo de portas existe, caso contrário, criar
if [ ! -f "$PORTS_FILE" ]; then
    sudo touch "$PORTS_FILE"
fi

# Loop do menu
while true; do
    show_menu
done
