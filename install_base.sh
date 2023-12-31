#!/bin/bash

echo "##########################"
echo "Script to install the web server and the database server + phpmyadmin + prestashop + nodejs on Debian"
echo "##########################"

# Verify that the script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Verify that the system as apt-get
if ! [ -x "$(command -v apt)" ]; then
  echo 'Error: apt is not installed.' >&2
  exit 1
fi

# Update the system
echo "##########################"
echo "Update the system"
echo "##########################"
apt-get update -y
apt-get upgrade -y

# Create a new user named presta
echo "##########################"
echo "Create a new user named presta"
echo "##########################"
useradd -m presta

# Set a password for the user presta
echo "##########################"
echo "Set a password for the user presta"
echo "Please save the password in a safe place"
echo "##########################"
passwd presta

# Install sudo
echo "##########################"
echo "Install sudo"
echo "##########################"
apt-get install sudo -y

# Make the user sudoer
echo "##########################"
echo "Make the user sudoer"
echo "##########################"
usermod -aG sudo presta

# Add the user presta to the sudoers file
echo "##########################"
echo "Add the user presta to the sudoers file"
echo "##########################"
echo "presta ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Disable the ssh access for the root user
echo "##########################"
echo "Disable the ssh access for the root user"
echo "Next time you will connect to the server, you will have to connect with the user presta"
echo "##########################"
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

# Install the lamp stack

echo "##########################"
echo "Install php 8.1 source"
echo "##########################"
apt-get -y install lsb-release ca-certificates curl
curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
apt-get update
apt-get upgrade -y

echo "##########################"
echo "Install the lamp stack"
echo "##########################"
apt-get install apache2 php8.1 libapache2-mod-php8.1 mariadb-server php8.1-mysql -y
echo "##########################"
echo "Install some php extensions commonly used by CMS"
echo "##########################"
apt-get install php8.1-curl php8.1-gd php8.1-intl php8.1-mbstring php8.1-xml php8.1-zip -y

# Install a firewall and configure it in this case ufw
echo "##########################"
echo "Install a firewall and configure it in this case ufw"
echo "##########################"
apt-get install ufw -y
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# Enable the apache rewrite module
echo "##########################"
echo "Enable the apache rewrite module"
echo "##########################"
a2enmod rewrite

# Enable the apache auth basic module
echo "##########################"
echo "Enable the apache auth basic module"
echo "##########################"
a2enmod auth_basic

# Restart the apache service
echo "##########################"
echo "Restart the apache service"
echo "##########################"
systemctl restart apache2

# Configure mysql_secure_installation
echo "##########################"
echo "Configure mysql_secure_installation"
echo "You will have to enter the password of the root user of the database server"
echo "Please use a strong password and save it in a safe place"
echo "##########################"
mysql_secure_installation

# Get the php version into a variable
echo "##########################"
echo "Get the php version into a variable"
echo "Your php version is:"
php -v
echo "##########################"
php_version=$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,2,3)

# Change php configuration to allow url fopen and set the upload_max_filesize to 32M
echo "##########################"
echo "Change php configuration to allow url fopen and set the upload_max_filesize to 32M"
echo "##########################"
# if allow_url_fopen is off change it to on else do nothing
sed -i "s/allow_url_fopen = Off/allow_url_fopen = On/g" /etc/php/$php_version/apache2/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 32M/g" /etc/php/$php_version/apache2/php.ini

# Restart the apache service
echo "##########################"
echo "Restart the apache service"
echo "##########################"
systemctl restart apache2

# Create a new user retro and ask the password password and grant him all privileges on the database retro
echo "##########################"
echo "Create a new user retro and ask the password password and grant him all privileges on the database retro"
echo "Please save the password in a safe place"
echo "##########################"
echo "Please enter the password for the user retro"
read -r passwdRetro
# Create the user retro
mysql -u root -e "CREATE USER 'retro'@'localhost' IDENTIFIED BY '$passwdRetro';"
# Create the database retro
mysql -u root -e "CREATE DATABASE retro;"
# Grant all privileges on the database retro to the user retro
mysql -u root -e "GRANT ALL PRIVILEGES ON retro.* TO 'retro'@'localhost';"
# Flush the privileges
mysql -u root -e "FLUSH PRIVILEGES;"
# Display the password
echo "##########################"
echo "The password for the user retro is $passwdRetro"
echo "Please enter it in the installation of prestashop"
echo "Also save it in a safe place"
echo "##########################"

# Create the folder /var/www/retro
echo "##########################"
echo "Create the folder /var/www/retro"
echo "##########################"
mkdir /var/www/retro

# Create the folder /var/www/chat for the chat app
echo "##########################"
echo "Create the folder /var/www/chat for the chat app"
echo "##########################"
mkdir /var/www/chat

# Create the two virtual hosts
echo "##########################"
echo "Create the two virtual hosts"
echo "##########################"
# Create the file /etc/apache2/sites-available/retro.conf
echo "##########################"
touch /etc/apache2/sites-available/retro.conf
# Create the file /etc/apache2/sites-available/chat.conf
touch /etc/apache2/sites-available/chat.conf

