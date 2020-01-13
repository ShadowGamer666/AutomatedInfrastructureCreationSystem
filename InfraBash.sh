echo "Script Found!!!"
FILETYPE=$1
echo $FILETYPE
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
