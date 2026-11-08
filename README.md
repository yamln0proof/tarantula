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
**Tarantula: Web Crawler**

A terminal-based crawler for exploring pages and files on supplied domains.
Run a crawl from the interactive terminal UI and browse saved results.

- Clean, interactive UI
- Domain-scoped crawling
- Database and project management
- Configurable crawling and project export
- CAPTCHA detection that stops crawling without solving challenges


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

Choose **Crawl**, then enter comma-separated domains or `@/path/to/domains.txt`.
The domain file accepts comma-separated or whitespace-separated entries and
lines beginning with `#` as comments. Requests use HTTP(S), are limited to
the exact supplied hosts and standard ports, and do not follow redirects to
other hosts. HTML page crawling is capped at 500 pages per run. If a page
appears to contain a CAPTCHA, the crawler records the detection and stops
without processing that page or attempting to solve the challenge. Detection
uses a local, confidence-scored rule-based HTML classifier.

Crawl summaries and discovered page/file metadata are saved to a JSON database
at `data/tarantula-crawls.json`. Override its location with
`TARANTULA_DATABASE_PATH`.
Choose **View Saved Logs** from the welcome screen to
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
