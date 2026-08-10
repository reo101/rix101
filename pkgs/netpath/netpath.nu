#!/usr/bin/env nu

const default_config = "/etc/netpath.json"
const default_state = "/run/netpath/state.json"


def fail [message: string] {
  error make { msg: $message }
}


def config-path [] {
  $env.NETPATH_CONFIG? | default $default_config
}


def load-config [] {
  let path = (config-path)
  if not ($path | path exists) {
    fail $"missing netpath config: ($path)"
  }

  let config = (open $path)
  if (($config.profiles? | default []) | is-empty) {
    fail $"netpath config has no profiles: ($path)"
  }
  $config
}


def routing [config: record] {
  let settings = ($config.routing? | default {})
  {
    table: ($settings.table? | default 100 | into int)
    priority: ($settings.priority? | default 10000 | into int)
    probe: ($settings.probe? | default "1.1.1.1")
    require_probe: ($settings.require_probe? | default false | into bool)
    state: ($settings.state? | default $default_state)
  }
}


# A role maps to a list of interfaces; a single device string is accepted too.
def path-devices [profile: record, role: string] {
  let raw = ($profile.paths | get -o $role | default [])
  let devices = (if ($raw | describe | str starts-with "string") { [$raw] } else { $raw })
  $devices | uniq
}


def profile-devices [profile: record] {
  ["ethernet" "wifi"]
  | each {|role| path-devices $profile $role }
  | flatten
  | uniq
}


def other-role [role: string] {
  if $role == "ethernet" { "wifi" } else { "ethernet" }
}


def require-root [] {
  if ((^id -u | str trim | into int) != 0) {
    fail "this operation must run as root (use sudo)"
  }
}


def run-complete [program: string, ...args: string] {
  do { run-external $program ...$args } | complete
}


def run! [program: string, ...args: string] {
  let result = (run-complete $program ...$args)
  if $result.exit_code != 0 {
    let detail = ($result.stderr | str trim)
    fail (if ($detail | is-empty) {
      $"command failed: ($program) ($args | str join ' ')"
    } else {
      $"command failed: ($program) ($args | str join ' '): ($detail)"
    })
  }
  $result.stdout
}


def interface-addresses [device: string] {
  let result = (run-complete "ip" "-j" "-4" "address" "show" "dev" $device)
  if $result.exit_code != 0 or ($result.stdout | str trim | is-empty) {
    return []
  }

  let links = ($result.stdout | from json)
  let info = (($links | get -o 0.addr_info) | default [])
  $info | where {|address| $address.scope == "global" } | get local
}


def cached-gateway-mac [gateway: string, device: string] {
  let neighbors = (run-complete "ip" "-j" "neighbor" "show" "to" $gateway "dev" $device)
  if $neighbors.exit_code != 0 or ($neighbors.stdout | str trim | is-empty) {
    return ""
  }

  (($neighbors.stdout | from json | get -o 0.lladdr) | default "")
}


def local-vip-present [vip: string] {
  let result = (run-complete "ip" "-j" "-4" "address" "show")
  if $result.exit_code != 0 { return false }

  $result.stdout
  | from json
  | each {|link| $link.addr_info? | default [] }
  | flatten
  | any {|address| ($address.local? | default "") == $vip }
}


def path-status [profile: record, role: string, device: string] {
  let carrier_path = $"/sys/class/net/($device)/carrier"
  if not ($carrier_path | path exists) {
    return { ready: false, role: $role, device: $device, reason: "interface missing" }
  }
  let carrier = (run-complete "cat" $carrier_path)
  if $carrier.exit_code != 0 or ($carrier.stdout | str trim) != "1" {
    return { ready: false, role: $role, device: $device, reason: "no carrier" }
  }

  let management = (interface-addresses $device | where $it != $profile.vip)
  if ($management | is-empty) {
    return { ready: false, role: $role, device: $device, reason: "no management IPv4 address" }
  }

  # A root caller can probe L2 directly even while policy routing selects the other path
  let is_root = ((^id -u | str trim | into int) == 0)
  let cached_mac = (cached-gateway-mac $profile.gateway $device)
  let observed_mac = if $is_root {
    let probe = (run-complete "arping" "-c" "1" "-w" "2" "-I" $device $profile.gateway)
    if $probe.exit_code != 0 {
      return { ready: false, role: $role, device: $device, reason: "gateway unreachable" }
    }
    let probed_mac = ($probe.stdout
      | lines
      | parse --regex `\[(?<mac>[0-9A-Fa-f:]+)\]`
      | get -o 0.mac
      | default "")
    if ($probed_mac | is-empty) { $cached_mac } else { $probed_mac }
  } else if not ($cached_mac | is-empty) {
    $cached_mac
  } else {
    run-complete "ping" "-q" "-c" "1" "-W" "1" "-I" $device $profile.gateway | ignore
    let learned_mac = (cached-gateway-mac $profile.gateway $device)
    if ($learned_mac | is-empty) {
      return { ready: false, role: $role, device: $device, reason: "gateway unreachable" }
    }
    $learned_mac
  }
  let mac = ($observed_mac | str lowercase)
  let expected = ($profile.gateway_mac | str lowercase)
  if $mac != $expected {
    return {
      ready: false
      role: $role
      device: $device
      reason: $"gateway MAC mismatch: expected ($expected), got ($mac | default 'unknown')"
    }
  }

  {
    ready: true
    role: $role
    device: $device
    management_ip: ($management | first)
    gateway_mac: $mac
  }
}


