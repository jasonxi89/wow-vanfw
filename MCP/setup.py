from setuptools import setup, find_packages

setup(
    name="vanfw-mcp-server",
    version="1.0.0",
    description="MCP Server for VanFW WoW Framework - Realtime Logging & Debugging",
    author="VanFW Team",
    python_requires=">=3.10",
    py_modules=["server"],
    install_requires=[
        "mcp>=0.9.0",
    ],
    entry_points={
        "console_scripts": [
            "vanfw-mcp=server:main",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
)
