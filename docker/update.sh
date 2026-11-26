#!/bin/bash
#
# Update all Docker images on this machine (the images in docker/images/ plus the
# registry images you use). Also installed as `docker-images-update`.
#
#   update.sh               update now: the images you have built + registry images
#   update.sh --auto        same, but only if the last update is older than 7 days
#                           (used by the docker-update.timer, see below)
#   update.sh --list        show what would be updated, in order, and exit
#   update.sh NAME...       only these images from this folder (and their parents)
#   update.sh --all         build every image in this folder, also ones never built
#   update.sh --keep        keep the previous version of each image as NAME:prev
#
# What it does
#   1. Finds every folder in images/ with a Dockerfile and reads its FROM lines, so parents
#      are always built before children (archlinux -> my/base -> my/firefox_bare ...).
#      Only images you have already built are updated (unless --all / NAME).
#   2. archlinux: pulls archlinux:latest, then rebuilds it without cache (pacman -Syu,
#      your mirrorlist). my/base: rebuilt without cache. Everything below them is
#      rebuilt on the new parent, so all images get the new packages.
#   3. If a build fails, its children are skipped and the old image stays usable.
#   4. Pulls registry images you use (postgres ...) and rebuilds claude-local's image.
#   5. Removes the replaced old image layers and build cache older than a week.
#   6. Tells you which running containers still use an old image (restart them).
#
# Build context: the image folder. A Dockerfile with the line "# build-context: repo"
# is built from the root of the dotfiles instead (nvim-cpp uses common/nvim).
#
# Automatic updates (systemd user timer, linux/systemd, set up by install.sh):
#   systemctl --user enable --now docker-update.timer
#   Checks daily, updates when the last one is older than 7 days, only on AC power,
#   at low CPU/disk priority. Log: journalctl --user -u docker-update

set -uo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
IMAGES=$HERE/images
REPO=$(dirname "$HERE")
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/docker-update"
STAMP="$STATE/last-success"
INTERVAL_DAYS="${DOCKER_UPDATE_DAYS:-7}"

AUTO=0 LIST=0 ALL=0 KEEP=0
ONLY=()
for a in "$@"; do
	case $a in
	--auto) AUTO=1 ;;
	--list | -n) LIST=1 ;;
	--all) ALL=1 ;;
	--keep) KEEP=1 ;;
	-h | --help) sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
	-*) echo "unknown option $a (see --help)" >&2; exit 2 ;;
	*) ONLY+=("${a%/}") ;;
	esac
done

say() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33mwarning:\e[0m %s\n' "$*" >&2; }
notify() { command -v notify-send >/dev/null && notify-send -a "Docker update" "$@" 2>/dev/null; true; }

# ----------------------------------------------------------------- checks
mkdir -p "$STATE"
exec 9>"$STATE/lock"
flock -n 9 || { echo "another update is already running"; exit 0; }

if (( AUTO )) && [[ -f $STAMP ]]; then
	age_days=$(( ($(date +%s) - $(stat -c %Y "$STAMP")) / 86400 ))
	if (( age_days < INTERVAL_DAYS )); then
		echo "last update $age_days day(s) ago, next after $INTERVAL_DAYS days: nothing to do"
		exit 0
	fi
fi

if ! docker info >/dev/null 2>&1; then
	echo "Docker is not running, or you are not in the docker group" >&2
	exit 1
fi

if (( ! LIST )) && [[ $(curl -s -o /dev/null -w '%{http_code}' -m 10 https://registry-1.docker.io/v2/) == 000 ]]; then
	echo "no internet connection: skipping (the timer tries again tomorrow)"
	exit 0
fi

# ----------------------------------------------------------------- discover images
# image name for a folder: archlinux/ -> archlinux:latest, X/ -> my/X
image_of() { [[ $1 == archlinux ]] && echo "archlinux:latest" || echo "my/$1"; }
exists() { docker image inspect "$1" >/dev/null 2>&1; }

declare -A PARENTS # folder -> folders it is built FROM
DIRS=()
for f in "$IMAGES"/*/Dockerfile; do
	d=$(basename "$(dirname "$f")")
	DIRS+=("$d")
	deps=""
	while read -r _ from _; do
		case $from in
		my/*) p=${from#my/}; p=${p%%:*} ;;
		archlinux | archlinux:latest) p=archlinux ;;
		*) continue ;;
		esac
		[[ $p != "$d" && -f $IMAGES/$p/Dockerfile && " $deps " != *" $p "* ]] && deps+=" $p"
	done < <(grep -iE '^[[:space:]]*FROM[[:space:]]' "$f")
	PARENTS[$d]=${deps# }
done

# which folders to build
declare -A WANT
add_with_parents() {
	local d=$1 p
	[[ -n ${WANT[$d]:-} ]] && return
	WANT[$d]=1
	for p in ${PARENTS[$d]:-}; do add_with_parents "$p"; done
}
if (( ${#ONLY[@]} )); then
	for d in "${ONLY[@]}"; do
		[[ -f $IMAGES/$d/Dockerfile ]] || { echo "no Dockerfile in $IMAGES/$d" >&2; exit 2; }
		add_with_parents "$d"
	done
else
	for d in "${DIRS[@]}"; do
		if (( ALL )) || exists "$(image_of "$d")"; then
			add_with_parents "$d"
		fi
	done
fi

# order: parents first
ORDER=()
declare -A PLACED
while (( ${#ORDER[@]} < ${#WANT[@]} )); do
	progress=0
	for d in "${DIRS[@]}"; do
		[[ -n ${WANT[$d]:-} && -z ${PLACED[$d]:-} ]] || continue
		ready=1
		for p in ${PARENTS[$d]:-}; do [[ -n ${WANT[$p]:-} && -z ${PLACED[$p]:-} ]] && ready=0; done
		if (( ready )); then ORDER+=("$d"); PLACED[$d]=1; progress=1; fi
	done
	(( progress )) || { echo "circular FROM between images, giving up" >&2; exit 1; }
done

# registry images in use (pulled, not built here): they have a repo digest.
# Not when only some images were asked for.
REGISTRY=()
(( ${#ONLY[@]} )) || while read -r ref; do
	[[ $ref == *"<none>"* || $ref == my/* || $ref == archlinux:* || $ref == *:prev || $ref == *:old ]] && continue
	[[ $(docker image inspect -f '{{len .RepoDigests}}' "$ref" 2>/dev/null) -gt 0 ]] && REGISTRY+=("$ref")
done < <(docker image ls --format '{{.Repository}}:{{.Tag}}' | sort -u)

CLAUDE_IMAGE="${CLAUDE_LOCAL_IMAGE:-localai/claude-code-offline}"
CLAUDE=0
command -v claude-local >/dev/null && exists "$CLAUDE_IMAGE" && (( ! ${#ONLY[@]} )) && CLAUDE=1

if (( LIST )); then
	echo "Build, in this order:"
	for d in "${ORDER[@]}"; do printf '  %-22s %s\n' "$(image_of "$d")" "${PARENTS[$d]:+(from ${PARENTS[$d]})}"; done
	(( ${#REGISTRY[@]} )) && { echo "Pull:"; printf '  %s\n' "${REGISTRY[@]}"; }
	(( CLAUDE )) && echo "Rebuild: $CLAUDE_IMAGE (claude-local build)"
	exit 0
fi

# ----------------------------------------------------------------- build
start=$SECONDS
OK=() FAILED=() SKIPPED=()
declare -A BAD

build() { # folder
	local d=$1 img
	img=$(image_of "$d")
	(( KEEP )) && exists "$img" && docker image tag "$img" "${img%%:*}:prev"
	case $d in
	archlinux)
		docker pull -q archlinux:latest >/dev/null &&
			{ [[ -r /etc/pacman.d/mirrorlist ]] && cp /etc/pacman.d/mirrorlist "$IMAGES/archlinux/" || true; } &&
			docker build --no-cache -t archlinux:latest "$IMAGES/archlinux"
		;;
	base)
		docker build --no-cache --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" \
			-t my/base "$IMAGES/base"
		;;
	*)
		if grep -q '^# build-context: repo' "$IMAGES/$d/Dockerfile"; then
			docker build -t "$img" -f "$IMAGES/$d/Dockerfile" "$REPO"
		else
			docker build -t "$img" "$IMAGES/$d"
		fi
		;;
	esac
}

for d in "${ORDER[@]}"; do
	img=$(image_of "$d")
	skip=""
	for p in ${PARENTS[$d]:-}; do [[ -n ${BAD[$p]:-} ]] && skip=$p; done
	if [[ -n $skip ]]; then
		warn "$img skipped: its parent $(image_of "$skip") failed (old $img still works)"
		SKIPPED+=("$img"); BAD[$d]=1
		continue
	fi
	say "building $img"
	if build "$d"; then
		OK+=("$img")
	else
		warn "$img failed (the old image is still there)"
		FAILED+=("$img"); BAD[$d]=1
	fi
done

for ref in "${REGISTRY[@]}"; do
	say "pulling $ref"
	if docker pull -q "$ref" >/dev/null; then OK+=("$ref"); else warn "pull $ref failed"; FAILED+=("$ref"); fi
done

if (( CLAUDE )); then
	say "rebuilding $CLAUDE_IMAGE"
	if claude-local build; then OK+=("$CLAUDE_IMAGE"); else FAILED+=("$CLAUDE_IMAGE"); fi
fi

# ----------------------------------------------------------------- clean up
say "removing replaced image layers and old build cache"
docker image prune -f >/dev/null
docker builder prune -f --filter until=168h >/dev/null 2>&1

# running containers that still use an old image
OUTDATED=()
while read -r name image_ref image_id; do
	new_id=$(docker image inspect -f '{{.Id}}' "$image_ref" 2>/dev/null) || continue
	[[ $new_id != "$image_id" ]] && OUTDATED+=("$name")
done < <(docker ps --format '{{.Names}} {{.Image}}' | while read -r n i; do
	echo "$n $i $(docker inspect -f '{{.Image}}' "$n" 2>/dev/null)"
done)

# ----------------------------------------------------------------- report
mins=$(( (SECONDS - start + 59) / 60 ))
echo
say "updated ${#OK[@]} image(s) in ${mins} min"
(( ${#FAILED[@]} )) && warn "failed: ${FAILED[*]}"
(( ${#SKIPPED[@]} )) && warn "skipped: ${SKIPPED[*]}"
(( ${#OUTDATED[@]} )) && echo "Restart to use the new version: ${OUTDATED[*]}"
df -h /var/lib/docker 2>/dev/null | awk 'NR==2 {print "Disk: " $4 " free on " $6}'

body="${#OK[@]} updated in ${mins} min"
(( ${#OUTDATED[@]} )) && body+=$'\n'"Restart: ${OUTDATED[*]}"
if (( ${#FAILED[@]} + ${#SKIPPED[@]} )); then
	notify -u critical "Docker update: problems" "$body"$'\n'"Failed: ${FAILED[*]} ${SKIPPED[*]}"$'\n'"journalctl --user -u docker-update"
	exit 1
fi
touch "$STAMP"
notify "Docker images updated" "$body"
exit 0
