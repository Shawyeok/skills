#!/usr/bin/env bash
# mat.sh — Shell wrapper for Eclipse MAT headless heap dump analysis
# Usage: mat.sh <subcommand> [args...]
#
# Subcommands:
#   healthcheck                             Check MAT + Java setup
#   index-status <heap>                     Check if heap dump is already indexed
#   report <heap> <report_id> [options]     Run a predefined MAT report
#   oql <heap> <query> [--format F] [--limit N]
#   command <heap> <cmd> [args] [--format F] [--limit N]

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Search for MAT installation in order: new path, then legacy path
_resolve_mat_home() {
  if [[ -d "/Applications/MemoryAnalyzer.app/Contents/Eclipse" ]]; then
    echo "/Applications/MemoryAnalyzer.app/Contents/Eclipse"
  elif [[ -d "/Applications/mat.app/Contents/Eclipse" ]]; then
    echo "/Applications/mat.app/Contents/Eclipse"
  else
    echo "/Applications/mat.app/Contents/Eclipse"
  fi
}
MAT_HOME="${MAT_HOME:-$(_resolve_mat_home)}"
MAT_XMX="${MAT_XMX:-4g}"
MAT_TIMEOUT="${MAT_TIMEOUT:-1800}"

# Resolve Java
resolve_java() {
  if [[ -n "${JAVA_HOME:-}" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
    echo "$JAVA_HOME/bin/java"
  elif command -v jenv &>/dev/null; then
    jenv which java 2>/dev/null || echo "java"
  else
    echo "java"
  fi
}

JAVA_CMD="$(resolve_java)"

# Resolve MAT launcher jar
resolve_launcher() {
  local plugins_dir="$MAT_HOME/plugins"
  if [[ ! -d "$plugins_dir" ]]; then
    echo "ERROR: MAT plugins directory not found: $plugins_dir" >&2
    echo "Set MAT_HOME to the Eclipse MAT installation root." >&2
    return 1
  fi
  # Find the latest equinox launcher jar
  local launcher
  launcher=$(ls "$plugins_dir"/org.eclipse.equinox.launcher_*.jar 2>/dev/null | sort | tail -1)
  if [[ -z "$launcher" ]]; then
    echo "ERROR: No equinox launcher jar found in $plugins_dir" >&2
    return 1
  fi
  echo "$launcher"
}

# Resolve ParseHeapDump.sh
resolve_parse_script() {
  local script="$MAT_HOME/ParseHeapDump.sh"
  if [[ ! -x "$script" ]]; then
    echo "ERROR: ParseHeapDump.sh not found at $script" >&2
    return 1
  fi
  echo "$script"
}

# ---------------------------------------------------------------------------
# Healthcheck
# ---------------------------------------------------------------------------
cmd_healthcheck() {
  echo "=== MAT Healthcheck ==="
  echo ""
  echo "MAT_HOME: $MAT_HOME"

  # Check ParseHeapDump.sh
  local parse_script
  if parse_script=$(resolve_parse_script 2>/dev/null); then
    echo "ParseHeapDump.sh: $parse_script"
  else
    echo "ParseHeapDump.sh: NOT FOUND"
  fi

  # Check launcher jar
  local launcher
  if launcher=$(resolve_launcher 2>/dev/null); then
    echo "Launcher JAR: $launcher"
  else
    echo "Launcher JAR: NOT FOUND"
  fi

  # Check Java
  echo ""
  echo "Java command: $JAVA_CMD"
  if "$JAVA_CMD" -version 2>&1 | head -3; then
    :
  else
    echo "ERROR: Java not available at $JAVA_CMD"
    return 1
  fi

  echo ""
  echo "MAT_XMX: $MAT_XMX"
  echo "MAT_TIMEOUT: ${MAT_TIMEOUT}s"
  echo ""
  echo "Status: OK"
}

# ---------------------------------------------------------------------------
# Index Status
# ---------------------------------------------------------------------------
cmd_index_status() {
  local heap="$1"
  if [[ ! -f "$heap" ]]; then
    echo "ERROR: Heap dump not found: $heap" >&2
    return 1
  fi

  local heap_dir heap_name
  heap_dir=$(dirname "$heap")
  heap_name=$(basename "$heap")

  echo "=== Index Status ==="
  echo "Heap: $heap"
  echo ""

  local index_files=()
  local threads_file=""
  local latest_mtime=0

  local heap_stem="${heap_name%.*}"

  while IFS= read -r -d '' f; do
    local fname
    fname=$(basename "$f")
    # Match files starting with either the full name or stem (without extension)
    if { [[ "$fname" == "$heap_name"* ]] || [[ "$fname" == "$heap_stem"* ]]; } && [[ "$fname" != "$heap_name" ]]; then
      if [[ "$fname" == *".index"* ]]; then
        index_files+=("$f")
        local mtime
        mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
        if (( mtime > latest_mtime )); then
          latest_mtime=$mtime
        fi
      fi
      if [[ "$fname" == *"threads"* ]]; then
        threads_file="$f"
      fi
    fi
  done < <(find "$heap_dir" -maxdepth 1 -type f \( -name "${heap_name}*" -o -name "${heap_stem}.*" -o -name "${heap_stem}_*" \) -print0 2>/dev/null)

  if (( ${#index_files[@]} > 0 )); then
    echo "Indexed: YES"
    echo "Index files: ${#index_files[@]}"
    for f in "${index_files[@]}"; do
      echo "  $(basename "$f")"
    done
    if [[ -n "$threads_file" ]]; then
      echo "Threads file: $(basename "$threads_file")"
    fi
    if (( latest_mtime > 0 )); then
      echo "Last modified: $(date -r "$latest_mtime" 2>/dev/null || date -d "@$latest_mtime" 2>/dev/null || echo "$latest_mtime")"
    fi
  else
    echo "Indexed: NO"
    echo "Run a report or command to trigger indexing."
  fi
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
cmd_report() {
  local heap="$1"
  local report_id="$2"
  shift 2

  if [[ ! -f "$heap" ]]; then
    echo "ERROR: Heap dump not found: $heap" >&2
    return 1
  fi

  local launcher
  launcher=$(resolve_launcher)

  echo "=== Running Report ==="
  echo "Heap: $heap"
  echo "Report: $report_id"
  [[ $# -gt 0 ]] && echo "Options: $*"
  echo ""

  # Use java -jar launcher (same approach as mcp-mat) instead of ParseHeapDump.sh
  # which uses the MemoryAnalyzer binary that has macOS SWT issues in headless mode
  local -a java_args=(
    "-Xmx${MAT_XMX}"
    "--add-exports=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED"
    "-jar" "$launcher"
    "-consolelog"
    "-nosplash"
    "-application" "org.eclipse.mat.api.parse"
    "$heap"
  )
  # Append any extra options (e.g. -baseline /path/to/other.hprof)
  while (( $# > 0 )); do
    java_args+=("$1")
    shift
  done
  java_args+=("$report_id")

  local start_time
  start_time=$(date +%s)

  local exit_code=0
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
  else
    TIMEOUT_CMD=""
  fi

  if [[ -n "$TIMEOUT_CMD" ]]; then
    "$TIMEOUT_CMD" "$MAT_TIMEOUT" "$JAVA_CMD" "${java_args[@]}" 2>&1 || exit_code=$?
  else
    "$JAVA_CMD" "${java_args[@]}" 2>&1 || exit_code=$?
  fi

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  echo ""
  echo "=== Report Complete ==="
  echo "Exit code: $exit_code"
  echo "Duration: ${duration}s"

  if (( exit_code != 0 )); then
    echo "ERROR: Report generation failed with exit code $exit_code" >&2
    return $exit_code
  fi

  # List generated artifacts
  echo ""
  echo "=== Generated Artifacts ==="
  local heap_dir heap_base heap_stem
  heap_dir=$(dirname "$heap")
  heap_base=$(basename "$heap")
  heap_stem="${heap_base%.*}"

  find "$heap_dir" -maxdepth 1 \( -name "${heap_base}_*" -o -name "${heap_stem}_*" \) 2>/dev/null | sort | while read -r f; do
    if [[ -d "$f" ]]; then
      echo "  [DIR]  $(basename "$f")"
    else
      echo "  [FILE] $(basename "$f") ($(du -h "$f" | cut -f1))"
    fi
  done
}

# ---------------------------------------------------------------------------
# OQL Query
# ---------------------------------------------------------------------------
cmd_oql() {
  local heap="$1"
  local query="$2"
  shift 2

  # Parse optional flags
  local format="txt"
  local limit=""
  while (( $# > 0 )); do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      --limit)  limit="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  if [[ ! -f "$heap" ]]; then
    echo "ERROR: Heap dump not found: $heap" >&2
    return 1
  fi

  local launcher
  launcher=$(resolve_launcher)

  echo "=== OQL Query ==="
  echo "Heap: $heap"
  echo "Query: $query"
  echo "Format: $format"
  [[ -n "$limit" ]] && echo "Limit: $limit"
  echo ""

  # Build java command
  local -a java_args=(
    "-Xmx${MAT_XMX}"
    "--add-exports=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED"
    "-jar" "$launcher"
    "-consolelog"
    "-nosplash"
    "-application" "org.eclipse.mat.api.parse"
    "$heap"
    "-command=oql \"$query\""
    "-format=$format"
    "-unzip"
  )
  if [[ -n "$limit" ]]; then
    java_args+=("-limit=$limit")
  fi
  java_args+=("org.eclipse.mat.api:query")

  local start_time
  start_time=$(date +%s)

  local exit_code=0
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
  else
    TIMEOUT_CMD=""
  fi

  if [[ -n "$TIMEOUT_CMD" ]]; then
    "$TIMEOUT_CMD" "$MAT_TIMEOUT" "$JAVA_CMD" "${java_args[@]}" 2>&1 || exit_code=$?
  else
    "$JAVA_CMD" "${java_args[@]}" 2>&1 || exit_code=$?
  fi

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  echo ""
  echo "=== Query Complete ==="
  echo "Exit code: $exit_code"
  echo "Duration: ${duration}s"

  if (( exit_code != 0 )); then
    echo "ERROR: OQL query failed with exit code $exit_code" >&2
    return $exit_code
  fi

  # Find and display query results
  echo ""
  local heap_dir heap_base heap_stem
  heap_dir=$(dirname "$heap")
  heap_base=$(basename "$heap")
  heap_stem="${heap_base%.*}"

  # Look for Query result text files
  local result_found=false
  for query_dir in "$heap_dir/${heap_base}_Query" "$heap_dir/${heap_stem}_Query"; do
    if [[ -d "$query_dir/pages" ]]; then
      local result_txt
      result_txt=$(ls "$query_dir/pages"/Query_Command*.txt 2>/dev/null | sort | tail -1)
      if [[ -n "$result_txt" ]]; then
        echo "=== Query Results ==="
        cat "$result_txt"
        result_found=true
        break
      fi
    fi
  done

  if ! $result_found; then
    echo "(No text result file found. Check generated artifacts below.)"
  fi

  echo ""
  echo "=== Generated Artifacts ==="
  find "$heap_dir" -maxdepth 2 \( -name "${heap_base}_Query*" -o -name "${heap_stem}_Query*" \) 2>/dev/null | sort | while read -r f; do
    if [[ -d "$f" ]]; then
      echo "  [DIR]  $(basename "$f")"
    else
      echo "  [FILE] $(basename "$f")"
    fi
  done
}

# ---------------------------------------------------------------------------
# Run Command
# ---------------------------------------------------------------------------
cmd_command() {
  local heap="$1"
  local cmd_name="$2"
  shift 2

  # Parse optional command_args and flags
  local cmd_args=""
  local format="txt"
  local limit=""
  while (( $# > 0 )); do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      --limit)  limit="$2"; shift 2 ;;
      --args)   cmd_args="$2"; shift 2 ;;
      *) # Treat remaining positional args as command args if not a flag
         if [[ -z "$cmd_args" ]]; then
           cmd_args="$1"
         else
           cmd_args="$cmd_args $1"
         fi
         shift ;;
    esac
  done

  if [[ ! -f "$heap" ]]; then
    echo "ERROR: Heap dump not found: $heap" >&2
    return 1
  fi

  local launcher
  launcher=$(resolve_launcher)

  echo "=== Running Command ==="
  echo "Heap: $heap"
  echo "Command: $cmd_name"
  [[ -n "$cmd_args" ]] && echo "Args: $cmd_args"
  echo "Format: $format"
  [[ -n "$limit" ]] && echo "Limit: $limit"
  echo ""

  # Build the -command= argument
  local command_arg
  if [[ -n "$cmd_args" ]]; then
    command_arg="-command=$cmd_name $cmd_args"
  else
    command_arg="-command=$cmd_name"
  fi

  local -a java_args=(
    "-Xmx${MAT_XMX}"
    "--add-exports=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED"
    "-jar" "$launcher"
    "-consolelog"
    "-nosplash"
    "-application" "org.eclipse.mat.api.parse"
    "$heap"
    "$command_arg"
    "-format=$format"
    "-unzip"
  )
  if [[ -n "$limit" ]]; then
    java_args+=("-limit=$limit")
  fi
  java_args+=("org.eclipse.mat.api:query")

  local start_time
  start_time=$(date +%s)

  local exit_code=0
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  elif command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
  else
    TIMEOUT_CMD=""
  fi

  if [[ -n "$TIMEOUT_CMD" ]]; then
    "$TIMEOUT_CMD" "$MAT_TIMEOUT" "$JAVA_CMD" "${java_args[@]}" 2>&1 || exit_code=$?
  else
    "$JAVA_CMD" "${java_args[@]}" 2>&1 || exit_code=$?
  fi

  local end_time
  end_time=$(date +%s)
  local duration=$(( end_time - start_time ))

  echo ""
  echo "=== Command Complete ==="
  echo "Exit code: $exit_code"
  echo "Duration: ${duration}s"

  if (( exit_code != 0 )); then
    echo "ERROR: Command failed with exit code $exit_code" >&2
    return $exit_code
  fi

  # Find and display results
  echo ""
  local heap_dir heap_base heap_stem
  heap_dir=$(dirname "$heap")
  heap_base=$(basename "$heap")
  heap_stem="${heap_base%.*}"

  local result_found=false
  for query_dir in "$heap_dir/${heap_base}_Query" "$heap_dir/${heap_stem}_Query"; do
    if [[ -d "$query_dir/pages" ]]; then
      local result_txt
      result_txt=$(ls "$query_dir/pages"/Query_Command*.txt 2>/dev/null | sort | tail -1)
      if [[ -n "$result_txt" ]]; then
        echo "=== Command Results ==="
        cat "$result_txt"
        result_found=true
        break
      fi
    fi
  done

  if ! $result_found; then
    echo "(No text result file found. Check generated artifacts below.)"
  fi

  echo ""
  echo "=== Generated Artifacts ==="
  find "$heap_dir" -maxdepth 2 \( -name "${heap_base}_*" -o -name "${heap_stem}_*" \) 2>/dev/null | sort | while read -r f; do
    if [[ -d "$f" ]]; then
      echo "  [DIR]  $(basename "$f")"
    else
      echo "  [FILE] $(basename "$f")"
    fi
  done
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage: mat.sh <subcommand> [args...]

Subcommands:
  healthcheck                                   Check MAT + Java setup
  index-status <heap>                           Check if heap dump is indexed
  report <heap> <report_id> [options...]        Run a predefined MAT report
  oql <heap> <query> [--format txt|html|csv] [--limit N]
  command <heap> <cmd> [args] [--format txt|html|csv] [--limit N]

Environment variables:
  MAT_HOME      MAT installation directory (auto-detected: MemoryAnalyzer.app or mat.app)
  MAT_XMX       Java max heap size (default: 4g)
  MAT_TIMEOUT   Command timeout in seconds (default: 1800)
  JAVA_HOME     Java installation directory

Report IDs:
  org.eclipse.mat.api:suspects      Leak suspects report
  org.eclipse.mat.api:overview      Heap overview report
  org.eclipse.mat.api:top_components Top memory consumers
  org.eclipse.mat.api:compare       Comparison report (needs -baseline option)
  org.eclipse.mat.api:suspects2     Leak suspects (comparison)
  org.eclipse.mat.api:overview2     Overview (comparison)

Examples:
  mat.sh healthcheck
  mat.sh index-status dump.hprof
  mat.sh report dump.hprof org.eclipse.mat.api:suspects
  mat.sh oql dump.hprof "SELECT * FROM java.lang.String" --limit 100
  mat.sh command dump.hprof histogram
  mat.sh command dump.hprof path2gc 0x12345678
USAGE
}

if (( $# < 1 )); then
  usage
  exit 1
fi

subcmd="$1"
shift

case "$subcmd" in
  healthcheck)
    cmd_healthcheck "$@"
    ;;
  index-status)
    if (( $# < 1 )); then
      echo "Usage: mat.sh index-status <heap_dump_path>" >&2
      exit 1
    fi
    cmd_index_status "$@"
    ;;
  report)
    if (( $# < 2 )); then
      echo "Usage: mat.sh report <heap_dump_path> <report_id> [options...]" >&2
      exit 1
    fi
    cmd_report "$@"
    ;;
  oql)
    if (( $# < 2 )); then
      echo "Usage: mat.sh oql <heap_dump_path> <query> [--format txt|html|csv] [--limit N]" >&2
      exit 1
    fi
    cmd_oql "$@"
    ;;
  command)
    if (( $# < 2 )); then
      echo "Usage: mat.sh command <heap_dump_path> <command_name> [args] [--format txt|html|csv] [--limit N]" >&2
      exit 1
    fi
    cmd_command "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "Unknown subcommand: $subcmd" >&2
    usage
    exit 1
    ;;
esac
