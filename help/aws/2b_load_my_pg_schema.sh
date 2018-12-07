#!/bin/sh
#############################################################################################
# call psql on the REMOTE_ADDR where you know your psql installation will reach your RDS
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


MASTERPGOWNER=${MASTERPGOWNER-myfnapp}
MASTERPGHOST=${MASTERPGHOST-myfnapptst00.cmveeqewqewqwe.us-east-1.rds.amazonaws.com}
MASTERPGPASS=${MASTERPGPASS-00yellow00dark}
MASTERPGDB=${MASTERPGDB-myfnapptst00}
MASTERPGPORT=${MASTERPGPORT-5432}


# please note that, in Postgres, username are lowercase, and psql needs it lowercase
(echo $MASTERPGPASS ; cat  ) | ssh $SSHOPTS $SSHKEY $TARGET "psql -h ${MASTERPGHOST} -p ${MASTERPGPORT} -U ${MASTERPGOWNER} -d ${MASTERPGDB} -e"












