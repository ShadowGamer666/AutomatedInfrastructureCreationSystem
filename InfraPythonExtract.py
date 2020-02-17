#!/usr/bin/python3

# Uses created Google AutoML Model to produce a template recommendation
# for the submitted SRS Document.
from google.cloud import automl
# Used to produce the plain representation of PDf files.
from pdfminer.converter import TextConverter
from pdfminer.pdfinterp import PDFPageInterpreter
from pdfminer.pdfinterp import PDFResourceManager
from pdfminer.pdfpage import PDFPage
import io
# Used in obtain user arguments from Bash wrapper.
import sys

# Extracts Text input from SRS PDF files.
def extract_pdf_text(pdf_filepath):
    pdf_resource_manager = PDFResourceManager()
    # Manages exceptions caused by invalid PDF files.
    file_handle = io.StringIO()
    pdf2txt_converter = TextConverter(pdf_resource_manager,file_handle)
    pdf_page_interpreter = PDFPageInterpreter(pdf_resource_manager,pdf2txt_converter)

   # Reads the PDF file and processes each page into it's text equivilent.
    with open(pdf_filepath,'rb') as pdf_file:
        for pdf_page in PDFPage.get_pages(pdf_file,caching=True,check_extractable=True):
            pdf_page_interpreter.process_page(pdf_page)
        pdf_text_data = file_handle.getvalue()
    # Closes handler to prevent resource leakage.
    pdf2txt_converter.close()
    file_handle.close()
    # Ensures text is present for the AutoML model.
    if pdf_text_data:
        return pdf_text_data
    else:
        print("No Data has been extracted from the PDF file.")
        exit(5)

# Retrieves the Entity Prediction from the AutoML Extraction Model.
def get_prediction(prediction_text,ext,srs_model_id):
   # Creates the Text Snippet Object for the Request Payload.
    srs_predict_text = automl.types.TextSnippet(
    content = prediction_text, mime_type = "text/plain"
    )
    # Creates any additional Payload objects required for each file type.
    if ext == "txt":
        srs_payload = automl.types.ExamplePayload(text_snippet=srs_predict_text)
    elif ext == "pdf":
        srs_pdf_doc = automl.types.Document(
        document_text = srs_predict_text
        )
        srs_payload = automl.types.ExamplePayload(document=srs_pdf_doc)
    # Obtains the Payload Response from the Extraction model.
    srs_response = srs_prediction_client.predict(srs_model_id,srs_payload)
    return srs_response

# Performs additional preprocessing for SRS inputs that need to be split into
# speparate requests (Extraction Model Limit = 10,000 characters.
def split_payload_prediction(srs_data,len_srs_data):
    # Creates 10,000 character Payloads to send for separate predictions.
    split_srs_data = [(srs_data[i:i + 10000]) for i in range(0, len_srs_data, 10000)]
    for payload in split_srs_data:
        srs_response = get_prediction(payload, ext, srs_model_id)
        # Records all relevant Payload fields from the Response.
        for response_payload in srs_response.payload:
            srs_entity_label_part = response_payload.display_name
            srs_text_score_part = response_payload.text_extraction.score
            srs_response_entities.append(srs_entity_label_part)
            srs_response_scores.append(srs_text_score_part)

# Creates an Entity Label occurance count from the Entity Model response.
def process_response(srs_response_entities):
    # Ensures these variables will be treated as String.
    srs_entity_label = ""
    srs_entity_count = ""
    for entity in srs_response_entities:
        # Adds current Label to the Dictonary if not already present.
        if entity not in srs_entity_stats:
            srs_entity_stats[entity] = 0
        srs_entity_count = srs_entity_stats.get(entity)
        # Increments the Label count for every recorded occurance.
        srs_entity_stats[entity] = srs_entity_count + 1
    # Gets the Labels that were detected during Extraction.
    for label in srs_entity_stats:
        srs_entity_label = srs_entity_label + label + " "
        srs_entity_count = str(srs_entity_count) + str(srs_entity_stats[label]) + " "
    # Prints a specical message if no Labels are assigned.
    if srs_entity_label == "":
        print("No Label has been assigned.")
    else:
        # Otherwise prints final Entity Extraction decisions.
        print(srs_entity_label)
        print(srs_entity_count)

# Reads script parameters from the Bash wrapper script.
ext = sys.argv[1]
# Ensures that valid parameters have been provided by the user.
if ext != "pdf" and ext != "txt":
    print("Invalid Extenstion Parameter Provided.")
    exit(15)
# Sets the correct model for the Extraction model.
model_id = "TEN1729571372910247936"
model_region = "us-central1"
# Performs the SRS Document Classification Prediction
srs_prediction_client = automl.PredictionServiceClient()
# Discovers the full_model_id based on project_id,location,model_id.
srs_model_id = srs_prediction_client.model_path(
"avian-cat-259412",model_region,model_id
)
# Initialises the variables used to stores Payload responses.
srs_response_entities = []
srs_response_scores = []
srs_entity_stats = {}  # [Entity Name: No. of Occurrences]
if ext == "txt":
    # Creates the Payload for SRS input in text format.
    srs_text_data = open("/opt/infra/SRSDocs/PredictSRSDoc.txt",'r')
    srs_text_data = srs_text_data.read()
    # Splits the Payload if it's over Extraction Model character limit.
    len_text_data = len(srs_text_data)
    if len_text_data > 10000:
        # Get Prediction Data for SRS with Multiple Payloads.
        srs_response = split_payload_prediction(srs_text_data, len_text_data)
    else:
        srs_response = get_prediction(srs_text_data, ext, srs_model_id)
        # Records the Entity Extraction Model response.
        for response_payload in srs_response.payload:
            srs_response_entities.append(srs_response.display_name)
            srs_response_scores.append(srs_response.text_extraction.score)
    # Creates the Final Response Outputs for the Bash script.
    process_response(srs_response_entities)
elif ext == "pdf":
   # Creates the Payload for SRS input originally in PDF format.
    pdf_to_text = extract_pdf_text("/opt/infra/SRSDocs/PredictSRSDoc.pdf")
    # Splits the Payload if it's over Extraction Model character limit.
    len_pdf_to_text = len(pdf_to_text)
    if len_pdf_to_text > 10000:
        # Get Prediction Data for SRS with Multiple Payloads.
        srs_response = split_payload_prediction(pdf_to_text,len_pdf_to_text)
    else:
        srs_response = get_prediction(pdf_to_text, ext, srs_model_id)
        # Records the Entity Extraction Model response.
        for response_payload in srs_response.payload:
            srs_response_entities.append(srs_response.display_name)
            srs_response_scores.append(srs_response.text_extraction.score)
    # Creates the Final Response Outputs for the Bash script.
    process_response(srs_response_entities)
