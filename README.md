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
git clone https://github.com/<user>/claude-mv.git
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
curl -fsSL https://raw.githubusercontent.com/<user>/claude-mv/main/install.sh | bash
```

This downloads the latest `claude-mv`, places it at `~/.local/bin/claude-mv`,
makes it executable, and tells you whether `~/.local/bin` is in your `PATH`.

If you want to inspect the install script first (recommended), download it
explicitly:

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/<user>/claude-mv/main/install.sh
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

What happens:
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

## Safety: backups before any destructive operation

Every move, reassign, and rename automatically creates a tarball backup of
the affected `~/.claude/projects/<key>/` directories at:

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
