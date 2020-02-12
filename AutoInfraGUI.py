# GUI to accept SRS Document/Text input for the Classification and Creation system
# Based on 'tkinter' tutorial by GeeksForGeeks at: https://www.geeksforgeeks.org/python-gui-tkinter/
import tkinter as tk
from tkinter import font as tkFont
from tkinter import filedialog as tkFile
from tkinter import messagebox as tkMessageBox
# Open Source File Format Determination Library at: https://github.com/floyernick/fleep-py
import fleep
# Allows discovery of SRS PDF Document file sizes.
import os
# Allows program to execute remote operations on the Central Server.
import subprocess
import platform
# Allows credentials/information to be sent encrypted to the Central Server.
import rsa
# Allows users to copy/paste PlainText SRS from the system clipboard.
import pyperclip

# Defines functions that will be executed by the GUI.
# Process any SRS Document provider in text format.
def input_as_text():
    # Obtains SRS text document from the GUI Text Box.
    srs_data = srs_text_input.get('1.0','end')

    # Saves the text input to a temp file for copying to central server.
    if platform.system() == "Windows":
        srs_filepath = "C:\\Temp\\tempsrsdoc.txt"
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        srs_filepath = "/tmp/tempsrsdoc.txt"
    srs_temp_file = open(srs_filepath,"w")
    srs_temp_file.write(srs_data)
    srs_temp_file.close()

    # Displays the data as collected by the system for debugging purposes.
    print("The following SRS Document has been submitted for analysis: ")
    print(srs_data)
    # Clears text box after analysis is complete.
    srs_text_input.delete('1.0', 'end')
    # Obtains additional project details from the user.
    get_project_details(srs_filepath, "txt")

# Process any SRS Document provider in the PFG format.
def input_as_file():
    # Allows user to select an SRS document for analysis.
    srs_file = tkFile.askopenfile(parent=inter, mode='rb', title="Choose a File")

    # Reads the selected file from the user's system, insuring valid filepath.
    if srs_file != None:
        srs_filepath = srs_file.name
        srs_data = srs_file.read()

        # Checks if file meets format and size requirements for Google AutoML.
        srs_file_info = fleep.get(srs_data)
        srs_file_size = os.stat(srs_filepath).st_size / 1024 # Size comparisons happen in KB.
        print("Size of Input SRS File: " + str(srs_file_size) + "KB")
        if srs_file_info.mime_matches("application/pdf") and srs_file_size <= 128:
            print("File retrieved, uploading to application server for analysis.")
            srs_file.close()
            # Obtains additional project details from the user.
            get_project_details(srs_filepath,"pdf")
        else:
            srs_file.close()
            # Exits the operation if the file selected is not a PDF file.
            if srs_file_size > 128 and srs_file_info.mime_matches("application/pdf"):
                print("File must be 128KB or less.")
                tkMessageBox.showerror("File Size Error","File must be 128KB or less.")
            else:
                print("File retrieved is not in the PDF format.")
                tkMessageBox.showerror("File Format Error","File retrieved is not in the PDF format.")
    else:
        # Exits the operation if filepath is invalid.
        print("User has not selected a file or filepath provided is invalid.")
        tkMessageBox.showerror("No File Selected","You have not selected a file or the filepath provided is invalid.")
        return

