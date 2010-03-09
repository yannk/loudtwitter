#! /bin/sh

datum=`/bin/date +%Y%m%d-%H`
dir="/backups/sql"
file="${dir}/backup-${datum}.sql"
user=root
password=none

mkdir -p $dir >/dev/null 2>&1

/usr/bin/mysql -p$password -e 'STOP SLAVE SQL_THREAD;'
/usr/bin/mysqldump --user=$user -p$password twitter user auth_token > $file
/usr/bin/mysql -p$password -e 'START SLAVE SQL_THREAD;'
bzip2 -c $file > $file.bz2
gpg2 --trust-model=always --yes --batch --no-tty -r kerherve -o $file.gpg -e $file.bz2
rm $file.bz2
rm $file

## now delete old local files
for file in "$( /usr/bin/find $dir -type f -mtime +7 )"
do
  /bin/rm -f ${file}.gpg
done
echo "done ${file}"
