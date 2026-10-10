"""Check generated integrations in temporary homes/repositories, never live state."""

import fcntl
import json
import os
import pty
import re
import select
import shlex
import shutil
import statistics
import subprocess
import sys
import tempfile
import termios
import time
from pathlib import Path

import tomllib

ANSI_SEQUENCE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
generated = Path(sys.argv[1])
manifest = json.loads((generated / "manifest.json").read_text())
binaries = manifest["binaries"]

with tempfile.TemporaryDirectory(prefix="rix101-shell-integration-") as directory:
    root = Path(directory)
    home = root / "home"
    environment = {
        name: value
        for name, value in os.environ.items()
        if not name.startswith(
            ("ATUIN_", "STARSHIP_", "JJ_", "GIT_", "ZOXIDE_", "DIRENV_")
        )
        and name not in ("GHOSTTY_RESOURCES_DIR", "IN_NIX_SHELL")
    }
    environment.update(
        {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_CACHE_HOME": str(home / ".cache"),
            "XDG_RUNTIME_DIR": str(root / "runtime"),
            "ZDOTDIR": str(home / ".config/zsh"),
            "GNUPGHOME": str(home / ".gnupg"),
            "ATUIN_CONFIG_DIR": str(home / ".config/atuin"),
            "NIX_PROFILES": "",
            "SHLVL": "10",
            "SSH_CONNECTION": "",
            "SSH_AUTH_SOCK": "",
            "TERM": "xterm-256color",
            "STARSHIP_SHELL": "zsh",
            "PATH": ":".join(str(Path(binary).parent) for binary in binaries.values())
            + ":"
            + environment["PATH"],
        }
    )
    for name in (
        "HOME",
        "XDG_CONFIG_HOME",
        "XDG_DATA_HOME",
        "XDG_CACHE_HOME",
        "XDG_RUNTIME_DIR",
        "GNUPGHOME",
        "ATUIN_CONFIG_DIR",
    ):
        Path(environment[name]).mkdir(parents=True, mode=0o700, exist_ok=True)
    # Observe the asynchronous TTY update without launching a real GPG agent.
    agent = root / "gpg-connect-agent"
    agent.write_text(
        f'#!{binaries["zsh"]} -f\nprint -r -- "$GPG_TTY" > "$GPG_TEST_OUTPUT"\n'
    )
    agent.chmod(0o700)
    environment["GPG_TEST_OUTPUT"] = str(root / "agent-tty")
    for name in ("zshrc", "config.nu", "env.nu", "starship.toml", "atuin.toml"):
        text = (
            (generated / name).read_text().replace(manifest["homeDirectory"], str(home))
        )
        text = re.sub(r"/nix/store/\S*/bin/gpg-connect-agent", str(agent), text)
        if name == "atuin.toml":
            text = re.sub(r"(?m)^auto_sync\s*=\s*true$", "auto_sync = false", text)
            assert not tomllib.loads(text)["auto_sync"]
        (root / name).write_text(text)
    shutil.copy2(
        root / "atuin.toml", Path(environment["ATUIN_CONFIG_DIR"]) / "config.toml"
    )
    shutil.copy2(
        root / "starship.toml", Path(environment["XDG_CONFIG_HOME"]) / "starship.toml"
    )
    environment["STARSHIP_CONFIG"] = str(root / "starship.toml")
    schema_path = (
        Path(binaries["starship"]).parent.parent / "share/starship/config-schema.json"
    )
    assert tomllib.loads((root / "starship.toml").read_text())["$schema"] == (
        f"file://{schema_path}"
    )
    assert {"jj_bookmark", "jj_change", "jj_metrics", "jj_status"} <= set(
        json.loads(schema_path.read_text())["properties"]
    )
    for plugin in manifest["plugins"]:
        target = home / ".config/zsh/plugins" / plugin["name"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(plugin["source"])

    def run(arguments, cwd=root):
        result = subprocess.run(
            arguments,
            cwd=cwd,
            env=environment | {"PWD": str(cwd)},
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert result.returncode == 0, (arguments, result.stdout, result.stderr)
        assert "Error parsing" not in result.stderr, result.stderr
        return ANSI_SEQUENCE.sub("", result.stdout).replace("%{%}", "").strip()

    def run_terminal(arguments, commands=b""):
        master, slave = pty.openpty()

        def configure_terminal():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        process = subprocess.Popen(
            arguments,
            cwd=root,
            env=environment | {"PWD": str(root)},
            stdin=slave,
            stdout=slave,
            stderr=slave,
            # This test is single-threaded; the child needs a controlling TTY.
            preexec_fn=configure_terminal,  # noqa: PLW1509
        )
        os.close(slave)
        output = bytearray()
        try:
            os.write(master, commands)
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        data = os.read(master, 65536)
                    except OSError:
                        break
                    if not data:
                        break
                    output.extend(data)
                    if b"\x1b[6n" in data:
                        os.write(master, b"\x1b[1;1R")
                elif process.poll() is not None:
                    break
            assert process.wait(timeout=1) == 0, output.decode(errors="replace")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)
        rendered = output.decode(errors="replace")
        terminal = re.search(r"__GPG_TTY__(/dev/[^\s]+)", rendered)
        assert terminal, rendered
        assert Path(environment["GPG_TEST_OUTPUT"]).read_text().strip() == terminal[1]
        return rendered

    for shell in ("nu", "zsh"):
        initialization = run([binaries["starship"], "init", shell])
        assert (
            binaries["starship"] in initialization
            and ".starship-wrapped" not in initialization
        )
    sources = list(dict.fromkeys(re.findall(
        r"source (/nix/store/\S*rix101-shell-zsh-\S*/init\.zsh)",
        (root / "zshrc").read_text(),
    )))
    assert len(sources) == 5
    for source in sources:
        assert Path(source + ".zwc").is_file()
    run(
        [
            binaries["zsh"],
            "-dfi",
            "-c",
            f'source "{root / "zshrc"}"; (( $+functions[zvm_init] && $+functions[_zsh_autosuggest_bind_widgets] && $+widgets[atuin-search-viins] )) && [[ $_comps[nix] != _carapace_completer ]]',
        ]
    )
    completion_directories = []
    for version in ("first", "second"):
        data_directory = root / f"completion {version}"
        functions = data_directory / "zsh/site-functions"
        functions.mkdir(parents=True)
        (functions / "_environment_complete").write_text(
            f"#compdef environment-command\nprint -r -- {version}\n"
        )
        completion_directories.append(data_directory)
    completion_test = f'''
        source {shlex.quote(str(root / "zshrc"))}
        setopt errexit
        (( $precmd_functions[(Ie)_direnv_hook] < $precmd_functions[(Ie)_rix101_completion_refresh] ))
        original_git_handler=$_comps[git]
        original_key_binding=$(bindkey -M viins '^R')
        original_data_directories=${{XDG_DATA_DIRS-}}
        export XDG_DATA_DIRS={shlex.quote(str(completion_directories[0]))}:$original_data_directories
        _rix101_completion_refresh
        [[ $_comps[environment-command] == _environment_complete ]]
        [[ "$(_environment_complete)" == first ]]
        _environment_complete > /dev/null
        export XDG_DATA_DIRS={shlex.quote(str(completion_directories[1]))}:$original_data_directories
        _rix101_completion_refresh
        [[ "$(_environment_complete)" == second ]]
        _environment_complete > /dev/null
        [[ $_comps[git] == $original_git_handler ]]
        [[ "$(bindkey -M viins '^R')" == "$original_key_binding" ]]
        export XDG_DATA_DIRS=$original_data_directories
        _rix101_completion_refresh
        [[ ! -v '_comps[environment-command]' ]]
        [[ $_comps[git] == $original_git_handler ]]
    '''
    run([binaries["zsh"], "-dfi", "-c", completion_test])
    terminal_state = run_terminal(
        [binaries["zsh"], "-dfi"],
        (
            f'source "{root / "zshrc"}"\n'
            'print -r -- "__GPG_TTY__$GPG_TTY"; bindkey -M viins "^R"; print -r -- "__KEYMAP__$widgets[zle-keymap-select]"\n'
            "exit\n"
        ).encode(),
    )
    assert (
        "atuin-search-viins" in terminal_state
        and "starship_zle-keymap-select" in terminal_state
    )
    run_terminal(
        [
            binaries["nushell"],
            "--no-config-file",
            "-i",
            "-c",
            f'''
        source "{root / "env.nu"}"
        source "{root / "config.nu"}"
        sleep 200ms
        print $"__GPG_TTY__($env.GPG_TTY)"
    ''',
        ]
    )
    state = json.loads(
        run(
            [
                binaries["nushell"],
                "--no-config-file",
                "-c",
                f'''
        source "{root / "env.nu"}"
        source "{root / "config.nu"}"
        {{ insert: (do $env.PROMPT_INDICATOR_VI_INSERT), normal: (do $env.PROMPT_INDICATOR_VI_NORMAL),
           right_empty: ($env.PROMPT_COMMAND_RIGHT | is-empty),
           private_history: $env.config.history.ignore_space_prefixed,
           bindings: ($env.config.keybindings | get name), starship_config: $env.STARSHIP_CONFIG,
           nix_completion_empty: (do $env.config.completions.external.completer [nix shell 'nixpkgs#he'] | is-empty) }} | to json
    ''',
            ]
        )
    )
    assert (
        state["insert"] != state["normal"]
        and state["right_empty"]
        and state["private_history"]
        and state["nix_completion_empty"]
    )
    assert {"copy_commandline", "copy_formatted_commandline", "atuin"} <= set(
        state["bindings"]
    )
    assert tomllib.loads(Path(state["starship_config"]).read_text())["character"][
        "disabled"
    ]
    for component, symbol in (
        ("doom", "𝓔"),
        ("emacs", "𝓔"),
        ("Home", "🏠"),
        (".config", ""),
        ("nvim", ""),
        ("doom-project", "doom-project"),
        ("nvim-project", "nvim-project"),
        ("not.config", "not.config"),
    ):
        path = home / component
        path.mkdir(exist_ok=True)
        rendered = run([binaries["starship"], "module", "directory"], cwd=path)
        assert symbol in rendered, (component, symbol, rendered)
    status = run([binaries["starship"], "module", "status", "--status", "1"])
    assert "[" in status and "]" in status
    character = run([binaries["starship"], "module", "character", "--keymap", "vicmd"])
    assert "" in character
    jj_repository = root / "jj-repository"
    run([binaries["jujutsu"], "git", "init", "--colocate", str(jj_repository)])
    (jj_repository / "example.txt").write_text("fixture\n")
    run(
        [
            binaries["jujutsu"],
            "--config",
            'user.name="Regression"',
            "--config",
            'user.email="regression@example.invalid"',
            "describe",
            "-m",
            "fixture",
        ],
        cwd=jj_repository,
    )
    run([binaries["jujutsu"], "new"], cwd=jj_repository)
    change = run(
        [
            binaries["jujutsu"],
            "log",
            "--no-graph",
            "--color=never",
            "-r",
            "@",
            "-T",
            "change_id.short(6)",
        ],
        cwd=jj_repository,
    )
    commit = run(
        [
            binaries["jujutsu"],
            "log",
            "--no-graph",
            "--color=never",
            "-r",
            "@-",
            "-T",
            "commit_id.short(6)",
        ],
        cwd=jj_repository,
    )
    assert change in run([binaries["starship"], "module", "vcs"], cwd=jj_repository)
    original_path = environment["PATH"]
    try:
        # The Starship wrapper, not the surrounding profile, must provide jj.
        environment["PATH"] = ""
        assert change in run([binaries["starship"], "module", "vcs"], cwd=jj_repository)
    finally:
        environment["PATH"] = original_path
    # Copy only the Git fixture to exercise fallback without mutating Git metadata.
    git_repository = root / "git-repository"
    shutil.copytree(jj_repository / ".git", git_repository / ".git")
    shutil.copy2(jj_repository / "example.txt", git_repository / "example.txt")
    assert commit in run([binaries["starship"], "module", "vcs"], cwd=git_repository)
    prompt = run([binaries["starship"], "prompt", "--status", "1"], cwd=jj_repository)
    assert all(segment in prompt for segment in ("╭", "│", "╰", change)), (
        change,
        prompt,
    )

    if "--benchmark" in sys.argv[2:]:
        initialization_commands = {
            "atuin": "init zsh --disable-ctrl-r --disable-up-arrow --disable-ai",
            "carapace": "_carapace zsh",
            "direnv": "hook zsh",
            "starship": "init zsh",
            "zoxide": "init zsh",
        }
        scripts = {
            "compiled store init": "\n".join(
                f"source {shlex.quote(source)}" for source in sources
            ),
            "runtime init generation": "\n".join(
                f'eval "$({shlex.quote(binaries[name])} {arguments})"'
                for name, arguments in initialization_commands.items()
            ),
        }
        samples = {name: [] for name in scripts}
        for iteration in range(12):
            for name, script in scripts.items():
                start = time.perf_counter()
                run(
                    [
                        binaries["zsh"],
                        "-dfi",
                        "-c",
                        'autoload -Uz compinit; compinit -C -d "$XDG_CACHE_HOME/benchmark-zcompdump";\n'
                        + script,
                    ]
                )
                if iteration >= 2:
                    samples[name].append((time.perf_counter() - start) * 1000)
        for name, durations in samples.items():
            print(
                f"warm init-only median, {name}: {statistics.median(durations):.1f} ms"
            )

print("generated shell/native VCS integration checks passed")
