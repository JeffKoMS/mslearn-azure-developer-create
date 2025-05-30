import threading
import time
from mcp.server.fastmcp import FastMCP
import socket
import json

# Define the MCP server
def start_server():
    mcp = FastMCP("Demo")

    @mcp.tool()
    def say_hello(name: str) -> str:
        return f"Hello, {name}!"

    @mcp.tool()
    def reverse_string(text: str) -> str:
        return text[::-1]

    mcp.run()

# Define the client
def start_client():
    time.sleep(2)  # Give the server time to start

    def client_send(message):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.connect(('localhost', 5000))
            sock.send(message.encode())
            response = sock.recv(1024).decode()
            return response

    # Discover available tools
    tools_response = client_send('{"jsonrpc": "2.0", "method": "mcp.tools", "id": 1}')
    tools = json.loads(tools_response).get('result', [])

    while True:
        print("Available tools:")
        for i, tool in enumerate(tools):
            print(f"{i + 1}. {tool['name']}")

        choice = input("Enter the number of the tool you want to use: ")

        try:
            tool_index = int(choice) - 1
            tool = tools[tool_index]
            tool_name = tool['name']
            params = {}

            for param in tool['params']:
                param_name = param['name']
                param_value = input(f"Enter value for {param_name}: ")
                params[param_name] = param_value

            request = {
                "jsonrpc": "2.0",
                "method": tool_name,
                "params": params,
                "id": 1
            }

            response = client_send(json.dumps(request))
            print(f"Server responded: {response}")

        except (IndexError, ValueError):
            print("Invalid choice. Please try again.")

# Run both in threads
server_thread = threading.Thread(target=start_server, daemon=True)
client_thread = threading.Thread(target=start_client)

server_thread.start()
client_thread.start()

client_thread.join()
