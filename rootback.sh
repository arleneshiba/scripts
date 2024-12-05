#!/bin/bash
# wget https://raw.githubusercontent.com/arleneshiba/scripts/refs/heads/main/rootback.sh && chmod +x rootback.sh && bash rootback.sh
# Переменные
SSH_CONFIG="/etc/ssh/sshd_config"
CLOUD_INIT_CONFIG="/etc/ssh/sshd_config.d/50-cloud-init.conf"

# Проверка прав
if [[ $EUID -ne 0 ]]; then
    echo "Этот скрипт необходимо запускать с правами root."
    exit 1
fi

# Функция для изменения пароля root
change_root_password() {
    local new_password="$1"
    
    if [[ -z "$new_password" ]]; then
        echo "Вы должны указать новый пароль после ключа -p."
        exit 1
    fi

    echo "Меняем пароль root..."
    
    # Проверяем, требуется ли ввод старого пароля
    if passwd --help 2>&1 | grep -q "current"; then
        echo "root:$new_password" | chpasswd
    else
        echo -e "$new_password\n$new_password" | passwd root
    fi
    
    if [[ $? -eq 0 ]]; then
        echo "Пароль root успешно изменён."
    else
        echo "Не удалось изменить пароль root."
        exit 1
    fi
}

# Очистка файла 50-cloud-init.conf
echo "Очищаем $CLOUD_INIT_CONFIG..."
> "$CLOUD_INIT_CONFIG"

# Разрешение root-логина и пароля в sshd_config
echo "Обновляем $SSH_CONFIG для разрешения логина root и пароля..."
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' "$SSH_CONFIG"
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' "$SSH_CONFIG"

# Проверка и добавление строк, если их нет
grep -q "^PermitRootLogin yes" "$SSH_CONFIG" || echo "PermitRootLogin yes" >> "$SSH_CONFIG"
grep -q "^PasswordAuthentication yes" "$SSH_CONFIG" || echo "PasswordAuthentication yes" >> "$SSH_CONFIG"

# Перезагрузка SSH сервера
echo "Перезагружаем SSH сервер..."
systemctl restart sshd
if [[ $? -eq 0 ]]; then
    echo "SSH сервер успешно перезагружен."
else
    echo "Ошибка при перезагрузке SSH сервера."
    exit 1
fi

# Обработка аргументов командной строки
while getopts "p:" opt; do
    case $opt in
        p)
            change_root_password "$OPTARG"
            ;;
        *)
            echo "Неверный ключ. Используйте -p <новый_пароль> для смены пароля root."
            exit 1
            ;;
    esac
done

echo "Скрипт успешно выполнен."
