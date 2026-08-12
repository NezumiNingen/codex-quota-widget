# Desktop widgets

- `quota-widget/`: the original quota ring bubble. Run `start.sh` to start only this widget.
- `usage-widget/`: the separate usage insights strip. Run `start.sh` to start only this widget.

Each widget has its own Swift package and executable. The live sync scripts stay in the repository-level `scripts/` folder because they provide shared read-only data to both widgets.
