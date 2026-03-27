import azure.functions as func
import datetime
import json
import logging
import os
import pyodbc
import requests
from dataclasses import fields
from decimal import Decimal
from uuid import UUID
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient
import struct
from models import (
    AccountStocks,
    Accounts,
    Beneficiaries,
    Currencies,
    DatabaseFirewallRules,
    OrderStatus,
    PaymentMethods,
    PaymentMethodTypes,
    Payments,
    PurchaseOrders,
    Stocks,
    Transactions,
    TransactionTypes,
    User,
)

app = func.FunctionApp()


ENTITY_MODEL_CONFIG = {
    "accountstocks": {"table": "AccountStocks", "model": AccountStocks, "pk": "Id", "pk_type": "int"},
    "beneficiaries": {"table": "Beneficiaries", "model": Beneficiaries, "pk": "Id", "pk_type": "int"},
    "currencies": {"table": "Currencies", "model": Currencies, "pk": "Id", "pk_type": "int"},
    "orderstatus": {"table": "OrderStatus", "model": OrderStatus, "pk": "StatusId", "pk_type": "int"},
    "paymentmethods": {"table": "PaymentMethods", "model": PaymentMethods, "pk": "Id", "pk_type": "int"},
    "paymentmethodtypes": {"table": "PaymentMethodTypes", "model": PaymentMethodTypes, "pk": "Id", "pk_type": "int"},
    "payments": {"table": "Payments", "model": Payments, "pk": "PaymentId", "pk_type": "int"},
    "purchaseorders": {"table": "PurchaseOrders", "model": PurchaseOrders, "pk": "PurchaseOrderId", "pk_type": "int"},
    "stocks": {"table": "Stocks", "model": Stocks, "pk": "Id", "pk_type": "int"},
    "transactions": {
        "table": "Transactions",
        "model": Transactions,
        "pk": "Id",
        "pk_type": "uuid",
        "allow_pk_on_insert": True,
    },
    "transactiontypes": {"table": "TransactionTypes", "model": TransactionTypes, "pk": "Id", "pk_type": "int"},
    "user": {"table": "[User]", "model": User, "pk": "UserName", "pk_type": "str", "allow_pk_on_insert": True},
    "database_firewall_rules": {
        "table": "database_firewall_rules",
        "model": DatabaseFirewallRules,
        "pk": "id",
        "pk_type": "int",
    },
    "accounts": {"table": "Accounts", "model": Accounts, "pk": "Id", "pk_type": "int"},
}


def _to_db_column_name(field_name):
    return "".join(word.capitalize() for word in field_name.split("_"))


def _build_entity_schema(config):
    model_columns = [_to_db_column_name(model_field.name) for model_field in fields(config["model"])]
    return {
        "table": config["table"],
        "pk": config["pk"],
        "pk_type": config["pk_type"],
        "allow_pk_on_insert": config.get("allow_pk_on_insert", False),
        "columns": model_columns,
    }


ENTITY_SCHEMA = {
    entity_name: _build_entity_schema(entity_config)
    for entity_name, entity_config in ENTITY_MODEL_CONFIG.items()
}


def _sql_default(value):
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (datetime.date, datetime.datetime)):
        return value.isoformat()
    return value


def _json_response(payload, status_code=200):
    return func.HttpResponse(
        json.dumps(payload, default=_sql_default),
        mimetype="application/json",
        status_code=status_code,
    )


def handle_datetimeoffset(dto_value):
    # ref: https://github.com/mkleehammer/pyodbc/issues/134#issuecomment-281739794
    tup = struct.unpack("<6hI2h", dto_value)  # e.g., (2017, 3, 16, 10, 35, 18, 0, -6, 0)
    tweaked = [tup[i] // 100 if i == 6 else tup[i] for i in range(len(tup))]
    return "{:04d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d}.{:07d} {:+03d}:{:02d}".format(*tweaked)



def _get_sql_connection():
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={os.environ.get('SERVER_NAME')}.database.windows.net;"
        f"DATABASE={os.environ.get('DATABASE_NAME')};"
        f"UID={os.environ.get('UID')};"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;Authentication=ActiveDirectoryMsi;"
    )
    conn = pyodbc.connect(conn_str)
    conn.add_output_converter(-155, handle_datetimeoffset)
    return conn


def _resolve_entity(entity_name):
    if not entity_name:
        return None
    return ENTITY_SCHEMA.get(entity_name.lower())


def _parse_pk_value(raw_value, pk_type):
    if pk_type == "int":
        return int(raw_value)
    if pk_type == "uuid":
        return str(UUID(raw_value))
    return str(raw_value)


def _row_to_dict(cursor, row):
    columns = [col[0] for col in cursor.description]
    return {columns[idx]: row[idx] for idx in range(len(columns))}


