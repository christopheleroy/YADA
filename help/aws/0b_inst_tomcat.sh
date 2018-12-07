#!/bin/sh
#############################################################################################
# install Tomcat for the purpose of running a YADA instance on
# this fresh EC2 instance
# The Yada instance runs on a Yada index which is pointed at by the file /opt/yada/etc/YADA.properties
# that is - the file is external to the Yada WAR file
#############################################################################################
if [ ! -z "$SSH_KEY_FILE" ]; then
	SSHKEY=-i \"$SSH_KEY_FILE\"
else
	SSHKEY=
fi
SSH_OPTS=${SSH_OPTS--q}
REM_U=${REMOTE_USER-ec2-user}
TARGET=${REM_U}@${REM_IP}
#############################################################################################

TOMCATLOC=${TOMCATLOC-http://archive.apache.org/dist/tomcat/}
TOMCATVER=${TOMCATVER-8.5.34}
TOMCATHEAD=${TOMCATHEAD-tomcat-8}
TOMCATSHA512=131dfe23918f33fb24cefa7a03286c786304151f95f7bc0b6e34dfb6b0d1e65fe606e48b85c60c8a522938d1a01a36b540e69c94f36973321858e229731cda82

cat > /tmp/just-do-it.$$.sh <<EndOfNike
set -x 
cp /tmp/tomcat.service /etc/systemd/system/
groupadd tomcat
mkdir /opt/tomcat
useradd -s /bin/nologin -g tomcat -d /opt/tomcat tomcat

env http_proxy=$HANDYPROXY wget  ${TOMCATLOC}/$TOMCATHEAD/v$TOMCATVER/bin/apache-tomcat-${TOMCATVER}.tar.gz
SHA512TOM=\$(cat apache-tomcat-${TOMCATVER}.tar.gz | sha512sum | awk '{print \$1 }' )
if [ \$SHA512TOM = $TOMCATSHA512 ]; then
	tar -zxvf apache-tomcat-${TOMCATVER}.tar.gz -C /opt/tomcat --strip-components=1
	cd /opt/tomcat
	chgrp -R tomcat conf
	chmod g+rwx conf 
	chmod -R g+r conf
	chown -R tomcat logs/ temp/ webapps/ work/
	chgrp -R tomcat bin
	chgrp -R tomcat lib
	echo export JAVA_OPTS=\"\\\$JAVA_OPTS -DYADA.properties.path=/opt/yada/etc/YADA.properties -Dsecurity.token=awsYADAaws\" >bin/setenv.sh
	chmod g+rwx bin
	chmod g+r bin/*
else
	echo Tomcat download checksum failed...
	exit 99
fi
EndOfNike

inithome=$(dirname $0)

# transfer the template tomcat.service
scp $SSHOPTS $SSHKEY ${inithome}/jdk-art/tomcat.service $TARGET:/tmp/tomcat.service
# send script to install tomcat.service, install tomcat etc.
scp $SSHOPTS $SSHKEY /tmp/just-do-it.$$.sh $TARGET:/tmp/
# run the script to install tomcat, including creating tomcat user and tomcat group, 
# and install tomcat.service to systemd.
ssh $SSHOPTS $SSHKEY $TARGET sudo /bin/sh /tmp/just-do-it.$$.sh