def profile-by-name [config: record, name: string] {
  $config.profiles | where name == $name | get -o 0
}


def matching-paths [config: record, role: string] {
  $config.profiles
  | each {|profile|
      path-devices $profile $role
      | each {|device|
          let status = (path-status $profile $role $device)
          if $status.ready {
            { profile: $profile, role: $role, device: $device, status: $status }
          }
        }
      | compact
    }
  | flatten
}


# Role-wide: first ready device of the role; explicit: `device` must be ready.
def select-path [config: record, role: string, device?: string] {
  let matches = (matching-paths $config $role)
  if ($matches | is-empty) {
    fail $"no configured network has a ready ($role) path"
  }
  if (($matches | get profile.name | uniq | length) > 1) {
    fail $"multiple configured networks match ($role); make gateway MACs unique"
  }
  if ($device | is-empty) {
    return ($matches | first)
  }
  let chosen = ($matches | where device == $device | get -o 0)
  if $chosen == null {
    fail $"($device) is not ready in role ($role)"
  }
  $chosen
}


def read-state [settings: record] {
  if ($settings.state | path exists) { open $settings.state }
}


def write-state [settings: record, state: record] {
  mkdir ($settings.state | path dirname)
  $state | to json | save --force $settings.state
}


def ensure-rule [settings: record] {
  let rules = (^ip -j rule show | from json | where priority == $settings.priority)
  if not ($rules | is-empty) {
    let table = (($rules | first).table | into string)
    if $table != ($settings.table | into string) {
      fail $"routing-rule priority ($settings.priority) is already owned by table ($table)"
    }
    return
  }
  run! "ip" "rule" "add" "priority" ($settings.priority | into string) "lookup" ($settings.table | into string) | ignore
}


def add-vip [profile: record] {
  for device in (profile-devices $profile) {
    if ($"/sys/class/net/($device)" | path exists) {
      run! "ip" "address" "replace" $"($profile.vip)/32" "dev" $device | ignore
    }
  }
}


def check-vip-free [profile: record, device: string] {
  if (local-vip-present $profile.vip) { return }

  let result = (run-complete "arping" "-q" "-D" "-I" $device "-c" "3" "-w" "4" $profile.vip)
  if $result.exit_code != 0 {
    fail $"($profile.vip) answered duplicate-address detection on ($device)"
  }
}


def apply-routes [settings: record, profile: record, device: string] {
  let tbl = ($settings.table | into string)
  # `ip route replace` keys the connected route by device, so switching cards
  # would otherwise accumulate one stale route per card ever used
  for d in (profile-devices $profile) {
    run-complete "ip" "route" "del" "table" $tbl $profile.cidr "dev" $d | ignore
  }
  run! "ip" "route" "replace" "table" $tbl $profile.cidr "dev" $device "src" $profile.vip "proto" "static" | ignore
  run! "ip" "route" "replace" "table" $tbl "default" "via" $profile.gateway "dev" $device "src" $profile.vip "onlink" "proto" "static" | ignore
  run! "ip" "route" "flush" "cache" | ignore
}


def announce [profile: record, device: string] {
  run! "arping" "-q" "-U" "-I" $device "-s" $profile.vip "-c" "1" $profile.gateway | ignore
  run! "arping" "-q" "-A" "-I" $device "-s" $profile.vip "-c" "1" $profile.gateway | ignore
}


