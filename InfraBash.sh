#!/usr/bin/bash

echo "Script Found!!!"
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
CLASS_RESULT=`python3 /opt/infra/InfraPython.py $FILETYPE`
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
        echo "Google Cloud support will come in the future."
elif [ $CLOUD_PROVIDER = "AZURE" ]
then
        echo "Azure support will come in the future."
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

# Executes any required Ansible Playbooks to configure the new infrastructure.
KEY_FILEPATH="/tmp/connectfile.pem"
if [ $CLOUD_PROVIDER = "AWS" ]
then
        # Obtains the nessecary output data from Terraform.
        SERVICE_NAME=$PROJECT_NAME"InfraService"
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
        ansible-playbook -i ec2.py -l tag_Service_$SERVICE_NAME Playbooks/webserver_php.yml --key-file $KEY_FILEPATH --flush-cache
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
        echo "----------"
        echo "SRS Infrastructure has been successfully created for:"
        echo $PROJECT_NAME
        echo "----------"
fi
