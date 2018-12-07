#!/bin/sh

YADAINDEX=${YADAINDEX-/opt/tomcat/yada-index}
YADAINDEX_PORT=${YADAINDEX_PORT-9137}

cd $YADAINDEX
nohup java -cp ./jar/hsqldb.jar org.hsqldb.server.Server --port $YADAINDEX_PORT --database.0 file:db/yada --dbname.0 yada >> logs/server.log 2>&1 &