def verify [settings: record, profile: record, device: string] {
  let route = (run! "ip" "-j" "route" "get" $settings.probe "from" $profile.vip | from json | first)
  if $route.dev != $device {
    fail $"route verification failed: expected ($profile.vip) via ($device), got ($route.dev)"
  }
  if ($route.table? | default "main") != ($settings.table | into string) {
    fail $"route verification failed: expected policy table ($settings.table), got ($route.table? | default 'main')"
  }

  # The LAN gateway is the make-before-break gate that actually matters: a new
  # link that reaches the gateway routes the shared address. Internet reachability
  # is optional (require_probe) because a momentary uplink outage at the router
  # must not abort switching between two otherwise-healthy LAN paths.
  let gateway_ok = ((run-complete "ping" "-q" "-c" "2" "-W" "2" "-I" $profile.vip $profile.gateway).exit_code == 0)
  if not $gateway_ok {
    fail $"handover verification failed: gateway ($profile.gateway) is unreachable from ($profile.vip)"
  }
  if $settings.require_probe {
    let probe_ok = ((run-complete "ping" "-q" "-c" "2" "-W" "2" "-I" $profile.vip $settings.probe).exit_code == 0)
    if not $probe_ok {
      fail $"handover verification failed: internet probe ($settings.probe) is unreachable from ($profile.vip)"
    }
  }
}


def remove-rule [settings: record] {
  loop {
    let result = (run-complete "ip" "rule" "del" "priority" ($settings.priority | into string) "lookup" ($settings.table | into string))
    if $result.exit_code != 0 { break }
  }
}


def off-internal [config: record] {
  let settings = (routing $config)
  remove-rule $settings
  run-complete "ip" "route" "flush" "table" ($settings.table | into string) | ignore

  for profile in $config.profiles {
    for device in (profile-devices $profile) {
      run-complete "ip" "address" "del" $"($profile.vip)/32" "dev" $device | ignore
    }
  }
  run-complete "ip" "route" "flush" "cache" | ignore
  if ($settings.state | path exists) { rm --force $settings.state }
}


def select-carrier [profile: record, role: string, device?: string] {
  let devices = (path-devices $profile $role)
  if ($devices | is-empty) {
    fail $"role ($role) has no configured devices"
  }
  if ($device | is-empty) {
    for candidate in $devices {
      let status = (path-status $profile $role $candidate)
      if $status.ready {
        return { role: $role, device: $candidate, status: $status }
      }
    }
    fail $"no ready device in role ($role): ($devices | str join ', ')"
  }
  if not ($devices | any {|d| $d == $device }) {
    fail $"($device) is not a configured ($role) device: ($devices | str join ', ')"
  }
  let status = (path-status $profile $role $device)
  if not $status.ready {
    fail $"($device) is not ready: ($status.reason)"
  }
  { role: $role, device: $device, status: $status }
}


def resolve-carrier [config: record, profile: record, role: string] {
  let match = (matching-paths $config $role | where profile.name == $profile.name | get -o 0)
  if $match == null { null } else { $match.device }
}


def switch-to [config: record, profile: record, role: string, device?: string] {
  let settings = (routing $config)
  let carrier = (select-carrier $profile $role $device)
  let target = $carrier.status

  let previous = (read-state $settings)

  try {
    check-vip-free $profile $target.device
    add-vip $profile
    apply-routes $settings $profile $target.device
    ensure-rule $settings
    announce $profile $target.device
    verify $settings $profile $target.device
  } catch {|problem|
    if $previous != null {
      let old_profile = (profile-by-name $config $previous.profile)
      if $old_profile != null {
        let old_device = if ($previous.device? | default "") != "" {
          $previous.device
        } else {
          resolve-carrier $config $old_profile $previous.active
        }
        if $old_device != null {
          apply-routes $settings $old_profile $old_device
          announce $old_profile $old_device
        } else {
          off-internal $config
        }
      } else {
        off-internal $config
      }
    } else {
      off-internal $config
    }
    error make $problem
  }

  write-state $settings {
    profile: $profile.name
    active: $role
    device: $target.device
    switched_at: (date now | format date "%+")
  }
  print $"active: ($profile.name) ($role) via ($target.device), source ($profile.vip)"
  print $"safe to disconnect: ((other-role $role))"
}


def main [] {
  print "usage: netpath {status|check|wifi [device]|ethernet [device]|auto|off|reconcile|self-test}"
}


