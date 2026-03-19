---
name: eclipse-mat
description: Analyze Java heap dumps using Eclipse Memory Analyzer Tool (MAT). Use when the user asks to analyze heap dumps, find memory leaks, inspect object retention, run OQL queries, or investigate OutOfMemoryError issues.
---

# MAT Heap Dump Analysis

Analyze Java heap dumps headlessly using Eclipse MAT via the `scripts/mat.sh` shell wrapper.

## Prerequisites

- **MAT** installed at `/Applications/MemoryAnalyzer.app/Contents/Eclipse/` (new) or `/Applications/mat.app/Contents/Eclipse/` (legacy), auto-detected in that order (or set `MAT_HOME`)
- **Java 17+** available via `$JAVA_HOME/bin/java`, `/usr/libexec/java_home -V`, or `java` on PATH

## Script Location

`scripts/mat.sh` in this skills folder.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MAT_HOME` | auto-detected (`MemoryAnalyzer.app` → `mat.app`) | MAT installation root |
| `MAT_XMX` | `4g` | Java max heap size for MAT |
| `MAT_TIMEOUT` | `1800` | Command timeout in seconds |
| `JAVA_HOME` | (system) | Java installation directory |

## Operations

### 1. Healthcheck — Verify MAT + Java setup

```bash
scripts/mat.sh healthcheck
```

Run this first to confirm MAT and Java are available.

### 2. Index Status — Check if a heap dump is already indexed

```bash
scripts/mat.sh index-status /path/to/dump.hprof
```

If the heap dump has been parsed before, MAT creates `.index` files next to it. This avoids re-indexing on subsequent operations.

### 3. Parse Report — Run predefined analysis reports

```bash
scripts/mat.sh report /path/to/dump.hprof <report_id> [options...]
```

**Available report IDs:**

| Report ID | Description |
|-----------|-------------|
| `org.eclipse.mat.api:suspects` | Leak suspects report — identifies likely memory leaks |
| `org.eclipse.mat.api:overview` | Heap overview — class histogram, top consumers, system info |
| `org.eclipse.mat.api:top_components` | Top memory-consuming components |
| `org.eclipse.mat.api:compare` | Comparison report (requires `-baseline /path/to/other.hprof`) |
| `org.eclipse.mat.api:suspects2` | Leak suspects comparison |
| `org.eclipse.mat.api:overview2` | Overview comparison |

**Examples:**

```bash
# Leak suspects
scripts/mat.sh report dump.hprof org.eclipse.mat.api:suspects

# Overview
scripts/mat.sh report dump.hprof org.eclipse.mat.api:overview

# Comparison (two heap dumps)
scripts/mat.sh report dump.hprof org.eclipse.mat.api:compare -baseline baseline.hprof
```

Reports generate HTML/ZIP artifacts in the same directory as the heap dump.

### 4. OQL Query — Execute Object Query Language queries

```bash
scripts/mat.sh oql /path/to/dump.hprof "<query>" [--format txt|html|csv] [--limit N]
```

**Examples:**

```bash
# List all String objects
scripts/mat.sh oql dump.hprof "SELECT * FROM java.lang.String" --limit 100

# Inspect fields of a specific object by address
scripts/mat.sh oql dump.hprof "SELECT p.topic FROM OBJECTS 0x12345678 p"

# Find instances of a class
scripts/mat.sh oql dump.hprof "SELECT p FROM INSTANCEOF com.example.MyClass p" --limit 50
```

### 5. Run Command — Execute built-in MAT analysis commands

```bash
scripts/mat.sh command /path/to/dump.hprof <command_name> [args] [--format txt|html|csv] [--limit N]
```

**Examples:**

```bash
# Class histogram
scripts/mat.sh command dump.hprof histogram

# Dominator tree
scripts/mat.sh command dump.hprof dominator_tree

# Path to GC roots for a specific object
scripts/mat.sh command dump.hprof path2gc 0x12345678

# Thread overview
scripts/mat.sh command dump.hprof thread_overview

# Find strings
scripts/mat.sh command dump.hprof find_strings --limit 200
```

## Supported Commands (56 total)

See [`references/commands.md`](references/commands.md) for the full list with descriptions.

## OQL Specification

MAT uses its own OQL dialect in "parse-application command mode":

**Command format:** `-command=oql "<query>"`

### Supported Patterns

| Pattern | Example | Use Case |
|---------|---------|----------|
| Instance scan | `SELECT p FROM INSTANCEOF com.example.MyClass p` | Iterate objects by class |
| Field extraction | `SELECT p.topic FROM OBJECTS 0x12345678 p` | Read fields from a specific object |
| Boolean/state check | `SELECT p.isClosing FROM OBJECTS 0x12345678 p` | Validate lifecycle flags |
| Class histogram | Use `org.eclipse.mat.api:overview` report instead | Ranking classes by count/size |

### Known Limitations

- SQL-like `GROUP BY` / `ORDER BY` frequently fail in parse-app query mode
- Dialect-specific helpers like `classof(...)` may be rejected depending on parser context
- For ranking/top classes, prefer MAT overview/suspects reports then parse the artifacts
- For root-cause inspection, use targeted field-level OQL against object addresses

## Instructions for Heap Dump Analysis

### Recommended Workflow

1. **Healthcheck first**: Run `scripts/mat.sh healthcheck` to verify the setup
2. **Check index status**: Run `scripts/mat.sh index-status <heap>` — if already indexed, subsequent operations will be faster
3. **Start with overview**: Run `scripts/mat.sh report <heap> org.eclipse.mat.api:overview` to get class histogram and system info
4. **Run leak suspects**: Run `scripts/mat.sh report <heap> org.eclipse.mat.api:suspects` for automatic leak detection
5. **Drill down**: Use `scripts/mat.sh command <heap> histogram` for class-level breakdown, then `dominator_tree` for retained size analysis
6. **Investigate specific objects**: Use `scripts/mat.sh oql <heap> "SELECT ..."` to inspect individual objects by address or class
7. **Thread analysis**: Use `scripts/mat.sh command <heap> thread_overview` to see thread stacks and local variables

### Reading Results

- **Reports** generate HTML directories and ZIP files next to the heap dump (e.g., `dump_Leak_Suspects/`)
- **Queries and commands** produce text results in `*_Query/pages/Query_Command*.txt`
- The script automatically displays text results and lists generated artifacts
- For HTML reports, read the generated files in the report directory

### Tips

- First-time analysis of a heap dump triggers indexing, which can take minutes for large dumps. Subsequent operations reuse the index.
- Increase `MAT_XMX` for very large heap dumps (e.g., `MAT_XMX=8g`)
- Increase `MAT_TIMEOUT` for long-running analyses (e.g., `MAT_TIMEOUT=3600`)
- Use `--limit` with OQL and commands to avoid overwhelming output
- The `path2gc` command is invaluable for understanding why objects are retained
- Compare two heap dumps with `org.eclipse.mat.api:compare` to find growth patterns
