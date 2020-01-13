# GUI to accept SRS Document/Text input for the Classification and Creation system
# Based on 'tkinter' tutorial by GeeksForGeeks at: https://www.geeksforgeeks.org/python-gui-tkinter/
import tkinter as tk
from tkinter import font as tkFont
from tkinter import filedialog as tkFile
# Open Source File Format Determination Library at: https://github.com/floyernick/fleep-py
import fleep
# Allows discovery of file sizes.
import os
# Allows program to execute remote operations on the central server.
import subprocess
import platform

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

def input_as_file():
    # Allows user to select an SRS document for analysis.
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
    windows_key_filepath = "C:\\Users\\Thomas\\Documents\\InfrastructureLibrary\\PuttyCentralKey.ppk"
    linux_key_filepath = "/opt/infra/CentralKey.pem"
    central_server = "ec2-user@ec2-52-30-159-69.eu-west-1.compute.amazonaws.com"
    central_server_filepath = central_server+":/opt/infra/SRSDocs/PredictSRSDoc."+ ext
    # Requires different commands depending on the User's OS.
    print(platform.system())
    # Copies SRS data to Central Server, then executes the SRS Analysis and Infrastructure Creation script.
    if platform.system() == "Windows":
        # Putty SCP and Plick are used as they directly integrate with Bash like Putty.
        subprocess.run(["pscp", "-i", windows_key_filepath, srs_filepath, central_server_filepath])
        subprocess.run(["plink", "-ssh","-i",windows_key_filepath,central_server,"/opt/infra/InfraBash.sh",ext])
    elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
        # Uses SSH sessions to initiate the required operations on the Central Server.
        subprocess.run(["scp", "-i", linux_key_filepath, srs_filepath, central_server_filepath])
        subprocess.run(["ssh", "-i",linux_key_filepath,central_server, "/opt/infra/InfraBash.sh",ext])

def set_selected_provider():
    def update_selected_provider():
        print(selected_cloud_provider.get())

    selected_cloud_filepath_windows = "C:\\Users\\Thomas\\Documents\\InfrastructureLibrary\\SelectedCloud.txt"
    selected_cloud_filepath_linux = "/opt/infra/selected_cloud.txt"

    # Sets the selected provider value
    selected_cloud_provider = tk.IntVar()
    # Shows the current selected provider to the user.
    try:
        if platform.system() == "Windows":
            selected_provider_file = open(selected_cloud_filepath_windows, 'r')
        elif platform.system() == "Linux" or "Darwin":  # Darwin = MacOS
            selected_provider_file = open(selected_cloud_filepath_linux, 'r')
        selected_cloud_provider.set(selected_provider_file.read())
    except FileNotFoundError:
        selected_cloud_provider.set(1)
        print("No default provider found, selecting AWS as default provider.")

    set_selected_provider_gui = tk.Tk()
    set_selected_provider_gui.title("Set Default Cloud Provider")
    set_selected_provider_label = tk.Label(set_selected_provider_gui, text="Default Cloud Provider:", font=srs_font)

    # Creates the selection radio button frame.
    selected_provider_radio_button_frame = tk.Frame(set_selected_provider_gui)
    aws_radio_button = tk.Radiobutton(selected_provider_radio_button_frame, text = "AWS", variable=selected_cloud_provider, value=1)
    google_radio_button = tk.Radiobutton(selected_provider_radio_button_frame, text = "Google Cloud", variable=selected_cloud_provider, value=2)
    azure_radio_button = tk.Radiobutton(selected_provider_radio_button_frame, text = "Azure", variable=selected_cloud_provider, value=3)

    # Programmatically activates the relevant Radio Button.
    if selected_cloud_provider.get() == 1:
        aws_radio_button.invoke()
    elif selected_cloud_provider.get() == 2:
        google_radio_button.invoke()
    elif selected_cloud_provider.get() == 3:
        azure_radio_button
    else:
        print("Invalid Cloud Provider found.")

    set_selected_provider_label.grid()
    selected_provider_radio_button_frame.grid()
    aws_radio_button.pack()
    google_radio_button.pack()
    azure_radio_button.pack()

    # The button to submit changes to default cloud provider.
    selected_cloud_provider_button = tk.Button(set_selected_provider_gui, text="Select Default Provider", width=25, command=update_selected_provider)
    selected_cloud_provider_button.grid()
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

    # Ensures that user text input can be read by all GUI methods.
    aws_filepath_windows = "C:\\Users\\Thomas\\Documents\\InfrastructureLibrary\\AWSInfraUserCredentials.txt"
    aws_filepath_linux = "/opt/infra/AWS_credentials.txt"

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


# Create the GUI master object.
inter = tk.Tk()
inter.title("Automated Infrastructure Creation System")
# Sets the Font for GUI Labels ensuring global access.
global srs_font
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
