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
echo "Please enter a password for the user presta and save it in a safe place"
echo "##########################"
useradd -m presta

# Make the user sudoer
echo "##########################"
echo "Make the user sudoer"
echo "##########################"
usermod -aG sudo presta

# Disable the ssh access for the root user
echo "##########################"
echo "Disable the ssh access for the root user"
echo "Next time you will connect to the server, you will have to connect with the user presta"
echo "##########################"
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

# Install the lamp stack
echo "##########################"
echo "Install the lamp stack"
echo "##########################"
apt install apache2 php libapache2-mod-php mariadb-server php-mysql -y
echo "##########################"
echo "Install some php extensions commonly used by CMS"
echo "##########################"
apt install php-curl php-gd php-intl php-json php-mbstring php-xml php-zip -y

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

# Install phpmyadmin
echo "##########################"
echo "Install phpmyadmin"
echo "Please choose apache2 when you will be asked to choose a web server"
echo "##########################"
apt install phpmyadmin -y

# Get the php version into a variable
echo "##########################"
echo "Get the php version into a variable"
echo "Your php version is:"
php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,2,3
echo "##########################"
php_version=$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,2,3)

# Change php configuration to allow url fopen and set the upload_max_filesize to 32M
echo "##########################"
echo "Change php configuration to allow url fopen and set the upload_max_filesize to 32M"
echo "##########################"
sed -i "s/;allow_url_fopen = On/allow_url_fopen = On/g" /etc/php/$php_version/apache2/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 32M/g" /etc/php/$php_version/apache2/php.ini

# Restart the apache service
echo "##########################"
echo "Restart the apache service"
echo "##########################"
systemctl restart apache2

# Create a new user retro with a random password and grant him all privileges on the database retro
echo "##########################"
echo "Create a new user retro with a random password and grant him all privileges on the database retro"
echo "Please save the password in a safe place"
randompsswd=$(openssl rand -base64 12)
mysql -u root -e "CREATE USER 'retro'@'localhost' IDENTIFIED BY '$randompsswd';"
# Create the database retro
mysql -u root -e "CREATE DATABASE retro;"
# Grant all privileges on the database retro to the user retro
mysql -u root -e "GRANT ALL PRIVILEGES ON retro.* TO 'retro'@'localhost';"
# Flush the privileges
mysql -u root -e "FLUSH PRIVILEGES;"
# Display the password
echo "##########################"
echo "The password for the user retro is $randompsswd"
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
read version
wget https://github.com/PrestaShop/PrestaShop/releases/download/$version/prestashop_$version.zip

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
unzip $archive_name

# Remove the archive
echo "##########################"
echo "Remove the archive"
echo "##########################"
rm $archive_name

# Change the owner and group of the folder /var/www/retro to www-data
echo "##########################"
echo "Change the owner and group of the folder /var/www/retro to www-data"
echo "##########################"
chown -R www-data:www-data /var/www/retro

echo "Go to http://shop.$domain_name to install prestashop"
# If it is finished, press enter
echo "Press enter when you have finished the installation of prestashop"
read



# Install letsencrypt
echo "##########################"
echo "Install letsencrypt"
echo "##########################"
apt install certbot python-certbot-apache -y

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