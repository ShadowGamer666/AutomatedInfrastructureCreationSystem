# GUI to accept SRS Document/Text input for the Classification and Creation system
# Based on 'tkinter' tutorial by GeeksForGeeks at: https://www.geeksforgeeks.org/python-gui-tkinter/
import tkinter as tk
from tkinter import font as tkFont
from tkinter import filedialog as tkFile
# Open Source File Format Determination Lbrary at: https://github.com/floyernick/fleep-py
import fleep
# Allows discovery of file sizes.
import os
# Allows program to execute remote operations on the central server.
import subprocess
import platform
# Allows credentials to be sent encrypted to the central server.
import rsa

# Defines functions that will be executed by the GUI.
def input_as_text():
    srs_data = srs_text_input.get('1.0','end')
    # Saves the text input to a temp file for copying to central server.
    if platform.system() == "Windows":
        srs_filepath = "C:\\Temp\\tempsrsdoc.txt"
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        srs_filepath = "/tmp/tempsrsdoc.txt"
    srs_temp_file = open(srs_filepath,"w")
    srs_temp_file.write(srs_data)
    srs_temp_file.close()
    print(srs_data)
    input_to_central_server(srs_filepath,"txt")
    # Clears text box after analysis is complete.
    srs_text_input.delete('1.0','end')

def input_as_file():   # Allows user to select an SRS document for analysis.
    srs_file = tkFile.askopenfile(parent=inter, mode='rb', title="Choose a File")
    # Reads the selected file from the user's system.
    if srs_file != None:
        srs_filepath = srs_file.name
        srs_data = srs_file.read()
        # Checks if file meets format and size requirements for Google AutoML.
        srs_file_info = fleep.get(srs_data)
        srs_file_size = os.stat(srs_filepath).st_size / 1024 # Size comparisons happen in KB.
        print(srs_file_size)
        if srs_file_info.mime_matches("application/pdf") and srs_file_size <= 128:
            print("File retrieved, uploading to application server for analysis.")
            input_to_central_server(srs_filepath,"pdf")
            srs_file.close()
        else:
            srs_file.close()
            # Exits the operation if the file selected is not a PDF file.
            if srs_file_size > 128 and srs_file_info.mime_matches("application/pdf"):
                print("File must be less than 128KB.")
                exit(5)
            else:
                print("File retrieved is not in the PDF format.")
                exit(6)
    else:
        # Exits the operation if filepath is invalid.
        print("No file was discovered at this location.")
        srs_file.close()
        exit(9)

