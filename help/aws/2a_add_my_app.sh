#!/bin/sh
#############################################################################################
# Add an App to the Yada index
# Do not call this twice for the same app !
# Consider restarting Tomcat after you've defined all your apps
#############################################################################################
if [ ! -z "$SSH_KEY_FILE" ]; then
	SSHKEY=-i \"$SSH_KEY_FILE\"
else
	SSHKEY=
fi
SSHOPTS=${SSHOPTS--q}
REM_U=${REMOTE_USER-ec2-user}
TARGET=${REM_U}@${REM_IP}
#############################################################################################

# the password for the Yada index schema
YADAPASS=${YADAPASS-rulebreakers}

# the App is on the MASTER datbase and we connect to it with this MASTER password
# although, obviously, you could have a side schema with a side password etc...
MASTERPGOWNER=${MASTERPGOWNER-myfnapp}
MASTERPGHOST=${MASTERPGHOST-myfnapptst00.cmveeqewqewqwe.us-east-1.rds.amazonaws.com}
MASTERPGPASS=${MASTERPGPASS-00yellow00dark}
MASTERPGDB=${MASTERPGDB-myfnapptst00}
MASTERPGPORT=${MASTERPGPORT-5432}

# just in case your Yada index is elsewhere:
YADAPGHOST=${YADAPGHOST-$MASTERPGHOST}
YADAPGPORT=${YADAPGPORT-$MASTERPGPORT}

# the JDBC URL to connect to the db for the APP
JDBCURL=jdbc:postgresql://${MASTERPGHOST}:${MASTERPGPORT}/yada
JDBCDRIVER=org.postgresql.Driver

# The appcode, name 
APPCODE=${APPCODE-MYFNA}
APPNAME=${APPNAME-MyFnApp}
APPDESCR=${APPDESC-MyFnApp queries}

# Dance a little to make sure the file is not accessible by others as we create and consume it
secret=/tmp/yadamyapp.$$.sql
echo Secret > $secret
chmod 600 $secret

cat >$secret <<EofSQL
insert into yada_query_conf (app,name,descr,active,conf) values ('$APPCODE','$APPNAME','$APPDESCR',1,
'jdbcUrl=$JDBCURL
driverClassName=$JDBCDRIVER
username=$MASTERPGOWNER
password=$MASTERPGPASS
autoCommit=false
connectionTimeout=300000
idleTimeout=600000
maxLifetime=1800000
minimumIdle=5
maximumPoolSize=100
poolName=HikariPool-$APPCODE
');

INSERT into YADA_UG(app,userid,role)VALUES('$APPCODE', 'YADA', 'ADMIN');

commit;
\q
EofSQL

# please note that, in Postgres, username are lowercase, and psql needs it lowercase
(echo $YADAPASS ; cat $secret ) | ssh $SSHOPTS $SSHKEY $TARGET "psql -h ${YADAPGHOST} -p ${YADAPGPORT} -U yada -d yada"
rm $secret

ssh $SSHOPTS $SSHKEY ${TARGET} "sudo systemctl restart tomcat.service"











