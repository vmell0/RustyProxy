#!/bin/bash

PORTS_FILE="/opt/rustyproxy/ports"

#FUNÇÃO PARA ABRIR PORTAS DE UM PROXY
add_proxy_port() {
    local port=$1
    local status=${2:-"ProxyPro"}

    if is_port_in_use $port; then
        echo "A PORTA $port JÁ ESTÁ EM USO."
        return
    fi

    local command="/opt/rustyproxy/proxy --port $port --status \"$status\""
    local service_file_path="/etc/systemd/system/proxy${port}.service"
    local service_file_content="[Unit]
Description=RustyProxy ${port}
After=network.target

[Service]
LimitNOFILE=infinity
Type=simple
ExecStart=${command}
Restart=always

[Install]
WantedBy=multi-user.target"

    echo "$service_file_content" | sudo tee "$service_file_path" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "proxy${port}.service"
    sudo systemctl start "proxy${port}.service"

    #SALVAR PORTAS NO ARQUIVO COM CÓDIGO ANSI
    echo -e "$port \033[1;32m$status\033[0m" >> "$PORTS_FILE"
    echo "Porta $port ABERTA COM SUCESSO."
    clear
}

#FUNÇÃO VERIFICAR PORTAS EM USO
is_port_in_use() {
    local port=$1

    #VERIFICA CONEXÕES ESTABELECIDAS OU LISTEN
    if netstat -tuln 2>/dev/null | awk '{print $4}' | grep -q ":$port$"; then
        return 0
    elif ss -tuln 2>/dev/null | awk '{print $4}' | grep -q ":$port$"; then
        return 0
    elif lsof -i :"$port" 2>/dev/null | grep -q LISTEN; then
        return 0
    else
        return 1
    fi

}

#FUNÇÃO PARA FECHAR PORTAS DE UM PROXY
del_proxy_port() {
    local port=$1

    sudo systemctl disable "proxy${port}.service"
    sudo systemctl stop "proxy${port}.service"
    sudo rm -f "/etc/systemd/system/proxy${port}.service"
    sudo systemctl daemon-reload

    #MATAR QUALQUER PROCESSO QUE AINDA ESTEJA USANDO A PORTA
    fuser -k "$port"/tcp 2>/dev/null

    #REMOVER A PORTA DO ARQUIVO DE CONTROLE
    sed -i "/^$port /d" "$PORTS_FILE"
    echo "Porta $port FECHADA COM SUCESSO."
    clear
}

#FUNÇÃO PARA ALTERAR UM STATUS DE UM PROXY
update_proxy_status() {
    local port=$1
    local new_status=$2
    local service_file_path="/etc/systemd/system/proxy${port}.service"

    if ! is_port_in_use $port; then
        echo "A PORTA $port NÃO ESTÁ ATIVA."
        return
    fi

    if [ ! -f "$service_file_path" ]; then
        echo "ARQUIVO DE SERVIÇO PARA $port NÃO ENCONTRADO."
        return
    fi

    local new_command="/opt/rustyproxy/proxy --port $port --status \"$new_status\""
    sudo sed -i "s|^ExecStart=.*$|ExecStart=${new_command}|" "$service_file_path"

    sudo systemctl daemon-reload
    sudo systemctl restart "proxy${port}.service"

    #ATUALIZAR O ARQUIVO DE PORTAS COM CÓDIGO ANSI
    sed -i "s/^$port .*/$port \033[1;32m$status\033[0m" "$PORTS_FILE"

    echo "STATUS DA PORTA $port ATUALIZADO PARA '$new_status'."
    sleep 3
    clear
}

#FUNÇÃO PARA DESINSTALAR RUSTY PROXY
    uninstall_rustyproxy() {
    echo "DESINSTALANDO, AGUARDE..."
    sleep 3
    clear

#REMOVER TODOS OS SERVIÇOS
    if [ -s "$PORTS_FILE" ]; then
        while read -r port; do
            del_proxy_port $port
        done < "$PORTS_FILE"
    fi
	
	#REMOVER BINÁRIOS, ARQUIVOS E DIRETÓRIOS
    sudo rm -rf /opt/rustyproxy
    sudo rm -f "$PORTS_FILE"

    echo -e "\033[0;34m---------------------------------------------------------\033[0m"
    echo -e "\033[40;1;37m           DESINSTALADO COM SUCESSO.                   \E[0m"
    echo -e "\033[0;34m---------------------------------------------------------\033[0m"
    sleep 4
    clear
}

#FUNÇÃO PARA REINICIAR TODAS AS PORTAS PROXYS ABERTAS
restart_all_proxies() {
    if [ ! -s "$PORTS_FILE" ]; then
        echo "NENHUMA PORTA ENCONTRADA PARA REINICIAR."
        return
    fi

    echo "REINICIANDO TODAS AS PORTAS..."
    while read -r line; do
        port=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | cut -d' ' -f2-)
        del_proxy_port "$port"
        add_proxy_port "$port" "$status"
    done < "$PORTS_FILE"

    echo "✅ TODAS AS PORTAS FORAM REINICIADAS COM SUCESSO."
    sleep 3
    clear
}

