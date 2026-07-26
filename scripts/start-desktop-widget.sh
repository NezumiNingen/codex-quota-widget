#!/bin/zsh
set -euo pipefail
plugin_dir="${0:A:h:h}"
cd "$plugin_dir/macos-app"
swift run -c release CodexQuotaDesktop
