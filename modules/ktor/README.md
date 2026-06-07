# Ktor / JAR Module

Runs the JAR in the foreground. No nginx — embedded server binds directly to `APP_PORT` (defaults to Pterodactyl `SERVER_PORT`).

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_JAR` | `app.jar` | JAR in `/home/container` |
| `APP_PORT` | `SERVER_PORT` | HTTP listen port |
| `APP_PORT_METHOD` | `property` | `property` or `cli` |
| `APP_ARGS` | — | Args after `-jar` |
| `JAVA_OPTS` | `-Xms128M -XX:MaxRAMPercentage=95.0` | JVM flags |
