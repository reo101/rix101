def env-default [name: string, fallback: string] {
  let value = ($env | get -o $name | default "")
  if (($value | into string) == "") { $fallback } else { $value | into string }
}

def die [message: string, code: int = 1] {
  print -e $message
  exit $code
}

def first-location [headers: string] {
  let matches = ($headers | lines | where { |line| ($line | str downcase | str starts-with "location:") })
  if (($matches | length) == 0) {
    ""
  } else {
    $matches | first | str replace -r "(?i)^location:\\s*" "" | str trim
  }
}

def firefox-cookies-db [] {
  let explicit_db = (env-default CACHIX_FIREFOX_COOKIES_SQLITE "")
  if $explicit_db != "" { return ($explicit_db | path expand) }

  let explicit_profile = (env-default CACHIX_FIREFOX_PROFILE "")
  if $explicit_profile != "" { return ($explicit_profile | path expand | path join "cookies.sqlite") }

  if ((env-default CACHIX_USE_FIREFOX_COOKIES "0") != "1") { return "" }

  let candidates = (glob ~/.mozilla/firefox/* | where { |p| ($p | path join "cookies.sqlite" | path exists) })
  if (($candidates | length) == 0) { return "" }

  $candidates
  | each { |p| { profile: $p, modified: (ls ($p | path join "cookies.sqlite") | get modified.0) } }
  | sort-by modified
  | last
  | get profile
  | path join "cookies.sqlite"
}

def copy-firefox-cookie-db [cookies_db: string] {
  if (($cookies_db == "") or (not ($cookies_db | path exists))) {
    die $"Firefox cookies database not found: ($cookies_db)"
  }

  let tmpdir = (^mktemp -d | str trim)
  let copied_db = ($tmpdir | path join "cookies.sqlite")

  ^cp $cookies_db $copied_db
  if ($"($cookies_db)-wal" | path exists) { ^cp $"($cookies_db)-wal" $"($copied_db)-wal" }
  if ($"($cookies_db)-shm" | path exists) { ^cp $"($cookies_db)-shm" $"($copied_db)-shm" }

  $copied_db
}

def firefox-cookie-jar [cookies_db: string, service: string] {
  let copied_db = (copy-firefox-cookie-db $cookies_db)
  let jar = ((^dirname $copied_db | str trim) | path join $"($service)-cookies.txt")
  let host_filter = if $service == "github" {
    "(host = 'github.com' OR host LIKE '%.github.com')"
  } else if $service == "cachix" {
    "(host = 'cachix.org' OR host LIKE '%.cachix.org')"
  } else {
    die $"Unknown cookie service: ($service)"
  }

  let sql = (
    "SELECT " +
    "CASE WHEN isHttpOnly THEN '#HttpOnly_' ELSE '' END || host || char(9) || " +
    "CASE WHEN substr(host, 1, 1) = '.' THEN 'TRUE' ELSE 'FALSE' END || char(9) || " +
    "path || char(9) || " +
    "CASE WHEN isSecure THEN 'TRUE' ELSE 'FALSE' END || char(9) || " +
    "expiry || char(9) || name || char(9) || value " +
    "FROM moz_cookies " +
    $"WHERE ($host_filter) " +
    "AND (expiry = 0 OR expiry > strftime('%s', 'now'));"
  )

  let rows = (^sqlite3 -noheader $copied_db $sql | str trim)
  if $rows == "" { return "" }

  "# Netscape HTTP Cookie File\n" | save -f $jar
  $"($rows)\n" | save --append $jar
  $jar
}

def cachix-cookie-jar-via-github-oauth [cookies_db: string] {
  let github_cookie_file = (firefox-cookie-jar $cookies_db github)
  if $github_cookie_file == "" { die $"No live GitHub cookies found in Firefox database: ($cookies_db)" 2 }

  let api_host = (env-default CACHIX_API_HOST "https://app.cachix.org" | str replace -r "/+$" "")
  print -e "No live Cachix cookies found; trying Cachix GitHub OAuth via Firefox GitHub cookies."

  let login = (do { ^curl -sS -i --max-time 15 $"($api_host)/api/v1/login/github?redirect=/" } | complete)
  if $login.exit_code != 0 { die $"Failed to start Cachix GitHub login: ($login.stderr)" }

  let github_authorize_url = (first-location $login.stdout)
  if $github_authorize_url == "" { die "Cachix login endpoint did not return a GitHub OAuth redirect." }

  let github_headers = (^mktemp | str trim)
  let github = (do {
    ^curl -sS -D $github_headers -o /dev/null --max-redirs 0 --cookie $github_cookie_file -A "Mozilla/5.0 (X11; Linux x86_64; rv:151.0) Gecko/20100101 Firefox/151.0" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Accept-Language: en-US,en;q=0.5" -H "Sec-Fetch-Site: cross-site" -H "Sec-Fetch-Mode: navigate" -H "Sec-Fetch-Dest: document" $github_authorize_url
  } | complete)
  if $github.exit_code != 0 { die $"GitHub OAuth request failed: ($github.stderr)" }

  let callback = (first-location (open --raw $github_headers))
  rm -f $github_headers
  if not ($callback | str starts-with $"($api_host)/api/v1/login/callback") {
    die "GitHub did not redirect back to Cachix. You may need to be logged into GitHub in Firefox and have authorized the Cachix OAuth app."
  }

  let cachix_cookie_file = (^mktemp | str trim)
  let callback_status = (^curl -sS -o /dev/null -w "%{http_code}" -c $cachix_cookie_file -A "Mozilla/5.0" $callback | str trim)
  if not ($callback_status in ["200", "302", "303"]) { die $"Cachix login callback failed: HTTP ($callback_status)" }

  let user_status = (^curl -sS -o /dev/null -w "%{http_code}" -b $cachix_cookie_file $"($api_host)/api/v1/user" | str trim)
  if $user_status != "200" { die $"Cachix OAuth cookie did not authenticate /api/v1/user: HTTP ($user_status)" }

  $cachix_cookie_file
}

def auth-args [] {
  let refresh_token = (env-default CACHIX_REFRESH_TOKEN "")
  let refresh_token_file = (env-default CACHIX_REFRESH_TOKEN_FILE "")
  let cookie_file = (env-default CACHIX_COOKIE_FILE "")
  let firefox_db = (firefox-cookies-db)

  if $refresh_token != "" {
    { args: ["-H", $"Authorization: Bearer ($refresh_token)"], cookie_mode: false }
  } else if $refresh_token_file != "" {
    let auth_token = (open --raw $refresh_token_file | str replace -a "\r" "" | str replace -a "\n" "")
    { args: ["-H", $"Authorization: Bearer ($auth_token)"], cookie_mode: false }
  } else if $cookie_file != "" {
    { args: ["--cookie", ($cookie_file | path expand)], cookie_mode: true }
  } else if $firefox_db != "" {
    mut generated_cookie_file = (firefox-cookie-jar $firefox_db cachix)
    if $generated_cookie_file == "" {
      $generated_cookie_file = (cachix-cookie-jar-via-github-oauth $firefox_db)
    } else {
      print -e $"Using Cachix cookies exported from Firefox DB: ($firefox_db)"
    }
    { args: ["--cookie", $generated_cookie_file], cookie_mode: true }
  } else {
    print -e "No credential for Cachix API calls was supplied."
    print -e "Set CACHIX_REFRESH_TOKEN, CACHIX_REFRESH_TOKEN_FILE, CACHIX_COOKIE_FILE,"
    print -e "CACHIX_FIREFOX_COOKIES_SQLITE, CACHIX_FIREFOX_PROFILE, or CACHIX_USE_FIREFOX_COOKIES=1."
    exit 2
  }
}

def token-description [token] {
  $token | get -o description | default "" | into string
}

def token-expiry [token] {
  let expiry = ($token | get -o expiresOn | default "")
  if ($expiry == null) { "" } else { $expiry | into string }
}

def token-revoked [token] {
  $token | get -o isRevoked | default false
}

def token-status [token] {
  let revoked = (token-revoked $token)
  let expiry = (token-expiry $token)

  if $revoked {
    "❌ revoked"
  } else if $expiry == "" {
    "✅ no expiry"
  } else if (($expiry | into datetime) > (date now)) {
    "✅ valid"
  } else {
    "❌ expired"
  }
}

def latest-matching-token [tokens, prefix: string] {
  let matches = (
    $tokens
    | where { |t|
      let desc = (token-description $t)
      let suffix = ($desc | str replace $prefix "")
      ($desc | str starts-with $prefix) and ($suffix =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
    }
    | each { |t|
      let desc = (token-description $t)
      let suffix = ($desc | str replace $prefix "")
      let created = ($t | get -o createdOn | default "" | into string)
      $t | insert sortKey $"($suffix)-($created)"
    }
    | sort-by sortKey
  )

  if (($matches | length) == 0) { null } else { $matches | last }
}

def api-get-json [api_host: string, auth_args: list<string>, path: string] {
  let response = (^mktemp | str trim)
  let status = (^curl -sS -o $response -w "%{http_code}" -H "Accept: application/json" ...$auth_args $"($api_host)/api/v1/($path)" | str trim)

  if $status != "200" {
    print -e $"Cachix API GET /api/v1/($path) failed: HTTP ($status)"
    open --raw $response | lines | each { |line| print -e $"  ($line)" }
    rm -f $response
    exit 1
  }

  let parsed = (open --raw $response | from json)
  rm -f $response
  $parsed
}

def api-post-json [api_host: string, auth_args: list<string>, path: string, body: string] {
  let response = (^mktemp | str trim)
  let status = (^curl -sS -o $response -w "%{http_code}" -X POST -H "Content-Type: application/json" -H "Accept: application/json" ...$auth_args --data $body $"($api_host)/api/v1/($path)" | str trim)

  if $status != "200" {
    print -e $"Cachix API POST /api/v1/($path) failed: HTTP ($status)"
    open --raw $response | lines | each { |line| print -e $"  ($line)" }
    rm -f $response
    exit 1
  }

  let parsed = (open --raw $response | from json)
  rm -f $response
  $parsed
}

def api-post-empty [api_host: string, auth_args: list<string>, path: string] {
  let response = (^mktemp | str trim)
  let status = (^curl -sS -o $response -w "%{http_code}" -X POST -H "Accept: application/json" ...$auth_args $"($api_host)/api/v1/($path)" | str trim)

  if not ($status in ["200", "204"]) {
    print -e $"Cachix API POST /api/v1/($path) failed: HTTP ($status)"
    open --raw $response | lines | each { |line| print -e $"  ($line)" }
    rm -f $response
    exit 1
  }

  rm -f $response
}

def nix-netrc-file [] {
  let configured = (do { ^nix config show netrc-file } | complete)
  let path = if (($configured.exit_code == 0) and (($configured.stdout | str trim) != "")) {
    $configured.stdout | str trim
  } else {
    "~/.config/nix/netrc"
  }

  $path | path expand
}

def install-nix-netrc-token [cache: string, token: string] {
  let netrc = (nix-netrc-file)
  let machine = $"($cache).cachix.org"
  let parent = ($netrc | path dirname)

  mkdir $parent

  let existing_lines = if ($netrc | path exists) {
    let backup = $"($netrc).bak.(date now | format date '%s')"
    ^cp $netrc $backup
    open --raw $netrc | lines
  } else {
    []
  }

  let kept_lines = (
    $existing_lines
    | where { |line| not (($line | str trim) | str starts-with $"machine ($machine) ") }
  )

  ($kept_lines | append $"machine ($machine) password ($token)" | str join (char newline) | $in + (char newline)) | save -f $netrc
  ^chmod 600 $netrc

  print $"Synced Nix netrc entry for ($machine) at ($netrc)."
}

def print-token-summary [cache: string, prefix: string, token] {
  if $token == null {
    print $"No matching tokens found for cache ($cache) with prefix ($prefix)."
    return
  }

  print $"Latest matching token for cache ($cache):"
  print $"  name:    ((token-description $token))"
  print $"  expiry:  ((token-expiry $token | default 'none'))"
  print $"  status:  ((token-status $token))"
}

# Print or rotate the latest host-named Cachix auth token.
#
# Default mode lists the latest token matching:
# `$CACHIX_TOKEN_USER-$CACHIX_TOKEN_HOSTNAME_YYYY-MM-DD`.
#
# `--refresh` revokes the latest non-revoked matching token, creates a new
# 30-day token, installs it with `cachix authtoken --stdin`, and verifies the
# cache.
#
# Authentication for Cachix API calls must be supplied by one of:
# - `CACHIX_REFRESH_TOKEN`
# - `CACHIX_REFRESH_TOKEN_FILE`
# - `CACHIX_COOKIE_FILE`
# - `CACHIX_FIREFOX_COOKIES_SQLITE`
# - `CACHIX_FIREFOX_PROFILE`
# - `CACHIX_USE_FIREFOX_COOKIES=1`
#
# Firefox mode first tries existing Cachix cookies. If none exist, it uses
# Firefox's GitHub cookies to complete Cachix's GitHub OAuth login and capture
# a fresh Cachix cookie.
#
# Optional environment:
# - `CACHIX_CACHE`: default cache when `cache` is omitted, defaults to `rix101`
# - `CACHIX_API_HOST`: defaults to `https://cachix.org`; cookie/OAuth mode
#   defaults to `https://app.cachix.org`
# - `CACHIX_TOKEN_USER`: defaults to current user name
# - `CACHIX_TOKEN_HOSTNAME`: defaults to short hostname
# - `CACHIX_PERMISSION`: defaults to `Read`
#
# On refresh, this updates both Cachix's CLI config and Nix's configured
# `netrc-file`, since `cachix authtoken` alone does not update the token Nix
# uses for authenticated substituter downloads.
def main [
  cache?: string # Cachix cache name, defaults to `$CACHIX_CACHE` or `rix101`
  --refresh # Revoke the old token, create and install a new 30-day token
] {
  let cache = if ($cache == null) { env-default CACHIX_CACHE rix101 } else { $cache }
  let permission = (env-default CACHIX_PERMISSION Read)
  let token_user = (env-default CACHIX_TOKEN_USER (^id -un | str trim))
  let token_host = (env-default CACHIX_TOKEN_HOSTNAME (^uname -n | str trim | split row "." | first))
  let today = (^date -u +%F | str trim)
  let description = $"($token_user)-($token_host)_($today)"
  let prefix = $"($token_user)-($token_host)_"
  let expires_on = (^date -u -d "+30 days" "+%Y-%m-%dT%H:%M:%S.000Z" | str trim)

  let auth = (auth-args)
  let default_api_host = if $auth.cookie_mode { "https://app.cachix.org" } else { "https://cachix.org" }
  let api_host = (env-default CACHIX_API_HOST $default_api_host | str replace -r "/+$" "")

  let tokens = (api-get-json $api_host $auth.args "token")
  let old_token = (latest-matching-token $tokens $prefix)

  if not $refresh {
    print-token-summary $cache $prefix $old_token
    return
  }

  print-token-summary $cache $prefix $old_token

  let revoke_token = (latest-matching-token ($tokens | where { |t| not (token-revoked $t) }) $prefix)
  if $revoke_token != null {
    let old_id = ($revoke_token | get -o id | default "" | into string)
    if $old_id != "" {
      print $"Revoking old token: (token-description $revoke_token)"
      api-post-empty $api_host $auth.args $"token/($old_id)/revoke"
    } else {
      print "Old token has no id; skipping revoke."
    }
  }

  let body = ({
    description: $description
    cacheName: $cache
    workspaceSlug: null
    expiresOn: $expires_on
    isAgentToken: false
    permission: $permission
  } | to json -r)

  let parsed_response = (api-post-json $api_host $auth.args "token" $body)

  mut new_token = ""
  if (($parsed_response | describe) == "string") {
    $new_token = $parsed_response
  } else if (($parsed_response | describe) | str starts-with "record") {
    $new_token = ($parsed_response | get -o token | default "")
  }

  if $new_token == "" { die "Cachix API response did not contain a token." }

  ^printf "%s" $new_token | ^cachix authtoken --stdin
  install-nix-netrc-token $cache $new_token
  print $"Installed new Cachix token ($description) for ($cache), expiring at ($expires_on)."

  ^nix store info --store $"https://($cache).cachix.org" out> /dev/null
  print $"Verified https://($cache).cachix.org."
}
