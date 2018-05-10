# UBUNTU 16.04

if [ $# -eq 0  ] && [ ! -f ../setup.conf ]; then
	echo "No setup file"
	exit 1
elif [ $# -ne 0 ]; then
	source $1
else
	source ../setup.conf
fi

ssh -t -o StrictHostKeyChecking=no $USER@$IP << EOF
apt-get update

echo -e "$INFO[Install dependencies]$END"
yes | apt-get install python3-pip python3-dev libpq-dev postgresql postgresql-contrib nginx
echo -e "$SUCCESS[Dependencies OK]$END"


if [ ! -f ~/.bash_aliases ]; then
	echo -e "$INFO[Alias python3]$END"
	alias python='python3'
	echo "alias python='python3'" >> ~/.bash_aliases
fi

echo -e "$INFO[Database setup]$END"
su - postgres << EOF_UPSQL
psql -c "CREATE USER $DATABASE_USER WITH PASSWORD '$DATABASE_PASSWORD';"
psql -c "ALTER USER $DATABASE_USER CREATEDB;"
psql -c "CREATE DATABASE $DATABASE_NAME;"
psql -c "ALTER DATABASE $DATABASE_NAME OWNER TO $DATABASE_USER;"
psql -c "GRANT ALL ON $DATABASE_NAME TO $DATABASE_USER;"

echo "CREATE ROLE $DATABASE_USER LOGIN ENCRYPTED PASSWORD '$DATABASE_PASSWORD';" | sudo -u postgres psql
echo "CREATE DATABASE $DATABASE_NAME WITH OWNER $DATABASE_USER;" | sudo -u postgres psql
echo "ALTER ROLE $DATABASE_USER SET client_encoding TO 'utf8';" | sudo -u postgres psql
echo "ALTER ROLE $DATABASE_USER SET default_transaction_isolation TO 'read committed';" | sudo -u postgres psql
echo "ALTER ROLE $DATABASE_USER SET timezone TO 'UTC';" | sudo -u postgres psql
echo "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DATABASE_USER;" | sudo -u postgres psql
EOF_UPSQL
service postgresql reload
echo -e "$SUCCESS[Database OK]$END"

echo -e "$INFO[Git clone the repository]$END"
git clone https://$GIT_USERNAME:$PWD@github.com/$GIT_USERNAME/$GIT_FOLDER $TARGET_REPOSITORY
mkdir $LOGS_DIRECTORY
echo -e "$SUCCESS[Git clone OK]$END"

echo -e "$INFO[Install project packages]$END"
sudo -H pip3 install --upgrade pip
pip3 install -r $TARGET_REPOSITORY/requirements.txt
pip3 install gunicorn psycopg2
echo -e "$SUCCESS[Django OK]$END"


echo -e "$INFO[Setup Gunicorn systemd]$END"
echo "[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$TARGET_REPOSITORY
ExecStart=/usr/local/bin/gunicorn --access-logfile - --workers 2 --bind 127.0.0.1:8000 $PROJECT_NAME.wsgi:application

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/gunicorn.service

echo -e "$SUCCESS[Gunicorn OK]$END"

echo -e "$INFO[Setup Nginx]$END"
echo "server {
	listen 80;
	server_name $IP;

	access_log $LOGS_DIRECTORY/nginx-access.log;
    	error_log $LOGS_DIRECTORY/nginx-error.log;

	location /static/ {
		root $GIT_TARGET;
	}

	location / {
		include proxy_params;
		proxy_pass http://127.0.0.1:8000;
	}
}" > /etc/nginx/sites-available/$PROJECT_NAME
ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled
sudo systemctl restart nginx

echo -e "$SUCCESS[Nginx OK]$END"

echo -e "$INFO[Push prod server]$END"

sudo systemctl restart nginx
sudo systemctl start gunicorn
sudo systemctl enable gunicorn
systemctl daemon-reload
sudo ufw allow 'Nginx Full'

echo -e "$SUCCESS[End of server local setup]$END"

EOF

echo "$INFOL[Push config on server]$ENDL"
scp $INI_FILE $USER@$IP:$TARGET_REPOSITORY/../config.ini


ssh -t $USER@$IP << EOF
sudo systemctl restart gunicorn
EOF

echo "$SUCCESSL[End of setup]$ENDL"
