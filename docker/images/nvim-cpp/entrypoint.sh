#!/bin/bash
#
# Container start: find the local AI servers, set up OpenCode, then run the
# command (default: nvim).
#
# With arch-local-ai on the host (mounted read-only by `nvimcpp`):
#   ~/.config/localai/localai.conf  -> FIM_PORT / ROUTER_PORT
#   ~/.config/opencode/             -> your OpenCode config, agents and /test /build ...
#   ~/.local/bin/cpp-report         -> used by those commands
#   /run/localai-ctl/ctl.sock       -> `localai ...` runs on the host (localai-ctl.service)
#
# Overrides (environment, e.g. ~/.config/docker/localai.env on the host):
#   LOCALAI_URL         router / OpenAI-compatible endpoint  (default http://127.0.0.1:ROUTER_PORT)
#   LOCALAI_FIM_URL     llama.cpp FIM server for llama.vim    (default http://127.0.0.1:FIM_PORT)
#   LOCALAI_CHAT_MODEL  default model when no OpenCode config is mounted (default qwen-agent)
#   LOCALAI_API_KEY     only if the server needs a key

# --- ports from the host's localai.conf --------------------------------------
fim_port=8012 router_port=8080
conf="$HOME/.config/localai/localai.conf"
if [[ -r $conf ]]; then
	read -r fim_port router_port < <(
		FIM_PORT=8012 ROUTER_PORT=8080
		# shellcheck source=/dev/null
		. "$conf" >/dev/null 2>&1
		echo "$FIM_PORT $ROUTER_PORT"
	)
fi

strip() { local u=${1%/}; echo "${u%/v1}"; }
LOCALAI_URL=$(strip "${LOCALAI_URL:-http://127.0.0.1:$router_port}")
LOCALAI_FIM_URL=$(strip "${LOCALAI_FIM_URL:-http://127.0.0.1:$fim_port}")
: "${LOCALAI_CHAT_MODEL:=qwen-agent}"
: "${LOCALAI_API_KEY:=sk-local}"
export LOCALAI_URL LOCALAI_FIM_URL LOCALAI_CHAT_MODEL LOCALAI_API_KEY

up() { [[ $(curl -s -o /dev/null -w '%{http_code}' -m 2 "$1/health") == 200 ]]; }
problems=0
up "$LOCALAI_FIM_URL" || { echo "autocomplete server not answering: $LOCALAI_FIM_URL" >&2; problems=1; }
up "$LOCALAI_URL" || { echo "router (OpenCode) not answering:    $LOCALAI_URL" >&2; problems=1; }
if (( problems )); then
	if [[ -S /run/localai-ctl/ctl.sock ]]; then
		echo "  start them with: localai start   (or <leader>as in Neovim)" >&2
	else
		echo "  no control socket: on the host run  systemctl --user enable --now localai-ctl" >&2
	fi
fi

# --- OpenCode ------------------------------------------------------------------
dir="$HOME/.config/opencode"
major=$(opencode --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [[ -e $dir/opencode.jsonc || -e $dir/opencode.json ]]; then
	# your own config (mounted from the host): use it as it is
	if [[ -e $dir/opencode.jsonc ]] && grep -q '"providers"' "$dir/opencode.jsonc" && (( ${major:-2} < 2 )); then
		echo "OpenCode $major.x in the image, but your config uses the v2 format: rebuild the image" >&2
		problems=1
	fi
else
	# no config mounted: write one for the router's models (format of the installed version)
	mapfile -t models < <(curl -fsS -m 3 -H "Authorization: Bearer $LOCALAI_API_KEY" \
		"$LOCALAI_URL/v1/models" 2>/dev/null | jq -r '.data[].id' 2>/dev/null)
	[[ " ${models[*]} " == *" $LOCALAI_CHAT_MODEL "* ]] || models+=("$LOCALAI_CHAT_MODEL")
	mkdir -p "$dir"
	if (( ${major:-2} >= 2 )); then
		jq -n --arg url "$LOCALAI_URL/v1" --arg model "local/$LOCALAI_CHAT_MODEL" '{
			"$schema": "https://opencode.ai/config.json",
			providers: { local: {
				name: "Local (llama.cpp)",
				env: ["LOCALAI_API_KEY"],
				package: "@opencode/ai/providers/openai-compatible",
				settings: { baseURL: $url },
				models: ($ARGS.positional | map({ key: ., value: { name: . } }) | from_entries)
			} },
			model: $model
		}' --args "${models[@]}" >"$dir/opencode.jsonc"
	else
		jq -n --arg url "$LOCALAI_URL/v1" --arg model "local/$LOCALAI_CHAT_MODEL" '{
			"$schema": "https://opencode.ai/config.json",
			provider: { local: {
				npm: "@ai-sdk/openai-compatible",
				name: "Local (llama.cpp)",
				options: { baseURL: $url, apiKey: "{env:LOCALAI_API_KEY}" },
				models: ($ARGS.positional | map({ key: ., value: { name: . } }) | from_entries)
			} },
			model: $model
		}' --args "${models[@]}" >"$dir/opencode.json"
	fi
fi

(( problems )) && sleep 3
exec "$@"
