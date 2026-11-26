#!/usr/bin/env python3
"""Bring new commits of the original repo (HardDie/My_linux_settings) into this layout.

    python3 tools/sync_upstream.py --list    show the new upstream commits and where
                                             their files go here
    python3 tools/sync_upstream.py           apply them, one commit each (git am -3,
                                             author and message kept)

The original repo uses the old stow layout (zsh/dot-zshrc, sway/sway/config, ...).
Each upstream patch is rewritten to the new paths (MAP below) and applied. Files
that have no place here any more (old scripts, termite, fonts ...) are skipped and
listed. The last synced upstream commit is kept in .upstream-sync.

On a conflict: fix the files, `git add` them, `git am --continue`, then run
    python3 tools/sync_upstream.py --done   (records that commit, goes on)
or skip it: `git am --skip`, then --done as well.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARK = os.path.join(ROOT, ".upstream-sync")
URL = "https://github.com/HardDie/My_linux_settings.git"
BRANCH = "upstream/master"

# old path prefix -> new path prefix (longest match wins)
MAP = {
    "zsh/dot-zshrc": "common/zsh/.zshrc",
    "oh-my-zsh/zsh/oh-my-zsh/themes/": "common/zsh/.config/zsh/themes/",
    "tmux/dot-tmux.conf": "common/tmux/.tmux.conf",
    "tmux-theme/tmux/": "common/tmux/.config/tmux/",
    "vim/dot-vimrc": "common/vim/.vimrc",
    "vim/dot-vim/": "common/vim/.vim/",
    "git/dot-gitconfig": "common/git/.gitconfig",
    "alacritty/alacritty/": "common/alacritty/.config/alacritty/",
    "clang-format/dot-clang-format": "common/clang-format/.clang-format",
    "sway/sway/config": "wayland/sway/.config/sway/config",
    "mako/mako/": "wayland/mako/.config/mako/",
    "i3/i3/config": "i3/i3/.config/i3/config",
    "dunst/dunst/": "i3/dunst/.config/dunst/",
    "docker/docker/": "linux/docker/.config/docker/",
    "ncmpcpp/dot-ncmpcpp/": "linux/ncmpcpp/.ncmpcpp/",
    "my_scripts/dot-my_scripts/docker_images/update.sh": "docker/update.sh",
    "my_scripts/dot-my_scripts/docker_images/": "docker/images/",
}


def git(*args, check=True, **kw):
    r = subprocess.run(["git", "-C", ROOT, *args], text=True, capture_output=True, **kw)
    if check and r.returncode:
        sys.exit(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def new_path(old):
    for prefix in sorted(MAP, key=len, reverse=True):
        if old == prefix or (prefix.endswith("/") and old.startswith(prefix)):
            return MAP[prefix] + old[len(prefix):]
    return None


def rewrite(patch):
    """patch text with new paths; returns (patch, kept files, skipped files)"""
    files, kept, skipped = re.findall(r"^diff --git a/(\S+) b/(\S+)$", patch, re.M), [], []
    exists = set(git("ls-files").split("\n"))
    creates = set(re.findall(r"^diff --git a/\S+ b/(\S+)\n(?:new file mode|similarity)", patch, re.M))
    for a, b in files:
        na, nb = new_path(a), new_path(b)
        # a file that has a place here and still exists (or is new upstream)
        if nb and (na in exists or b in creates):
            kept.append((a, b, na, nb))
        else:
            skipped.append(b)

    def sub(m):
        path = m.group(2)
        n = new_path(path)
        return m.group(1) + (n or path)

    out = re.sub(r"^(diff --git a/)(\S+)", sub, patch, flags=re.M)
    out = re.sub(r"^(diff --git a/\S+ b/)(\S+)", sub, out, flags=re.M)
    out = re.sub(r"^(--- a/|\+\+\+ b/|rename from |rename to |copy from |copy to )(\S+)", sub, out, flags=re.M)
    return out, kept, skipped


def excludes(skipped):
    """--exclude for skipped files (their old path, or new path if they map)"""
    return [f"--exclude={new_path(s) or s}" for s in skipped]


def base():
    if not os.path.exists(MARK):
        sys.exit(f"missing {MARK} (the last upstream commit already in this repo)")
    return open(MARK).read().split()[0]


def record(rev):
    with open(MARK, "w") as f:
        f.write(f"{rev}\n# last commit of {URL} that is in this repo (tools/sync_upstream.py)\n")
    git("add", MARK)


def main():
    args = sys.argv[1:]
    if "-h" in args or "--help" in args:
        print(__doc__)
        return
    if "upstream" not in git("remote").split():
        git("remote", "add", "upstream", URL)
    git("fetch", "-q", "upstream")

    if "--done" in args:
        # after a conflict: the commit git am just finished
        pending = git("rev-list", "--reverse", "--no-merges", f"{base()}..{BRANCH}").split()
        if not pending:
            print("nothing pending")
            return
        record(pending[0])
        git("commit", "-q", "--amend", "--no-edit")
        print(f"recorded {pending[0][:9]}; run again for the rest")
        return

    if os.path.isdir(os.path.join(ROOT, ".git", "rebase-apply")):
        sys.exit("a git am is in progress: finish it (git am --continue / --skip), then --done")

    commits = git("rev-list", "--reverse", "--no-merges", f"{base()}..{BRANCH}").split()
    if not commits:
        print(f"up to date with {BRANCH} ({base()[:9]})")
        return
    if "--list" not in args and git("status", "--porcelain", "--untracked-files=no").strip():
        sys.exit("commit or stash your changes first")

    for c in commits:
        title = git("log", "-1", "--format=%h %s", c).strip()
        patch, kept, skipped = rewrite(git("format-patch", "-1", "--stdout", c))
        print(f"\n{title}")
        for a, b, na, nb in kept:
            print(f"  {b}  ->  {nb}")
        for s in skipped:
            print(f"  {s}  (skipped: no place for it here)")
        if "--list" in args:
            continue
        if not kept:
            record(c)
            git("commit", "-q", "-m", f"upstream sync: skip {title} (nothing for this layout)")
            continue
        r = subprocess.run(["git", "-C", ROOT, "am", "-3", "--keep-cr", *excludes(skipped)],
                           input=patch, text=True, capture_output=True)
        if r.returncode:
            print(r.stdout + r.stderr)
            sys.exit("conflict: fix it, git add, git am --continue, then: "
                     "python3 tools/sync_upstream.py --done")
        record(c)
        git("commit", "-q", "--amend", "--no-edit")
    if "--list" not in args:
        print(f"\nsynced to {commits[-1][:9]}")


if __name__ == "__main__":
    main()
