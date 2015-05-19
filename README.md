# alm_deploy
Application Lifecycle Management deployment script - push artifact to target server

Usage: ./alm-dm-deploy.sh [environement] [groupid] [artifact] [version] [packaging] [server] [destination]

-e | -environement [OPTION] dev, test, qa, preprod, prod
-g | -groupid [Ex: edu.ucla.its.dt]
-a | -artifact-id [OPTION] application name
-r | -release [OPTION] install OR rollback
-p | -packaging EX: war
-s | -server [HOSTNAME]
-d | -destination EX: /var/tmp
-m | -email user1@it.ucla.edu group@it.ucla.edu

Usage:
Install latest artifact:
./alm-dm-deploy-windows.sh -e dev -g edu.ucla.alm.demo -a alm-war -r install -p war -s windows-tomcat.domain.com -d ALM -W DOMAIN_NAME
/alm-dm-deploy.sh -e prod -g edu.ucla.its.demo -a StudentServicesEAR -r install -p ear -s linux-websphere.domain.com -d /usr/local/tomcat/webapps/

Rollback latest artifact:
/alm-dm-deploy.sh -e prod -g edu.ucla.its.demo -a StudentServicesEAR -r rollback -p ear -s linux-websphere.domain.com -d /usr/local/tomcat/webapps/