def _extract_payload(req):
    try:
        body = req.get_json()
        if isinstance(body, dict):
            return body, None
        return None, "Request body must be a JSON object."
    except ValueError:
        return None, "Request body must be valid JSON."


def _validate_payload_columns(payload, schema, include_pk=False):
    allowed = set(schema["columns"])
    if not include_pk:
        allowed.discard(schema["pk"])

    invalid = [k for k in payload.keys() if k not in allowed]
    if invalid:
        return f"Invalid columns: {', '.join(invalid)}"
    return None

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

@app.function_name(name="ListTables")
@app.route(route="tables", auth_level=func.AuthLevel.FUNCTION)
def ListTables(req: func.HttpRequest) -> func.HttpResponse:

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT TOP 50 * FROM sys.tables;")
        rows = cursor.fetchall()

        # Format results
        table_names = [row[0] for row in rows]
        print(table_names)
        return func.HttpResponse(
            json.dumps(table_names),
            mimetype="application/json",
            status_code=200
        )

def handle_datetimeoffset(dto_value):
    # ref: https://github.com/mkleehammer/pyodbc/issues/134#issuecomment-281739794
    tup = struct.unpack("<6hI2h", dto_value)  # e.g., (2017, 3, 16, 10, 35, 18, 0, -6, 0)
    tweaked = [tup[i] // 100 if i == 6 else tup[i] for i in range(len(tup))]
    return "{:04d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d}.{:07d} {:+03d}:{:02d}".format(*tweaked)


@app.function_name(name="CrudList")
@app.route(route="crud/{entity}", methods=["GET"], auth_level=func.AuthLevel.FUNCTION)
def CrudList(req: func.HttpRequest) -> func.HttpResponse:
    entity = req.route_params.get("entity")
    schema = _resolve_entity(entity)
    if not schema:
        return _json_response({"error": f"Unknown entity: {entity}"}, status_code=400)

    query = f"SELECT * FROM {schema['table']}"

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        rows = cursor.fetchall()
        result = [_row_to_dict(cursor, row) for row in rows]
        return _json_response(result)


@app.function_name(name="CrudGetById")
@app.route(route="crud/{entity}/{item_id}", methods=["GET"], auth_level=func.AuthLevel.FUNCTION)
def CrudGetById(req: func.HttpRequest) -> func.HttpResponse:
    entity = req.route_params.get("entity")
    item_id = req.route_params.get("item_id")

    schema = _resolve_entity(entity)
    if not schema:
        return _json_response({"error": f"Unknown entity: {entity}"}, status_code=400)

    try:
        parsed_pk = _parse_pk_value(item_id, schema["pk_type"])
    except (ValueError, TypeError):
        return _json_response({"error": f"Invalid id for entity {entity}."}, status_code=400)

    query = f"SELECT * FROM {schema['table']} WHERE {schema['pk']} = ?"

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, (parsed_pk,))
        row = cursor.fetchone()
        if not row:
            return _json_response({"error": "Not found."}, status_code=404)
        return _json_response(_row_to_dict(cursor, row))


@app.function_name(name="CrudCreate")
@app.route(route="crud/{entity}", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def CrudCreate(req: func.HttpRequest) -> func.HttpResponse:
    entity = req.route_params.get("entity")
    schema = _resolve_entity(entity)
    if not schema:
        return _json_response({"error": f"Unknown entity: {entity}"}, status_code=400)

    payload, payload_error = _extract_payload(req)
    if payload_error:
        return _json_response({"error": payload_error}, status_code=400)

    allow_pk_on_insert = schema.get("allow_pk_on_insert", False)

    validation_error = _validate_payload_columns(payload, schema, include_pk=allow_pk_on_insert)
    if validation_error:
        return _json_response({"error": validation_error}, status_code=400)

    columns = [
        c
        for c in schema["columns"]
        if c in payload and (allow_pk_on_insert or c != schema["pk"])
    ]
    values = [payload[c] for c in columns]

    if not columns:
        return _json_response({"error": "No valid fields provided for insert."}, status_code=400)

    placeholders = ", ".join(["?"] * len(columns))
    insert_columns = ", ".join(columns)
    query = f"INSERT INTO {schema['table']} ({insert_columns}) VALUES ({placeholders})"

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, values)
        conn.commit()
        return _json_response({"message": "Created.", "entity": schema["table"]}, status_code=201)


