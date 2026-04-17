# Bazaar

**Persian: بازار — marketplace/gathering**

Community package repository for [AGNOS](https://github.com/MacCracken/agnosticos). Like Arch's AUR, but for ark.

## How It Works

1. Community members submit takumi recipe CYMLs via pull request
2. Maintainers review for security and correctness
3. Users install via `ark bazaar install <package>`
4. Packages build locally via takumi or download from build mirror

## Usage

```bash
# Search for a package
ark bazaar search neovim

# Install a package (builds locally via takumi)
ark bazaar install neovim

# Update the recipe index
ark bazaar update

# List installed community packages
ark bazaar list

# Submit a recipe for review
ark bazaar submit recipes/editors/neovim.cyml
```

## Submitting a Recipe

1. Fork this repo
2. Create a recipe CYML in the appropriate category under `recipes/`
3. Follow the [takumi recipe format](https://github.com/MacCracken/agnosticos/blob/main/recipes/README.md)
4. Sign your commit with GPG
5. Open a pull request

Recipes are [Cyrius](https://github.com/MacCracken/cyrius) CYML files — same syntax as TOML with `.cyml` extension. Matches zugot convention. Toolchain is pinned in `cyrius.cyml`.

### Recipe Categories

| Directory | Contents |
|-----------|----------|
| `recipes/editors/` | Text editors, IDEs |
| `recipes/tools/` | CLI tools, utilities |
| `recipes/media/` | Media players, editors, codecs |
| `recipes/networking/` | Network tools, VPNs, proxies |
| `recipes/security/` | Security tools, password managers |
| `recipes/ai/` | AI/ML tools, models, runtimes |
| `recipes/games/` | Games and emulators |

### Recipe Requirements

- Must build from source (no pre-compiled binaries)
- Must include `sha256` checksum for source tarballs
- Must specify all runtime and build dependencies
- Must work with the AGNOS base system (no glibc version assumptions)
- GPG-signed commits required

## Trust Model

- All recipes are reviewed by maintainers before merging
- Community packages run in a restricted sandbox by default (no network access)
- Packages requiring network access must be explicitly approved
- GPG signature verification on all recipe commits

## License

Recipes in this repository are individually licensed by their authors.
The repository infrastructure is licensed under GPL-3.0.
