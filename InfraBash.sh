#!/usr/bin/bash

echo "----------"
echo "Script Found !!!!!"
echo "----------"

FILETYPE=$1
# Reads in user credentials for the chosen cloud provider.
CREDENTIALS=`openssl rsautl -decrypt -inkey /opt/infra/infra_exchange_key.pem -in /tmp/encryptcreds.txt`
# Reads in project info provided by the user.
PROJECT_INFO=`openssl rsautl -decrypt -inkey /opt/infra/infra_exchange_key.pem -in /tmp/encryptprojectinfo.txt`
PROJECT_NAME=`echo $PROJECT_INFO | cut -d' ' -f1`
DB_USERNAME=`echo $PROJECT_INFO | cut -d' ' -f2`
DB_PASSWORD=`echo $PROJECT_INFO | cut -d' ' -f3`
# Sets up credential access for AutoML Classification Model.
export GOOGLE_APPLICATION_CREDENTIALS="/opt/infra/automl.json"
# Runs the Python Google AutoML Classification script.
echo "----------"
echo "Peformining Classification Analysis on SRS data ....."
echo "----------"
CLASS_RESULT=`python3 /opt/infra/InfraPythonClass.py $FILETYPE`
# Ensures that Model Prediction was successful.
PREDICTION_SUCCESS=$?
if [ $PREDICTION_SUCCESS -ne 0 ]
then
        echo "xxxxxxxxxx"
        echo "Model Prediction Failure Detected !!!!!"
        echo "xxxxxxxxxx"
        exit 15
fi
# Prints the Classification result to the user.
echo "----------"
echo "SRS Classification Complete. This application requires:"
echo $CLASS_RESULT "[<Class> : <Confidence>]"
echo "----------"
# Build the required template for the user with Terraform.
echo "----------"
echo "Beginning Infrastructure Creation for "$PROJECT_NAME" ....."
echo "----------"
# Splits the user credentials into their individual elements.
TEMPLATE_NAME=`echo $CLASS_RESULT | cut -d' ' -f1`
# Records for Ansible if the template requires server configuration.
if [ $TEMPLATE_NAME = "mobile_bucket_noserver" ] || [ $TEMPLATE_NAME = "mobile_dbcluster_noserver" ] || [ $TEMPLATE_NAME = "mobile_db_noserver" ]
then
        SERVER=false
else
        SERVER=true
fi
CLOUD_PROVIDER=`echo $CREDENTIALS | cut -d' ' -f1`
# Gets the Infra Application Root Directory from Env Variable.
INFRA_PATH="/opt/infra"
# Sets up user credentials based on the selected cloud provider.
if [ $CLOUD_PROVIDER = "AWS" ]
then
        echo "----------"
        echo "AWS is set as the Default Provider ....."
        echo "----------"
        # Exports AWS connection parameters to the Shell Env.
        ACCESS_KEY_ID=`echo $CREDENTIALS | cut -d' ' -f2`
        SECRET_ACCESS_KEY=`echo $CREDENTIALS | cut -d' ' -f3`
        DEFAULT_REGION=`echo $CREDENTIALS | cut -d' ' -f4`
        DEFAULT_SUBNET_ID=`echo $CREDENTIALS | cut -d' ' -f5`
        DEFAULT_VPC_ID=`echo $CREDENTIALS | cut -d' ' -f6`
        DEFAULT_RDSSUBNET_NAME=`echo $CREDENTIALS | cut -d' ' -f7`
        export AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID
        export AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY
        export AWS_DEFAULT_REGION=$DEFAULT_REGION
        # Checks that env variables have been set correctly.
        printenv AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION >/dev/null 2> /dev/null
        AWS_PARAMETER_SUCCESS=$?
        if [ $AWS_PARAMETER_SUCCESS -ne 0 ]
        then
                echo "xxxxxxxxxx"
                echo "Script Cannot Load Cloud Provider Parameters !!!!!"
                echo "xxxxxxxxxx"
                exit 20
        else
                echo "----------"
                echo "AWS Parameters Loaded Successfully ....."
                echo "----------"
        fi
        # Ensures script is executing the correct Terraform template.
        cd $INFRA_PATH/InfrastructureLib/Terraform/Projects/aws_$TEMPLATE_NAME
elif [ $CLOUD_PROVIDER = "GOOGLE" ]
then
        echo "Google Cloud Support will come in the future."
elif [ $CLOUD_PROVIDER = "AZURE" ]
then
        echo "Azure Support will come in the future."
fi
echo "----------"
echo "Beginning Terraform Creation Process ....."
echo "----------"
# Executes the required Terraform script based on classification.
terraform init -input=false
terraform apply \
-var project_name=$PROJECT_NAME \
-var db_username=$DB_USERNAME \
-var db_password=$DB_PASSWORD \
-var ec2_subnet_id=$DEFAULT_SUBNET_ID \
-var ec2_vpc_id=$DEFAULT_VPC_ID \
-var rds_subnet_group_name=$DEFAULT_RDSSUBNET_NAME \
-var region=$DEFAULT_REGION \
-var "project_tags={\"Service\":\""$PROJECT_NAME"InfraService\"}" \
-lock=false -input=false -auto-approve
# -lock=false ensures no state data conflicts from previous sessions.
# The tag ensures Ansible has something to reference.

