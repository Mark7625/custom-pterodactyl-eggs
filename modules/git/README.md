# Website Deploy Module

Pulls your website source from Git on every server restart (clone on first run, `git pull` after that).

## Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `GIT_STATUS` | `true` | Enable website deploy on startup |
| `WEBSITE_REPO` | — | Git URL of your website repository |
| `WEBSITE_BRANCH` | repo default | Branch to deploy |
| `WEBSITE_TOKEN` | — | Access token for private repos |
| `WEBSITE_USERNAME` | `x-access-token` | Git username for auth (GitHub PATs) |
| `WEBSITE_DIR` | `/home/container/www` | Where the site source is stored |

Legacy variables `GIT_ADDRESS`, `GIT_BRANCH`, `ACCESS_TOKEN`, and `USERNAME` are still supported as fallbacks.
