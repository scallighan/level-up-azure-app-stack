from microsoft_agents.activity import load_configuration_from_env
from microsoft_agents.authentication.msal import MsalConnectionManager
from microsoft_agents.hosting.core import (
   AgentApplication,
   Authorization,
   TurnState,
   TurnContext,
   MemoryStorage,
)
from microsoft_agents.hosting.aiohttp import CloudAdapter
from os import environ
from .server import start_server
from azure.identity import DefaultAzureCredential
from agent_framework import Agent, tool
from agent_framework.foundry import FoundryChatClient

agents_sdk_config = load_configuration_from_env(environ)
print(f"Loaded configuration: {agents_sdk_config}")
# Create storage and connection manager
STORAGE = MemoryStorage()
CONNECTION_MANAGER = MsalConnectionManager(**agents_sdk_config)
ADAPTER = CloudAdapter(connection_manager=CONNECTION_MANAGER)
AUTHORIZATION = Authorization(STORAGE, CONNECTION_MANAGER, **agents_sdk_config)

AGENT_APP = AgentApplication[TurnState](
    storage=STORAGE,
    adapter=ADAPTER,
    authorization=AUTHORIZATION
)

async def _help(context: TurnContext, _: TurnState):
    await context.send_activity(
        "Welcome to the Level Up Agent sample 🚀. "
        "Type 'help' for help or send a message to see the echo feature in action."
    )

AGENT_APP.conversation_update("membersAdded")(_help)

AGENT_APP.message("help")(_help)

def _init_agent():
    print("Initializing agent...")
    # Any additional initialization logic can go here
    credential = DefaultAzureCredential()
    client = FoundryChatClient(
        project_endpoint=environ.get("FOUNDRY_PROJECT_ENDPOINT"),
        model=environ.get("FOUNDRY_MODEL"),
        credential=credential)
    agent = Agent(
        client=client, 
        name="LevelUpAgent", 
        description="An agent for the Level Up Azure App Stack workshop", 
        tools=[]
    )
    print("Agent initialized.")
    return agent

MY_AGENT = None
SESSION = None

@AGENT_APP.activity("message")
async def on_message(context: TurnContext, _):
    global MY_AGENT
    global SESSION
    print(f"Received message: {context.activity.text}")
    
    if MY_AGENT is None:
        MY_AGENT = _init_agent()
    
    try:
        if SESSION is None:
            SESSION = MY_AGENT.start_session()
        response = await MY_AGENT.run(context.activity.text, session=SESSION)
        await context.send_activity(response)
    except Exception as e:
        print(f"Error processing message: {e}")
        await context.send_activity(f"Error processing message: {e}")
    

if __name__ == "__main__":
    try:
        start_server(AGENT_APP, CONNECTION_MANAGER.get_default_connection_configuration())
    except Exception as error:
        raise error