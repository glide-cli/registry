# Glide Plugin Registry

The official plugin registry for [Glide CLI](https://github.com/glide-cli/glide), a context-aware command orchestrator.

## Structure

```
registry/
├── categories.yml          # Category definitions
├── plugins/
│   └── {plugin-name}/
│       ├── plugin.yml      # Plugin metadata
│       └── versions/
│           └── {version}.yml
└── .github/
    └── workflows/
        └── validate.yml    # PR validation
```

## Installing Plugins

```bash
# Search for plugins
glide plugin search docker

# Install a plugin
glide plugin install docker

# Install specific version
glide plugin install docker@3.0.0
```

## Contributing a Plugin

### 1. Fork and Clone

```bash
git clone https://github.com/glide-cli/registry.git
cd registry
```

### 2. Create Plugin Directory

```bash
mkdir -p plugins/your-plugin/versions
```

### 3. Add Plugin Metadata

Create `plugins/your-plugin/plugin.yml`:

```yaml
name: your-plugin
description: Brief description of what your plugin does
author: your-github-username
homepage: https://github.com/your-org/glide-plugin-yourplugin
repository: https://github.com/your-org/glide-plugin-yourplugin
license: MIT

categories:
  - utilities  # See categories.yml for options

tags:
  - relevant
  - searchable
  - keywords

# Current versions
latest: 1.0.0
stable: 1.0.0
```

### 4. Add Version Metadata

Create `plugins/your-plugin/versions/1.0.0.yml`:

```yaml
version: 1.0.0
releaseDate: 2025-01-01T00:00:00Z
minGlideVersion: 3.0.0

# GitHub release URL
releaseURL: https://github.com/your-org/glide-plugin-yourplugin/releases/tag/v1.0.0

# SHA256 checksums for each platform binary
checksums:
  darwin-amd64: sha256:abc123...
  darwin-arm64: sha256:def456...
  linux-amd64: sha256:ghi789...
  linux-arm64: sha256:jkl012...
  windows-amd64: sha256:mno345...

changelog: |
  ### Added
  - Initial release
  - Feature X
  - Feature Y

commands:
  - name: command-name
    description: What this command does
```

### 5. Submit Pull Request

1. Create a feature branch
2. Commit your changes
3. Open a PR against `main`
4. Automated validation will run
5. Maintainers will review

## Validation

All submissions are validated for:

- **Schema compliance**: Required fields present and correctly formatted
- **Version consistency**: Version in filename matches version in YAML
- **Checksum format**: Valid SHA256 checksums
- **URL accessibility**: Release URLs are reachable
- **Category validity**: Categories exist in `categories.yml`

## Plugin Requirements

### Binary Distribution

Plugins must be distributed as pre-compiled binaries via GitHub Releases:

- Support at minimum: `darwin-arm64`, `linux-amd64`
- Recommended: All five platforms (darwin-amd64, darwin-arm64, linux-amd64, linux-arm64, windows-amd64)
- Binary naming: `glide-plugin-{name}_{os}_{arch}` (e.g., `glide-plugin-docker_darwin_arm64`)

### Glide SDK

Plugins must use the [Glide Plugin SDK](https://github.com/glide-cli/glide):

```go
import "github.com/glide-cli/glide/v3/sdk/v2"
```

See [Plugin Development Guide](https://github.com/glide-cli/glide/blob/main/PLUGIN_DEVELOPMENT.md) for details.

### Security

- No network calls during plugin initialization
- Request only necessary capabilities
- Follow principle of least privilege

## Categories

| ID | Name | Description |
|----|------|-------------|
| docker | Docker & Containers | Container orchestration and workflows |
| languages | Languages & Runtimes | Language tooling and version management |
| databases | Databases | Database management and migrations |
| testing | Testing & Quality | Test runners and CI/CD integration |
| cloud | Cloud & Infrastructure | Cloud CLIs and IaC tools |
| security | Security | Scanning and secrets management |
| monitoring | Monitoring & Observability | Logging, metrics, and tracing |
| utilities | Utilities | General development tools |

## Official Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [docker](plugins/docker) | Docker and Docker Compose management | 3.0.0 |
| go | Go version and module management | Coming soon |
| node | Node.js and npm/yarn management | Coming soon |
| php | PHP and Composer management | Coming soon |

## License

This registry is MIT licensed. Individual plugins maintain their own licenses.
