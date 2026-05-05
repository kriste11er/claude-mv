# claude-mv

**Move directories without orphaning your Claude Code conversation threads.**

Claude Code stores conversation threads in `~/.claude/projects/` keyed by the
absolute path of the directory you ran `claude` from. When you `mv` or rename
that directory, the key no longer matches and Claude can't find your old
sessions. They're not deleted — just orphaned. `claude-mv` fixes this by
moving the directory **and** updating the session storage atomically, so
your conversation history follows the directory.

It also handles a related problem: **memory file migration when reassigning
a session to a different project**, with an interactive prompt and a
safe-by-default flow.

## What it does

- **`claude-mv old new`** — move/rename a directory and update all Claude
  session keys so threads keep working at the new location
- **`claude-mv --reassign <session-uuid> <target-dir>`** — move a single
  conversation to a different project, with an interactive prompt for each
  loaded memory file (move with session / keep at source / copy to both /
  skip)
- **`claude-mv --reconcile`** — find Claude session directories whose
  original filesystem path no longer exists (orphans from past `mv` operations)
- **`claude-mv --list`** — show all your Claude project sessions

Plus quality-of-life:

- **Automatic backup** of the affected `~/.claude/projects/<key>/` dirs to a
  timestamped tarball before any destructive operation. Restore is a single
  `tar -xzf` command.
- **Clipboard auto-copy** of the resume command after a successful operation,
  so you can paste-and-execute into any terminal.
- **Dry-run mode** for any operation (`--dry-run`, `--reassign-dry-run`).
- **Cross-platform** clipboard support: pbcopy (macOS), xclip / xsel (Linux),
  clip.exe (WSL / Windows).

## Why you'd use it

If you've ever:
- Renamed a project folder and lost access to weeks of conversation history
- Reorganized your codebase and watched your Claude session list become a
  graveyard of broken keys
- Wanted to move a single conversation thread to a different project home
- Manually fixed `~/.claude/projects/` directory names because of (1) or (2)

…this tool fixes that class of problem.

## Install

### Manual install

Clone or download this repo, copy `claude-mv` to a directory in your `PATH`,
and make it executable:

```bash
git clone https://github.com/kriste11er/claude-mv.git
cp claude-mv/claude-mv ~/.local/bin/   # or wherever you keep user scripts
chmod +x ~/.local/bin/claude-mv
```

Make sure `~/.local/bin` is in your `PATH`. If not, add to `~/.bashrc` or
`~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Verify:

```bash
claude-mv --help
```

### One-line install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/kriste11er/claude-mv/main/install.sh | bash
```

This downloads the latest `claude-mv`, places it at `~/.local/bin/claude-mv`,
makes it executable, and tells you whether `~/.local/bin` is in your `PATH`.

