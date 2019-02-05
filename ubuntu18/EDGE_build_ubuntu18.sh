#!/usr/bin/env bash

export TERM="xterm-256color"
export DEBIAN_FRONTEND=noninteractive
# Debug flags
CPANM_QUIET="-q"		             # Cpanm quiet mode
CPANM_FORCE=""		                  # Cpanm force updates mode
GIT_CLONE_TIMEOUT="15m"	               # Git clone time out = 15minutes


EDGE_HOME="/home/edge"          # EDGE home
OPT_APPS="/opt/apps"		     # Application installation
EDGE_VERSION="dev"       # EDGE version
EDGE_APPS="${EDGE_HOME}/edge_${EDGE_VERSION}"    	# EDGE Applications

EDGE_User="edge"
EDGE_UserPW="edge"
EDGE_Group="edge"

CMD_PATH=$(dirname "${0}")
CMD_NAME=$(basename "${0}" .sh)

FON_bold="$(tput setab 11 2>/dev/null)"
FOF_bold="$(tput init 2>/dev/null)"
FON_red="$(tput setaf 1 2>/dev/null)"
FOF_red="$(tput setaf 0 2>/dev/null)"

# MYSQL users

# MySQL Root account
MYSQL_R_USER="root"
MYSQL_R_PW="edge"               # MySQL Root password
MYSQL_E_USER="edge"           # MySQL Edge User Management account
MYSQL_E_PW="edge"               # MySQL Edge User Management account

# Edge User Admin

EDGE_A_USER="admin_docker@my.edge"      # EDGE admin account
EDGE_A_PW="admin_docker"	           # EDGE admin password

# Set max upload size

MAX_UPLOAD_SIZE=5gb			   ## Default to 5GB

# Apache Paths

HTTPD_MAIN_CONF="/etc/apache2/apache2.conf"
HTTPD_APP_CONF="/etc/apache2/conf-available"
HTTPD_APP_ENABLE_CONF="/etc/apache2/conf-enabled"
HTTPD_MOD_CONF="/etc/apache2/mods-available"
HTTPD_MOD_ENABLE_CONF="/etc/apache2/mods-enabled"

# Tomcat Paths

TOMCAT_USERS="/usr/share/tomcat7/conf/tomcat-users.xml"
TOMCAT_WEB="/usr/share/tomcat7/conf/web.xml"
TOMCAT_CONF="/usr/share/tomcat7/bin/catalina.sh"
TOMCAT_LIB="/usr/share/tomcat7/lib"
TOMCAT_APPS="/usr/share/tomcat7/webapps"
TOMCAT_UCONF="/usr/share/tomcat7/conf/Catalina/localhost"
CATALINA_HOME="/usr/share/tomcat7"

PrintInfo ()
{
    echo "${FON_bold}$(date '+[%Y-%m-%d %H:%M:%S]')${FOF_bold} " "${*}"
}

ErrorExit ()
{
    echo "${CMD_NAME}.sh: ${FON_red}${*}${FOF_red}" 1>&2;

# If the cleanup function exists - run it

    if   declare -F Cleanup >/dev/null
    then Cleanup
    fi 
    exit 1
}


CheckError () 
{
    "$@"
    res="$?"

    if   [ "${res}" -ne 0 ]
    then ErrorExit "${E_MESSAGE} - command {$@} failed [${res}]."
    fi
}

CheckErrorPipe ()
{
    if   [ "${1}" -ne 0 ]
    then ErrorExit "${2} [${1}]."
    fi
}

apt-get update
#apt-get install -y software-properties-common
#add-apt-repository "deb http://us.archive.ubuntu.com/ubuntu/ xenial main"
#add-apt-repository "deb http://us.archive.ubuntu.com/ubuntu/ xenial universe"

