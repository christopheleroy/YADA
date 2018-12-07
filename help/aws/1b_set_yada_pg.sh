#!/bin/sh
#############################################################################################
# Install postgresql client on EC2 instance
# Create Yada schema in a Postgres RDS instance (destructive), generate password if not specified
# Add YADA artefacts to Yada schema
# Prepare ROOT.war for Yada pointing to this new schema
# Install ROOT.war and start Tomcat
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
POSTGRESJDBCJAR=${POSTGRESJDBCJAR-postgresql-9.4-1202.jdbc4.jar}

ja=$(dirname $0)/jdk-art
scp $SSHOPTS $SSHKEY $ja/yadactl.sh $TARGET:    #copy to main user's home
ssh $SSHOPTS $SSHKEY $TARGET "chmod 755 yadactl.sh ; sudo yum install -y postgresql"

if [ -z "$YADAPASS" ]; then
	if [ -x /bin/uuidgen -o -x /usr/bin/uuidgen ]; then
		echo Generate the YADA password. You will never see it though.
		YADAPASS=`(uuidgen -r ; uuidgen -t; uuidgen ) | md5sum | head -c 20`
		if [ -z "$YADAADMINPASS" ]; then
			YADAADMINPASS=$YADAPASS
		fi
	fi
fi
if [ -z "$YADAPASS" ]; then
	echo YADAPASS must be specified as it could not be generated.
	exit 88
fi

if [ -z "$YADAADMINPASS" ]; then
	YADAADMINPASS=`(uuidgen -r ; uuidgen -t; uuidgen ) | md5sum | head -c 20`
	echo Yada Admin Password will be $YADAADMINPASS
	echo Yada user password will be $YADAPASS
fi

	
		

YADAPASS=${YADAPASS-rulebreakers}
MASTERPGOWNER=${MASTERPGOWNER-myfnapp}
MASTERPGHOST=${MASTERPGHOST-myfnapptst00.cmveeqewqewqwe.us-east-1.rds.amazonaws.com}
MASTERPGPASS=${MASTERPGPASS-00yellow00dark}
MASTERPGDB=${MASTERPGDB-myfnapptst00}
MASTERPGPORT=${MASTERPGPORT-5432}



WARFIN=YADA/yada-war/target/ROOT.war
WARFTMP=YADAwar.tmp
WARFOUT=ROOT.war

JDBCURL=jdbc:postgresql://${MASTERPGHOST}:${MASTERPGPORT}/yada
JDBCDRIVER=org.postgresql.Driver


#  manage sensitive 'yadapg.sql' file so that it is barely possible
# for a concurrent user to see - the file contains the YADA user password eventually
rm /tmp/yadapg.$$.sql
touch /tmp/yadapg.$$.sql
chmod 600 /tmp/yadapg.$$.sql

cat > /tmp/yadapg.$$.sql <<EofSQL
drop database YADA;
drop user YADA;
create user YADA password '$YADAPASS';
grant YADA to $MASTERPGOWNER;
create database YADA with owner = YADA;
\q
EofSQL

(echo $MASTERPGPASS ; cat /tmp/yadapg.$$.sql) | ssh $SSHKEY $TARGET psql -h ${MASTERPGHOST} -p $MASTERPGPORT -U ${MASTERPGOWNER} -d $MASTERPGDB
rm /tmp/yadapg.$$.sql

# please note that, in Postgres, username are lowercase, and psql needs it lowercase
UUU=YADA/yada-api/target/test-classes
ssh $SSOPTS $SSHKEY $TARGET "(echo $YADAPASS; cat $UUU/YADA_db_PostgreSQL.sql $UUU/YADA_query_essentials.sql | perl -pe s,/home.ec2/ec2-user/YADA/yada-api/target/test-classes,/opt/yada,g ; echo UPDATE YADA_USER set pw = \\'$YADAADMINPASS\\' WHERE userid = \\'YADA\\'\; ) | psql -h ${MASTERPGHOST} -p ${MASTERPGPORT} -U yada -d yada"

WARF=${WARFIN}

set -x

ssh $SSHOPTS $SSHKEY ${TARGET} "rm -rf ${WARFOUT} ${WARFTMP};mkdir ${WARFTMP} ; cd ${WARFTMP}; jar xvf ../${WARFIN}; rm WEB-INF/classes/YADA.properties"

touch /tmp/yadadb.$$.props ; chmod 600 /tmp/yadadb.$$.props
# note that for Postgres, we've had issues when username is in all caps in this file
cat > /tmp/yadadb.$$.props <<EndOfProps
jdbcUrl=$JDBCURL
driverClassName=$JDBCDRIVER
username=yada
password=$YADAPASS
autoCommit=false
connectionTimeout=300000
idleTimeout=600000
maxLifetime=1800000
minimumIdle=5
maximumPoolSize=100
poolName=HikariPool-YADA
EndOfProps


ssh $SSHOPTS $SSHKEY ${TARGET} "sudo mkdir -p /opt/yada/etc/"
cat /tmp/yadadb.$$.props | ssh $SSHOPTS $SSHKEY ${TARGET} "sudo sh -c 'cat > /opt/yada/etc/YADA.properties; sudo chown -R tomcat.tomcat /opt/yada;chmod o-rwx -R /opt/yada'"
scp $SSHOPTS $SSHKEY $(dirname $0)/jdk-art/$POSTGRESJDBCJAR ${TARGET}:/tmp
ssh $SSHOPTS $SSHKEY ${TARGET} "sudo  cp /tmp/$POSTGRESJDBCJAR /opt/tomcat/lib; sudo chmod a+r /opt/tomcat/lib/$POSTGRESJDBCJAR"
ssh $SSHOPTS $SSHKEY ${TARGET} "cd ${WARFTMP} ; jar cvf ../${WARFOUT} .; chmod 600 ../${WARFOUT}" 
ssh $SSHOPTS $SSHKEY ${TARGET} "rm -rf ${WARFTMP}"
ssh $SSHOPTS $SSHKEY ${TARGET} "sudo rm -rf /opt/tomcat/webapps/ROOT.war; sudo mv /opt/tomcat/webapps/ROOT /opt/tomcat/webapps.ROOT"
ssh $SSHOPTS $SSHKEY ${TARGET} "sudo cp ${WARFOUT} /opt/tomcat/webapps/ROOT.war ; sudo chown tomcat /opt/tomcat/webapps/ROOT.war; chmod 600 ${WARFOUT} "
ssh $SSHOPTS $SSHKEY ${TARGET} "sudo systemctl restart tomcat.service"