atualizar_script() {
    uninstall_rustyproxy
	bash <(wget -qO- https://raw.githubusercontent.com/vmell0/RustyProxy/refs/heads/main/install.sh)
}

executar_comando() {
    local comando="$1"
    local mensagem="$2"
    local delay=0.1
    local percent=0
    local bar=""

    echo -e "${YELLOW}${mensagem:0:50}${NC}"
    echo -n ' '
    
    eval "$comando" & local cmd_pid=$!
    
    while kill -0 $cmd_pid 2>/dev/null; do
        percent=$((percent + 1))
        if [ $percent -ge 100 ]; then
            percent=100
        fi
        echo -ne "       \r$percent% [${bar:0:$((percent / 5))}]"
        sleep $delay
        bar=$(printf "%-30s" | tr ' ' '#')
    done

    wait $cmd_pid
    if [ $? -eq 0 ]; then
        percent=100
        echo -ne "       \r$percent% [${bar:0:20}]\n"
    else
        echo -e "\r${RED}Erro ao executar o comando.${NC}"
    fi
    
    echo
    sleep 1
}

show_menu() {
    clear
    echo -e "\E[44;1;37m         MULTI-PROXY           \E[0m"
    echo -e "\033[0;36m╔════════════•⊱✦⊰•════════════╗\033[0m"
    #VERIFICADOR DE PORTAS ATIVAS
    if [ ! -s "$PORTS_FILE" ]; then
        printf "033[1;33m  NENHUMA PORTA %-34s\n" ""
    else
        while read -r line; do
            port=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | cut -d' ' -f2-)
            printf "033[1;33m  PORTA: %-5s \033[1;32m%s\033[0m\n" "$port"
        done < "$PORTS_FILE"
    fi
    echo -e "\033[0;36m° ° ° ° ° ° ° ° ° ° ° ° ° ° ° °\033[0m"
    echo -e "\033[1;31m[\033[1;36m01\033[1;31m] \033[1;37m• \033[1;37mABRIR PORTA \033[1;31m
[\033[1;36m02\033[1;31m] \033[1;37m• \033[1;37mFECHAR PORTA \033[1;31m
[\033[1;36m03\033[1;31m] \033[1;37m• \033[1;37mREINICIAR PORTA \033[1;31m
[\033[1;36m04\033[1;31m] \033[1;37m• \033[1;37mALTERAR STATUS \033[1;31m
[\033[1;36m05\033[1;31m] \033[1;37m• \033[1;37mATUALIZAR SCRIPT \033[1;31m
[\033[1;36m06\033[1;31m] \033[1;37m• \033[1;37mREMOVER SCRIPT \033[1;31m
[\033[1;36m00\033[1;31m] \033[1;37m• \033[1;37mSAIR DO MENU \033[1;31m"
    echo -e "\033[0;36m╚════════════•⊱✦⊰•════════════╝\033[0m"
    echo -ne "  \033[1;31m➤ \033[1;32mOPÇÃO\033[1;33m\033[1;31m\033[1;37m: ";
    read option
    case $option in
        1 | 01)
            clear
            read -p "DIGITE A PORTA: " port
            while ! [[ $port =~ ^[0-9]+$ ]]; do
                echo "DIGITE UMA PORTA VÁLIDA."
                read -p "DIGITE A PORTA: " port
            done
            read -p "DIGITE O NOME DO STATUS: " status
            add_proxy_port $port "$status"
            read -p "✅ PORTA ATIVADA COM SUCESSO. PRESSIONE QUALQUER TECLA PARA VOLTAR AO MENU." dummy
            ;;
        2 | 02)
            clear
            read -p "DIGITE A PORTA: " port
            while ! [[ $port =~ ^[0-9]+$ ]]; do
                echo "DIGITE UMA PORTA VÁLIDA."
                read -p "DIGITE A PORTA: " port
            done
            del_proxy_port $port
            read -p "✅ PORTA DESATIVADA. PRESSIONE QUALQUER TECLA PARA VOLTAR AO MENU." dummy
			clear
            ;;			
		3 | 03)
            clear
            restart_all_proxies
            read -p "✅ PORTAS REINICIADAS. PRESSIONE QUALQUER TECLA PARA VOLTAR AO MENU." dummy
            ;;				
        4 | 04)
            clear
            read -p "DIGITE A PORTA: " port
            while ! [[ $port =~ ^[0-9]+$ ]]; do
                echo "DIGITE UMA PORTA VÁLIDA."
                read -p "DIGITE A PORTA: " port
            done
            read -p "DIGITE O NOVO STATUS DE CONEXÃO: " new_status
            update_proxy_status $port "$new_status"
            read -p "✅ STATUS DA PORTA ATUALIZADO. PRESSIONE QUALQUER TECLA PARA VOLTAR AO MENU." dummy
            ;;			
	    5 | 05)
            clear
            echo ""
            executar_comando "atualizar_script &> /dev/null" "ATUALIZANDO SCRIPT"
			clear
	        menuproxy
            ;;	
		6 | 06)
            clear
            uninstall_rustyproxy
            read -p "◉ PRESSIONE QUALQUER TC PARA SAIR." dummy
	        clear
            exit 0
            ;;	
        0)
	    clear
            exit 0
            ;;
        *)
            echo "OPÇÃO INVÁLIDA. PRESSIONE QUALQUER TECLA PARA VOLTAR AO MENU."
            read -n 1 dummy
            ;;
    esac
}

#VERIFICAR SE O ARQUIVO DE PORTAS EXISTE, CASO CONTRÁRIO, CRIAR
if [ ! -f "$PORTS_FILE" ]; then
    sudo touch "$PORTS_FILE"
fi

#LOOP DO MENU
while true; do
    show_menu
done
