# Tarantula

<pre style="color: red">
                |
                |
               /|\\
            __/ | \\__
            \\  (@)  /
             \\ /|\\ /
              / | \\
             /  |  \\
</pre>
**Tarantula: Web Crawler**
**Crawling Made Easy**

A terminal-based crawler for exploring pages and files on supplied domains.
Run a crawl from the interactive terminal UI and browse saved results.

- Clean, interactive UI
- Domain-scoped crawling
- Database and project management
- Configurable crawling and project export
- CAPTCHA detection and Ai solving(In progress)


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

To install Tarantula for your current macOS or Linux user, start
`bin/tarantula` and choose **Install on this device**. This builds and installs
the gem and its dependencies into your user gem directory without `sudo`. It
installs the `tarantula` command at `~/.local/bin/tarantula`. Add that directory
to your shell's `PATH` if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

On macOS, ensure the native build prerequisites described above are installed
if the `curses` gem needs to be compiled.

Installed crawls are stored under `$XDG_DATA_HOME/tarantula` or
`~/.local/share/tarantula` on Linux, and in
`~/Library/Application Support/tarantula` on macOS.

## Usage

Start the terminal UI:

```bash
bin/tarantula
```

Choose **Crawl**, then enter comma-separated domains or `@/path/to/domains.txt`.
The domain file accepts comma-separated or whitespace-separated entries and
lines beginning with `#` as comments. Requests use HTTP(S), are limited to
the exact supplied hosts and standard ports, and do not follow redirects to
other hosts. The crawler follows discovered links on the supplied hosts,
queues each page once, and records linked files separately. It continues until
the discovered-link queue is empty, unless a CAPTCHA is detected. If a page
appears to contain a CAPTCHA, the crawler records the detection and stops
without processing that page or attempting to solve the challenge. Detection
uses a local, confidence-scored rule-based HTML classifier.
During an interactive crawl, press `s` to stop after the current HTTP request;
partial results are saved and marked as stopped by the user.

Choose **Configure Settings** to edit HTTP open/read timeouts, the redirect
limit, maximum HTML response size, requests per minute, crawl database path,
custom HTTP header, and CAPTCHA detection threshold. Set requests per minute
to `0` for no rate limit. Enter a custom header as `Name: Value`; clear the
field to remove it. Settings apply for the current application session only.
CAPTCHA challenges are detected but are not solved.

Crawl summaries and discovered page/file metadata are saved to a JSON database
at `data/tarantula-crawls.json`. Override its location with
`TARANTULA_DATABASE_PATH`.
Choose **View Saved Logs** from the welcome screen to
browse previous crawls and inspect their results.

Choose **Export Report** to select a saved crawl, set an output directory, and
write a text report named `crawl-<id>.txt`. Use Up/Down to select a crawl, `d`
to edit the destination, and `e` or Enter to export.

Export a text-only report to a specific directory with:

```ruby
report_path = Tarantula::Config::CrawlReportExporter.new.export_text(
  crawl,
  directory: "/path/to/reports"
)
```

The method creates the directory if needed and returns the generated file path.

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

To uninstall a per-user installation created from the welcome screen, run:

```bash
gem uninstall --user-install --bindir "$HOME/.local/bin" tarantula
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
