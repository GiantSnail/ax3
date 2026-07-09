# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ax3 is an AS3-to-Haxe source converter by InnoGames, written in Haxe 4 and compiled to a JVM jar (`converter.jar`). It is structured like a compiler: parse → type → rewrite → generate, preserving comments/whitespace in the output.

## Commands

```bash
# One-time setup (dependencies are managed by Lix, pinned via .haxerc / haxe_libraries/)
npm i lix
npx lix download

# Build converter.jar (NOTE: build.hxml's last -cmd also runs the converter
# against config-local.json, so a build doubles as a smoke test)
npx haxe build.hxml

# Run a conversion
java -jar converter.jar path/to/config.json

# Run a conversion without Java installed (eval interpreter, fine for dev/testing)
npx haxe -cp src -lib format --run ax3.Main path/to/config.json

# Quick end-to-end smoke test (small AS3 sources, no SWC needed; output in test-fixture/out)
npx haxe -cp src -lib format --run ax3.Main test-fixture/config.json

# Run compat-layer unit tests (utest; first target compiles to JS and runs
# under node, the --next second target builds test.swf)
npx haxe test-compat.hxml
```

There is no per-test runner: tests are utest suites registered in `compat-test/Main.hx` (`TestASAny`, `TestXML`, `TestASCompat`, `TestASDictionary`). To narrow a run, temporarily remove suites from that list.

The converter config JSON schema is the `Config` typedef in `src/ax3/Context.hx` (`src`, `swc`, `hxout`, `skipFiles`, `haxeTypes`, `rootImports`, `settings`, ...). `config-local.json` is the local dev config.

## Architecture

The pipeline is orchestrated by `ax3.Main.main()` (`src/ax3/Main.hx`), five phases with distinct data structures:

1. **Scan/Parse** — `Scanner.hx` produces tokens carrying lead/trail *trivia* (comments, whitespace); `Parser.hx` (recursive descent) builds the untyped `ParseTree.hx`. Trivia is carried through the whole pipeline so generated Haxe preserves comments and formatting.
2. **SWC loading** — `SWCLoader.hx` reads ABC bytecode from SWC libraries (via the `format` haxelib, the only dependency) and registers extern signature-only declarations in the `TypedTree`.
3. **Typing** — `Typer.hx` + `ExprTyper.hx` turn the ParseTree into `TypedTree.hx`, where every expression has both `type` and `expectedType`. Typing runs in three deferred-closure queues: `importSetups` → `structureSetups` (inheritance/signatures) → `exprTypings` (bodies), so symbols are all registered before resolution.
4. **Filters** — the heart of the tool. ~50 small AST rewriters in `src/ax3/filters/`, each extending `AbstractFilter` and overriding `processExpr`. They run sequentially in the exact order listed in `Filters.hx` — **order matters**; new filters must be inserted thoughtfully into that list. Each filter does one AS3→Haxe adaptation (e.g. `RewriteE4X`, `RewriteForIn`, `CoerceToBool`, `HaxeProperties`, `RestArgs`).
5. **Codegen** — `GenHaxe.hx` prints the rewritten TypedTree to `.hx` files (one per module, package dirs mirrored) plus a top-level `import.hx` collecting compat imports/usings.

Unresolvable AS3 types fall back to `TTAny`, which maps to the `ASAny` compat abstract in output.

### compat/ — the runtime support library

`compat/` (`ASAny`, `ASCompat`, `ASDictionary`, `ASObject`, `ASFunction`, ...) is what converted code links against; it is the haxelib's `classPath`, tested by `compat-test/` against both JS (node + openfl with `--remap flash:openfl`) and SWF targets. Changes to filters that emit `ASCompat.*` calls usually require corresponding compat-layer support.

### Error handling

`Context.reportError(path, pos, msg)` prints `path:line:char: msg` to stderr without aborting; hard failures throw. Per-phase timings print to stdout at the end of every run.

## Debugging aids (commented-out hooks)

- `Main.parseFile`: uncomment `ParseTreeDump.printFile(...)` to dump parse trees.
- `Main.main`: uncomment `sys.io.File.saveContent("structure.txt", tree.dump())` to dump the full TypedTree.
- `Filters.hx`: `CheckExpectedTypes` (commented out in the list) reports every `type`/`expectedType` mismatch; `CheckUntypedMethodCalls` (enabled) warns about untyped calls.
- `build.hxml`: uncomment `--macro nullSafety("ax3")` for null-safety checking.

## Known limitations (from README)

- The parser does not support ASI; semicolons may only be omitted for the last expression of a block.
- Only a small, commonly used subset of E4X is supported — rewrite unsupported constructs in the AS3 sources before converting.
