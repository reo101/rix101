# git-credential helper: environment variables, in Uiua.
# 
# Compiled to a standalone binary at build time via
# `uiua stand` — no interpreter, no runtime formatting.
# Each keyword maps to its GIT_ prefixed, uppercase variable.
# Missing or empty variables → no useful output,
# exit 0 → git/jj fall back to interactive prompting.

# Experimental!
# Type check!

# &var that yields "" instead of throwing when unset
Get ← ⊨⊙(⍣&var"") {𝕌∞} ⊨{𝕌∞}

K ← {"username" "password"}

# ASCII lowercase keywords → GIT_ prefixed variable values
V ← ⊨⊙(⍚(Get⊂"GIT_"-₃₂) K) {{𝕌∞} ⧻K}

# payload = "keyword=value" lines joined by \n
W ← ⊨⊙(/◇⊂₃"\n"⍚(⊂₃⊙"=") K V) {𝕌∞}

# emit nothing unless ALL vars are non-empty
C ← ⊨⊙(¬/∨ ≡◇(=₀⧻) V) 𝔹
&p ⨬""∘ C W