echo "Please enter the domain name of the website"
read domain_name

# Write the content of the file /etc/apache2/sites-available/retro.conf
echo "##########################"
echo "Create the file /etc/apache2/sites-available/retro.conf"
echo "##########################"
echo "<VirtualHost *:80>
    ServerName shop.$domain_name
    ServerAlias www.shop.$domain_name
    DocumentRoot /var/www/retro
    <Directory /var/www/retro>
        Options -Indexes +FollowSymLinks +MultiViews
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/retro_error.log
    CustomLog ${APACHE_LOG_DIR}/retro_access.log combined
</VirtualHost>" > /etc/apache2/sites-available/retro.conf

# Write the content of the file /etc/apache2/sites-available/chat.conf
echo "##########################"
echo "Create the file /etc/apache2/sites-available/chat.conf"
echo "##########################"
echo "<VirtualHost *:80>
    ServerName chat.$domain_name
    ServerAlias www.chat.$domain_name
    DocumentRoot /var/www/chat
    <Directory /var/www/chat>
        Options -Indexes +FollowSymLinks +MultiViews
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/chat_error.log
    CustomLog ${APACHE_LOG_DIR}/chat_access.log combined
</VirtualHost>" > /etc/apache2/sites-available/chat.conf

# Enable the two virtual hosts
echo "##########################"
echo "Enable the two virtual hosts"
echo "##########################"
a2ensite retro.conf
a2ensite chat.conf

# Disable the default virtual host
echo "##########################"
echo "Disable the default virtual host"
echo "##########################"
a2dissite 000-default.conf

# Restart the apache service
echo "##########################"
echo "Restart the apache service"
echo "##########################"
systemctl restart apache2

# Install nodejs
echo "##########################"
echo "Install nodejs"
echo "##########################"
apt-get install nodejs -y

# Install npm
echo "##########################"
echo "Install npm"
echo "##########################"
apt-get install npm -y

# Install prestashop
echo "##########################"
echo "Install prestashop"
echo "##########################"
cd /var/www/retro

# Verify if wget is installed else install it
if ! [ -x "$(command -v wget)" ]; then
  echo 'Error: wget is not installed.' >&2
  apt install wget -y
fi

# Download the latest version of prestashop
echo "##########################"
echo "Please indicate the version of prestashop you want to install (example: 8.1.1)"
echo "##########################"
read -r version
wget https://github.com/PrestaShop/PrestaShop/releases/download/"$version"/prestashop_"$version".zip

# Verify if unzip is installed else install it
if ! [ -x "$(command -v unzip)" ]; then
  echo 'Error: unzip is not installed.' >&2
  apt install unzip -y
fi

# Get the name of the prestashop archive
archive_name=$(ls | grep prestashop)

# Unzip the prestashop archive
echo "##########################"
echo "Unzip the prestashop archive"
echo "##########################"
unzip "$archive_name"

# Remove the archive
echo "##########################"
echo "Remove the archive"
echo "##########################"
rm "$archive_name"

# Change the owner and group of the folder /var/www/retro to www-data
echo "##########################"
echo "Change the owner and group of the folder /var/www/retro to www-data"
echo "##########################"
chown -R www-data:www-data /var/www/retro

echo "Go to http://shop.$domain_name to install prestashop"
# If it is finished, press enter
echo "Press enter when you have finished the installation of prestashop"
read -r

# delete install folder from prestashop
echo "#####################################"
echo "Delete install folder from prestashop"
echo "#####################################"

rm -rf /var/www/retro/install

# Install letsencrypt
echo "##########################"
echo "Install letsencrypt"
echo "##########################"
apt-get install certbot python3-certbot-apache -y

# Launch the letsencrypt script
echo "##########################"
echo "Launch the letsencrypt script"
echo "##########################"
certbot --apache

# Restart the ssh service
echo "##########################"
echo "Restart the ssh service"
echo "##########################"
systemctl restart sshd

# Add a user that can only connect with sftp and can only access to the folder /var/www
echo "##########################"
echo "Add a user that can only connect with sftp and can only access to the folder /var/www"
echo "##########################"
useradd -M -g www-data -s /usr/sbin/nologin webupload

# Change the password of the user webupload
echo "##########################"
echo "Change the password of the user webupload"
echo "Please save the password in a safe place"
echo "##########################"
passwd webupload

# Change the file sshd_config
echo "##########################"
echo "Change the file sshd_config"
echo "##########################"
sed -i 's/Subsystem sftp \/usr\/lib\/openssh\/sftp-server/Subsystem sftp internal-sftp/g' /etc/ssh/sshd_config
echo "Match User webupload
    ChrootDirectory /var/www
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no" >> /etc/ssh/sshd_config

# Restart the ssh service
echo "##########################"
echo "Restart the ssh service"
echo "##########################"
systemctl restart sshd