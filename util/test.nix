# { lib, stdenv, darwin, fetchFromGitHub, rustPlatform, openssl, pkg-config, libxkbcommon }:

# # rustPlatform.buildRustPackage rec {
# rec {
#   pname = "vim-fmi-cli";
#   version = "0.2.0";
#
#   src = fetchFromGitHub {
#     owner = "AndrewRadev";
#     repo = pname;
#     rev = "v${version}";
#     sha256 = "sha256-RAlvDiNvDVRNtex0aD8WESc4R/lskjda;sldfjmAr7FjWtgzHWa4ZSI=";
#   };
# }

# {
#   a = ''''\'''${a}''\''';
#
#   src = fetchFromGitHub {
#     owner = "g15ecb";
#     repo = "promela-mode";
#     rev = "53863e62cfedcd0466e1e19b1ca7b5786cb7a576";
#     # hash = "sha256-pOVIOj5XnZcNVFNyjMV7Iv0X+R+W+mQfT1o5nay2Kww=";
#   };
# }

# let
#   a = "v${b}.${c}.${d}";
#   b = "2";
#   c = "3";
#   d = "6";
#   rev = a;
# in
# rec {
#   src = fetchTest {
#     inherit a b c rev;
#   };
#   rev = "aloda";
#   alo = da;
# }

let
  # kek
  type = "256";
in
let
in
rec {
  pname = "vim-fmi-cli";
  version = "0.2.0";
  sha = "RAlvDiNvDVRNtex0aD8WESc4R/mAr7FjWtgzHWa4ZSI=";
  sha256 = "sha${type}-${sha}";

  kek = let
  in rec {};

  src = fetchFromGitHub {
    owner = "AndrewRadev";
    repo = pname;
    rev = "v${version}";
    inherit sha256;
  };
}

# let
#   bb = "2";
#   b = bb;
# in
# let
#   # ...
# in
#   fetchTest {
#     a = "1";
#     inherit b;
#     c = "3";
#     rev = "456";
#   }

# let
#   f = "2";
#   s = "3";
#   t = "4";
#   a = "1";
#   c = "2";
#   v = "${f}.${s}.${t}";
#   kek = rec {
#     x = "5";
#     y = x;
#   };
#   aloda = fetchTest rec {
#     c = b;
#     a = "2";
#     b = a;
#     rev = "v${c}";
#   };
# in
#   fetchTest {
#     inherit a c;
#     m = a;
#     b = "b";
#     aloda = "${a}b${c}d";
#     rev = "v${v}";
#   }
