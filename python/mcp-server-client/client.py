import asyncio
from typing import Optional
from contextlib import AsyncExitStack
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def connect_to_server(server_script_path: str, exit_stack: AsyncExitStack):
    """
    Args:
        server_script_path, file name of the server script (.py).
        Enter the full path if file is not in the same directory.
    """
    is_python = server_script_path.endswith('.py')
    if not is_python:
        raise ValueError("Server script must be a .py file")

    server_params = StdioServerParameters(
        command="python",
        args=[server_script_path],
        env=None
    )

    # Start the server using stdio transport
    stdio_transport = await exit_stack.enter_async_context(stdio_client(server_params))
    stdio, write = stdio_transport
    session = await exit_stack.enter_async_context(ClientSession(stdio, write))
    await session.initialize()

    # List available tools
    response = await session.list_tools()
    tools = response.tools
    print("\nConnected to server with tools:", [tool.name for tool in tools])
    return session

async def chat_loop(session):
    while True:
        # List tools available on the server
        response = await session.list_tools()
        tools = response.tools
        print("\nAvailable tools:")
        for idx, tool in enumerate(tools, 1):
            print(f"{idx}. {tool.name}: {tool.description}")
        print("Type the tool number to use it, or type 'quit' to exit.")
        
        # Get user input for tool selection
        user_input = input("Select tool or quit: ").strip()
        if user_input.lower() == "quit":
            print("Exiting chat.")
            break
        try:
            tool_idx = int(user_input) - 1
            tool = tools[tool_idx]
        except (ValueError, IndexError):
            print("Invalid selection. Please try again.")
            continue
        
        # Prepare tool input
        params = {}
        if hasattr(tool, 'inputSchema') and tool.inputSchema:
            for param in tool.inputSchema.get('properties', {}):
                val = input(f"Enter value for '{param}': ")
                params[param] = val
        
        # Call the tool
        result = await session.call_tool(tool.name, params)
        
        # Return the result
        text = result.content[0].text if result.content else "No content returned."
        print(f"\n{text}\n")

async def main():
    import sys
    if len(sys.argv) < 2:
        print("Usage: python client.py <path_to_server_script>")
        sys.exit(1)
    exit_stack = AsyncExitStack()
    try:
        session = await connect_to_server(sys.argv[1], exit_stack)
        await chat_loop(session)
    finally:
        await exit_stack.aclose()

if __name__ == "__main__":
    asyncio.run(main())