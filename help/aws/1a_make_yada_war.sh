#!/bin/sh
#############################################################################################
# Clone the YADA github repo and point to a specific tag (default: 8.5.0)
# then use Mavent to build Yada for this tag.
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
STARTFROM=.
BUILDTAG=${YADA_BUILD_TAG-8.5.0}

# clone the Yada git hub repot
ssh $SSHOPTS $SSHKEY $TARGET  "cd $STARTFROM ; test -d YADA  || env HTTPS_PROXY=$HANDYPROXY git clone https://github.com/Novartis/YADA.git"
# point to chosen build tag
ssh $SSHOPTS $SSHKEY $TARGET "cd $STARTFROM ; test -d YADA && ( cd YADA ; env HTTPS_PROXY=$HANDYPROXY git pull --all ; git reset ; git checkout $BUILDTAG )"

# go around some unresolved issure: cannot use CORS illegal settings
ssh $SSHOPTS $SSHKEY $TARGET "cd $STARTFROM/YADA/yada-war/src/main/webapp/WEB-INF/ ; mv web.xml web.xml- ; xml2 < web.xml- | perl -pe 'if(\$corscred) { s/true/false/; } if(/cors.support.credentials/) { \$corscred=1; } else {\$corscred =0;}' | 2xml  > web.xml"

# use maven to build yada
ssh $SSHOPTS $SSHKEY $TARGET ". /etc/profile.d/maven.sh ; cd $STARTFROM/YADA ; mvn package -DskipTests=true"



	






