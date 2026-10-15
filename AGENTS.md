# Local Codex Rules

## Modern redesign continuity

Read [`docs/context/modern-redesign.md`](docs/context/modern-redesign.md) before
continuing UI work. The Modern Figma redesign applies across the app, not only
the admin overview. Inspect both Admin showcase and Foundations pages, and
apply the shared components to public, authentication, and management screens.
Preserve existing functionality; label unsupported features instead of adding
new backend behavior solely to match the mockup.

These rules are project-local and should take precedence over global defaults where they differ.

## Environment Guidelines

### Local Source Inspection
- Source code inspection may be performed directly on the local filesystem when commands are read-only.
- Read-only inspection includes commands like `ls`, `find`, `rg`, `cat`, `sed`, and similar file-view/search operations.
- Use Docker execution for runtime, dependency, database, and test commands.

### Docker Command Execution
- Execute shell commands inside the Docker container.
- Prefix commands with: `docker compose exec web <command>`.

Examples:
- `docker compose exec web rails db:migrate`
- `docker compose exec web rails console`
- `docker compose exec web rails test`
- `docker compose exec web bundle install`
- `docker compose exec web rake routes`

### File Paths for Instrumentation
- For instrumentation, logging, or debug output in Rails code, use `Rails.root.join(...)`.

Examples:
- `File.write(Rails.root.join("tmp", "debug.log"), output)`
- `FileUtils.mkdir_p(Rails.root.join("tmp", "instrumentation"))`
- `path = Rails.root.join("log", "custom.log")`

## Global Rule References

For non-environment guidance, use the global files:
- `~/.codex/rules/global/models.md`
- `~/.codex/rules/global/concerns.md`
- `~/.codex/rules/global/controllers.md`
- `~/.codex/rules/global/actions.md`
- `~/.codex/rules/global/policies.md`
- `~/.codex/rules/global/views.md`