apt-get install -y build-essential libreadline-gplv2-dev libx11-dev \
  libxt-dev libgsl-dev libfreetype6-dev libncurses5-dev gfortran \
  inkscape libwww-perl libxml-libxml-perl libperlio-gzip-perl  \
  zlib1g-dev zip unzip libjson-perl libpng-dev cpanminus default-jre \
  firefox wget curl csh liblapack-dev libblas-dev libatlas-base-dev \
  libcairo2-dev libssh2-1-dev libssl-dev libcurl4-openssl-dev bzip2 \
  bioperl rsync libbz2-dev liblzma-dev time libterm-readkey-perl \
  liblwp-protocol-https-perl gnuplot libjson-xs-perl libio-socket-ip-perl \
  vim php apache2 sendmail mysql-client mysql-server cron \
  openssh-server openssh-client zlib1g-dev openjdk-11-jdk texlive \
  texlive-fonts-extra texinfo libboost-all-dev libgfortran3

a2enmod cgid proxy proxy_http headers rewrite

apt-get autoremove && apt-get clean

## tomcat7
cd /usr/share
wget https://archive.apache.org/dist/tomcat/tomcat-7/v7.0.92/bin/apache-tomcat-7.0.92.tar.gz
tar xzf apache-tomcat-7.0.92.tar.gz
rm apache-tomcat-7.0.92.tar.gz
mv apache-tomcat-7.0.92 tomcat7
echo "export CATALINA_HOME=\"/usr/share/tomcat7\"" >> /etc/profile

### add tomcat7 service 
cat > "/etc/init.d/tomcat7" << _EOM
#!/bin/bash

### BEGIN INIT INFO
# Provides:        tomcat7
# Required-Start:  $network
# Required-Stop:   $network
# Default-Start:   2 3 4 5
# Default-Stop:    0 1 6
# Short-Description: Start/Stop Tomcat server
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

start() {
 sh ${CATALINA_HOME}/bin/startup.sh
}

stop() {
 sh ${CATALINA_HOME}/bin/shutdown.sh
}

case \$1 in
  start) start;;
  stop)  stop;;
  restart) stop; start;;
  *) echo "Run as \$0 "; exit 1;;
esac
_EOM

chmod 755 /etc/init.d/tomcat7
update-rc.d tomcat7 defaults
mkdir -p ${TOMCAT_UCONF}
## 

# Change the image conversion policy:
sed -i.bak 's/rights=\"none\" pattern=\"PDF\"/rights=\"read|write\" pattern=\"PDF\"/' /etc/ImageMagick-6/policy.xml
 
cat >> "/etc/mysql/my.cnf" << _EOM
# Added to make backward compatibility with MySQL 5.6 
[mysqld]
show_compatibility_56 = on
sql-mode=""
_EOM



# Create Edge group - try and add them above 2000 so they don't conflict with the host OS file.
echo "export TERM=xterm" >> /etc/bash.bashrc
echo "COLUMNS=\`tput cols\`" >> /etc/bash.bashrc
echo "LINES=\`tput lines\`"  >> /etc/bash.bashrc

# change CPU numbers when container startup
chmod +x /etc/rc.local
echo -e "su edge -c 'CPUNUM=\`grep -c processor /proc/cpuinfo\`;perl -pi -e \"s/edgeui_tol_cpu=\d+/edgeui_tol_cpu=\$CPUNUM/\" $EDGE_APPS/edge_ui/sys.properties'" >> /etc/rc.local
echo -e "su edge -c 'perl $EDGE_APPS/edge_ui/cgi-bin/edge_build_list.pl $EDGE_APPS/edge_ui/data/Host > $EDGE_APPS/edge_ui/data/host_list.json'"  >> /etc/rc.local

if   ! grep "^${EDGE_Group}:" /etc/group >/dev/null
then guid=$(for i in $(seq 2000 2020); do if ! grep "^[^:]*:[^:]*:$i:" /etc/group >/dev/null; then echo "$i"; exit; fi; done; echo "") 

     if [ "${guid}" == "" ]
     then CheckError groupadd "${EDGE_Group}"
     else CheckError groupadd -g "${guid}" "${EDGE_Group}"
     fi
