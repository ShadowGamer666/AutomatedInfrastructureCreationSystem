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
echo $FILETYPE
echo $CREDENTIALS
echo $PROJECT_INFO
# Sets up credential access for AutoML Classification Model.
export GOOGLE_APPLICATION_CREDENTIALS="/opt/infra/automl.json"
# Runs the Python Google AutoML Classification script.
echo "Peformining Classification Analysis on SRS data ....."
CLASSRESULT=`python3 /opt/infra/InfraPython.py $FILETYPE`
# Prints the Classification result to the user.
echo "SRS Classification Complete. This application requires:"
echo $CLASSRESULT
# Build the required template for the user with Terraform.
echo "Creating Infrastructure for Application ....."
# Splits the user credentials into their individual elements.
TEMPLATE_NAME=`echo $CLASSRESULT | cut -d' ' -f1`
CLOUD_PROVIDER=`echo $CREDENTIALS | cut -d' ' -f1`
# Sets up user credentials based on the selected cloud provider.
if [ $CLOUD_PROVIDER = "AWS" ]
then
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
        printenv AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
        # Ensures script is executing the correct Terraform template.
        cd /opt/infra/InfrastructureLib/Terraform/Projects/aws_$TEMPLATE_NAME
elif [ $CLOUD_PROVIDER = "GOOGLE" ]
then
        echo "Google Cloud support will come in the future."
elif [ $CLOUD_PROVIDER = "AZURE" ]
then
        echo "Azure support will come in the future."
fi
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
        echo "Infrastructure Creation Failed."
        # Wipes all failed data from the system.
        terraform state list | xargs -L 1 terraform state rm
        exit 3
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
        # Ensures script can easily access Ansible playbooks.
        cd /opt/infra/InfrastructureLib/Ansible
        # Obtains Inv data for user's current EC2 infrastructure.
        ./ec2.py --refresh-cache
        # Runs the required playbook on the newly created EC2.
        ansible-playbook -i ec2.py -l tag_Service_$SERVICE_NAME Playbooks/webserver_php.yml --key-file $KEY_FILEPATH --flush-cache
fi

# Records the success of the Ansible operation.
ANSIBLE_SUCCESS=$?
# Halts execution if Ansible configuration was unsuccessful for any reason.
if [ $ANSIBLE_SUCCESS -ne 0 ]
then
        echo "Infrastructure Configuration Failed."
        exit 4
fi

if [ $TERRAFORM_SUCCESS -eq 0 ]
then
        # Removes Project State information if required.
        terraform state list | xargs -L 1 terraform state rm 2> /dev/null
        echo "SRS Infrastructure has been successfully created for:"
        echo $PROJECT_NAME
fi