# Records the sucess of the Terraform operation.
TERRAFORM_SUCCESS=$?
# Halts execution if Terraform operation was unsuccessful for any reason.
if [ $TERRAFORM_SUCCESS -ne 0 ]
then
        echo "xxxxxxxxxx"
        echo "Infrastructure Creation Failed !!!!!"
        echo "xxxxxxxxxx"
        # Wipes all failed data from the system.
        terraform state list | xargs -L 1 terraform state rm
        exit 3
else
        echo "----------"
        echo "Terraform Infrastructure Creation Complete ....."
        echo "----------"
fi

# Runs the Google AutoML Extraction Model script.
echo "----------"
echo "Performing Extraction Analysis on SRS Data ....."
echo "----------"
# Resets to Root Directory to get prediction from Extraction model.
cd $INFRA_PATH
# Discovers if any configuration is considered nessecary by the Extraction Model.
EXTRACT_RESULT=`python3 InfraPythonExtract.py $FILETYPE`
# Ensures that Model Prediction was successful.
EXTRACTION_SUCCESS=$?
if [ $EXTRACTION_SUCCESS -ne 0 ]
then
        echo "xxxxxxxxxx"
        echo "Model Prediction Failure Detected !!!!!"
        echo "xxxxxxxxxx"
        exit 16
fi
# Sets Server flag to False if Extraction Model suggests no configuration chang$
if [ "$EXTRACT_RESULT" = "No Label has been assigned." ]
then
        echo "----------"
        echo "No Infrastructure Configuration will be Performed ....."
        echo "----------"
        SERVER=false
else
        # Otherwise prints the Extraction result to the user.
        echo "----------"
        echo "SRS Configuration Analysis Complete. This application requires:"
        echo $EXTRACT_RESULT "[<Entity> : <Confidence>]"
        echo "----------"
fi

PLAYBOOK_NAME=`echo $EXTRACT_RESULT | cut -d' ' -f1`
KEY_FILEPATH="/tmp/connectfile.pem"
# Executes any required Ansible Playbooks to configure the new infrastructure.
if [ $CLOUD_PROVIDER = "AWS" ] && [ $SERVER = true ]
then
        # Obtains the nessecary output data from Terraform.
        SERVICE_NAME=$PROJECT_NAME"InfraService"
        # Ensures script has access to Terraform outputs.
        cd $INFRA_PATH/InfrastructureLib/Terraform/Projects/aws_$TEMPLATE_NAME
        # Writes the required key to a tmp file.
        terraform output ec2_private_key > $KEY_FILEPATH
        # Ensures KeyFile has the correct permissions level.
        sudo chmod 600 $KEY_FILEPATH
        # Ensures that a valid key has been provided by checking for empty keyfile.
        [ -s $KEY_FILEPATH ]
        VALID_KEY=$?
        if [ $VALID_KEY -ne 0 ]
        then
                echo "xxxxxxxxxx"
                echo "Invalid Ansible Access Key Provided !!!!!"
                echo "xxxxxxxxxx"
                exit 12
        fi
        # Ensures script can easily access Ansible playbooks.
        cd $INFRA_PATH/InfrastructureLib/Ansible
        # Obtains Inv data for user's current EC2 infrastructure.
        echo "----------"
        echo "Obtaining AWS EC2 Host Information ....."
        echo "----------"
        ./ec2.py --refresh-cache
        # Runs the required playbook on the newly created EC2.
        echo "----------"
        echo "Beginning Ansible Playbook Configuration ....."
        echo "----------"
        # Read the Extraction Model output into a Bash array.
        IFS=' ' read -a EXTRACT_ARRAY <<< "${EXTRACT_RESULT}"
        for playbook in "${!EXTRACT_ARRAY[@]}"
        do
                # Playbooks will always have even indexes.
                if [ $((playbook%2)) -eq 0 ]
                then
                        PLAYBOOK_NAME=${EXTRACT_ARRAY[$playbook]}
                        echo $PLAYBOOK_NAME
                        ansible-playbook -i ec2.py -l tag_Service_$SERVICE_NAME Playbooks/$PLAYBOOK_NAME.yml --key-file $KEY_FILEPATH --flush-cache
                fi
        done
elif [ $CLOUD_PROVIDER = "GOOGLE" ] && [ $SERVER = true ]
then
        echo "Google Clouud Support will come in the future."
elif [ $CLOUD_PROVIDER = "AZURE" ] && [ $SERVER = true ]
then
        echo "Azure Support will come in the future."
else
        echo "----------"
        echo "No Infrastructure Configuration is Required ....."
        echo "----------"
fi

# Records the success of the Ansible operation.
ANSIBLE_SUCCESS=$?
# Halts execution if Ansible configuration was unsuccessful for any reason.
if [ $ANSIBLE_SUCCESS -ne 0 ]
then
        echo "xxxxxxxxxx"
        echo "Infrastructure Configuration Failed !!!!!"
        echo "xxxxxxxxxx"
        exit 4
fi

if [ $TERRAFORM_SUCCESS -eq 0 ]
then
        # Removes Project State information if required.
        terraform state list | xargs -L 1 terraform state rm >/dev/null 2> /dev/null
        # Prevents Outputs from Conflicting.
        sleep 2
        echo "----------"
        echo "SRS Infrastructure has been successfully created and configured for:"
        echo $PROJECT_NAME
        echo "----------"
fi