fi

# Create Edge user - try and add them above 2000 so they don't conflict with the host OS file.
if   ! grep "^${EDGE_User}:" /etc/passwd >/dev/null
then nuid=$(for i in $(seq 2000 2020); do if ! grep "^[^:]*:[^:]*:$i:" /etc/passwd >/dev/null; then echo "$i"; exit; fi; done; echo "") 
   
     if [ "${nuid}" == "" ]
     then CheckError useradd -m -g "${EDGE_Group}" "${EDGE_User}"
     else CheckError useradd -m -u "${nuid}" -g "${EDGE_Group}" "${EDGE_User}"
     fi

# Set the password.

     echo "${EDGE_UserPW}" | passwd "${EDGE_User}" --stdin
fi


if   [ ! -e "${EDGE_HOME}/EDGE_input" ]
then CheckError mkdir "${EDGE_HOME}/EDGE_input"
fi

if   [ ! -e "${EDGE_HOME}/EDGE_output" ]
then CheckError mkdir "${EDGE_HOME}/EDGE_output"
fi

if   [ ! -e "${EDGE_HOME}/EDGE_report" ]
then CheckError mkdir "${EDGE_HOME}/EDGE_report"
fi

if   [ ! -e "${EDGE_HOME}/inputData" ]
then CheckError mkdir "${EDGE_HOME}/inputData"
fi

if   [ ! -e "${EDGE_HOME}/database" ]
then CheckError mkdir -p "${EDGE_HOME}/database/Krona_taxonomy"
fi

rm -f "${EDGE_APPS}" "${EDGE_HOME}/edge"
CheckError ln -s "${EDGE_APPS}" "${EDGE_HOME}"/edge

# if mount the edge source in /edge_source/
# if not, download from LANL ftp site
if   [ -e "/edge_source/INSTALL.sh" ]
then
  mkdir -p ${EDGE_APPS}
  cp -r /edge_source/* ${EDGE_APPS}/
else

  ## Codebase is ~107Mb and contains all the scripts and HTML needed to make EDGE run
  CheckError wget -c https://edge-dl.lanl.gov/EDGE/dev/edge_dev_main.tgz
  tar xzf  edge_dev_main.tgz -C ${EDGE_HOME}
  rm -f edge_dev_main.tgz



  ## Third party tools is ~2.9Gb and contains the underlying programs needed to do the analysis
  CheckError wget -c https://edge-dl.lanl.gov/EDGE/dev/edge_dev_thirdParty_softwares.tgz
  tar xzf edge_dev_thirdParty_softwares.tgz -C ${EDGE_HOME}/edge
  rm -f edge_dev_thirdParty_softwares.tgz

fi

CheckError ln -s "${EDGE_HOME}/database" "${EDGE_APPS}"/database

(

cd "${EDGE_HOME}"; chown -R "${EDGE_User}":"${EDGE_Group}" .

CheckError echo ${EDGE_User} > /etc/cron.allow

cd ${EDGE_APPS}

CheckError su "${EDGE_User}" -c "bash ./INSTALL.sh"

## clean up space 
rm -f thirdParty/*.tgz thirdParty/*.tar.gz thirdParty/*.tar.bz2 thirdParty/Anaconda*.sh
if [ -e "thirdParty/metaphlan-1.7.7" ]
then rm -rf thirdParty/metaphlan-1.7.7/blastdb thirdParty/metaphlan-1.7.7/bowtie2db
fi


CheckErrorPipe $? "Install EDGE support applications"
)

# Cleanup from the EDGE install
(cd "${EDGE_HOME}"; rm -rf .cache .continuum .cpanm)
(cd /root; rm -rf .cache .continuum .cpanm)
rm -rf /tmp/??????????

#Cron (at least in Debian) does not execute crontabs with more than 1 hardlink, see bug 647193.
#As Docker uses overlays, it results with more than one link to the file, so you have to touch it in your startup script, so the link is severed:
echo "touch /etc/crontab /etc/cron.*/* /var/spool/cron/edge " >> /etc/rc.local
echo -e "su edge -c 'bash $EDGE_APPS/scripts/pangia-vis-checker.sh > /dev/null'" >> /etc/rc.local
echo -e "rm -f $EDGE_APPS/edge_ui/EDGE_output/*/HTML_Report/.complete_report_web"  >> /etc/rc.local 
echo -e "rm -f $EDGE_APPS/edge_ui/EDGE_input/*/.edgeinfo.json"  >> /etc/rc.local 
echo -e "mysql -f -u edge -pedge -D userManagement < /home/edge/edge/userManagement/update_userManagement_db.sql 2>/dev/null" >> /etc/rc.local 
echo -e "su edge -c 'perl /home/edge/edge/edge_ui/cgi-bin/edge_um_project_monitor.pl'"  >> /etc/rc.local 