def input_to_central_server(srs_filepath,ext):
    # Sends file to central application server for analysis.
    # These filepaths are only used for demonstration purposes, templates of default filepaths.
    windows_server_key_filepath = infra_directory_windows + "PuttyCentralKey.ppk"
    linux_server_key_filepath = infra_directory_linux + "CentralKey.pem"
    windows_creds_key_filepath = infra_directory_windows + "CredentialKey.txt"
    linux_creds_key_filepath = infra_directory_linux + "CredentialKey.txt"
    central_server = "ec2-user@ec2-52-30-159-69.eu-west-1.compute.amazonaws.com"
    central_server_filepath = central_server+":"+infra_directory_linux+"SRSDocs/PredictSRSDoc."+ ext
    windows_encrypted_creds_filepath = "C:\\Temp\\encryptcreds.txt"
    linux_encrypted_creds_filepath = "/tmp/encryptcreds.txt"
    central_encrypted_creds_filepath = central_server+":"+linux_encrypted_creds_filepath
    # Imports the Key required to send sensitive credentials to the Central Server.

    # Reads the required infrastructure credential details and OpenSSL RSA Key.
    if platform.system() == "Windows":
        selected_provider_file = open(selected_cloud_filepath_windows, 'r')
        creds_key_file = open(windows_creds_key_filepath, 'rb')
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        selected_provider_file = open(selected_cloud_filepath_linux, 'r')
        creds_key_file = open(linux_creds_key_filepath,'rb')
    # Loads the Public Key used to encrypt sensitive cloud provider credentials.
    srs_creds_key = creds_key_file.read()
    srs_creds_key = rsa.PublicKey.load_pkcs1_openssl_pem(srs_creds_key)
    # Loads the currently selected cloud provider .
    selected_provider = selected_provider_file.read()
    selected_provider_file.close()
    creds_key_file.close()

    if selected_provider == "AWS":
        try:
            if platform.system() == "Windows":
                aws_credentials_file = open(aws_filepath_windows, 'r')
            elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
                aws_credentials_file = open(aws_filepath_linux, 'r')
            # Splits the file into it's individual parameters.
            for parameters in aws_credentials_file:
                aws_credentials = parameters.split(" ")
            # Performs any credential encryption operations required for this provider.
            # AWS Format: AWS <ACCESS_KEY> <SECRET_KEY> <DEFAULT_REGION>
            srs_user_credentials = aws_credentials[0] + " " + aws_credentials[1] + " " + aws_credentials[2] + " " + aws_credentials[3]
            # Full payload is encrypted into Bytes.
            encrypted_user_credentials = rsa.encrypt(srs_user_credentials.encode('utf8'), srs_creds_key)
        except FileNotFoundError:
            print("Please set up your AWS user credentials under 'Manage Cloud Provider Details'")
            # Prevents further execution in the event that no credentials are available.
            return
    elif selected_provider == "GOOGLE":
        print("Provider not supported at the moment.")
    elif selected_provider == "AZURE":
        print("Provider not supported at the moment.")

    # Sends encrypted credentials to a temp file for transfer to Central Server.
    if platform.system() == "Windows":
        encrypted_creds_file = open(windows_encrypted_creds_filepath, 'wb')
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        encrypted_creds_file = open(linux_encrypted_creds_filepath, 'wb')
    encrypted_creds_file.write(encrypted_user_credentials)
    encrypted_creds_file.close()

    # Requires different commands depending on the User's OS.
    print(platform.system())
    # Copies SRS data to Central Server, then executes the SRS Analysis and Infrastructure Creation script.
    if platform.system() == "Windows":
        # Putty SCP and Plick are used as they directly integrate with Bash like Putty.
        # Transfers the SRS document to the Central Server for classification analysis.
        subprocess.run(["pscp", "-i", windows_server_key_filepath, srs_filepath, central_server_filepath])
        # Sends the encrypted credentials for this session to the Central Server.
        subprocess.run(["pscp", "-i", windows_server_key_filepath, windows_encrypted_creds_filepath, central_encrypted_creds_filepath])
        # Executes the Bash wrapper script on the Central Server to perform classification and infrastructure creation.
        subprocess.run(["plink", "-ssh","-i",windows_server_key_filepath,central_server,infra_directory_linux+"InfraBash.sh",ext])
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        # Uses SSH sessions to initiate the required operations on the Central Server.
        subprocess.run(["scp", "-i", linux_server_key_filepath, srs_filepath, central_server_filepath])
        # Sends the encrypted credentials for this session to the Central Server.
        subprocess.run(["scp", "-i", linux_server_key_filepath, linux_encrypted_creds_filepath, central_encrypted_creds_filepath])
        # Executes the Bash wrapper script on the Central Server to perform classification and infrastructure creation.
        subprocess.run(["ssh", "-i",linux_server_key_filepath,central_server, infra_directory_linux+"InfraBash.sh",ext])

