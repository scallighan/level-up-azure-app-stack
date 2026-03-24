import azure.functions as func
import datetime
import json
import logging
import os
import requests
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient

app = func.FunctionApp()

@app.function_name(name="HttpTrigger1")
@app.route(route="HttpExample", auth_level=func.AuthLevel.ANONYMOUS)
def HttpExample(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get('name')

    msg = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."
    
    if name:
        msg = f"Hello, {name}. This HTTP triggered function executed successfully."

    logging.info(msg)
    return func.HttpResponse(
            msg,
            status_code=200
    )

@app.function_name(name="ListHoldings")
@app.route(route="holdings", auth_level=func.AuthLevel.FUNCTION)
def ListHoldings(req: func.HttpRequest) -> func.HttpResponse:
    # read the holdings.csv file from azure blob storage container and return the contents as a json response
    logging.info('Python HTTP trigger function ListHoldings processed a request.')
    credential = DefaultAzureCredential()
    blob_service_client = BlobServiceClient(account_url=f"https://{os.environ['STORAGE_ACCOUNT_NAME']}.blob.core.windows.net", credential=credential)
    container_client = blob_service_client.get_container_client("holdings")
    blob_client = container_client.get_blob_client("holdings.csv")
    blob_data = blob_client.download_blob().readall()
    holdings = [line.split(",") for line in blob_data.decode("utf-8").split("\n") if line]
    holdings_json = []
    for holding in holdings[1:]:
        holdings_json.append({
            "date": holding[1],
            "ticker": holding[2],
            "buy_or_sell": holding[3],
            "shares": holding[4],
            "buy_price": holding[5],
            "sell_price": holding[6],
            "position": holding[7]
        })
    return func.HttpResponse(
        json.dumps(holdings_json),
        mimetype="application/json",
        status_code=200
    )