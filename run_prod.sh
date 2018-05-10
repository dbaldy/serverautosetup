if [ $# -eq 0  ] && [ ! -f ../setup.conf ]; then
	echo "No setup file"
	exit 1
elif [ $# -ne 0 ]; then
	source $1
else
	source ../setup.conf
fi

echo "$SUCCESSL[Push config on server]$ENDL"
scp $INI_FILE $USER@$IP:$TARGET_REPOSITORY/../config.ini

ssh -t $USER@$IP << EOF
cd $TARGET_REPOSITORY
echo -e "$SUCCESS[Pull git repository]$ENDL"
git pull https://$GIT_USERNAME:$PWD@github.com/$GIT_USERNAME/$GIT_FOLDER

echo -e "$SUCCESS[Makemigrations]$ENDL"
python3 manage.py makemigrations $APPS

echo -e "$SUCCESS[Dump database]$ENDL"
python3 manage.py dumpdata --exclude auth.permission --exclude contenttypes --exclude admin.LogEntry --indent 2 > dumpdatabase.json

echo -e "$SUCCESS[Migrate database]$ENDL"
python3 manage.py migrate

echo -e "$SUCCESS[Collect database]$ENDL"
python3 manage.py collectstatic --noinput
systemctl restart gunicorn
EOF

echo "$SUCCESSL[Copy database locally]$ENDL"
scp $USER@$IP:$TARGET_REPOSITORY/dumpdatabase.json .