def set_selected_provider():
    def update_selected_provider():
        # Discovers the currently selected Radio Button.
        selected_radio_button = selected_cloud_provider.get()
        # Write this as the new user selected provider.
        if platform.system() == "Windows":
            selected_provider_file = open(selected_cloud_filepath_windows, 'w')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            selected_provider_file = open(selected_cloud_filepath_linux, 'w')
        selected_provider_file.write(selected_radio_button)
        selected_provider_file.close()

    # Creates the root GUI interface, as IntVar needs to be explicitly linked to this root.
    set_selected_provider_gui = tk.Tk()
    set_selected_provider_gui.title("Set Default Cloud Provider")
    # Sets the selected provider value
    selected_cloud_provider = tk.StringVar(set_selected_provider_gui)
    # Shows the current selected provider to the user.
    try:
        if platform.system() == "Windows":
            selected_provider_file = open(selected_cloud_filepath_windows, 'r')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            selected_provider_file = open(selected_cloud_filepath_linux, 'r')
        selected_cloud_provider.set(selected_provider_file.read())
    except FileNotFoundError:
        selected_cloud_provider.set("AWS")
        if platform.system() == "Windows":
            selected_provider_file = open(selected_cloud_filepath_windows, 'w')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            selected_provider_file = open(selected_cloud_filepath_linux, 'w')
        selected_provider_file.write("AWS")
        selected_provider_file.close()
        print("No default provider found, selecting AWS as default provider.")

    set_selected_provider_label = tk.Label(set_selected_provider_gui, text="Default Cloud Provider:", font=srs_font)

    # Creates the selection radio button frame.
    selected_provider_radio_button_frame = tk.Frame(set_selected_provider_gui)
    aws_radio_button = tk.Radiobutton(selected_provider_radio_button_frame, text = "AWS", value="AWS", variable=selected_cloud_provider, command=update_selected_provider)
    google_radio_button = tk.Radiobutton(selected_provider_radio_button_frame, text = "Google Cloud", value="GOOGLE", variable=selected_cloud_provider, command=update_selected_provider)
    azure_radio_button = tk.Radiobutton(selected_provider_radio_button_frame, text = "Azure", value="AZURE", variable=selected_cloud_provider, command=update_selected_provider)

    # Programmatically activates the relevant Radio Button.
    if selected_cloud_provider.get() == "AWS":
        aws_radio_button.invoke()
    elif selected_cloud_provider.get() == "GOOGLE":
        google_radio_button.invoke()
    elif selected_cloud_provider.get() == "AZURE":
        azure_radio_button.invoke()
    else:
        print("Invalid Cloud Provider found.")

    set_selected_provider_label.grid()
    selected_provider_radio_button_frame.grid()
    aws_radio_button.pack()
    google_radio_button.pack()
    azure_radio_button.pack()

    # The button to submit changes to default cloud provider.
    finish_selection_button = tk.Button(set_selected_provider_gui, text="Finish", width=25, command=set_selected_provider_gui.destroy)
    finish_selection_button.grid()
    set_selected_provider_gui.mainloop()

def aws_cloud_details():
    # Sub-Method for updating the user's AWS credentials.
    def write_aws_details():
        access_key = aws_access_key_input.get()
        secret_key = aws_secret_key_input.get()
        default_region = aws_default_region_input.get()
        # Ensures that all parameters are specified before continuing.
        if len(access_key) == 0 or len(secret_key) == 0 or len(default_region) == 0:
            print("All cloud provider parameters must be specified.")
            return;
        # Filepath for the AWS credentials file.
        if platform.system() == "Windows":
            aws_credentials_file = open(aws_filepath_windows, 'w')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            aws_credentials_file = open(aws_filepath_linux, 'w')
        # ';' will act as a separator character.
        aws_credentials_file.write("AWS " + access_key + " " + secret_key + " " + default_region)
        aws_credentials_file.close()
        # Indicates successful credential updates and closes the interface.
        print("AWS Credential Changes Have Been Saved.")
        aws_details_gui.destroy()

    # Reads current credentials for user to view if available.
    try:
        if platform.system() == "Windows":
            aws_credentials_file = open(aws_filepath_windows, 'r')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            aws_credentials_file = open(aws_filepath_linux, 'r')
        # Splits the file into it's individual segments.
        for parameters in aws_credentials_file:
            aws_credentials = parameters.split(" ")
        access_key = aws_credentials[1]
        secret_key = aws_credentials[2]
        default_region = aws_credentials[3]
        aws_credentials_file.close()
    except FileNotFoundError:
        access_key = ""
        secret_key = ""
        default_region = ""

    # Creates a GUI where users can alter their AWS User details.
    aws_details_gui = tk.Tk()
    srs_font = tkFont.Font(family="Helvetica", size=12)
    aws_details_gui.title("AWS Cloud Provider Details")

    # AWS connection requires 3 parameters: Access Key ID, Secret Key ID and Default Region.
    aws_access_key_frame = tk.Frame(aws_details_gui)
    aws_secret_key_frame = tk.Frame(aws_details_gui)
    aws_default_region_frame = tk.Frame(aws_details_gui)

    aws_access_key_label = tk.Label(aws_access_key_frame, text="Access Key ID:", font=srs_font)
    aws_access_key_input = tk.Entry(aws_access_key_frame, width=50)
    if access_key != "":
        aws_access_key_input.insert(tk.END,access_key)
    aws_access_key_frame.grid()
    aws_access_key_label.pack(side = "left")
    aws_access_key_input.pack(side = "right")

    aws_secret_key_label = tk.Label(aws_secret_key_frame, text="Secret Key ID:", font=srs_font)
    aws_secret_key_input = tk.Entry(aws_secret_key_frame, width=50)
    if secret_key != "":
        aws_secret_key_input.insert(tk.END,secret_key)
    aws_secret_key_frame.grid()
    aws_secret_key_label.pack(side = "left")
    aws_secret_key_input.pack(side = "right")

    aws_default_region_label = tk.Label(aws_default_region_frame, text="Region:", font=srs_font)
    aws_default_region_input = tk.Entry(aws_default_region_frame, width=50)
    if default_region != "":
        aws_default_region_input.insert(tk.END,default_region)
    aws_default_region_frame.grid()
    aws_default_region_label.pack(side = "left")
    aws_default_region_input.pack(side = "right")

    # This submits any changes made to user credentials.
    aws_button_frame = tk.Frame(aws_details_gui)
    aws_details_button = tk.Button(aws_button_frame, text="Submit Changes", width=25, command=write_aws_details)
    aws_quit_button = tk.Button(aws_button_frame, text="Finish", width=25, command=aws_details_gui.destroy)
    aws_button_frame.grid()
    aws_details_button.pack(side = "left")
    aws_quit_button.pack(side = "right")
    aws_details_gui.mainloop()

