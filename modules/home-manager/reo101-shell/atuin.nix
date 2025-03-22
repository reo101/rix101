{ keyPath, ... }:

/* toml */ ''
  ## where to store your database, default is your system data directory
  ## mac: ~/Library/Application Support/com.elliehuxtable.atuin/history.db
  ## linux: ~/.local/share/atuin/history.db
  # db_path = "~/.history.db"

  ## where to store your encryption key, default is your system data directory
  key_path = "${keyPath}"

  ## where to store your auth session token, default is your system data directory
  # session_path = "~/.key"

  ## date format used, either "us" or "uk"
  # dialect = "us"

  ## enable or disable automatic sync
  auto_sync = true

  ## enable or disable automatic update checks
  update_check = false

  ## address of the sync server
  # sync_address = "https://naboo.qtrp.org/atuin"
  sync_address = "http://atuin.jeeves.lan"

  ## how often to sync history. note that this is only triggered when a command
  ## is ran, so sync intervals may well be longer
  ## set it to 0 to sync after every command
  sync_frequency = "1m"

  ## which search mode to use
  ## possible values: prefix, fulltext, fuzzy, skim
  # search_mode = "fuzzy"

  ## which filter mode to use
  ## possible values: global, host, session, directory
  filter_mode = "global"

  # ## which filter mode to use when atuin is invoked from a shell up-key binding
  # ## the accepted values are identical to those of "filter_mode"
  # ## leave unspecified to use same mode set in "filter_mode"
  # filter_mode_shell_up_keybinding = "session"

  ## which style to use
  ## possible values: auto, full, compact
  # style = "auto"

  ## the maximum number of lines the interface should take up
  ## set it to 0 to always go full screen
  # inline_height = 0

  ## enable or disable showing a preview of the selected command
  ## useful when the command is longer than the terminal width and is cut off
  # show_preview = false

  ## what to do when the escape key is pressed when searching
  ## possible values: return-original, return-query
  # exit_mode = "return-original"

  ## possible values: emacs, subl
  # word_jump_mode = "emacs"

  ## characters that count as a part of a word
  # word_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  ## number of context lines to show when scrolling by pages
  # scroll_context_lines = 1

  ## prevent commands matching any of these regexes from being written to history.
  ## Note that these regular expressions are unanchored, i.e. if they don't start
  ## with ^ or end with $, they'll match anywhere in the command.
  ## For details on the supported regular expression syntax, see
  ## https://docs.rs/regex/latest/regex/#syntax
  # history_filter = [
  #   "^secret-cmd",
  #   "^innocuous-cmd .*--secret=.+"
  # ]
''
