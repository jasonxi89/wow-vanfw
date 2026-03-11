#!/usr/bin/env python3
"""
VanFW MCP Server - Realtime WoW Bot Framework Logger
Provides MCP resources for reading and monitoring VanFW logs in realtime.
"""

import os
import json
import asyncio
from pathlib import Path
from datetime import datetime
from typing import Any, Optional
import time

from mcp.server import Server
from mcp.types import Resource, Tool, TextContent, ImageContent, EmbeddedResource
import mcp.server.stdio

LOG_DIR = Path("c:/WGG/MCP/logs")
REALTIME_LOG = LOG_DIR / "vanfw_realtime.json"
POLL_INTERVAL = 0.1


class VanFWMCPServer:
    def __init__(self):
        self.server = Server("vanfw-mcp")
        self.last_realtime_check = 0
        self.realtime_log_cache = None
        self._start_time = time.time()
        self.setup_handlers()

    def setup_handlers(self):
        @self.server.list_resources()
        async def list_resources() -> list[Resource]:
            resources = []

            # Realtime log
            if REALTIME_LOG.exists():
                resources.append(
                    Resource(
                        uri=f"vanfw://realtime",
                        name="Realtime Log",
                        mimeType="application/json",
                        description="Live VanFW logs (updated every 100ms)",
                    )
                )

            if LOG_DIR.exists():
                for log_file in sorted(LOG_DIR.glob("*.json"), key=os.path.getmtime, reverse=True):
                    if log_file.name == "vanfw_realtime.json":
                        continue

                    name = log_file.stem
                    mtime = datetime.fromtimestamp(log_file.stat().st_mtime)

                    resources.append(
                        Resource(
                            uri=f"vanfw://logs/{log_file.name}",
                            name=f"Log: {name}",
                            mimeType="application/json",
                            description=f"Exported log from {mtime.strftime('%Y-%m-%d %H:%M:%S')}",
                        )
                    )

            resources.append(
                Resource(
                    uri="vanfw://stats",
                    name="Logger Statistics",
                    mimeType="application/json",
                    description="VanFW logger statistics and session info",
                )
            )

            return resources

        @self.server.read_resource()
        async def read_resource(uri: str) -> str:
            if uri == "vanfw://realtime":
                return await self._read_realtime_log()
            elif uri == "vanfw://stats":
                return await self._read_statistics()
            elif uri.startswith("vanfw://logs/"):
                filename = uri.replace("vanfw://logs/", "")
                log_file = LOG_DIR / filename

                if not log_file.exists():
                    raise ValueError(f"Log file not found: {filename}")

                with open(log_file, "r", encoding="utf-8") as f:
                    data = json.load(f)

                return json.dumps(data, indent=2)

            else:
                raise ValueError(f"Unknown resource URI: {uri}")

        @self.server.list_tools()
        async def list_tools() -> list[Tool]:
            return [
                Tool(
                    name="vanfw_check_connection",
                    description="Check if VanFW MCP server is connected and get connection status",
                    inputSchema={
                        "type": "object",
                        "properties": {},
                    },
                ),
                Tool(
                    name="vanfw_query_logs",
                    description="Query VanFW logs with filters (category, time range, search)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "category": {
                                "type": "string",
                                "description": "Filter by category (combat, spell, rotation, error, etc.)",
                            },
                            "limit": {
                                "type": "number",
                                "description": "Maximum number of logs to return (default: 100)",
                            },
                            "search": {
                                "type": "string",
                                "description": "Search term to filter messages",
                            },
                            "time_range": {
                                "type": "number",
                                "description": "Only show logs from last N seconds",
                            },
                        },
                    },
                ),
                Tool(
                    name="vanfw_watch_logs",
                    description="Watch VanFW logs in realtime (returns recent changes)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "category": {
                                "type": "string",
                                "description": "Filter by category",
                            },
                        },
                    },
                ),
                Tool(
                    name="vanfw_analyze_combat",
                    description="Analyze combat logs and provide insights (rotation issues, errors, performance)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "log_file": {
                                "type": "string",
                                "description": "Specific log file to analyze (optional, uses realtime if not specified)",
                            },
                        },
                    },
                ),
                Tool(
                    name="vanfw_list_exports",
                    description="List all exported log files with metadata",
                    inputSchema={"type": "object", "properties": {}},
                ),
            ]

        @self.server.call_tool()
        async def call_tool(name: str, arguments: Any) -> list[TextContent]:
            if name == "vanfw_check_connection":
                result = await self._check_connection()
                return [TextContent(type="text", text=json.dumps(result, indent=2))]

            elif name == "vanfw_query_logs":
                result = await self._query_logs(arguments)
                return [TextContent(type="text", text=json.dumps(result, indent=2))]

            elif name == "vanfw_watch_logs":
                result = await self._watch_logs(arguments)
                return [TextContent(type="text", text=json.dumps(result, indent=2))]

            elif name == "vanfw_analyze_combat":
                result = await self._analyze_combat(arguments)
                return [TextContent(type="text", text=result)]

            elif name == "vanfw_list_exports":
                result = await self._list_exports()
                return [TextContent(type="text", text=json.dumps(result, indent=2))]

            else:
                raise ValueError(f"Unknown tool: {name}")


    async def _read_realtime_log(self) -> str:
        if not REALTIME_LOG.exists():
            return json.dumps(
                {
                    "status": "no_data",
                    "message": "Realtime logging not active. Enable with /mcp realtime on in-game",
                    "logs": [],
                },
                indent=2,
            )

        try:
            with open(REALTIME_LOG, "r", encoding="utf-8") as f:
                data = json.load(f)

            data["_read_time"] = time.time()
            data["_file_mtime"] = REALTIME_LOG.stat().st_mtime

            return json.dumps(data, indent=2)

        except Exception as e:
            return json.dumps({"error": str(e), "logs": []}, indent=2)

    async def _read_statistics(self) -> str:
        stats = {
            "realtime_active": REALTIME_LOG.exists(),
            "last_realtime_update": None,
            "total_exports": 0,
            "log_directory": str(LOG_DIR),
        }

        if REALTIME_LOG.exists():
            stats["last_realtime_update"] = datetime.fromtimestamp(
                REALTIME_LOG.stat().st_mtime
            ).isoformat()
        if LOG_DIR.exists():
            exports = list(LOG_DIR.glob("*.json"))
            stats["total_exports"] = len([f for f in exports if f.name != "vanfw_realtime.json"])
            latest = None
            for log_file in exports:
                if log_file.name == "vanfw_realtime.json":
                    continue
                if latest is None or log_file.stat().st_mtime > latest.stat().st_mtime:
                    latest = log_file

            if latest:
                try:
                    with open(latest, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    stats["latest_export"] = {
                        "filename": latest.name,
                        "timestamp": datetime.fromtimestamp(latest.stat().st_mtime).isoformat(),
                        "meta": data.get("meta", {}),
                        "statistics": data.get("statistics", {}),
                    }
                except:
                    pass

        return json.dumps(stats, indent=2)
    async def _check_connection(self) -> dict:
        """Check MCP server connection and VanFW status"""
        status = {
            "connected": True,
            "server": "VanFW MCP Server",
            "version": "1.0.0",
            "timestamp": datetime.now().isoformat(),
            "uptime_seconds": time.time() - getattr(self, '_start_time', time.time()),
        }

        vanfw_active = False
        last_activity = None

        if REALTIME_LOG.exists():
            vanfw_active = True
            last_activity = datetime.fromtimestamp(REALTIME_LOG.stat().st_mtime).isoformat()
            status["realtime_logging"] = True
            status["last_realtime_update"] = last_activity
        else:
            status["realtime_logging"] = False
        if LOG_DIR.exists():
            exports = list(LOG_DIR.glob("*.json"))
            if exports:
                vanfw_active = True
                latest = max(exports, key=lambda f: f.stat().st_mtime)
                if latest.name != "vanfw_realtime.json":
                    last_activity = datetime.fromtimestamp(latest.stat().st_mtime).isoformat()
                    status["last_export"] = latest.name
                    status["last_export_time"] = last_activity

            status["total_exports"] = len([f for f in exports if f.name != "vanfw_realtime.json"])
        status["vanfw_active"] = vanfw_active
        status["last_activity"] = last_activity
        status["log_directory"] = str(LOG_DIR)
        status["log_directory_exists"] = LOG_DIR.exists()

        return status

    async def _query_logs(self, args: dict) -> dict:
        category = args.get("category")
        limit = args.get("limit", 100)
        search = args.get("search")
        time_range = args.get("time_range")
        if not REALTIME_LOG.exists():
            return {"error": "No realtime log available", "logs": []}

        try:
            with open(REALTIME_LOG, "r", encoding="utf-8") as f:
                data = json.load(f)
        except:
            return {"error": "Failed to read realtime log", "logs": []}

        logs = data.get("logs", [])

        filtered = []
        current_time = time.time()

        for log in logs:
            if category and log.get("category") != category:
                continue

            if time_range:
                log_time = log.get("timestamp", 0)
                if current_time - log_time > time_range:
                    continue

            if search:
                message = log.get("message", "").lower()
                if search.lower() not in message:
                    continue

            filtered.append(log)
        if len(filtered) > limit:
            filtered = filtered[-limit:]

        return {
            "total": len(filtered),
            "filters": {
                "category": category,
                "search": search,
                "time_range": time_range,
                "limit": limit,
            },
            "logs": filtered,
        }

    async def _watch_logs(self, args: dict) -> dict:
        category = args.get("category")

        if not REALTIME_LOG.exists():
            return {"status": "waiting", "message": "Realtime logging not active", "logs": []}

        try:
            with open(REALTIME_LOG, "r", encoding="utf-8") as f:
                data = json.load(f)
        except:
            return {"status": "error", "message": "Failed to read log", "logs": []}

        logs = data.get("logs", [])

        if category:
            logs = [log for log in logs if log.get("category") == category]

        cache_key = f"watch_{category or 'all'}"
        if not hasattr(self, "_watch_cache"):
            self._watch_cache = {}

        last_count = self._watch_cache.get(cache_key, 0)
        new_logs = logs[last_count:]
        self._watch_cache[cache_key] = len(logs)

        return {
            "status": "ok",
            "new_entries": len(new_logs),
            "total_entries": len(logs),
            "logs": new_logs,
        }

    async def _analyze_combat(self, args: dict) -> str:
        log_file = args.get("log_file")
        if log_file:
            log_path = LOG_DIR / log_file
            if not log_path.exists():
                return f"Error: Log file not found: {log_file}"

            with open(log_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        else:
            if not REALTIME_LOG.exists():
                return "Error: No realtime log available"

            with open(REALTIME_LOG, "r", encoding="utf-8") as f:
                data = json.load(f)

        logs = data.get("logs", [])
        analysis = {
            "total_events": len(logs),
            "categories": {},
            "errors": [],
            "warnings": [],
            "combat_summary": {},
            "spell_details": {
                "casts": [],
                "queue_events": [],
            },
            "rotation_events": [],
            "targeting_changes": [],
        }

        combat_start = None
        combat_end = None

        for log in logs:
            category = log.get("category", "unknown")
            analysis["categories"][category] = analysis["categories"].get(category, 0) + 1
            log_data = log.get("data", {})

            if category == "error":
                analysis["errors"].append({
                    "time": log.get("sessionTime", 0),
                    "message": log.get("message", ""),
                    "data": log_data,
                })

            if category == "warning":
                analysis["warnings"].append({
                    "time": log.get("sessionTime", 0),
                    "message": log.get("message", ""),
                })

            if category == "combat":
                message = log.get("message", "")
                if "started" in message.lower():
                    combat_start = log.get("sessionTime", 0)
                elif "ended" in message.lower():
                    combat_end = log.get("sessionTime", 0)

            if category == "spell":
                spell_count += 1
                spell_data = log.get("data", {})
                if spell_data:
                    analysis["spell_casts"].append(
                        {
                            "time": log.get("sessionTime", 0),
                            "spell": spell_data.get("spellName", "Unknown"),
                            "id": spell_data.get("spellID", 0),
                        }
                    )

        if combat_start is not None and combat_end is not None:
            analysis["combat_summary"] = {
                "duration": combat_end - combat_start,
                "spell_count": spell_count,
                "casts_per_second": spell_count / (combat_end - combat_start)
                if combat_end > combat_start
                else 0,
            }

        report = ["# VanFW Combat Log Analysis", ""]
        report.append(f"**Total Events:** {analysis['total_events']}")
        report.append(f"**Errors:** {len(analysis['errors'])}")
        report.append("")

        report.append("## Events by Category")
        for cat, count in sorted(
            analysis["categories"].items(), key=lambda x: x[1], reverse=True
        ):
            report.append(f"- {cat}: {count}")
        report.append("")

        if analysis["combat_summary"]:
            report.append("## Combat Summary")
            cs = analysis["combat_summary"]
            report.append(f"- Duration: {cs['duration']:.2f}s")
            report.append(f"- Total Spells: {cs['spell_count']}")
            report.append(f"- Casts/Second: {cs['casts_per_second']:.2f}")
            report.append("")

        if analysis["errors"]:
            report.append("## Errors")
            for err in analysis["errors"][:10]:
                report.append(f"- [{err['time']:.2f}s] {err['message']}")
            report.append("")

        if analysis["spell_casts"]:
            report.append("## Recent Spell Casts")
            for cast in analysis["spell_casts"][-10:]:
                report.append(f"- [{cast['time']:.2f}s] {cast['spell']} (ID: {cast['id']})")
            report.append("")

        return "\n".join(report)

    async def _list_exports(self) -> dict:
        exports = []

        if LOG_DIR.exists():
            for log_file in sorted(LOG_DIR.glob("*.json"), key=os.path.getmtime, reverse=True):
                if log_file.name == "vanfw_realtime.json":
                    continue

                stat = log_file.stat()
                exports.append(
                    {
                        "filename": log_file.name,
                        "size": stat.st_size,
                        "size_human": f"{stat.st_size / 1024:.2f} KB",
                        "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                        "uri": f"vanfw://logs/{log_file.name}",
                    }
                )

        return {"total": len(exports), "exports": exports}

    async def run(self):
        async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
            await self.server.run(
                read_stream,
                write_stream,
                self.server.create_initialization_options(),
            )


async def main():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    server = VanFWMCPServer()
    await server.run()
if __name__ == "__main__":
    asyncio.run(main())