def status-report [config: record] {
  let state = (read-state (routing $config))
  {
    schema_version: 1
    active: (if $state == null {
      null
    } else {
      {
        profile: $state.profile
        role: $state.active
        device: ($state.device? | default null)
        switched_at: $state.switched_at
      }
    })
    profiles: ($config.profiles | each {|profile|
      {
        name: $profile.name
        vip: $profile.vip
        paths: (["ethernet" "wifi"] | each {|role|
          path-devices $profile $role
          | each {|device|
              let status = (path-status $profile $role $device)
              {
                role: $role
                device: $device
                ready: $status.ready
                reason: ($status.reason? | default null)
                management_ip: ($status.management_ip? | default null)
              }
            }
        } | flatten)
      }
    })
  }
}


def "main status" [--json (-j)] {
  let report = (status-report (load-config))
  if $json {
    print ($report | to json --raw)
    return
  }

  print (if $report.active == null {
    "active: ordinary routing"
  } else {
    $"active: ($report.active.profile) ($report.active.role)"
  })

  for profile in $report.profiles {
    for path in $profile.paths {
      print $"($profile.name) ($path.role) ($path.device): (if $path.ready { 'ready' } else { $path.reason })"
    }
  }
}


def "main check" [] {
  require-root
  let config = (load-config)
  let matches = (["ethernet" "wifi"] | each {|role| matching-paths $config $role } | flatten)
  if ($matches | is-empty) { fail "no configured network is currently reachable" }

  for match in $matches {
    check-vip-free $match.profile $match.device
    print $"ok: ($match.profile.name) ($match.role) ($match.device), VIP ($match.profile.vip) available"
  }
}


def "main ethernet" [device?: string] {
  require-root
  let config = (load-config)
  let match = (select-path $config "ethernet" $device)
  switch-to $config $match.profile "ethernet" $match.device
}


def "main wifi" [device?: string] {
  require-root
  let config = (load-config)
  let match = (select-path $config "wifi" $device)
  switch-to $config $match.profile "wifi" $match.device
}


def "main auto" [] {
  require-root
  let config = (load-config)
  for role in ["ethernet" "wifi"] {
    let matches = (matching-paths $config $role)
    if not ($matches | is-empty) {
      let match = ($matches | first)
      switch-to $config $match.profile $role $match.device
      return
    }
  }

  off-internal $config
  print "no configured network found; using ordinary routing"
}


def "main off" [] {
  require-root
  let config = (load-config)
  off-internal $config
  print "active: ordinary routing"
}


def try-switch [config: record, profile: record, role: string, device?: string] {
  try {
    switch-to $config $profile $role $device
    true
  } catch {
    false
  }
}


def "main reconcile" [] {
  require-root
  let config = (load-config)
  let settings = (routing $config)
  let state = (read-state $settings)
  if $state == null { return }

  let profile = (profile-by-name $config $state.profile)
  if $profile == null {
    off-internal $config
    return
  }

  let active_role = $state.active
  let recorded = ($state.device? | default "")
  let active_ok = if ($recorded == "") {
    path-devices $profile $active_role
    | any {|device| (path-status $profile $active_role $device).ready }
  } else {
    (path-status $profile $active_role $recorded).ready
  }
  if $active_ok { return }

  # move within the same role first (another NIC of the same kind)
  mut did = false
  for device in (path-devices $profile $active_role) {
    if $device == $recorded { continue }
    if (try-switch $config $profile $active_role $device) {
      $did = true
      break
    }
  }
  if $did { return }

  # fall back to the other role
  if (try-switch $config $profile (other-role $active_role)) { return }

  off-internal $config
}


def "main self-test" [] {
  let profile = {
    name: "test"
    vip: "192.0.2.50"
    gateway: "192.0.2.1"
    gateway_mac: "00:11:22:33:44:55"
    cidr: "192.0.2.0/24"
    paths: { ethernet: "eth-test", wifi: "wifi-test" }
  }
  let multi = {
    name: "multi"
    vip: "192.0.2.51"
    gateway: "192.0.2.1"
    gateway_mac: "00:11:22:33:44:55"
    cidr: "192.0.2.0/24"
    paths: { ethernet: ["eth-a" "eth-b"], wifi: "wifi-a" }
  }
  let checks = [
    ((path-devices $profile "ethernet") == ["eth-test"])
    ((path-devices $multi "ethernet") == ["eth-a" "eth-b"])
    ((path-devices $multi "wifi") == ["wifi-a"])
    ((path-devices $multi "ethernet") == ["eth-a" "eth-b"])
    ((profile-devices $multi | sort) == (["eth-a" "eth-b" "wifi-a"] | sort))
    ((other-role "ethernet") == "wifi")
    (((routing { profiles: [$profile] }).table) == 100)
  ]
  if ($checks | any {|check| not $check }) { fail "self-test failed" }
  print "ok"
}