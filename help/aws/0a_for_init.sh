#!/bin/sh
#############################################################################################
# initialize a fresh EC2 instance, installing updates, Java 8, and Maven
# configure the remote user's maven settings to work with NIBR Artifactory
# currently: Maven 3.5.4 is installed. 
#            To get another version, please update the script AND include the correct SHA512 signature 
#            for the Maven bin-tar.gz
#############################################################################################
if [ ! -z "$SSH_KEY_FILE" ]; then
	SSHKEY=-i \"$SSH_KEY_FILE\"
else
	SSHKEY=
fi
SSH_OPTS=${SSH_OPTS--q}
REM_IP=${REMOTE_ADDR}
REM_U=${REMOTE_USER-ec2-user}
TARGET=${REM_U}@${REM_IP}
#############################################################################################
MAVENWEB=http://apache.cs.utah.edu/maven
MAVENBRANCH=maven-3
MAVENVER=3.5.4
MASHA512=2a803f578f341e164f6753e410413d16ab60fabe31dc491d1fe35c984a5cce696bc71f57757d4538fe7738be04065a216f3ebad4ef7e0ce1bb4c51bc36d6be86

sweethome=$(dirname $0)
if [ ! -f "$sweethome/jdk-art/user.m2.settings.xml" ]; then
	echo $0 : the directory $sweethome does not have ./jdk-art/user.m2.settings.xml
	exit 99
fi

# prepare fresh instannce with systtem updates, java8 and git. Also install xml2 as command line utility to help tweak some yada config files
ssh $SSHOPTS $SSHKEY $TARGET sudo yum update -y
ssh $SSHOPTS $SSHKEY $TARGET sudo yum install -y java-1.8.0-openjdk-devel.x86_64 git.x86_64 xml2

cat > /tmp/just-do-it.$$.sh <<EofScript
cd /opt
env http_proxy=$HANDYPROXY wget "$MAVENWEB/$MAVENBRANCH/$MAVENVER/binaries/apache-maven-${MAVENVER}-bin.tar.gz"
SHA512MVN=\$(cat apache-maven-${MAVENVER}-bin.tar.gz | sha512sum | awk '{print \$1 }' )
if [ \$SHA512MVN = $MASHA512 ]; then
	tar xvzf apache-maven-${MAVENVER}-bin.tar.gz
	ln -sf apache-maven-${MAVENVER} maven

	echo export M2_HOME=/opt/maven > /etc/profile.d/maven.sh
	echo export PATH=\"\$PATH:\\\$M2_HOME/bin\" >> /etc/profile.d/maven.sh
	echo Maven ready
else
	echo Maven archive checksum check failed
	exit 99
fi

EofScript

# send script to install maven and run it
scp $SSHOPTS $SSHKEY /tmp/just-do-it.$$.sh  $TARGET:/tmp
ssh $SSHOOPTS $SSHKEY $TARGET sudo /bin/sh /tmp/just-do-it.$$.sh

# configure Maven (.m2) for the remote user to be able to run Maven
ssh $SSHOPTS $SSHKEY $TARGET mkdir .m2
scp $SSHOPTS $SSHKEY "$sweethome/jdk-art/user.m2.settings.xml" $TARGET:.m2/settings.xml





	






