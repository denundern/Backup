#!/bin/bash

tk=6613356645:AAE_AA6p2nV8BAbjaa5cp-GNmYWx2prHnUY
chatid=205070885

# Caption
# گرفتن عنوان برای فایل پشتیبان و ذخیره آن در متغیر caption
echo "Caption (for example, your domain, to identify the database file more easily): "
read -r caption

# Assigning cron time to run every 12 hours
cron_time="0 */12 * * *"


# x-ui or marzban or hiddify
# گرفتن نوع نرم افزاری که می‌خواهیم پشتیبانی از آن بگیریم و ذخیره آن در متغیر xmh
while [[ -z "$xmh" ]]; do
    echo "x-ui or marzban or hiddify? [x/m/h] : "
    read -r xmh
    if [[ $xmh == $'\0' ]]; then
        echo "Invalid input. Please choose x, m or h."
        unset xmh
    elif [[ ! $xmh =~ ^[xmh]$ ]]; then
        echo "${xmh} is not a valid option. Please choose x, m or h."
        unset xmh
    fi
done

crontabs=n

if [[ "$crontabs" == "y" ]]; then
# remove cronjobs
sudo crontab -l | grep -vE '/root/SJ-backup.+\.sh' | crontab -
fi


# m backup
# ساخت فایل پشتیبانی برای نرم‌افزار Marzban و ذخیره آن در فایل SJ-backup.zip
if [[ "$xmh" == "m" ]]; then

if dir=$(find /opt /root -type d -iname "marzban" -print -quit); then
  echo "The folder exists at $dir"
else
  echo "The folder does not exist."
  exit 1
fi

if [ -d "/var/lib/marzban/mysql" ]; then

  sed -i -e 's/\s*=\s*/=/' -e 's/\s*:\s*/:/' -e 's/^\s*//' /opt/marzban/.env

  docker exec marzban-mysql-1 bash -c "mkdir -p /var/lib/mysql/db-backup"
  source /opt/marzban/.env

    cat > "/var/lib/marzban/mysql/SJ-backup.sh" <<EOL
#!/bin/bash

USER="root"
PASSWORD="$MYSQL_ROOT_PASSWORD"


databases=\$(mysql -h 127.0.0.1 --user=\$USER --password=\$PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

for db in \$databases; do
    if [[ "\$db" != "information_schema" ]] && [[ "\$db" != "mysql" ]] && [[ "\$db" != "performance_schema" ]] && [[ "\$db" != "sys" ]] ; then
        echo "Dumping database: \$db"
		mysqldump -h 127.0.0.1 --force --opt --user=\$USER --password=\$PASSWORD --databases \$db > /var/lib/mysql/db-backup/\$db.sql

    fi
done

EOL
chmod +x /var/lib/marzban/mysql/SJ-backup.sh

ZIP=$(cat <<EOF
docker exec marzban-mysql-1 bash -c "/var/lib/mysql/SJ-backup.sh"
zip -r /root/SJ-backup-m.zip /opt/marzban/* /var/lib/marzban/* /opt/marzban/.env -x /var/lib/marzban/mysql/\*
zip -r /root/SJ-backup-m.zip /var/lib/marzban/mysql/db-backup/*
rm -rf /var/lib/marzban/mysql/db-backup/*
EOF
)

    else
      ZIP="zip -r /root/SJ-backup-m.zip ${dir}/* /var/lib/marzban/* /opt/marzban/.env"
fi

SJBackuper="marzban backup"

# x-ui backup
# ساخت فایل پشتیبانی برای نرم‌افزار X-UI و ذخیره آن در فایل SJ-backup.zip
elif [[ "$xmh" == "x" ]]; then

if dbDir=$(find /etc /opt/freedom -type d -iname "x-ui*" -print -quit); then
  echo "The folder exists at $dbDir"
  if [[ $dbDir == *"/opt/freedom/x-ui"* ]]; then
     dbDir="${dbDir}/db/"
  fi
else
  echo "The folder does not exist."
  exit 1
fi

if configDir=$(find /usr/local -type d -iname "x-ui*" -print -quit); then
  echo "The folder exists at $configDir"
else
  echo "The folder does not exist."
  exit 1
fi

ZIP="zip /root/SJ-backup-x.zip ${dbDir}/x-ui.db ${configDir}/config.json"
SJBackuper="x-ui backup"

# hiddify backup
# ساخت فایل پشتیبانی برای نرم‌افزار Hiddify و ذخیره آن در فایل SJ-backup.zip
elif [[ "$xmh" == "h" ]]; then

if ! find /opt/hiddify-config/hiddify-panel/ -type d -iname "backup" -print -quit; then
  echo "The folder does not exist."
  exit 1
fi

ZIP=$(cat <<EOF
cd /opt/hiddify-config/hiddify-panel/
if [ $(find /opt/hiddify-config/hiddify-panel/backup -type f | wc -l) -gt 100 ]; then
  find /opt/hiddify-config/hiddify-panel/backup -type f -delete
fi
python3 -m hiddifypanel backup
cd /opt/hiddify-config/hiddify-panel/backup
latest_file=\$(ls -t *.json | head -n1)
rm -f /root/SJ-backup-h.zip
zip /root/SJ-backup-h.zip /opt/hiddify-config/hiddify-panel/backup/\$latest_file

EOF
)
SJBackuper="hiddify backup"
else
echo "Please choose m or x or h only !"
exit 1
fi


trim() {
    # remove leading and trailing whitespace/lines
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
caption="${caption}\n\n${SJBackuper}\n<code>${IP}</code>\nCreated by @Suppvm - https://github.com/Denumen/MarzBackup"
comment=$(echo -e "$caption" | sed 's/<code>//g;s/<\/code>//g')
comment=$(trim "$comment")

# install zip
# نصب پکیج zip
sudo apt install zip -y

# send backup to telegram
# ارسال فایل پشتیبانی به تلگرام
cat > "/root/SJ-backup-${xmh}.sh" <<EOL
rm -rf /root/SJ-backup-${xmh}.zip
$ZIP
echo -e "$comment" | zip -z /root/SJ-backup-${xmh}.zip
curl -F chat_id="${chatid}" -F caption=\$'${caption}' -F parse_mode="HTML" -F document=@"/root/SJ-backup-${xmh}.zip" https://api.telegram.org/bot${tk}/sendDocument
EOL


# Add cronjob
# افزودن کرانجاب جدید برای اجرای دوره‌ای این اسکریپت
{ crontab -l -u root; echo "${cron_time} /bin/bash /root/SJ-backup-${xmh}.sh >/dev/null 2>&1"; } | crontab -u root -

# run the script
# اجرای این اسکریپت
bash "/root/SJ-backup-${xmh}.sh"

# Done
# پایان اجرای اسکریپت
echo -e "\nDone\n"
