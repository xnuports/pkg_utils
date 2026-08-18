# pkg_utils

Builds `pkg` and associated utilities for macOS from the xnuports/pkg fork and the FreeBSD ports tree.

## Prerequisites

- Xcode Command Line Tools
- `/opt/homebrew/opt/dialog` (for `pkg_cleanup`)
- `/opt/homebrew/opt/ncurses` (for `pkg_cleanup`)

## Usage

```bash
make all          # fetch and build everything
make install      # install to /usr/local
make clean        # remove build artifacts only
make clean CLEAN_REPOS=1  # remove build artifacts and cloned repos
make distclean    # remove everything
```

## Overrides

```bash
make all PREFIX=/opt/homebrew DESTDIR=/tmp/stage
```

## License

BSD 2-Clause. See LICENSE.
