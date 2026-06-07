# Auto-Update Module

Checks for and applies egg infrastructure updates from GitHub on every server start.

## Source

- **Repository**: https://github.com/Mark7625/custom-pterodactyl-eggs
- **Branch**: `nextjs`

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTOUPDATE_STATUS` | `true` | Enable update checks |
| `AUTOUPDATE_FORCE` | `false` | Automatically apply updates |

## Updated Paths

- `modules/`
- `nginx/`
- `start-modules.sh`
- `README.md`
- `LICENSE`

User data in `www/` is never modified.
