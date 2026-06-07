# JAR Module

Runs `java -jar` in the foreground.

| Variable | Default |
|----------|---------|
| `SERVER_JAR` | `app.jar` |
| `APP_ARGS` | — |
| `JAVA_OPTS` | `-Xms128M -XX:MaxRAMPercentage=95.0` |

`SERVER_PORT` is appended to `APP_ARGS` when not already present.
