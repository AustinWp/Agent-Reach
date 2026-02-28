# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agent Reach is a unified CLI and Python library that provides standardized read and search capabilities across 10+ internet platforms (Twitter/X, Reddit, YouTube, GitHub, Bilibili, XiaoHongShu, RSS, Exa, and generic web). It wraps external tools (gh, yt-dlp, bird, mcporter) behind a pluggable channel architecture with async-first APIs.

## Development Commands

```bash
# Install in editable dev mode
pip install -e .

# Install with all optional features
pip install -e ".[all]"

# Run CLI directly
agent-reach doctor          # Health check all channels
agent-reach read <url>      # Test reading a URL
agent-reach search "query"  # Test web search

# Run as Python module (alternative)
python -m agent_reach.cli doctor
```

There is no test suite or linter configured in this project.

## Architecture

### Channel System (core abstraction)

Every platform is a **Channel** — a class inheriting from `agent_reach/channels/base.py:Channel` (ABC). Channels implement:

- `can_handle(url) -> bool` — URL routing (first match wins)
- `read(url, config) -> ReadResult` — read content from a URL
- `search(query, ...) -> List[SearchResult]` — search the platform (optional)
- `check(config) -> Tuple[str, str]` — health status reporting

Channels are registered in order in `agent_reach/channels/__init__.py:ALL_CHANNELS`. **Order matters** — `WebChannel` is last as the universal fallback.

### Data Flow

```
CLI (cli.py) or Library (core.py)
  → AgentReach.read(url) / .search(query)
    → channels/__init__.py:get_channel_for_url(url)  # URL routing
      → specific Channel.read() / .search()
        → subprocess call to external tool (gh, yt-dlp, bird, mcporter)
          → parse output into ReadResult / SearchResult
```

### Key Files

| File | Purpose |
|------|---------|
| `agent_reach/core.py` | `AgentReach` class — main programmatic API |
| `agent_reach/cli.py` | CLI entry point (~900 lines, all commands) |
| `agent_reach/channels/base.py` | `Channel` ABC, `ReadResult`, `SearchResult` dataclasses |
| `agent_reach/channels/__init__.py` | Channel registry and URL routing |
| `agent_reach/config.py` | Config loading from `~/.agent-reach/config.yaml` + env vars |
| `agent_reach/doctor.py` | Health check system aggregating channel status |
| `agent_reach/integrations/mcp_server.py` | MCP protocol server (8 tools) |
| `config/mcporter.json` | MCP server endpoints for Exa and XiaoHongShu |

### Channel Backends

Each channel wraps external CLI tools via subprocess. Some have fallback chains:

- **Twitter**: bird CLI → Jina Reader fallback
- **GitHub**: gh CLI → Jina Reader fallback
- **YouTube/Bilibili**: yt-dlp
- **XiaoHongShu/Exa**: mcporter (MCP bridge to Docker containers)
- **Web**: Jina Reader API (universal fallback)
- **RSS**: feedparser (pure Python)

### Tier System

Channels declare a `tier` (0/1/2) indicating setup complexity:
- **Tier 0**: Zero config — works immediately (Web, YouTube, RSS, Twitter read, GitHub public)
- **Tier 1**: Free setup — needs mcporter (Exa search)
- **Tier 2**: User config — needs tokens/proxy/Docker (Twitter search, Reddit, XiaoHongShu)

### Adding a New Channel

1. Create `agent_reach/channels/{platform}.py`
2. Subclass `Channel`, implement `can_handle()`, `read()`, optionally `search()`
3. Register in `agent_reach/channels/__init__.py:ALL_CHANNELS` (before `WebChannel`)

### Configuration

Config is loaded from `~/.agent-reach/config.yaml` with environment variable overrides. The `Config` class in `config.py` maps feature names to required config keys (`FEATURE_REQUIREMENTS` dict).

## External Dependencies

This project relies heavily on external CLI tools installed on the system:
- `gh` (GitHub CLI)
- `yt-dlp` (video platforms)
- `bird` (Twitter, optional)
- `mcporter` (MCP bridge for Exa/XiaoHongShu)
- Docker (XiaoHongShu MCP container on port 18060)
