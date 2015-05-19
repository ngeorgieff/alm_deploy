#!/bin/bash
## Created on 3/27/2013 // ngeorgieff
## 4/1/2013 1.0-RC
## 5/7/2013 1.1-Alpha
## 5/9/2013 1.1-Beta - added symlink support and connection error check
## 5/14/2013 1.1-RC - fixed symlink bug and cleaned the code //ngeorgieff
## 5/20/2013 1.1 - production version
## 11/28/2013 1.2 - added Windows support and code cleanup // ngeorgieff

USAGE="Usage: $0 [environement] [groupid] [artifact] [version] [packaging] [server] [destination] [domain]"

if  [ $# -eq 0 ] ; then
echo $USAGE
echo ""
echo "-e | -environement [OPTION] dev, test, qa, preprod, prod"
echo "-g | -groupid [Ex: edu.ucla.its.dt]"  
echo "-a | -artifact-id [OPTION] application name"
echo "-r | -release [OPTION] install OR rollback"
echo "-p | -packaging EX: war"
echo "-s | -server [HOSTNAME]"
echo "-d | -destination EX: /var/tmp"
echo "-W | -domain AISDEV or AIS_SERVICES"
echo ""
     exit 0
fi 
while [ $# -gt 0 ] ; do
case $1 in
-e|-environment) DEPLOY_ENV=$2 ; shift 1 ;;
-g|-group) GROUP_ID=$2 ; shift 1 ;;
-a|-artifact-id) ARTIFACT_ID=$2 ; shift 1 ;;
-r|-release) RELEASE_ARG=$2 ; shift 1 ;;
-p|-packaging) EXT=$2 ; shift 1 ;;
-s|-server) DEST_SERVER=$2 ; shift 1 ;;
-d|-destination) DEST_DIR=$2 ; shift 1 ;;
-W|-domain) DOMAIN=$2 ; shift 1 ;;
-h|--help) echo $USAGE echo $HELP; exit 1 ; shift 1 ;;
*) shift 1 ;;
esac
done

ALM_HOME=/opt/alm/scm
DATE=$(date +%F.%T)
GROUP_PATH=(`echo ${GROUP_ID} |sed 's:\.:/:g'`) 
FULLPATH=$ALM_HOME/$DEPLOY_ENV/$GROUP_PATH/$ARTIFACT_ID
if [ "$RELEASE_ARG" == "install" ] ; then
  RELEASEPATH=$(readlink -f ${FULLPATH}/release)
fi
if [ "$RELEASE_ARG" == "rollback" ] ; then
  RELEASEPATH=$(readlink -f ${FULLPATH}/rollback)
fi
LAST_FILE=$(find ${RELEASEPATH} -name *.${EXT} -type f -print  |sort |tail -1)
EMPTY_CHECK=$(find ${RELEASEPATH} -name *.${EXT} -type f -print  |sort |tail -1 |wc -l)
# Get symlink version
GET_REL_VER=$(readlink $FULLPATH/release)

# Check for history file
if [ ! -f $FULLPATH/$ARTIFACT_ID-deploy.log ]; then
  touch $FULLPATH/$ARTIFACT_ID-deploy.log 
fi

# Check for current and rollback symlinks
if [ ! -h $FULLPATH/current ];then
  cd $FULLPATH &&  ln -s $(readlink release) current 
fi
if [ ! -h $FULLPATH/rollback ];then
  cd $FULLPATH &&  ln -s $(readlink release) rollback 
fi

# Log 
RLOG=$FULLPATH/$ARTIFACT_ID-deploy.log
GET_CURRENT_VER=$(readlink $FULLPATH/current)
GET_PREV_VER=$(readlink $FULLPATH/rollback)

# Script will exit if they are no files
if [ "$EMPTY_CHECK" -eq 0 ] ; then
  echo -e "\e[1;31mNo package\e[0m \e[1;37m$ARTIFACT_ID.$EXT\e[0m found. Please verify your script arguments"
  exit 2
else

MD5_FILE=$(md5sum ${LAST_FILE} | awk '{print $1}')
MD5_SUM=$(cat ${LAST_FILE}.md5)
SHORT_NAME=$(basename ${LAST_FILE}) 

# Update the release version to the current
function update_release_version
{
  cd $FULLPATH && unlink $FULLPATH/current &&  ln -s $GET_REL_VER current
  cd $FULLPATH && unlink $FULLPATH/rollback && ln -s $GET_CURRENT_VER rollback
}

