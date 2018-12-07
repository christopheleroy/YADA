#!/bin/sh

if [ -z "$1" ]; then
	sudo tail -f /opt/tomcat/logs/catalina.out
	exit $?
fi

tocat=
tomcat=/opt/tomcat
appname=mancala
warname=$HOME/wars/$appname


case $1 in
	help)
		echo $0 \[props\|debug\|info\|trunc\|restart\]
		;;
	props)
		tocat=/opt/yada/etc/YADA.properties
		;;
	debug)
		sudo perl -pi.bak -e s/info,stdout/debug,stdout/ $tomcat/webapps/ROOT/WEB-INF/classes/log4j.properties
		sudo systemctl restart tomcat
		tocat=/dev/null
		;;
	info)
		sudo perl -pi.bak -e s/debug,stdout/info,stdout/ $tomcat/webapps/ROOT/WEB-INF/classes/log4j.properties
		sudo systemctl restart tomcat
		tocat=/dev/null
		;;
	trunc)
		sudo systemctl stop tomcat
		sudo mv $tomcat/logs/catalina.out $tomcat/logs/catalina.trunc.$(date -Is).out
		sudo systemctl start tomcat
		tocat=/dev/null
		;;
	restart)
		sudo systemctl restart tomcat
		tocat=/dev/null
		;;
	war)
		warnamenow=${warname}.$(date -Is).war
		tocat=/dev/null
		cat > ${warnamenow}
		x3=$(jar tvf ${warnamenow} | egrep -c 'index.html|js/bundle.js|WEB-INF/web.xml')
		if [ $x3 -eq 3 ]; then
			echo Warfile found agreeable ... pushing
			cd /var/www/html/$appname
			sudo unzip -o ${warnamenow}
			sudo chown -R apache .
			
		else
			echo Warfile is not agreeable. Deleting.
			rm ${warnamenow}
		fi
		;;
	build+deploy|deploy-tag)
		zhome=$(dirname $0)
		${zhome}/${appname-mancala}.build.sh $*
		;;
	*)
		;;
esac

if  [ ! -z "$tocat" ]; then
	sudo cat $tocat
	exit $?
fi

for f in $(sudo find /opt/tomcat -name \*$1\* -a -type f )
do
	echo =====================================================
	echo  ----------- $f -------------------
	echo =====================================================
	sudo cat $f
done
