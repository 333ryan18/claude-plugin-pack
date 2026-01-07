# Claude Plugin Pack

A personal collection of Claude Code plugins.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [ralph-wiggum-windows](plugins/ralph-wiggum-windows) | Windows implementation of continuous self-referential AI loops |

## Installation

Add this marketplace to Claude Code:

```
/plugin marketplace add 333ryan18/claude-plugin-pack
```

Then install individual plugins:

```
/plugin install ralph-wiggum-windows
```

## Adding More Plugins

To add a new plugin, create a directory under `plugins/` with the standard Claude Code plugin structure:

```
plugins/
└── your-plugin-name/
    ├── .claude-plugin/
    │   └── plugin.json
    ├── commands/
    ├── agents/
    ├── hooks/
    └── README.md
```

Then update `.claude-plugin/marketplace.json` to include it.