sed -i.bak 's/www-data/edge/g' /etc/apache2/envvars

CheckError sed -i.bak -e 's/ServerTokens OS/ServerTokens Prod/' -e 's/ServerSignature On/ServerSignature Off/' "${HTTPD_APP_CONF}/security.conf"

CheckError sed -e "s;%EDGE_HOME%;${EDGE_HOME}/edge;g" -e "s;${EDGE_APPS};${EDGE_HOME}/edge;g" "${EDGE_HOME}/edge/edge_ui/apache_conf/edge_httpd.conf" > "${HTTPD_APP_CONF}/10_edge_httpd.conf"
CheckError ln -s ${HTTPD_APP_CONF}/10_edge_httpd.conf ${HTTPD_APP_ENABLE_CONF}/10_edge_httpd.conf
CheckError sed -e "s;%EDGE_HOME%;${EDGE_HOME}/edge;g" -e "s;${EDGE_APPS};${EDGE_HOME}/edge;g" "${EDGE_HOME}/edge/edge_ui/apache_conf/pangia-vis.conf" > "${HTTPD_APP_CONF}/09_pangia-vis.conf"
CheckError ln -s ${HTTPD_APP_CONF}/09_pangia-vis.conf ${HTTPD_APP_ENABLE_CONF}/09_pangia-vis.con

cat >> "${HTTPD_APP_CONF}/10_edge_httpd.conf" << _EOM

# Add rewrite rules to block access to stuff we don't want people to get it - mainly sys.properties

RewriteEngine On

ReWriteRule /EDGE_input/.*    - [L]
ReWriteRule /EDGE_output/.*   - [L]
ReWriteRule /EDGE_report/.*   - [L]
ReWriteRule /JBrowse/.*       - [L]
ReWriteRule /cgi-bin/.*       - [L]
ReWriteRule /cluster/.*       - [L]
ReWriteRule /css/.*           - [L]
ReWriteRule /data/.*          - [L]
ReWriteRule /error/.*         - [L]
ReWriteRule /gpl-3.0-standalone.html  - [L]
ReWriteRule /edgesite.installation.done  - [L]
ReWriteRule /images/.*        - [L]
ReWriteRule /index.html       - [L]
ReWriteRule /$                - [L]
ReWriteRule /javascript/.*    - [L]
ReWriteRule /metadata_scripts/.*  - [L]
ReWriteRule /userManagement/.*    - [L]
ReWriteRule /userManagementWS/.*  - [L]
ReWriteRule .*                - [R=403,L]
_EOM

cat >> "${HTTPD_MAIN_CONF}" << _EOM

# Limit the available commands

<Location />
    Order allow,deny
    Allow from all
    <LimitExcept HEAD POST GET PUT OPTIONS>
        Deny from all
    </LimitExcept>
</Location>

