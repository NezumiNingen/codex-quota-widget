#!/bin/zsh
set -euo pipefail
widget_dir="${0:A:h}"
cd "$widget_dir/macos-app"
swift run -c release CodexQuotaWidget