# Obtains additional project information from the user for the Central Server.
def get_project_details(srs_filepath,ext):
    # Writes these project parameters to be send to the Central Server for infrastructure creation.
    def write_project_details():
        # Project Parameters: <PROJECT_NAME> <DB_USERNAME> <DB_PASSWORD>
        project_name = srs_entries[0].get()
        db_username = srs_entries[1].get()
        db_password = srs_entries[2].get()

        # Test String to ensure compliance of db username and password.
        db_test_string = '/"@ '
        # Ensures that all parameters are specified before continuing.
        if len(project_name) == 0 or len(db_username) == 0 or len(db_password) == 0:
            print("All project parameters must be specified.")
            tkMessageBox.showerror("Unspecified Project Parameters","All project parameters must be specified.")
            return
        elif len(db_username) > 16:
            # Ensures username is compliant with all available DB Engines. Check for String = isinstance(db_username[0],str)
            print("DB Username must not be longer than 16 characters. The 1st character must be a letter.")
            tkMessageBox.showerror("DB Username Error","DB Username must not be longer than 16 characters. The 1st character must be a letter.")
            return
        elif len(db_password) < 8 or len(db_password) > 30 or any(element in db_password for element in db_test_string):
            # Ensures password is compliant with all available DB Engines.
            print('DB Password must be between 8-30 characters long. Containing no forbidden characters [/,",@, ]')
            tkMessageBox.showerror("DB Password Error",'DB Password must be between 8-30 characters long. Containing no forbidden characters [/,",@, ]')
            return
        project_parameters = project_name + " " + db_username + " " + db_password
        print("Project Info Successfully Gathered.")

        srs_parameters_gui.destroy()
        # Sends all required information to the Central Server.
        input_to_central_server(srs_filepath,ext,project_parameters)

    # List of generic project parameters for all cloud providers.
    srs_parameters = ["Project Name:","DB Username:","DB Password:"]
    srs_parameters_gui = tk.Tk()
    srs_parameters_gui.title("Please Enter Additional Project Information")
    srs_entries = []
    entry_count = 0
    # Loop to create the required parameter specification elements.
    for text in srs_parameters:
        aws_frame = tk.Frame(srs_parameters_gui)
        aws_label = tk.Label(aws_frame, text=text, font=srs_font)
        # Enables password style input for Db Password Text Entry.
        if text == "DB Password:":
            srs_entries.append(tk.Entry(aws_frame, show="*", width=50))
        else:
            srs_entries.append(tk.Entry(aws_frame, width=50))
        aws_frame.grid()
        aws_label.pack(side = "left")
        srs_entries[entry_count].pack(side = "right")
        entry_count += 1

    # Initializes the Submit and Cancel buttons for the GUI.
    srs_button_frame = tk.Frame(srs_parameters_gui)
    srs_details_button = tk.Button(srs_button_frame, text="Submit Info", width=25, command=write_project_details)
    srs_quit_button = tk.Button(srs_button_frame, text="Cancel", width=25, command=srs_parameters_gui.destroy)
    srs_button_frame.grid()
    srs_details_button.pack(side = "left")
    srs_quit_button.pack(side = "right")

    # Sets up appropriate Dialog if the user prematurely destroys this Window.
    def window_destroy():
        print("User has Refused to Provide Additional Project Information.")
        srs_parameters_gui.destroy()

    srs_parameters_gui.protocol("WM_DELETE_WINDOW", window_destroy)
    srs_parameters_gui.mainloop()


# Sends all relevant information/credentials to the Central Server.
def input_to_central_server(srs_filepath,ext,srs_project_info):
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
    central_encrypted_project_filepath = central_server+":"+linux_encrypted_project_filepath

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
            # AWS Format: AWS <ACCESS_KEY> <SECRET_KEY> <DEFAULT_REGION> <SUBNET_ID> <VPC_ID> <RDS_SUBNET_NAME>
            srs_user_credentials = aws_credentials[0] + " " + aws_credentials[1] + " " + aws_credentials[2] + " " + aws_credentials[3] + " " + aws_credentials[4] + " " + aws_credentials[5] + " " + aws_credentials[6]
            # Full payload is encrypted into Bytes.
            encrypted_user_credentials = rsa.encrypt(srs_user_credentials.encode('utf8'), srs_creds_key)
        except FileNotFoundError:
            print("Please set up your AWS user credentials under 'Manage Cloud Provider Details'")
            # Prevents further execution in the event that no credentials are available.
            return
    elif selected_provider == "GOOGLE":
        print("Provider not supported at the moment.")
        return
    elif selected_provider == "AZURE":
        print("Provider not supported at the moment.")
        return
    else:
        print("Invalid provider has been specified.")
        return

    # Sends encrypted credentials to a temp file for transfer to Central Server.
    if platform.system() == "Windows":
        encrypted_creds_file = open(windows_encrypted_creds_filepath, 'wb')
        project_info_file = open(windows_encrypted_project_filepath, 'wb')
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        encrypted_creds_file = open(linux_encrypted_creds_filepath, 'wb')
        project_info_file = open(linux_encrypted_project_filepath, 'wb')

    # Write the encrypted user credentials and info to a tmp file.
    encrypted_creds_file.write(encrypted_user_credentials)
    encrypted_creds_file.close()

    # Writes the encrypted project parameters to a tmp file.
    encrypted_project_info = rsa.encrypt(srs_project_info.encode('utf8'), srs_creds_key)
    project_info_file.write(encrypted_project_info)
    project_info_file.close()

    # Requires different commands depending on the User's OS.
    print("User Platform: " + platform.system())
    print("Sending User SRS Along With Relevant Info/Credentials to Central Server:")
    # Copies SRS data to Central Server, then executes the SRS Analysis and Infrastructure Creation script.
    if platform.system() == "Windows":
        # Putty SCP and Plick are used as they directly integrate with Bash like Putty.
        # Transfers the SRS document to the Central Server for classification analysis.
        subprocess.run(["pscp", "-i", windows_server_key_filepath, srs_filepath, central_server_filepath])
        # Sends the encrypted credentials for this session to the Central Server.
        subprocess.run(["pscp", "-i", windows_server_key_filepath, windows_encrypted_creds_filepath, central_encrypted_creds_filepath])
        # Sends the encrypted project parameters for this session to the Central Server.
        subprocess.run(["pscp", "-i", windows_server_key_filepath, windows_encrypted_project_filepath, central_encrypted_project_filepath])
        # Executes the Bash wrapper script on the Central Server to perform classification and infrastructure creation.
        central_server_result = subprocess.run(["plink", "-ssh","-i",windows_server_key_filepath,central_server,infra_directory_linux+"InfraBash.sh",ext])
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        # Uses SSH sessions to initiate the required operations on the Central Server.
        subprocess.run(["scp", "-i", linux_server_key_filepath, srs_filepath, central_server_filepath])
        # Sends the encrypted credentials for this session to the Central Server.
        subprocess.run(["scp", "-i", linux_server_key_filepath, linux_encrypted_creds_filepath, central_encrypted_creds_filepath])
        # Sends the encrypted project parameters for this session to the Central Server.
        subprocess.run(["pscp", "-i", windows_server_key_filepath, linux_encrypted_project_filepath, central_encrypted_project_filepath])
        # Executes the Bash wrapper script on the Central Server to perform classification and infrastructure creation.
        central_server_result = subprocess.run(["ssh", "-i",linux_server_key_filepath,central_server, infra_directory_linux+"InfraBash.sh",ext])

    # Checks to see if Central Server scripts/processes were successful.
    if central_server_result.returncode == 0:
        print("Infrastructure Creation Successful.")
        tkMessageBox.showinfo("Success","Infrastructure Creation Successful.")
        exit(0)
    else:
        print("Infrastructure Creation Failed.")
        tkMessageBox.showerror("Failed","Infrastructure Creation Failed.")
        exit(10)