# Update symlinks on rollback
function rollback_update_symlinks
{
  cd $FULLPATH && unlink $FULLPATH/current ; ln -s $GET_PREV_VER current
}
function update_install_log
{
echo "Date: $DATE"  >> $RLOG
echo "Action: $RELEASE_ARG" >> $RLOG
echo "Environment: $DEPLOY_ENV" >> $RLOG
echo "Group: $GROUP_ID" >> $RLOG
echo "Artifact: $ARTIFACT_ID" >> $RLOG
echo "Server: $DEST_SERVER" >> $RLOG
echo "File: ${SHORT_NAME}" >> $RLOG
echo "MD5 Sum: ${MD5_SUM}" >> $RLOG
echo "Symlinks: r:$(readlink $FULLPATH/release) c:$(readlink $FULLPATH/current) p:$(readlink $FULLPATH/rollback)" >> $RLOG
echo "*******************************************************************************" >> $RLOG
}
function update_rollback_log
{
echo "Date: $DATE"  >> $RLOG
echo "Action: $RELEASE_ARG" >> $RLOG
echo "Environment: $DEPLOY_ENV" >> $RLOG
echo "Group: $GROUP_ID" >> $RLOG
echo "Artifact: $ARTIFACT_ID" >> $RLOG
echo "Server: $DEST_SERVER" >> $RLOG
echo "File: $SHORT_NAME" >> $RLOG
echo "MD5 Sum: ${MD5_SUM}" >> $RLOG
echo "Symlinks: r:$(readlink $FULLPATH/release) c:$(readlink $FULLPATH/rollback) p:$(readlink $FULLPATH/rollback)" >> $RLOG
echo "*******************************************************************************" >> $RLOG
}


if [ "$MD5_FILE" != "$MD5_SUM" ] ; then
  echo -e "\e[1;31mError: Integrity failure\e[0m"
  exit
else
  echo "MD5 Checksum testing passed for ${SHORT_NAME} / md5sum: $MD5_SUM"
  echo "Uploading ${SHORT_NAME} to "${DEST_SERVER}:${DEST_DIR}""

  /opt/GoAnywhere_Client/RunProject -server "https://fxdirector.it.domain.com:8000/goanywhere" -user is_alm -password $(cat /home/alm-dm/ALM/fx_authentification) -project "/Infrastructure Services/ALM/ALM deploy artifact" ReleaseFileset "${RELEASEPATH}" DestDir "${DEPLOY_TMP_PATH}" DEST_SERVER "${DEST_SERVER}" fileList "${LAST_FILE}" artifactName "${ARTIFACT_ID}" artifactExtension "${EXT}" actionArg "${RELEASE_ARG}" FileName "${SHORT_NAME}" almEnvironment "${DEPLOY_ENV}" almGroup "${GROUP_ID}" md5sum "${MD5_SUM}" 
  #smbclient --socket-options='TCP_NODELAY IPTOS_LOWDELAY SO_KEEPALIVE SO_RCVBUF=65536 SO_SNDBUF=65536' -A /home/alm-dm/ALM/smb_authentification //${DEST_SERVER}/ALM -c "put ${LAST_FILE} ${ARTIFACT_ID}.${EXT}" -W ${DOMAIN}  2>&1
if [[ $? != 0 ]]; then
  echo -e "\e[1;31mError: Transfer failed!\e[0m"
  exit 1
else
  echo "Transfer complete."
fi

## if_error
RC=$?
if [ $RC -ne 0 ]
then
  echo -e "\e[1;31m`date`  - ERROR: script ended with return code $RC, please check log file.\e[0m"
  exit $?
fi

if [ "$RELEASE_ARG" == "install" ] ; then
	if [ "$GET_REL_VER" == "$GET_CURRENT_VER" ] ; then
	  echo "Redeploy for artifact $ARTIFACT_ID $GET_REL_VER detected, skipping symlink update"
	  update_install_log
else
	  echo "Updating symlinks for $ARTIFACT_ID"
	  update_release_version
	  update_install_log
	fi  
fi

if [ "$RELEASE_ARG" == "rollback" ] ; then
	if  [ "$GET_CURRENT_VER" != "$GET_PREV_VER" ] ; then
  	echo "Updating rollback symlinks for $ARTIFACT_ID $GET_PREV_VER"
  	rollback_update_symlinks
	update_rollback_log
else
   	echo "Rollback version is same as current, skipping symlink update"
	update_rollback_log
        fi
fi
echo -e "\e[1;32m`date`  - $0 has completed successfully.\e[0m"
echo " "
echo "*******************************************************************************"
echo "Date: $DATE"  
echo "Action: $RELEASE_ARG"
echo "Environment: $DEPLOY_ENV"
echo "Group: $GROUP_ID" 
echo "Artifact: $ARTIFACT_ID" 
echo "Server: $DEST_SERVER"
echo "File: $SHORT_NAME"
echo "MD5 Sum: ${MD5_SUM}"
echo "*******************************************************************************"
exit $?
fi
fi

