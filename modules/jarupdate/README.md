# JAR Update Module

Downloads a JAR from **GitHub Releases**.

## Pick a release

| Mode | Variable | Example |
|------|----------|---------|
| **Latest matching** | `JAR_RELEASE_FILTER` | `diff` matches tag `2026-06-07-diff-abc1234` or title `2026-06-07 - diff` |
| **Exact tag** | `JAR_UPDATE_TAG` | `v1.0.0` |
| **Newest any** | leave both blank | first published release with asset |

`JAR_UPDATE_TAG` overrides `JAR_RELEASE_FILTER` when set.

## Other settings

| Variable | Default |
|----------|---------|
| `JAR_UPDATE_REPO` | — |
| `SERVER_JAR` | `app.jar` |
| `JAR_UPDATE_MODE` | `Automatic` |
| `GITHUB_TOKEN` | PAT — recommended on Pterodactyl (avoids API rate limits) |
| `JAR_UPDATE_DEBUG` | `1` to log raw API response |

State: `/home/container/.jarupdate_release`