If you want to inspect the install script first (recommended), download it
explicitly:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/kriste11er/claude-mv/main/install.sh
less install.sh   # read it
bash install.sh
```

## Usage

### Move a directory + keep its Claude threads

```bash
claude-mv old_folder new_folder
```

What happens:
1. Tool computes the old and new Claude session keys (every non-alphanumeric
   character in the absolute path becomes a hyphen, e.g.
   `/Users/me/projects/foo` → `-Users-me-projects-foo`)
2. Lists all matching session directories (the directory itself + any
   subdirectory projects that have their own sessions)
3. Asks "Proceed? [y/N]"
4. After you confirm, creates a backup tarball
5. Moves the directory with `mv`
6. Renames each affected session directory to match the new key
7. Copies the `cd` command for the new path to your clipboard

Preview without changes: `claude-mv --dry-run old new`

### Reassign a single conversation to a different project

```bash
claude-mv --reassign <session-uuid> /path/to/target/project
```

Use this when you want to move a specific thread to a different project home
— for example, you started a thread in your top-level workspace folder but
realize it actually belongs in a sub-project.

#### Quick primer: what are "memory files"?

Claude Code stores per-project memory at
`~/.claude/projects/<encoded-path>/memory/*.md`. Each file has YAML
frontmatter (`name`, `description`, `type`) and a body. They're loaded
into every Claude session that runs inside that project directory.
Common types:
- `feedback` — user preferences ("don't use em-dashes", "default to terse")
- `project` — facts about the codebase, architecture, ongoing work
- `reference` — pointers to external systems (Linear, dashboards, sheets)
- `user` — info about the user themselves

If you've never used Claude Code's memory feature, you may have no memory
files. The `--reassign` flow is a no-op in that case (just moves the
session, no prompts).

#### What happens

1. Tool finds the session JSONL in `~/.claude/projects/<key>/`
2. Discovers all memory files (`*.md`) in the source project's `memory/`
   directory (excluding the `MEMORY.md` index)
3. **For each memory file**, shows you:
   - Filename
   - Frontmatter (`name`, `description`, `type`)
   - First two body lines
   - Prompt: `[M]ove with session (default) / [k]eep at source / [c]opy to both / [s]kip`
4. Press Enter to accept the default (move) for each.
5. Validates no destination collisions, prints the plan, asks "Proceed? [y/N]"
6. After confirming, creates a backup tarball, applies the memory operations,
   moves the session JSONL + session subdirectory, copies the resume command
   to clipboard.

For non-interactive use:
- `--memory-mode prompt` (default) — interactive per file
- `--memory-mode move` — move all without asking
- `--memory-mode copy` — copy all to dest, leave source intact
- `--memory-mode skip` — leave all at source

Preview: `claude-mv --reassign-dry-run [--memory-mode mode] <uuid> <dir>`

#### Tip: search for relevance before deciding move/copy/keep

The default action is "move," which is the right call when the source
project's memories were specifically built up around the session you're
moving. **It's the wrong call when memories are shared across many
sessions** — moving them strips context from the others.

A useful pattern: before running `--reassign`, grep the source memory
dir for keywords related to the session you're moving:

```bash
SRC_KEY="-Users-you-Desktop-old-project"   # encoded source path
grep -rli 'company-name\|key-person' ~/.claude/projects/$SRC_KEY/memory/
```

If only a small subset matches, those are the candidates to **move** or
**copy** with the session — and the rest you can confidently **keep** at
the source. If everything is general-purpose project context, the right
answer is often `--memory-mode skip` (leave it all alone) and rely on
`CLAUDE.md` inheritance + the session's own context to keep the moved
thread oriented.

### Find orphaned sessions

```bash
claude-mv --reconcile [search_root]
```

Scans `~/.claude/projects/` for session directories whose original
filesystem path no longer exists (because someone moved the directory with
plain `mv` instead of `claude-mv`). Tries to suggest possible new locations
by searching `search_root` (defaults to `~/Desktop`).

This is read-only — it tells you what's orphaned and how to fix manually,
it doesn't auto-fix.

### List all Claude sessions

```bash
claude-mv --list
```

Shows every project key under `~/.claude/projects/`, the number of session
JSONLs in it, and whether it has a `memory/` directory.

### Help

```bash
claude-mv --help
```

Full reference for all flags and behavior.

## Caveats

Two things to know before you run a move:

### Don't run `claude-mv` from a Claude session whose own directory is being moved

Run it from a regular terminal, or from a different Claude thread. Moving
the cwd out from under a running session breaks that session — the shell
the running Claude started in will end up pointing at a directory that no
longer exists at the old path.

### Restart any actively-running Claude session in the moved directory

Even if you ran `claude-mv` from a different terminal, any **live** Claude
process inside the moved directory is still pointing at the old encoded
path in memory. The on-disk state moves correctly, but the running process
won't see appended messages there until you exit and re-enter. The
auto-copied resume / cd command (already in your clipboard after a
successful operation) makes the re-entry one paste away.

### Use `claude --resume <uuid>` after a move, not plain `claude`

After moving a directory, if you `cd` into the new location and run plain
`claude`, you get a **new** session. The old session's history is there
on disk (we moved it), but Claude doesn't auto-pick-up old sessions when
you start fresh. To re-enter the old conversation, use
`claude --resume <session-uuid>`. The clipboard auto-copy gives you the
exact command after every successful move/reassign.

You can also list available sessions in the new location with
`claude --list` if you need to find a UUID by hand.

### External references aren't auto-updated

`claude-mv` updates everything inside `~/.claude/`, but anything **outside**
that directory which hardcodes the old path is on you to fix. After a
significant move, grep for the old path in the usual suspects:

```bash
grep -rn 'old/path/' ~/.bashrc ~/.zshrc ~/.bash_profile ~/.config 2>/dev/null
```

Common offenders:
- shell aliases and functions in `~/.bashrc` / `~/.zshrc`
- `cron` and `launchd` job paths
- IDE / editor config (VSCode workspace files, JetBrains projects)
- Scripts in your dotfiles that hardcode project paths
- Symlinks pointing into the moved tree (re-create them, or use `find -L`)

### No `--undo` command (yet)

To reverse a move, just run `claude-mv` in the opposite direction:

```bash
claude-mv new_path old_path
```

If you want to roll back fully (including the JSONL path-rewrite),
extract the auto-created backup tarball:

```bash
tar -xzf ~/.claude/claude-mv-backups/YYYY-MM-DD-HHMMSS-<op>.tar.gz -C /
```

…and then `mv new_path old_path` to restore the filesystem side. The
backup is the more accurate undo (it restores embedded paths inside
JSONLs to their pre-rewrite state).

### Don't run two `claude-mv` operations in parallel

The tool isn't built to be safe under concurrent invocation. Two moves
running at once could leave the Claude state directories in a half-renamed
state, with neither completing cleanly. Wait for one to finish before
starting another.

## What `claude-mv` updates when you move a directory

When you move a directory, `claude-mv` walks **all** of these per-project
state subdirectories under `~/.claude/`, not just `projects/`:

| Subdir | What it stores |
|--------|----------------|
| `projects/<key>/` | conversation history (sessions, memory) |
| `file-history/<key>/` | Claude Code's file-edit history |
| `todos/<key>/` | TaskCreate/TaskUpdate task lists |
| `shell-snapshots/<key>/` | shell session snapshots |
| `debug/<key>/` | debug logs |

Plus it rewrites embedded absolute paths inside session JSONLs and inside
`~/.claude/history.jsonl` (with a `.backup` file as a safety net) so
resumed sessions display the new path consistently in their history.

If only `projects/` got renamed and the others didn't follow (this was a
common bug in earlier directory-move scripts), Claude Code would silently
lose your file-edit history, task lists, and shell snapshots for the moved
project. `claude-mv` keeps all of it together.

## Safety: backups before any destructive operation

Every move, reassign, and rename automatically creates a tarball backup of
the affected state across all 5 subdirs (and `history.jsonl`) at:

```
~/.claude/claude-mv-backups/YYYY-MM-DD-HHMMSS-<op>.tar.gz
```

Created **after** you confirm `Proceed?` but **before** any actual
`mv`/`cp`/`rm`. The backup path and a one-line restore command print inline:

```
💾 Backup: ~/.claude/claude-mv-backups/2026-04-09-203936-reassign.tar.gz (517KB)
   Restore: tar -xzf ~/.claude/claude-mv-backups/2026-04-09-203936-reassign.tar.gz -C /
```

To restore, just run that command. The tarball stores paths relative to `/`,
so `tar -xzf <backup> -C /` puts everything back where it came from.

To list backups: `ls -lh ~/.claude/claude-mv-backups/`

To opt out (not recommended): pass `--no-backup` as a global flag.

Dry runs (`--dry-run`, `--reassign-dry-run`) never create backups.

### Pruning old backups

`claude-mv` never auto-deletes backups. The directory grows unboundedly
with each operation. After heavy use, you may want to prune.

Manual one-shot:

```bash
# Delete claude-mv backups older than 30 days
find ~/.claude/claude-mv-backups -name "*.tar.gz" -mtime +30 -delete

# Or keep only the 20 most recent
ls -t ~/.claude/claude-mv-backups/*.tar.gz | tail -n +21 | xargs rm -f
```

Set it on a schedule with cron / launchd if you want this to run
automatically. There's deliberately no built-in pruning — the tool
shouldn't delete backups you might still want.

## Backing up your Claude state

`claude-mv`'s built-in backup is **transactional** — one tarball per
operation, designed for "undo my last move." That's the right scope for
this tool.

But your `~/.claude/` directory contains a lot of valuable state beyond what
`claude-mv` touches: every session in every project you've ever opened with
Claude Code, every memory file, every CLAUDE.md you've configured, settings,
hooks, statusline scripts, and so on. **None of that is backed up by
`claude-mv` automatically.**

If you'd be sad to lose it, set up a separate periodic backup. Options
ranked by setup effort:

### Easy: rsync to Dropbox / iCloud / OneDrive (cloud sync)

Add a periodic rsync to a synced folder. Cron entry on macOS or Linux:

```bash
# Hourly snapshot to a Dropbox folder
0 * * * * rsync -a --delete ~/.claude/ ~/Dropbox/backups/claude-state/
```

Or use `launchd` on macOS (more reliable than cron). The synced folder
takes care of off-machine backup.

### More polished: restic or borg

Both are content-addressed dedup backup tools. Set them up to back
`~/.claude/` to a local external drive, NAS, or cloud target (S3,
Backblaze B2, etc.). They handle versioning, deduplication, and
encryption.

```bash
# restic example, daily snapshot
0 2 * * * restic -r /path/to/backup/repo backup ~/.claude
```

### Built-in: macOS Time Machine

If you're on macOS and Time Machine is enabled, `~/.claude/` is already
being backed up hourly to whatever drive you've designated. Verify:

```bash
tmutil isexcluded ~/.claude    # should print "Not excluded"
```

### What NOT to do

- **Don't** put `~/.claude/` under git. The session JSONLs are large,
  growing, frequently rewritten, and contain conversation content that
  may be sensitive. Wrong tool for this data.
- **Don't** rely solely on `claude-mv` backups for disaster recovery.
  Those tarballs only cover what was about to be moved, not your full
  state.

## Requirements

- **bash** 4.0+ (modern macOS, all Linux distros)
- **Standard Unix tools**: `find`, `grep`, `sed`, `awk`, `mktemp`, `tar`,
  `gzip` — present on every Unix-like system
- **Optional**: a clipboard tool for the auto-copy feature
  - macOS: `pbcopy` (built in)
  - Linux: `xclip` or `xsel`
  - WSL / Windows: `clip.exe`

  If none are installed, the operations still succeed but the resume command
  isn't copied automatically (you'll see it printed instead).

- **Claude Code installed** (this tool only makes sense if you use Claude Code)

## How the path-to-key encoding works

Claude Code uses a simple deterministic encoding: every non-alphanumeric
character in the absolute path becomes a hyphen. No collapsing of consecutive
hyphens.

```
/Users/me/projects/my-app           → -Users-me-projects-my-app
/Users/me/Desktop/_work/foo bar     → -Users-me-Desktop--work-foo-bar
/home/alice/projects/foo.bar        → -home-alice-projects-foo-bar
```

This is what makes the tool able to compute the new key from the new path
deterministically. If Claude ever changes this encoding, this tool will need
an update.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

This tool was co-developed with [Claude](https://claude.com) (Anthropic) in
[Claude Code](https://docs.claude.com/en/docs/claude-code) sessions. Jaguar
Kristeller directed the design, made all decisions, and tested every change
on real workspaces (including the bug where moving a session between projects
silently lost its loaded memories — which is what motivated the
`--reassign --memory-mode` interactive flow). Claude generated most of the
code under that direction, including the helper functions, error handling,
and cross-platform clipboard support.

**Inspiration & prior art:** The five-subdirectory handling
(`projects`, `file-history`, `todos`, `shell-snapshots`, `debug`) and the
embedded-path-rewrite-in-JSONLs technique were inspired by
[curiouslychase/dotfiles](https://github.com/curiouslychase/dotfiles)'s
`scripts/claude-mv` — a smaller solo-developer script that solves a related
problem. Their tool focuses on directory moves; ours adds session reassign,
memory file migration, automatic backups, clipboard auto-copy, dry-runs,
reconcile, and a few other features. Worth a look if you want a smaller
single-file tool with just the move-rename functionality.

If you're curious about the development process, the entire conversation
history that produced this tool is preserved in Jaguar's private workspace,
not just the final commits. Most of the design decisions documented in the
code comments came out of back-and-forth in those sessions.

## Contributing

Issues and pull requests welcome. This is a small, focused tool — not
trying to grow into a swiss-army-knife. Fixes for edge cases, support for
additional clipboard tools, and platform compatibility improvements are
especially appreciated.

If you hit a bug, please include:
- Output of `claude-mv --list`
- Output of `bash --version`
- Your OS (macOS version / Linux distro)
- The exact command that misbehaved (with paths if possible)
