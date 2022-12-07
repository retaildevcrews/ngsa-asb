#!/bin/bash

# change to the proper directory
cd $(dirname $0)

if [ -z "$ASB_DEPLOYMENT_NAME" ] || [ -z "$ASB_ENV" ]
then
  echo "Please set ASB_DEPLOYMENT_NAME ASB_ENV before running this script"
else
  if [ -z "$ASB_SPOKE_LOCATION" ]
  then
    # only hub variables exist
    export ENV_FILE_NAME="${ASB_DEPLOYMENT_NAME}-${ASB_ENV}.env"
  else
    # hub and spoke variables
    export ENV_FILE_NAME="${ASB_DEPLOYMENT_NAME}-${ASB_ENV}-${ASB_SPOKE_LOCATION}.env"
  fi

  if [ -f ${ENV_FILE_NAME} ]
  then
    if [ "$#" = 0 ] || [ $1 != "-y" ]
    then
      read -p "${ENV_FILE_NAME} already exists. Do you want to remove? (y/n) " response

      if ! [[ $response =~ [yY] ]]
      then
        echo "Please move or delete ${ENV_FILE_NAME} and rerun the script."
        exit 1;
      fi
    fi
  fi

  echo '#!/bin/bash' > ${ENV_FILE_NAME}
  echo '' >> ${ENV_FILE_NAME}

  IFS=$'\n'

  for var in $(env | grep -E 'ASB_' | sort | sed "s/=/='/g")
  do
    echo "export ${var}'" >> ${ENV_FILE_NAME}
  done

  cat ${ENV_FILE_NAME}
  echo ${ENV_FILE_NAME} > .current-deployment
fi
