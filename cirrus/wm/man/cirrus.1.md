cirrus(1) -- A stacking window cooker
=====================================

## SYNOPSIS

`cirrus` [-hv] [-c <config_path>]

## DESCRIPTION

`cirrus` is a stacking window manager that doesn't handle keyboard or
pointer inputs. It is controlled and configured by `sirocco`.

At startup,
`cirrus` runs a script located at `$XDG_CONFIG_HOME/cirrus/cirrusrc`
(`$XDG_CONFIG_HOME` is usually `~/.config`). The path of the configuration file can be
overridden with the `-c` flag.

## OPTIONS

* `-h`:
	Print usage.

* `-v`:
	Print version information.

* `-c` <config_path>:
	Load script from <config_path> instead of
	`$XDG_CONFIG_HOME/cirrus/cirrusrc`.

## SEE ALSO

sirocco(1), sxhkd(1), xinit(1)

## REPORTING BUGS

`cirrus` issue tracker: https://github.com/tudurom/cirrus/issues

## AUTHOR

Tudor Roman `<tudurom at gmail dot com>`

The default color scheme that comes with `cirrus` is [5725](https://github.com/dkeg/crayolo#5725) by dkeg.