ServerName localhost
_EOM

# Remove some default configuration files

rm -f "${HTTPD_APP_ENABLE_CONF}/javascript-common.conf" "${HTTPD_APP_ENABLE_CONF}/serve-cgi-bin.conf"


# Set up the Admin account
#

trolec=$(grep -c '^<user username=".*" roles="admin"/>' "${TOMCAT_USERS}")
troleo='<user username="'"${MYSQL_E_USER}"'" password="'"${MYSQL_E_PW}"'" roles="admin"/>'
trole=$(grep '^<user username=".*" roles="admin"/>' "${TOMCAT_USERS}")

if   [ "${trolec}" -eq 0 ]
then # No account set up, so set up ours
     CheckError sed -i 's@</tomcat-users>@<role rolename="admin"/>\n<user username="'"${UN}"'" password="'"${PW}"'" roles="admin"/>\n</tomcat-users>@g' "${TOMCAT_USERS}"

elif [[ ( "${trolec}" -eq 1 ) && ( "${trole}" = "${troleo}" ) ]]
then : Skip no action required - our value already set up

elif grep "^${troleo}" "${TOMCAT_USERS}" > /dev/null
then : Skip no action - our record is installed
else echo "Multiple or unexpected admin user records in ${TOMCAT_USERS} - requires manual intervention. Found ["
     grep '^<user username=".*" roles="admin"/>' "${TOMCAT_USERS}"
     echo '].'
fi

# Update inactive timeout to a more reasonable number 4320 min (3 days) from default (30mins) in /var/lib/tomcat7/conf/web.xml or /etc/tomcat/web.xml
# This is repeatable.
#

CheckError sed -i 's!<session-timeout>.*</session-timeout>!<session-timeout>4320</session-timeout>!g' "${TOMCAT_WEB}"

#
# Update the Java options - check if set correctly.
# Some versions contain multiple #JAVA_OPTS, so only changed the first
#
# Get the value of JAVA_OPTS if active
# Get the line number of the first #JAVA_OPTS line

jopts=$(grep "^JAVA_OPTS=" "${TOMCAT_CONF}")
jopts_l=$(grep -n '^#JAVA_OPTS' "${TOMCAT_CONF}" | sed -e 's/:.*//' -e '2,$d')

if   [ "${jopts}" = "" ]
then if   [ "${jopts_l}" = "" ]
     then echo "JAVA_OPTS string not found in ${TOMCAT_CONF} - appending"
          echo 'JAVA_OPTS="-Xms256m -Xmx1024m "' >> "${TOMCAT_CONF}"

     else CheckError sed -i "${jopts_l}"'s!#JAVA_OPTS!JAVA_OPTS="-Xms256m -Xmx1024m\"\n#JAVA_OPTS!g' "${TOMCAT_CONF}"
     fi

elif [ "${jopts}" != 'JAVA_OPTS="-Xms256m -Xmx1024m"' ]
then echo "Review JAVA_OPTS in [${TOMCAT_CONF}] as the expected and actual values do not match"
     echo '  Expected: JAVA_OPTS="-Xms256m -Xmx1024m"'
     echo "  Actual  : ${jopts}"
     
     CheckError sed -i "${jopts_l}"'s!#JAVA_OPTS!JAVA_OPTS="-Xms256m -Xmx1024m\"\n#JAVA_OPTS!g' "${TOMCAT_CONF}"
fi

# Install the driver in the EDGE Tomcat conf.
E_MESSAGE="Install EDGE TOMCAT database driver configuration"

CheckError cp "${EDGE_HOME}/edge/userManagement/mysql-connector-java-5.1.34-bin.jar" "${TOMCAT_LIB}"
CheckError chmod 744 "${TOMCAT_LIB}/mysql-connector-java-5.1.34-bin.jar"

#CheckError cp "${TOMCAT_CONF}" "${TOMCAT_CONF}.bak" 