# Defines all of the filepaths used by the system.
infra_directory_windows = "C:\\Users\\Thomas\\Documents\\InfrastructureLibrary\\"
infra_directory_linux = "/opt/infra/"
selected_cloud_filepath_windows = infra_directory_windows + "SelectedCloud.txt"
selected_cloud_filepath_linux = infra_directory_linux + "selected_cloud.txt"
aws_filepath_windows = infra_directory_windows + "AWSInfraUserCredentials.txt"
aws_filepath_linux = infra_directory_linux + "AWS_credentials.txt"
google_filepath_windows = infra_directory_windows + "GoogleInfraUserCredentials.txt"
google_filepath_linux = infra_directory_linux + "Google_credentials.txt"

# Create the GUI master object.
inter = tk.Tk()
inter.title("Automated Infrastructure Creation System")
# Sets the Font for GUI Labels ensuring global access.
srs_font = tkFont.Font(family = "Helvetica", size = 12)

# Creates the Menu that allows user Cloud Provider credentials to be set.
root_menu = tk.Menu(inter)
cloud_details_menu = tk.Menu(root_menu)
cloud_details_menu.add_command(label = "Set Default Provider", command = set_selected_provider)
cloud_details_menu.add_separator()
cloud_details_menu.add_command(label = "AWS", command = aws_cloud_details)
cloud_details_menu.add_cascade(label = "Google Cloud")
cloud_details_menu.add_command(label = "Azure")
root_menu.add_cascade(label = "Manage Cloud Provider Details", menu = cloud_details_menu)
# Displays the Menu to the user.
inter.config(menu = root_menu)

# Allows SRS input in text format.
srs_text_label = tk.Label(inter, text = "Input SRS Text Here:", font = srs_font)
srs_text_frame = tk.Frame(inter)
srs_text_input = tk.Text(srs_text_frame, height = 10)
srs_text_scrollbar = tk.Scrollbar(srs_text_frame)
srs_text_button = tk.Button(inter, text = "Input SRS as Text", width = 25, command = input_as_text)
srs_text_label.grid()
srs_text_frame.grid()
srs_text_input.pack(side = 'left', fill = tk.Y)
srs_text_scrollbar.pack(side = 'right', fill = tk.Y)
srs_text_button.grid()

# Allows SRS input in PDF format.
srs_file_label = tk.Label(inter, text = "Input SRS as PDF Document:", font = srs_font)
srs_file_button = tk.Button(inter, text = "Browse for File", width = 25, command = input_as_file)
srs_file_label.grid()
srs_file_button.grid()

# This loop is used to run the constructed GUI for the user.
inter.mainloop()
