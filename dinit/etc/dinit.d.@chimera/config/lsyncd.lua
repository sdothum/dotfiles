-- sdothum - 2016 (c) wtfpl

settings {
  logfile                   = "/var/log/dinit/lsyncd.log",
  statusFile                = "/var/log/dinit/lsyncd-status.log",
  statusInterval            = 20,
  insist                    = true,
  maxProcesses              = 1
}

sync {
  default.rsyncssh,
  source                    = "/home/shum/stow",
  host                      = "shum@luna",
  excludeFrom               = "/etc/lsyncd.exclude",
  targetdir                 = "/home/shum/stow",
  rsync = {

    archive                 = true,
    compress                = false,
    whole_file              = false
  },
  ssh                       = {
    port                    = 22,
    identityFile            = "/home/shum/.ssh/id_rsa",
    options = {
      User                  = "shum",
      StrictHostKeyChecking = "no"
    }
  }
}

sync {
  default.rsyncssh,
  source                    = "/home/shum/stow",
  host                      = "shum@monad",
  excludeFrom               = "/etc/lsyncd.exclude",
  targetdir                 = "/home/shum/stow",
  rsync = {

    archive                 = true,
    compress                = false,
    whole_file              = false
  },
  ssh                       = {
    port                    = 22,
    identityFile            = "/home/shum/.ssh/id_rsa",
    options = {
      User                  = "shum",
      StrictHostKeyChecking = "no"
    }
  }
}

