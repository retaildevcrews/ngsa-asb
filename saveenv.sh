#!/bin/bash

# change to the proper directory
cd $(dirname $0)

if [ -z "$ASB_DEPLOYMENT_NAME" ] || [ -z "$ASB_SPOKE_LOCATION" ] || [ -z "$ASB_ENV" ]
then
  echo "Please set ASB_DEPLOYMENT_NAME ASB_SPOKE_LOCATION ASB_ENV before running this script"
else
  if [ -f ${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env ]
  then
    if [ "$#" = 0 ] || [ $1 != "-y" ]
    then
      read -p "${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env already exists. Do you want to remove? (y/n) " response

      if ! [[ $response =~ [yY] ]]
      then
        echo "Please move or delete ${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env and rerun the script."
        exit 1;
      fi
    fi
  fi

  echo '#!/bin/bash' > ${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env
  echo '' >> ${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env

  IFS=$'\n'

  for var in $(env | grep -E 'ASB_' | sort | sed "s/=/='/g")
  do
    echo "export ${var}'" >> ${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env
  done

  cat ${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env
  echo ${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env > .current-deployment
fi
