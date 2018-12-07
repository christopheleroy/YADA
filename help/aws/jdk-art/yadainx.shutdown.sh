#!/bin/sh

YADAINDEX=${YADAINDEX-/opt/tomcat/yada-index}
YADAINDEX_PORT=${YADAINDEX_PORT-9137}

cd $YADAINDEX
java -jar ./jar/sqltool.jar --rcFile ./service/sqltool.rc --sql 'shutdown;' localhost-sa


