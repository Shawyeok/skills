# Agent Skills

A collection of agent skills.

## Available Skills

### eclipse-mat

Analyze Java heap dumps headlessly using [Eclipse Memory Analyzer Tool (MAT)](https://eclipse.dev/mat/).

Features:

- Run leak suspects, overview, and comparison reports
- Execute OQL (Object Query Language) queries
- Run 56+ built-in MAT commands (histogram, dominator tree, thread analysis, etc.)
- Auto-detects MAT installation and Java version

See [`eclipse-mat/SKILL.md`](eclipse-mat/SKILL.md) for full documentation.

Based on [mcp-mat](https://github.com/codelipenghui/mcp-mat) by codelipenghui.

## Installation

```bash
npx skills add https://github.com/Shawyeok/skills --skill eclipse-mat
```

## License

MIT
