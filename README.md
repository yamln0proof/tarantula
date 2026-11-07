# Tarantula

```text
                  |
                  |
               \  |  /
             ---\ | /---
                 \|/
                (@)
              --/|\--
               / | \
              /  |  \
```

## Introduction

**Tarantula: Web Crawler**

* Clean UI
* Seamless Crawling
* Database & Project Management
* Customise Crawling
* Export project

## Installation

### Requirements

- Ruby 3.1 or newer
- Bundler
- macOS or Linux
- A C compiler and ncurses development headers if the `curses` gem needs to be
  built from source

Clone the repository, then run the cross-platform setup script from any
directory:

```bash
git clone https://github.com/yamln0proof/tarantula.git
cd tarantula
bin/setup
```

The setup script installs the Bundler dependencies and verifies that the app
loads. On macOS, if native dependencies are missing, install Xcode Command
Line Tools (`xcode-select --install`) and ncurses (`brew install ncurses`).
On Debian/Ubuntu Linux, install them with
`sudo apt-get install build-essential libncurses-dev`. Fedora and Arch
prerequisites are printed by `bin/setup` when needed.

## Usage

Start the terminal UI:

```bash
bin/tarantula
```

Choose **Crawl**, then enter:

1. The root directory containing your fixtures.
2. A comma-separated list of domains. Each domain must have a matching
   subdirectory under the fixture root.

For example:

```text
fixtures/
└── example.test/
    ├── index.html
    ├── about.html
    └── documents/
        └── report.pdf
```

The `example.test` directory must contain `index.html` or `index.htm`. Links
are followed only when they point to one of the supplied domains and resolve
inside that domain's fixture directory. Disallowed external links and paths
outside the fixture tree are not fetched. HTML page crawling is capped at 500
pages per run.

Crawl summaries and discovered page/file metadata are saved to a JSON database
at `data/tarantula-crawls.json`. Override its location with
`TARANTULA_DATABASE_PATH`. Choose **View Saved Logs** from the welcome screen to
browse previous crawls and inspect their results.

## Uninstallation

`bin/uninstall` removes globally installed Tarantula gem versions and the
generated executable. It does not remove Bundler dependencies, the repository
checkout, or crawl data:

```bash
bin/uninstall
```

Confirm the prompt to proceed, or pass `--yes` to skip it:

```bash
bin/uninstall --yes
```

## Development

Run the app from source with `bin/tarantula`. The interactive console is
available with `bin/console`; dependencies can also be installed directly
with `bundle install`.

## Contributing

Bug reports and pull requests are welcome. Please follow the project's
[Code of Conduct](./CODE_OF_CONDUCT.md).

## License

Tarantula is available under the [MIT License](./LICENSE.txt).

## Code of Conduct

Please follow the project's [Code of Conduct](./CODE_OF_CONDUCT.md).
