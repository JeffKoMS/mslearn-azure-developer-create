# server.py
from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("Demo")


# Add an addition tool
@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers (a, b) and return the result"""
    total = a + b
    return f"Answer: {a} + {b} = {total}"


# Add a greeting tool
@mcp.tool()
def get_greeting(name: str) -> str:
    """Enter your name and get a personalized greeting"""
    return f"Hello, {name}, you look amazing today!"

mcp.run()