# Deploy userManagement to tomcat server:

E_MESSAGE="Install EDGE User Management application"

CheckError rm -rf "${TOMCAT_APPS}/userManagement*"
CheckError cp "${EDGE_HOME}/edge/userManagement/userManagementWS.war" "${EDGE_HOME}/edge/userManagement/userManagement.war" "${TOMCAT_APPS}"
CheckError cp "${EDGE_HOME}/edge/userManagement/userManagementWS.xml" "${TOMCAT_UCONF}"
CheckError chmod 744 "${TOMCAT_UCONF}/userManagementWS.xml"
CheckError chmod 755 ${TOMCAT_APPS}/*war
 
# Modify the username/password in userManagementWS.xml:

CheckError sed -i -e 's!username=.*$!username="'"${MYSQL_E_USER}"'"!' \
       		  -e 's!password=.*$!password="'"${MYSQL_E_PW}"'"!'	\
       		  "${TOMCAT_UCONF}/userManagementWS.xml"

# May need this to update the EDGE Admin account info

CheckError sed -i -e "s;^edgeui_admin=.*\$;edgeui_admin=${EDGE_A_USER};"  -e "s;^edgeui_admin_password=.*\$;edgeui_admin_password=${EDGE_A_PW};"  -e "s;^user_upload_maxFileSize=.*;user_upload_maxFileSize='${MAX_UPLOAD_SIZE}';"  "${EDGE_HOME}/edge/edge_ui/sys.properties"

# Protect the edge passwords

chmod 400 "${EDGE_HOME}/edge/edge_ui/sys.properties"
chmod 750 "${EDGE_HOME}/edge/edge_ui"

## Start up MySQL
service apache2 restart
service mysql start

(
    echo "UPDATE mysql.user SET authentication_string=password('"${MYSQL_R_PW}"') WHERE User='"${MYSQL_R_USER}"';"
    echo "DELETE FROM mysql.user WHERE User='"${MYSQL_R_USER}"' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    echo "DELETE FROM mysql.user WHERE User='';"
    echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';"
    echo "FLUSH PRIVILEGES;"
) |  mysql --user "${MYSQL_R_USER}"

OURUSER=$(mysql --user "${MYSQL_R_USER}" --password="${MYSQL_R_PW}" <<EOM
select user, host from mysql.user where user = '${MYSQL_E_USER}';
EOM
)

# Update

(
    cd "${EDGE_APPS}/userManagement"
    	 
    (
	echo "CREATE DATABASE IF NOT EXISTS userManagement;"
	echo "USE userManagement;"
	echo "SOURCE userManagement_schema.sql;"
	echo "SOURCE userManagement_constrains.sql;" 
	echo "INSERT INTO users VALUES (1,'admin@my.edge','790a674fe5754d47af2c78627b704cc0','790a674fe5754d47af2c78627b704cc0','edge','admin','admin','yes','2017-05-17 17:19:10',NULL);" 
	echo "INSERT INTO users VALUES (2,'pangia_admin@mriglobal.org','c1fe391946866ac52ad2821892ad54e5','c1fe391946866ac52ad2821892ad54e5','pangia','admin','admin','yes','2017-10-10 17:19:10',NULL);"
	echo "INSERT INTO users VALUES (3,'admin_docker@my.edge','4b1ca311bd6b1c7bf8bbb2eb62a2eaa4','4b1ca311bd6b1c7bf8bbb2eb62a2eaa4','docker','admin','admin','yes','2018-04-10 17:19:10',NULL);"

        if   [ "${OURUSER}" != "" ]
        then echo "DROP USER '"${MYSQL_E_USER}"'@'localhost';"
        fi

	echo "CREATE USER '"${MYSQL_E_USER}"'@'localhost' IDENTIFIED BY '"${MYSQL_E_PW}"';"
	echo "GRANT ALL PRIVILEGES ON userManagement.* to '"${MYSQL_E_USER}"'@'localhost';"
        echo "FLUSH PRIVILEGES;"
    ) |  mysql --user "${MYSQL_R_USER}" --password="${MYSQL_R_PW}"
)

cd "${EDGE_APPS}/SQLdbfile"

(
	echo "SOURCE virulence_db.sql;"
	echo "GRANT ALL PRIVILEGES ON virulenceFactors.* to '${MYSQL_E_USER}'@'localhost';"
    echo "FLUSH PRIVILEGES;"
) | mysql --user "${MYSQL_R_USER}" --password="${MYSQL_R_PW}"

(
	echo "create database edgeDB;"
	echo "use edgeDB;"
	echo "SOURCE edge_db.sql;"
	echo "GRANT ALL PRIVILEGES ON edgeDB.* to '${MYSQL_E_USER}'@'localhost';"
    echo "FLUSH PRIVILEGES;"
) | mysql --user "${MYSQL_R_USER}" --password="${MYSQL_R_PW}"
	
(
	echo "create database pathogens;"
	echo "use pathogens;"
	echo "SOURCE pathogen_db.sql;"
	echo "GRANT ALL PRIVILEGES ON pathogens.* to '${MYSQL_E_USER}'@'localhost';"
    echo "FLUSH PRIVILEGES;"
) | mysql --user "${MYSQL_R_USER}" --password="${MYSQL_R_PW}"



CheckError sed -i -e "s;VFDB_dbuser=edge_user\$;VFDB_dbuser=${MYSQL_E_USER};" \
            	-e "s;VFDB_dbpasswd=edge_user_password\$;VFDB_dbpasswd=${MYSQL_E_PW};" \
            	-e "s;edge_pathogen_detection=0\$;edge_pathogen_detection=1;" \
            	-e "s;pathogen_dbuser=edge_user\$;pathogen_dbuser=${MYSQL_E_USER};" \
            	-e "s;pathogen_dbpasswd=edge_user_password\$;pathogen_dbpasswd=${MYSQL_E_PW};" \
            	-e "s;edge_sample_metadata=0\$;edge_sample_metadata=1;" \
            	-e "s;edge_dbuser=edge_user\$;edge_dbuser=${MYSQL_E_USER};" \
            	-e "s;edge_dbpasswd=edge_user_password\$;edge_dbpasswd=${MYSQL_E_PW};" \
		       "${EDGE_HOME}/edge/edge_ui/sys.properties"
		       
unset HTTPS_PROXY
unset HTTP_PROXY
unset https_proxy
unset http_proxy	

cat > "/start.sh" << _EOM   
#!/bin/bash

chown -R ${EDGE_User}:${EDGE_Group} ${EDGE_HOME}/EDGE_output
chown -R ${EDGE_User}:${EDGE_Group} ${EDGE_HOME}/EDGE_input
chown -R mysql:mysql /var/lib/mysql
usermod -G staff mysql
usermod -G staff ${EDGE_User}
usermod -d /var/lib/mysql/ mysql

service mysql start
sleep 5;
service tomcat7 start
sleep 1;
source /etc/apache2/envvars && exec /usr/sbin/apache2 -DFOREGROUND
_EOM

chmod 755 "/start.sh"

service tomcat7 start
sleep 10;
# tomcat web app configuration
CheckError cp "${EDGE_HOME}/edge/userManagement/sys.properties" "${TOMCAT_APPS}/userManagement/WEB-INF/classes/sys.properties"
CheckError chmod 744 "${TOMCAT_APPS}/userManagement/WEB-INF/classes/sys.properties"


## docker run -d --privileged=true --security-opt "seccomp:unconfined" --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE -v "/sys/fs/cgroup:/sys/fs/cgroup:ro" -v /Users/218819/Projects/edge-bitbucket:/edge_source --name edge_dev_phase2 edge_dev /bin/bash -c /usr/sbin/init
## docker exec -it edge_dev bash