# Supported MAT Commands (56 total)

Usage: `scripts/mat.sh command <heap> <command_name> [args] [--format txt|html|csv] [--limit N]`

## Dominator Tree Analysis

| Command | Description |
|---------|-------------|
| `dominator_tree` | Display objects ranked by retained heap size in the dominator tree |
| `show_dominator_tree` | Show the full dominator tree starting from a specific object or class |
| `immediate_dominators` | Find the immediate dominator(s) of objects matching a pattern |
| `big_drops_in_dominator_tree` | Identify objects where retained size drops significantly between parent and children |

## Path to GC Roots

| Command | Description |
|---------|-------------|
| `path2gc` | Show the shortest path from a specific object to its GC root — key for diagnosing retention |
| `merge_shortest_paths` | Merge shortest paths from multiple objects to GC roots, grouping common segments |
| `gc_roots` | List all GC roots categorized by type (thread, JNI, system class, etc.) |

## Histogram & Object Listing

| Command | Description |
|---------|-------------|
| `histogram` | Class histogram: all classes ranked by instance count and shallow/retained heap size |
| `delta_histogram` | Difference between histograms of two snapshots for comparison |
| `list_objects` | List individual object instances of a given class with addresses and sizes |
| `group_by_value` | Group objects by their string representation or field value to find duplicates |
| `duplicate_classes` | Find classes loaded by multiple class loaders — common leak source in app servers |

## Leak Detection

| Command | Description |
|---------|-------------|
| `leakhunter` | Automatically identify suspected memory leaks based on retention patterns |
| `leakhunter2` | Extended leak hunter that compares two heap dumps to find growing object sets |
| `find_leaks` | Find objects that retain disproportionately large amounts of heap |
| `find_leaks2` | Comparative leak detection across two heap dumps |
| `reference_leak` | Detect reference leaks from unclosed resources or forgotten listeners |

## Thread Analysis

| Command | Description |
|---------|-------------|
| `thread_overview` | Overview of all threads: names, states, and stack depths |
| `thread_details` | Detailed info for a specific thread including full stack trace and local variables |
| `thread_stack` | Call stack of a specific thread with references to objects on the stack |

## Collection Analysis

| Command | Description |
|---------|-------------|
| `collection_fill_ratio` | Fill ratio of collections (how full vs. capacity) to find over-allocation |
| `collections_grouped_by_size` | Group collections by size to find patterns like many empty lists |
| `array_fill_ratio` | Fill ratio for arrays — how much capacity is actually used |
| `arrays_grouped_by_size` | Group arrays by length to identify allocation patterns |
| `hash_entries` | List individual entries (keys and values) in a hash map or hash set |
| `map_collision_ratio` | Hash map collision ratios — high rates indicate poor hash functions |
| `extract_list_values` | Extract and display values stored in a list object |
| `hash_set_values` | Extract and display values stored in a hash set |
| `primitive_arrays_with_a_constant_value` | Find primitive arrays where all elements are identical — often wasted memory |

## Reference Analysis

| Command | Description |
|---------|-------------|
| `references_statistics` | Overall statistics for all reference types in the heap |
| `weak_references_statistics` | Analyze WeakReference objects: count, cleared status, and referents |
| `soft_references_statistics` | Analyze SoftReference objects — cleared before OOM but can accumulate memory |
| `phantom_references_statistics` | Analyze PhantomReference objects used for custom cleanup logic |
| `finalizer_references_statistics` | Analyze objects with finalizers — large counts can delay GC |

## Finalizer Analysis

| Command | Description |
|---------|-------------|
| `finalizer_overview` | Finalizer state overview: queue depth, thread status, pending objects |
| `finalizer_thread` | Finalizer thread's state and stack trace |
| `finalizer_queue` | Objects currently in the finalizer queue waiting to be finalized |
| `finalizer_in_processing` | Object being finalized at the time of the heap dump |
| `finalizer_thread_locals` | Thread-local variables held by the finalizer thread |

## Retained Set

| Command | Description |
|---------|-------------|
| `show_retained_set` | All objects kept alive exclusively by a given object |
| `customized_retained_set` | Retained set with custom parameters (e.g., excluding certain GC roots) |

## Component & Top Consumers

| Command | Description |
|---------|-------------|
| `component_report` | Detailed report for a package/class loader: leaks, duplicate strings, collection waste |
| `component_report_top` | Auto-generate component reports for the top memory-consuming components |
| `top_consumers` | Top memory-consuming objects, classes, and class loaders (text) |
| `top_consumers_html` | HTML report of top consumers with charts and drill-down links |
| `pie_biggest_objects` | Pie chart of the biggest objects by retained size |

## String & Memory Waste

| Command | Description |
|---------|-------------|
| `find_strings` | Search for string objects — useful for finding sensitive data or duplicates |
| `waste_in_char_arrays` | Wasted space in char[] arrays backing String objects |

## Heap Info & Misc

| Command | Description |
|---------|-------------|
| `heap_dump_overview` | Basic heap info: total size, object count, class count, system properties |
| `unreachable_objects` | Objects not reachable from any GC root (garbage not yet collected) |
| `system_properties` | JVM system properties captured in the heap dump |
| `class_references` | Incoming and outgoing references for a specific class or object |
| `comparison_report` | Comparison report between two heap dumps to identify growth patterns |

## Eclipse/OSGi Specific

| Command | Description |
|---------|-------------|
| `bundle_registry` | List all installed OSGi bundles, their states, and dependencies |
| `leaking_bundles` | Detect bundles leaking memory via stale class loader references |

## Export

| Command | Description |
|---------|-------------|
| `export_hprof` | Export a subset of the heap dump to a new HPROF file |
