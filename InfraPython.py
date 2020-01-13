# Uses created Google AutoML Model to produce a template recomendation
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

# Reads script parameters from the Bash wrapper script.
ext = sys.argv[1]

# Performs the SRS Document Classification Prediction
# Ensures that the Client uses the EU API endpoint.
srs_client_options = {'api_endpoint':'eu-automl.googleapis.com:443'}
srs_prediction_client = automl.PredictionServiceClient(client_options=srs_client_options)
# Discovers the full_model_id based on project_id,location,model_id.
srs_model_id = srs_prediction_client.model_path(
"avian-cat-259412","eu","TCN3424494935406018560"
)
if ext == "txt":
   # Creates the Payload for SRS input in text format.
    srs_text_data = open("/opt/infra/SRSDocs/PredictSRSDoc.txt",'r')
    srs_text_doc = automl.types.TextSnippet(
    content = srs_text_data, mime_type = "text/plain"
    )
    srs_payload = automl.types.ExamplePayload(text_snippet=srs_text_doc)
elif ext == "pdf":
   # Creates the Payload for SRS input originally in PDF format.
    pdf_to_text = extract_pdf_text("/opt/infra/SRSDocs/PredictSRSDoc.pdf")
    srs_pdf_text = automl.types.TextSnippet(
    content = pdf_to_text, mime_type = "text/plain"
    )
    srs_pdf_doc = automl.types.Document(
    document_text = srs_pdf_text
    )
    srs_payload = automl.types.ExamplePayload(document=srs_pdf_doc)
# Sends the processed SRS payload to the Model for obtain Class result.
srs_response = srs_prediction_client.predict(srs_model_id,srs_payload)
# Decudes the most relevant template based on provided confidence scores.
final_confidence_score = 0
for result_payload in srs_response.payload:
    srs_class_name = result_payload.display_name
    srs_confidence_score = result_payload.classification.score
    if srs_confidence_score > final_confidence_score:
        final_class_name = srs_class_name
        final_confidence_score = srs_confidence_score
# Prints final classifier along with confidence score to the Bash wrapper.
print(final_class_name)
print(final_confidence_score)
