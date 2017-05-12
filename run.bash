#!/bin/bash

#
# Naemon container bootstrap. See the readme for usage.
#
source /data_dirs.env
DATA_PATH=/data

for datadir in "${DATA_DIRS[@]}"; do
  if [ ! -e "${DATA_PATH}/${datadir#/*}" ]
  then
    echo "Installing ${datadir}"
    mkdir -p ${DATA_PATH}/${datadir#/*}
    if [ "$(ls -A ${datadir}-template 2> /dev/null)"  ]
    then
      cp -pr ${datadir}-template/* ${DATA_PATH}/${datadir#/*}/
    fi
  fi
done

LDAP_CONF_TEMPLATE='LDAPCacheEntries 0
<Location /thruk/>
  AuthName \"Thruk LDAP Auth\"
  AuthType Basic
  AuthBasicProvider file ldap
  AuthUserFile /etc/thruk/htpasswd
  AuthLDAPURL $WEB_LDAP_URL
  AuthLDAPBindDN $WEB_LDAP_BIND_DN
  AuthLDAPBindPassword $WEB_LDAP_BIND_PASS
  Require valid-user
</Location>'

if [ ! -e /._container_setup ]
then
  #
  # SMTP configuration
  # Varaibles:
  # - SMTP_HOST
  # - SMTP_PORT
  # - SMTP_LOGIN
  # - SMTP_PASS
  # - SMTP_USE_TLS
  # - NOTIFICATION_FROM
  if [ -z "$SMTP_HOST" ]
  then
    echo "!! SMTP not configured, email will be sent !!"
  else
    SMTP_PORT=${SMTP_PORT:-25}
    DEFAULT_SMTP_USE_TLS=true
    if (( SMTP_PORT == 25 ))
    then
      DEFAULT_SMTP_USE_TLS=false
    fi
    SMTP_USE_TLS=${SMTP_USE_TLS:-$DEFAULT_SMTP_USE_TLS}
    echo "Configuring SMTP"
    # Setup the per-instance hostname in NAEMON
    sed -i "s/^hostname=.*/hostname=${HOSTNAME}/" /etc/ssmtp/ssmtp.conf
    sed -i "s/^mailhub=.*/mailhub=${SMTP_HOST}:${SMTP_PORT}/" /etc/ssmtp/ssmtp.conf
    if [[ -n "$SMTP_LOGIN" && -n "$SMTP_PASS" ]]
    then
      echo "AuthUser=${SMTP_LOGIN}" >> /etc/ssmtp/ssmtp.conf
      echo "AuthPass=${SMTP_PASS}" >> /etc/ssmtp/ssmtp.conf
    fi

    if [ $SMTP_USE_TLS == true ]
    then
      echo "UseTLS=Yes" >> /etc/ssmtp/ssmtp.conf
      echo "UseSTARTTLS=Yes" >> /etc/ssmtp/ssmtp.conf
    fi
  fi
 
  #
  # Thruk LDAP authentication (optional, see readme)
  #
  # Varaibles
  # - WEB_LDAP_AUTH_ENABLED
  # - WEB_LDAP_SSL
  # - WEB_LDAP_SSL_VERIFY
  # - WEB_LDAP_SSL_CA
  # - WEB_LDAP_HOST
  # - WEB_LDAP_PORT
  # - WEB_LDAP_BIND_DN
  # - WEB_LDAP_BIND_PASS
  # - WEB_LDAP_BASE_DN
  # - WEB_LDAP_UID
  # - WEB_LDAP_FILTER
  DEFAULT_WEB_LDAP_AUTH_ENABLED=false
  if [ -n "$WEB_LDAP_HOST" ]
  then
   DEFAULT_WEB_LDAP_AUTH_ENABLED=true
  fi

  WEB_LDAP_SSL=${WEB_LDAP_SSL:-false}
  DEFAULT_WEB_LDAP_PORT="389"
  if [ $WEB_LDAP_SSL == true ]
  then
   DEFAULT_WEB_LDAP_PORT="636"
  fi

  WEB_LDAP_PORT="${WEB_LDAP_PORT:-$DEFAULT_WEB_LDAP_PORT}"
  DEFAULT_WEB_LDAP_SSL_VERIFY=false
  if [ -n "$WEB_LDAP_SSL_CA" ]
  then
   DEFAULT_WEB_LDAP_SSL_VERIFY=true
  fi
  WEB_LDAP_SSL_VERIFY=${WEB_LDAP_SSL_VERIFY:-$DEFAULT_WEB_LDAP_SSL_VERIFY}
  WEB_LDAP_UID=${WEB_LDAP_UID:-uid}
  WEB_LDAP_AUTH_ENABLED=${WEB_LDAP_AUTH_ENABLED:-$DEFAULT_WEB_LDAP_AUTH_ENABLED}

  if [ "$WEB_LDAP_AUTH_ENABLED" == true ]
  then
   echo "Configuring LDAP web authentication"
   cd /etc/apache2/mods-enabled
   for apache_mod in authnz_ldap.load ldap.conf ldap.load
   do
     if [ ! -e $apache_mod ]
     then
       ln -s ../mods-available/${apache_mod} $apache_mod
     fi
   done

   # Setup the WEB_LDAP_URL variable
   WEB_LDAP_URL="ldap://"
   if [ $WEB_LDAP_SSL == true ]
   then
     WEB_LDAP_URL="ldaps://"
   fi
   WEB_LDAP_URL="${WEB_LDAP_URL}${WEB_LDAP_HOST}:${WEB_LDAP_PORT}"
   WEB_LDAP_URL="${WEB_LDAP_URL}/${WEB_LDAP_BASE_DN}?${WEB_LDAP_UID}?sub?${WEB_LDAP_FILTER}"
   eval LDAP_CONF_TEMPLATE=\""$LDAP_CONF_TEMPLATE"\"
   echo "$LDAP_CONF_TEMPLATE" > /etc/apache2/conf-enabled/thruk_ldap.conf
   chown www-data:www-data /etc/apache2/conf-enabled/thruk_ldap.conf

   if [ $WEB_LDAP_SSL == true ]
   then
     SECURITY_ADD_STR="LDAPVerifyServerCert off"
     if [[ $WEB_LDAP_SSL_VERIFY == true &&  -n "$WEB_LDAP_SSL_CA" ]]
     then
       SECURITY_ADD_STR="LDAPTrustedGlobalCert CA_BASE64 $WEB_LDAP_SSL_CA"
     fi
     grep -q "$SECURITY_ADD_STR" /etc/apache2/conf-enabled/security.conf
     if (( $? != 0 ))
     then
       echo $SECURITY_ADD_STR >> /etc/apache2/conf-enabled/security.conf
     fi
   fi
  fi
  touch /._container_setup
fi

# Be upgrade friendly for the jabber config
if [ ! -e /etc/naemon/conf.d/notify_jabber_commands.cfg ]
then
  if [ -e /etc/naemon/conf.d/notify_jabber.cfg ]
  then
    mv /etc/naemon/conf.d/notify_jabber.cfg /etc/naemon/conf.d/notify_jabber_commands.cfg 
  else
    cp /etc/naemon-template/conf.d/notify_jabber_commands.cfg /etc/naemon/conf.d/
  fi
fi

#
# Earlier versions of naemon store the thruk htpasswd file
# under /etc/naemon, support a smooth upgrade path by moving it
# if it exists
# 
if [ -e /etc/naemon/htpasswd ]
then
  echo "UPGRADE: Moving the htpasswd file to the new location..."
  mv /etc/naemon/htpasswd /etc/thruk/htpasswd
  # We assume the naemon password was set in an upgrade situation
  touch /etc/thruk/._install_script_password_set
fi

#
# Setup the random password for the thruk interface
#
if [ ! -e /etc/thruk/._install_script_password_set ]
then
  RANDOM_PASS=`date +%s | md5sum | base64 | head -c 8`
  WEB_ADMIN_PASSWORD=${WEB_ADMIN_PASSWORD:-$RANDOM_PASS}
  htpasswd -bc /etc/thruk/htpasswd thrukadmin ${WEB_ADMIN_PASSWORD}
  echo "Set the thrukadmin password to: $WEB_ADMIN_PASSWORD"
  touch /etc/thruk/._install_script_password_set
fi

#
# Setup the notification from email address
#
NOTIFICATION_FROM=${NOTIFICATION_FROM:-Naemon <naemon@$HOSTNAME>}
sed -i "s,| /usr/bin/mail .*\\\,| /usr/bin/mail -a \"From\: ${NOTIFICATION_FROM}\" \\\,"\
  /etc/naemon/conf.d/commands.cfg

#
# If upgrading from a previous container, move the cfg.cfg
#
if [ -e /etc/naemon/cgi.cfg ]
then
  echo "UPGRADE: Moving the cgi.cfg file to the new location..."
  mv /etc/naemon/cgi.cfg /etc/thruk/cgi.cfg
fi

#
# Note this is pretty liberal. Do not use this feature if you want
# granular control permissions
#
WEB_USERS_FULL_ACCESS=${WEB_USERS_FULL_ACCESS:-false}
if [ $WEB_USERS_FULL_ACCESS == true ]
then
  sed -i 's/authorized_for_\(.\+\)=thrukadmin/authorized_for_\1=*/' /etc/thruk/cgi.cfg
fi

#
# Configure jabber, if specified
#
# - JABBER_HOST
# - JABBER_PORT
# - JABBER_USER
# - JABBER_PASS
if [[ -n "$JABBER_USER" && -n "JABBER_PASS" ]]
then
  JABBER_HOST=${JABBER_HOST:-${JABBER_USER//*@}}
  JABBER_PORT=${JABBER_PORT:-5222}
  echo "${JABBER_USER};${JABBER_HOST}:${JABBER_PORT} ${JABBER_PASS}" > /etc/naemon/sendxmpprc
  chown naemon:naemon /etc/naemon/sendxmpprc
  chmod 600 /etc/naemon/sendxmpprc
fi

function graceful_exit(){
  /etc/init.d/apache2 stop
  # Note, "service naemon stop" does not work in the phusion image
  # We just kill the process rather than chase this down.
  pkill naemon
  exit $1
}

chown -R naemon:naemon /data/etc/naemon /data/var/log/naemon
chown -R www-data:www-data /data/var/log/thruk /data/etc/thruk

# Start the services
service naemon start
/etc/init.d/apache2 start

# Trap exit signals and do a proper shutdown
trap "graceful_exit 0;" SIGINT SIGTERM

while true
do
  service naemon status > /dev/null
  if (( $? != 0 ))
  then
    echo "Naemon no longer running"
    graceful_exit 1
  fi
  
  /etc/init.d/apache2 status > /dev/null
  if (( $? != 0 ))
  then
    echo "Apache no longer running"
    graceful_exit 2
  fi
  sleep 1
done