@app.function_name(name="CrudUpdate")
@app.route(route="crud/{entity}/{item_id}", methods=["PUT"], auth_level=func.AuthLevel.FUNCTION)
def CrudUpdate(req: func.HttpRequest) -> func.HttpResponse:
    entity = req.route_params.get("entity")
    item_id = req.route_params.get("item_id")

    schema = _resolve_entity(entity)
    if not schema:
        return _json_response({"error": f"Unknown entity: {entity}"}, status_code=400)

    try:
        parsed_pk = _parse_pk_value(item_id, schema["pk_type"])
    except (ValueError, TypeError):
        return _json_response({"error": f"Invalid id for entity {entity}."}, status_code=400)

    payload, payload_error = _extract_payload(req)
    if payload_error:
        return _json_response({"error": payload_error}, status_code=400)

    validation_error = _validate_payload_columns(payload, schema, include_pk=False)
    if validation_error:
        return _json_response({"error": validation_error}, status_code=400)

    update_columns = [c for c in schema["columns"] if c in payload and c != schema["pk"]]
    if not update_columns:
        return _json_response({"error": "No valid fields provided for update."}, status_code=400)

    set_clause = ", ".join([f"{col} = ?" for col in update_columns])
    values = [payload[col] for col in update_columns]
    values.append(parsed_pk)

    query = f"UPDATE {schema['table']} SET {set_clause} WHERE {schema['pk']} = ?"

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, values)
        affected = cursor.rowcount
        conn.commit()
        if affected == 0:
            return _json_response({"error": "Not found."}, status_code=404)
        return _json_response({"message": "Updated.", "rows_affected": affected})


@app.function_name(name="CrudDelete")
@app.route(route="crud/{entity}/{item_id}", methods=["DELETE"], auth_level=func.AuthLevel.FUNCTION)
def CrudDelete(req: func.HttpRequest) -> func.HttpResponse:
    entity = req.route_params.get("entity")
    item_id = req.route_params.get("item_id")

    schema = _resolve_entity(entity)
    if not schema:
        return _json_response({"error": f"Unknown entity: {entity}"}, status_code=400)

    try:
        parsed_pk = _parse_pk_value(item_id, schema["pk_type"])
    except (ValueError, TypeError):
        return _json_response({"error": f"Invalid id for entity {entity}."}, status_code=400)

    query = f"DELETE FROM {schema['table']} WHERE {schema['pk']} = ?"

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, (parsed_pk,))
        affected = cursor.rowcount
        conn.commit()
        if affected == 0:
            return _json_response({"error": "Not found."}, status_code=404)
        return _json_response({"message": "Deleted.", "rows_affected": affected})

# look up account by AccountHolderFullName and return the Account model
def _getAccountByHolderName(holder_name: str) -> Accounts:
    print(f"Looking up account for holder name: {holder_name}")
    query = "SELECT * FROM Accounts WHERE AccountHolderFullName = ?"

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, (holder_name,))
        row = cursor.fetchone()
        if not row:
            return None
        account = Accounts(
            id=row[0],
            user_name=row[1],
            account_holder_full_name=row[2],
            currency=row[3],
            activation_date=row[4],
            balance=row[5],
            created_date=row[6],
            modified_date=row[7]
        )
        return account


@app.function_name(name="GetAccountByHolderName")
@app.route(route="account/byholder/{holder_name}", methods=["GET"], auth_level=func.AuthLevel.FUNCTION)
def GetAccountByHolderName(req: func.HttpRequest) -> func.HttpResponse:
    holder_name = req.route_params.get("holder_name")    
    account = _getAccountByHolderName(holder_name)
    if not account:
        return _json_response({"error": "Not found."}, status_code=404)
    return _json_response(account.__dict__)

# get account stocks by account holder name, look up account by holder name and then get stocks for that account
@app.function_name(name="GetAccountStocksByHolderName")
@app.route(route="account/stocks/byholder/{holder_name}", methods=["GET"], auth_level=func.AuthLevel.FUNCTION)
def GetAccountStocksByHolderName(req: func.HttpRequest) -> func.HttpResponse:
    holder_name = req.route_params.get("holder_name")
    account = _getAccountByHolderName(holder_name)
    if not account:
        return _json_response({"error": "Account not found."}, status_code=404)

    #  query AccountStocks and it should join the stock_id and purchase_order_id
    query = """
    SELECT AccountStocks.*, Stocks.*, PurchaseOrders.*, OrderStatus*, PaymentMethods.*
    FROM AccountStocks
    JOIN Stocks ON AccountStocks.StockId = Stocks.Id
    JOIN PurchaseOrders ON AccountStocks.PurchaseOrderId = PurchaseOrders.PurchaseOrderId
    JOIN OrderStatus ON PurchaseOrders.StatusId = OrderStatus.StatusId
    JOIN PaymentMethods ON PurchaseOrders.PaymentMethodId = PaymentMethods.Id
    WHERE AccountStocks.AccountId = ?
    """

    with _get_sql_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, (account.id,))
        rows = cursor.fetchall()
        stocks = []
        for row in rows:
            # append row as dict to stocks list
            stocks.append(_row_to_dict(cursor, row))
        return _json_response(stocks)