# Allows the user to select which Cloud Provider to create infrastructure in.
def set_selected_provider():
    # Updates the user's default parameter in the system.
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
    # TkinterVar stores the currently selected Radio Button input.
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

    # Creates the Label used by the GUI.
    set_selected_provider_label = tk.Label(set_selected_provider_gui, text="Default Cloud Provider:", font=srs_font)

    # Creates the selection radio button frame.
    selected_provider_radio_button_frame = tk.Frame(set_selected_provider_gui)
    set_selected_provider_label.grid()
    selected_provider_radio_button_frame.grid()
    cloud_providers = [
        ("AWS","AWS"),
        ("Google Cloud", "GOOGLE"),
        ("Azure","AZURE")
    ]
    # Loop to create an pack the required Radio buttons.
    for provider, value in cloud_providers:
        radio_button = tk.Radiobutton(selected_provider_radio_button_frame,text=provider,value=value,variable=selected_cloud_provider,command=update_selected_provider)
        if selected_cloud_provider.get() == value:
            radio_button.invoke()
        radio_button.pack()

    # The button to submit changes to default cloud provider.
    finish_selection_button = tk.Button(set_selected_provider_gui, text="Finish", width=25, command=set_selected_provider_gui.destroy)
    finish_selection_button.grid()
    set_selected_provider_gui.mainloop()

