#!/bin/bash
# rustyproxy Installer

TOTAL_STEPS=9
CURRENT_STEP=0

show_progress() {
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo "Progresso: [${PERCENT}%] - $1"
}

error_exit() {
    echo -e "\nErro: $1"
    exit 1
}

increment_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
}

if [ "$EUID" -ne 0 ]; then
    error_exit "EXECUTE COMO ROOT"
else
    clear
    show_progress "Atualizando repositorios..."
    export DEBIAN_FRONTEND=noninteractive
    apt update -y > /dev/null 2>&1 || error_exit "Falha ao atualizar os repositorios"
    increment_step

    # ---->>>> Verificação do sistema
    show_progress "Verificando o sistema..."
    if ! command -v lsb_release &> /dev/null; then
        apt install lsb-release -y > /dev/null 2>&1 || error_exit "Falha ao instalar lsb-release"
    fi
    increment_step

    # ---->>>> Verificação do sistema
    OS_NAME=$(lsb_release -is)
    VERSION=$(lsb_release -rs)

    case $OS_NAME in
        Ubuntu)
            case $VERSION in
                24.*|22.*|20.*|18.*)
                    show_progress "Sistema Ubuntu suportado, continuando..."
                    ;;
                *)
                    error_exit "Versão do Ubuntu não suportada. Use 18, 20, 22 ou 24."
                    ;;
            esac
            ;;
        Debian)
            case $VERSION in
                12*|11*|10*|9*)
                    show_progress "Sistema Debian suportado, continuando..."
                    ;;
                *)
                    error_exit "Versão do Debian não suportada. Use 9, 10, 11 ou 12."
                    ;;
            esac
            ;;
        *)
            error_exit "Sistema não suportado. Use Ubuntu ou Debian."
            ;;
    esac
    increment_step

    # ---->>>> Instalação de pacotes requisitos e atualização do sistema
    show_progress "Atualizando o sistema..."
    apt upgrade -y > /dev/null 2>&1 || error_exit "Falha ao atualizar o sistema"
    apt-get install curl build-essential git -y > /dev/null 2>&1 || error_exit "Falha ao instalar pacotes"
    increment_step

    # ---->>>> Criando o diretório do script
    show_progress "Criando diretorio.."
    mkdir -p /opt/rustyproxy > /dev/null 2>&1
    mkdir -p /opt/rustymanager/ssl > /dev/null 2>&1
	if [ -d "/opt/rustymanager/ssl/cert.pem" ]; then
	cd /opt/rustymanager/ssl
    wget https://raw.githubusercontent.com/vmell0/RustyProxy/refs/heads/main/Utils/ssl/cert.pem > /dev/null 2>&1
	wget https://raw.githubusercontent.com/vmell0/RustyProxy/refs/heads/main/Utils/ssl/key.pem > /dev/null 2>&1
    chmod +x /opt/rustymanager/ssl/cert.pem /opt/rustymanager/ssl/key.pem
	cd	
	fi
    increment_step

    # ---->>>> Instalar rust
    show_progress "Instalando..."
	if [ -d "rustc-x86_64-unknown-linux-gnu" ]; then
        rm -rf ~/.rustup
		rm -rf ~/rust-gdb
    fi
    if ! command -v rustc &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1 || error_exit "Falha ao instalar Rust"
        source "$HOME/.cargo/env"
    fi
    increment_step

    # ---->>>> Instalar o RustyProxy
    show_progress "Compilando, isso pode levar algum tempo dependendo da maquina..."

    if [ -d "/root/RustyProxy" ]; then
        rm -rf /root/RustyProxy
    fi

    git clone --branch "main" https://github.com/vmell0/RustyProxy.git /root/RustyProxy > /dev/null 2>&1 || error_exit "Falha ao clonar Proxy"
    mv /root/RustyProxy/menu.sh /opt/rustyproxy/menu
    cd /root/RustyProxy/RustyProxy
    cargo build --release --jobs $(nproc) > /dev/null 2>&1 || error_exit "Falha ao compilar Proxy"
    mv ./target/release/RustyProxy /opt/rustyproxy/proxypro
    cd /root/RustyProxy/RustySSL
    cargo build --release --jobs $(nproc) > /dev/null 2>&1 || error_exit "Falha ao compilar SSL"
    mv ./target/release/RustySSL /opt/rustyproxy/proxyprossl
    increment_step

    # ---->>>> Configuração de permissões
    show_progress "Configurando permissões..."
    chmod +x /opt/rustyproxy/proxypro
	chmod +x /opt/rustyproxy/proxyprossl
    chmod +x /opt/rustyproxy/menu
    ln -sf /opt/rustyproxy/menu /usr/local/bin/proxypro
	ln -sf /opt/rustyproxy/menu /usr/local/bin/proxyprossl
    increment_step

    # ---->>>> Limpeza
    show_progress "Limpando diretórios temporários..."
    cd /root/
    rm -rf /root/RustyProxy/
    increment_step

    # ---->>>> Instalação finalizada :)
    echo "Instalação concluída com sucesso."
fi
