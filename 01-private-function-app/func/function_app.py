import azure.functions as func
import datetime
import json
import logging
import os
import requests

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
