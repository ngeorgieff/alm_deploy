#!/bin/bash
## Created on 3/27/2013 by Nikolay Georgieff
## 4/1/2013 1.0-RC
## 5/7/2013 1.1-Alpha
## 5/9/2013 1.1-Beta - added symlink support and connection error check
## 5/14/2013 1.1-RC - fixed symlink bug and cleaned the code //ngeorgieff
## 5/20/2013 1.1 - production version

# Logging setup
#logfile=/tmp/alm-tmplogfile
#mkfifo ${logfile}.pipe
#tee < ${logfile}.pipe $logfile &
#exec &> ${logfile}.pipe
#rm ${logfile}.pipe

USAGE="Usage: $0 [environement] [groupid] [artifact] [version] [packaging] [server] [destination]"

if  [ $# -eq 0 ] ; then
echo $USAGE
echo ""
echo "-e | -environement [OPTION] dev, test, qa, preprod, prod"
echo "-g | -groupid [Ex: edu.ucla.its.dt]"  
echo "-a | -artifact-id [OPTION] application name"
echo "-r | -release [OPTION] install OR enter custom version [e.g. 1.0.3-SNAPSHOT, 1.0.1 ...]"
echo "-p | -packaging EX: war"
echo "-s | -server [HOSTNAME]"
echo "-d | -destination EX: /var/tmp"
echo "-m | -email user1@it.domain.com group@it.domain.com"
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
-m|-email) RECIP=$2 ; shift 1 ;;
-h|--help) echo $USAGE echo $HELP; exit 1 ; shift 1 ;;
#--) shift ; break ;; # End of all options
#-*) echo "Error: Unknown option: $1" >&2; exit 1 ;;
#*) break ;; # No more options 
*) shift 1 ;;
esac
done

ALM_HOME=/opt/alm/scm
DATE=$(date +%F.%T)
GROUP_PATH=(`echo ${GROUP_ID} |sed 's:\.:/:g'`) 
FULLPATH=$ALM_HOME/$DEPLOY_ENV/$GROUP_PATH/$ARTIFACT_ID
if [ "$RELEASE_ARG" != "install" ] ; then
  RELEASEPATH=${FULLPATH}/$RELEASE_ARG
fi
if [ "$RELEASE_ARG" == "install" ] ; then
  RELEASEPATH=$(readlink -f ${FULLPATH}/release)
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

#echo "DEBUG: Release: $GET_REL_VER Current: $GET_CURRENT_VER Previous:$GET_PREV_VER"
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
#  echo "r:$GET_REL_VER c:$GET_REL_VER p:$GET_CURRENT_VER" >> $RLOG
}

# Update symlinks on rollback
function rollback_update_symlinks
{
  cd $FULLPATH && unlink $FULLPATH/current ; ln -s $GET_PREV_VER current
}
function update_install_log
{
  #echo "$DATE	r:$(readlink $FULLPATH/release) c:$(readlink $FULLPATH/current) p:$(readlink $FULLPATH/rollback)" >> $RLOG
#echo "*************************************************************" >> $RLOG
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
#  echo "$DATE	r:$(readlink $FULLPATH/release) c:$(readlink $FULLPATH/rollback) p:$(readlink $FULLPATH/rollback)" >> $RLOG
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
#  scp -l 8192 ${LAST_FILE} alm-dm@${DEST_SERVER}:${DEST_DIR} 2>&1
  scp  ${LAST_FILE} alm-dm@${DEST_SERVER}:${DEST_DIR} 2>&1
if [[ $? != 0 ]]; then
  echo -e "\e[1;31mError: Transfer failed!\e[0m"
  exit 1
else
  echo "Transfer complete."
fi
  echo "Creating short name symlink for $ARTIFACT_ID.$EXT -> $SHORT_NAME"
  ssh alm-dm@${DEST_SERVER} "bash -c 'ln -fs ${DEST_DIR}/${SHORT_NAME} ${DEST_DIR}/${ARTIFACT_ID}.${EXT} 2>&1'"

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
	  #update_release_version
	  #update_install_log
	fi  
fi

if [ "$RELEASE_ARG" != "install" ] ; then
	if  [ "$GET_CURRENT_VER" != "$GET_PREV_VER" ] ; then
  	#echo "Updating ack symlinks for $ARTIFACT_ID $GET_PREV_VER"
  	#rollback_update_symlinks
	update_install_log
else
   	#echo "$RELEASE_ARG version is same as current, skipping symlink update"
	update_install_log
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
#cat ${mylogfile} |sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" |mail -s "Artifact ${SHORT_NAME} successfully uploaded to ${DEST_SERVER}:${DEST_DIR}" $RECIP ; rm -f ${mylogfile}
exit $?
 fi
fi

