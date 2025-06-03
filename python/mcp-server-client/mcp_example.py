# server.py
from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("Demo")


# Add an addition tool
@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers"""
    return a + b


# Add a dynamic greeting resource
@mcp.tool()
def get_greeting(name: str) -> str:
    """Get a personalized greeting"""
    return f"Hello, {name}, you beautiful beast!"


if __name__ == "__main__":
    mcp.run()