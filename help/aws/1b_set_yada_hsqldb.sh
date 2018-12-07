(#!/bin/sh
#############################################################################################
# Use HSQL db for Yada index.
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

#ssh $SSHOPTS $SSHKEY $TARGET sudo yum install -y postgresql
# Provision the necessary HSQL-DB jar
sweethome=$(dirname $0)

hj=hsqldb-2.3.4.jar 
st=sqltool-2.2.6.jar

cat >/tmp/just-do-it.$$.sh <<EofScript
rm -rf /opt/tomcat/yada-index

mkdir -p /opt/tomcat/yada-index
cp /tmp/yadainx.service /etc/systemd/system/

cd /opt/tomcat/yada-index
mkdir db jar service logs
cp /tmp/$hj /tmp/$st jar/
ln -s $hj jar/hsqldb.jar
ln -s $st jar/sqltool.jar
cp /tmp/yadainx.startup.sh service/startup.sh
cp /tmp/yadainx.shutdown.sh service/shutdown.sh
chmod 555 service/startup.sh
chown -R tomcat db logs
chgrp -R tomcat /opt/tomcat/yada-index
chmod -R g+r /opt/tomcat/yada-index
chmod ug+rx logs jar db jar service

systemctl daemon-reload
systemctl restart yadainx.service
sleep 3
echo yadainx service restarted 3 seconds ago
rm /tmp/just-do-it.$$.sh
EofScript


ja=${sweethome}/jdk-art

scp $SSHOPTS $SSHKEY $ja/yadactl.sh $TARGET:    #copy to main user's home
scp $SSHOPTS $SSHKEY $ja/$hj $ja/$st $ja/yadainx.service $ja/yadainx.startup.sh $ja/yadainx.shutdown.sh /tmp/just-do-it.$$.sh $TARGET:/tmp
ssh $SSHOPTS $SSHKEY $TARGET "chmod 755 yadactl.sh sudo /bin/sh /tmp/just-do-it.$$.sh"


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


## note that we are assuming a port of 9137 for the hsqldb server - see yadainx.startup.sh and yadainx.service - and here below
YADAINDEX_PORT=9137

# prepare a SQL Tool RC, well protected to make it easy to access for root/tomcat
(echo urlid localhost-sa; echo url jdbc:hsqldb:hsql://localhost:$YADAINDEX_PORT/yada\;shutdown=true; echo username SA ; echo password $YADAPASS ; \
 echo ; echo ;\
  echo urlid localhost-yada; echo url jdbc:hsqldb:hsql://localhost:$YADAINDEX_PORT/yada\;shutdown=true; echo username YADA ; echo password $YADAPASS ; ) | ssh $SSHOPTS $SSHKEY $TARGET "rm .x0x0.$$; touch .x0x0.$$ ; chmod 700 .x0x0.$$; cat > .x0x0.$$; sudo cp .x0x0.$$ /opt/tomcat/yada-index/service/sqltool.rc; sudo chgrp tomcat /opt/tomcat/yada-index/service/sqltool.rc ; sudo chmod 640 /opt/tomcat/yada-index/service/sqltool.rc ; rm .x0x0.$$"


WARFIN=YADA/yada-war/target/ROOT.war
WARFTMP=YADAwar.tmp
WARFOUT=ROOT.war
JDBCURL=jdbc:hsqldb:hsql://localhost:$YADAINDEX_PORT/yada
JDBCDRIVER=org.hsqldb.jdbc.JDBCDriver


#  manage sensitive 'yadapg.sql' file so that it is barely possible
# for a concurrent user to see - the file contains the YADA user password eventually
rm /tmp/yadaHQ.$$.sql
touch /tmp/yadaHQ.$$.sql
chmod 600 /tmp/yadaHQ.$$.sql

cat > /tmp/yadaHQ.$$.sql <<EofSQL
drop user YADA;
drop schema YADA;
alter user "SA" set password "$YADAPASS";
create user YADA password "$YADAPASS" ADMIN;
create schema YADA AUTHORIZATION DBA;
ALTER USER "YADA" set initial schema "YADA";
EofSQL

#echo urlid sa0 ; echo url jdbc:hsqldb:localhost:$YADA_INDEX_PORT ; echo username SA echo password; echo ; echo urlid yada; echo url jdbc:hsqldb:localhost:$YADA_INDEX_PORT; echo username yada; echo password $YADAPASS;echo echo urlid yadasa ; echo url jdbc:hsqldb:localhost:$YADA_INDEX_PORT ; 
cat /tmp/yadaHQ.$$.sql  | ssh $SSHOPTS $SSHKEY $TARGET "java -jar /opt/tomcat/yada-index/jar/$st --inlineRc=url=jdbc:hsqldb:hsql://localhost:$YADAINDEX_PORT/yada,user=SA,password=  --stdInput"

#rm /tmp/yadaHQ.$$.sql

UUU=YADA/yada-api/target/test-classes
ssh $SSOPTS $SSHKEY $TARGET "(cat $UUU/YADA_db_HSQLdb.sql $UUU/YADA_query_essentials.sql ; echo COMMIT\; ; echo \\q) | sudo java -jar /opt/tomcat/yada-index/jar/$st --rcFile /opt/tomcat/yada-index/service/sqltool.rc  --stdInput localhost-yada"



WARF=${WARFIN}

set -x

ssh $SSHOPTS $SSHKEY ${TARGET} "rm -rf ${WARFOUT} ${WARFTMP};mkdir ${WARFTMP} ; cd ${WARFTMP}; jar xvf ../${WARFIN}"

touch /tmp/yadadb.$$.props ; chmod 600 /tmp/yadadb.$$.props
# note that for HSQLdb, the username is case sensitive and it must be all caps here...
cat > /tmp/yadadb.$$.props <<EndOfProps
jdbcUrl=$JDBCURL
driverClassName=$JDBCDRIVER
username=YADA
password=$YADAPASS
autoCommit=false
connectionTimeout=300000
idleTimeout=600000
maxLifetime=1800000
minimumIdle=5
maximumPoolSize=100
poolName=HikariPool-YADA
#connectionTestQuery=select 1 as COL1
#initializationFailFast=true
#isolateInternalQueries=false
#allowPoolSuspension=false
#readOnly=false
#registerMbeans=false
#catalog=driver default
#connectionInitSql=select 1 as COL1
#transactionIsolation=driver default
#validationTimeout=5000
#leakDetectionThreshold=0
EndOfProps


scp $SSHOPTS $SSHKEY /tmp/yadadb.$$.props $TARGET:${WARFTMP}/WEB-INF/classes/YADA.properties

ssh $SSHOPTS $SSHKEY ${TARGET} "sudo  cp /opt/tomcat/yada-index/jar/$hj /opt/tomcat/lib; sudo chmod a+r /opt/tomcat/lib/$hj"
ssh $SSHOPTS $SSHKEY ${TARGET} "cd ${WARFTMP} ; jar cvf ../${WARFOUT} .; chmod 600 ../${WARFOUT}" 
ssh $SSHOPTS $SSHKEY ${TARGET} "rm -rf ${WARFTMP}"
ssh $SSHOPTS $SSHKEY ${TARGET} "sudo rm -rf /opt/tomcat/webapps/ROOT.war; sudo mv /opt/tomcat/webapps/ROOT /opt/tomcat/webapps.ROOT"
ssh $SSHOPTS $SSHKEY ${TARGET} "sudo cp ${WARFOUT} /opt/tomcat/webapps/ROOT.war ; sudo chown tomcat /opt/tomcat/webapps/ROOT.war "
ssh $SSHOPTS $SSHKEY ${TARGET} "sudo systemctl restart tomcat.service"











)