# Allows user to edit AWS Cloud Provider exclusive details.
def aws_cloud_details():
    # Sub-Method for updating the user's AWS credentials.
    def write_aws_details():
        # Gather all user AWS credentials and parameters.
        aws_user_credentials = []
        for radio_buttons in aws_entries:
            aws_user_credentials.append(radio_buttons.get())

        # Ensures that all parameters are specified before continuing.
        if not all(aws_user_credentials):
            print("All cloud provider parameters must be specified.")
            return

        # Filepath for the AWS credentials file.
        if platform.system() == "Windows":
            aws_credentials_file = open(aws_filepath_windows, 'w')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            aws_credentials_file = open(aws_filepath_linux, 'w')

        # ' ' will act as a separator character.
        aws_credentials_file.write("AWS " + aws_user_credentials[0] + " " + aws_user_credentials[1] + " " + aws_user_credentials[2]+ " " + aws_user_credentials[3]+ " " + aws_user_credentials[4] + " " + aws_user_credentials[5])
        aws_credentials_file.close()

        # Indicates successful credential updates and closes the interface.
        print("AWS Credential Changes Have Been Saved.")
        aws_details_gui.destroy()

    # This list stores the AWS user credentials.
    aws_user_credentials = []

    # Reads current credentials for user to view if available.
    try:
        if platform.system() == "Windows":
            aws_credentials_file = open(aws_filepath_windows, 'r')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            aws_credentials_file = open(aws_filepath_linux, 'r')

        # Splits the file into it's individual segments.
        for parameters in aws_credentials_file:
            aws_credentials = parameters.split(" ")

        # Obtains each of the AWS Credentials from the user's file.
        for elements in aws_credentials:
            aws_user_credentials.append(elements)
        aws_credentials_file.close()
    except FileNotFoundError:
        # Sets each credential to blank if no user settings are found.
        for elements in aws_credentials:
            aws_user_credentials[aws_credentials.index(elements)] = ""

    # Creates a GUI where users can alter their AWS User details.
    aws_details_gui = tk.Tk()
    aws_details_gui.title("AWS Cloud Provider Details")

    # List specifies all required parameters for the AWS cloud environment.
    aws_parameters = [
        ("Access Key ID:",aws_user_credentials[1]),
        ("Secret Key ID:", aws_user_credentials[2]),
        ("Region:", aws_user_credentials[3]),
        ("Subnet ID:", aws_user_credentials[4]),
        ("VPC ID:",aws_user_credentials[5]),
        ("RDS Subnet Name:", aws_user_credentials[6])
    ]
    # Empty list allows Entry inputs to be accessed by the system.
    aws_entries = []
    entry_count = 0

    # Loop to create the required parameter specification elements.
    for text, value in aws_parameters:
        aws_frame = tk.Frame(aws_details_gui)
        aws_label = tk.Label(aws_frame, text=text, font=srs_font)
        aws_entries.append(tk.Entry(aws_frame, width=50))
        if value != "":
            aws_entries[entry_count].insert(tk.END, value)
        aws_frame.grid()
        aws_label.pack(side = "left")
        aws_entries[entry_count].pack(side = "right")
        entry_count += 1

    # This submits any changes made to user credentials.
    aws_button_frame = tk.Frame(aws_details_gui)
    aws_details_button = tk.Button(aws_button_frame, text="Submit Changes", width=25, command=write_aws_details)
    aws_quit_button = tk.Button(aws_button_frame, text="Finish", width=25, command=aws_details_gui.destroy)
    aws_button_frame.grid()
    aws_details_button.pack(side = "left")
    aws_quit_button.pack(side = "right")
    aws_details_gui.mainloop()

# This is the Main Function that creates the Main GUI users will utilise.

# Defines all of the filepaths used by the system.
infra_directory_windows = "C:\\Users\\Thomas\\Documents\\InfrastructureLibrary\\"
infra_directory_linux = "/opt/infra/"
selected_cloud_filepath_windows = infra_directory_windows + "SelectedCloud.txt"
selected_cloud_filepath_linux = infra_directory_linux + "selected_cloud.txt"
aws_filepath_windows = infra_directory_windows + "AWSInfraUserCredentials.txt"
aws_filepath_linux = infra_directory_linux + "AWS_credentials.txt"
google_filepath_windows = infra_directory_windows + "GoogleInfraUserCredentials.txt"
google_filepath_linux = infra_directory_linux + "Google_credentials.txt"
windows_encrypted_project_filepath = "C:\\Temp\\encryptprojectinfo.txt"
linux_encrypted_project_filepath = "/tmp/encryptprojectinfo.txt"

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
cloud_details_menu.add_command(label = "Google Cloud")
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

# Function manages the Popup of the Menu when Text Input is Right-Clicked.
def popup(event):
    try:
        popup_menu.tk_popup(event.x_root,event.y_root,0)
    finally:
        popup_menu.grab_release()
# Function allows system Clipboard to copy SRS Text Input contents.
def copy():
    srs_copy_text = srs_text_input.get("1.0",tk.END)
    # Ensures Empty String/New Line only String is not present in the Clipboard.
    if not srs_copy_text or srs_copy_text == "\n":
        print("No Text Available in the SRS Text Input Box.")
        return
    else:
        pyperclip.copy(srs_copy_text)
# Function allows user to paste Clipboard content into the SRS Text Input.
def paste():
    srs_text_input.insert(tk.END, pyperclip.paste())

# Attempt at a Popup Menu to Allow Copy/Paste of SRS PlainText Documents.
popup_menu = tk.Menu(inter)
popup_menu.add_command(label="Copy", command=copy)
popup_menu.add_command(label="Paste", command=paste)
# Binds the Popup Menu to the SRS Text Input.
srs_text_input.bind("<Button-3>",popup)

# This loop is used to run the constructed GUI for the user.
inter.mainloop()
