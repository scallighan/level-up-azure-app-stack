import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    PromptAgentDefinition,
)

load_dotenv()

endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]

with (
    DefaultAzureCredential() as credential,
    AIProjectClient(endpoint=endpoint, credential=credential) as project_client,
    project_client.get_openai_client() as openai_client,
):
    
    print("Connected to project.")
    

    agent = project_client.agents.create_version(
        agent_name="MyAgent",
        definition=PromptAgentDefinition(
            model=os.environ["FOUNDRY_MODEL_DEPLOYMENT_NAME"],
            instructions="You are a helpful assistant.",
        ),
    )
    print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")


    user_input = input("Enter your question (e.g., 'What can you do?'): \n")
    try:
        while user_input != "quit":
            print(f"\nSending user input to agent: {user_input}\n")
            stream_response = openai_client.responses.create(
                stream=True,
                input=user_input,
                extra_body={"agent_reference": {"name": agent.name, "type": "agent_reference"}},
            )
            for event in stream_response:
                
                if event.type == "response.created":
                    print(f"-----{event.type}-----")
                    print(f"Follow-up response created with ID: {event.response.id}")
                elif event.type == "response.output_text.delta":
                    #print(f"Delta: {event.delta}")
                    pass
                elif event.type == "response.text.done":
                    print(f"-----{event.type}-----")
                    print(f"\nFollow-up response done!")
                elif event.type == "response.output_item.done":
                    print(f"-----{event.type}-----")
                    item = event.item
                    if item.type == "remote_function_call":
                        print(f"Call ID: {getattr(item, 'call_id')}")
                        print(f"Label: {getattr(item, 'label')}")
                elif event.type == "response.completed":
                    print(f"-----{event.type}-----")
                    print(f"\nFollow-up completed!")
                    print(f"Full response: {event.response.output_text}")
                elif event.type == "response.oauth_consent_requested":
                    print(f"-----{event.type}-----")
                    print(f"OAuth consent requested for connection {event.server_label}: {event.consent_link}")
                elif event.type == "response.output_item.added":
                    print(f"-----{event.type}-----")
                    print(f"Output item added: {event.item.type} | {event}")
                elif event.type == "response.content_part.added":
                    print(f"-----{event.type}-----")
                    print(f"Content part added: {event.part}")
                elif event.type == "response.output_text.done":
                    print(f"-----{event.type}-----")
                    print(f"Response text completed: {event}")
                
                else:
                    print(f"Unknown event type: {event.type}")

            user_input = input("Enter your question (e.g., 'What can you do?' or 'quit' to end): \n")
    except Exception as e:
        print(f"Error during streaming response: {e}")
    finally:
        print("\nCleaning up...")
        project_client.agents.delete_version(agent_name=agent.name, agent_version=agent.version)
        print("Agent deleted")