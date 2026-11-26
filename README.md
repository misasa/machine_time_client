# gem package -- machine_time_client

Ruby client for the MachineTime REST API.

# Description

This gem uses [ActiveResource](https://github.com/rails/activeresource/)
to access machines and sessions managed by
[MachineTime](https://github.com/misasa/machine_time).
It provides methods to find machines by name, start and stop a machine,
and retrieve its current session.

[Godigo](https://github.com/misasa/godigo) uses this library.

# Requirements

Ruby 2.6 through 4.0. The gem requires Ruby 2.6.0 or later.

# Installation

Add this line to your application's Gemfile:

    gem 'machine_time_client'

Then run:

    bundle install

You can also download a gem from
[GitHub Releases](https://github.com/misasa/machine_time_client/releases)
and install it with `gem install ./machine_time_client-VERSION.gem`.
Release assets become available after a version tag is pushed and the
release workflow succeeds.

# Configuration and usage

Before requiring the library, create `~/.godigorc` with string keys:

```yaml
uri_machine: https://example.com/machine/
machine: MACHINE-1
```

The library reads this file when its resource classes are loaded. If reading
fails, it attempts to write a default configuration to the same path.

```ruby
require 'machine_time_client'

machine = MachineTimeClient::Machine.find_by_name('MACHINE-1')
session = machine.current_session if machine
```

See `spec/` for additional examples. This gem does not install any commands.

# Development

```sh
bundle install
bundle exec rspec
bundle exec rake build
bundle exec ruby script/verify_package.rb pkg/machine_time_client-1.1.1.gem
```

The package verifier installs the gem in a temporary directory, reuses the
resolved runtime dependencies (including Git sources), and loads the installed
library with a temporary configuration. It does not contact a MachineTime server.

# CI and releases

GitHub Actions tests Ruby 2.6.10, 2.7.8, 3.2, 3.3, 3.4, and 4.0.
After all tests pass, it builds and verifies the gem and saves it as an artifact.
A push of a matching `vVERSION` tag on a commit contained in `master` also
publishes the gem and its SHA-256 manifest to GitHub Releases. The workflow
rejects existing releases and legacy tags for the same version. It uploads a
draft, downloads and compares the uploaded files, and then publishes the release.
A push to `master` alone does not publish a release.

To download and verify a public release without a GitHub token or Ruby:

```sh
script/download_release.sh --version 1.1.1 --output-dir downloads
```

Omit `--version` to use the latest stable public release. Existing files are
never overwritten. Optional SSH deployment requires both `--deploy` and
`MACHINE_TIME_CLIENT_DEPLOY_DEST=user@host:/absolute/path`; it creates a new
`vVERSION` directory under that path. See `script/download_release.sh --help`.

# License

GPL-3.0-or-later. See `LICENSE.txt`.
