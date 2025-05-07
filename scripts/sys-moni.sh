#!/bin/bash





# Função para exibir uma barra de progresso horizontal
draw_bar() {
    local usage=$1
    local color=$2
    local bar_length=50
    local used_length=$((usage * bar_length / 100))
    local empty_length=$((bar_length - used_length))

    printf "\e[1;${color}m"
    printf "%0.s█" $(seq 1 $used_length)
    printf "\e[0m"
    printf "%0.s░" $(seq 1 $empty_length)
    printf " ${usage}%%\n"
}

# Função para obter o uso da CPU
get_cpu_usage() {
    local cpu_idle1=$(grep 'cpu ' /proc/stat | awk '{print $5}')
    local total1=$(grep 'cpu ' /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8}')
    sleep 1
    local cpu_idle2=$(grep 'cpu ' /proc/stat | awk '{print $5}')
    local total2=$(grep 'cpu ' /proc/stat | awk '{print $2+$3+$4+$5+$6+$7+$8}')
    local idle=$((cpu_idle2 - cpu_idle1))
    local total=$((total2 - total1))
    local usage=$((100 * (total - idle) / total))
    echo $usage
}

# Função para obter o uso da memória
get_memory_usage() {
    local total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local used=$((total - available))
    local usage=$((100 * used / total))
    echo $usage
}

# Função para obter o uso do disco
get_disk_usage() {
    local usage=$(df / | grep '/' | awk '{print $5}' | sed 's/%//')
    echo $usage
}

# Loop para atualizar as informações a cada 5 segundos

while true; do
    clear
    echo -e "\e[1;33mMonitor de Recursos do Sistema\e[0m"
    echo "-------------------------------"
    echo -e "\e[1;33m $(hostname) \e[0m"
    cpu_usage=$(get_cpu_usage)
    echo -e "\e[1;34mUso da CPU:\e[0m"
    draw_bar $cpu_usage 34

    memory_usage=$(get_memory_usage)
    echo -e "\e[1;32mUso da Memória:\e[0m"
    draw_bar $memory_usage 32

    disk_usage=$(get_disk_usage)
    echo -e "\e[1;35mUso do Disco (/):\e[0m"
    draw_bar $disk_usage 35

    sleep 15
done


