{
  pkgs,
  lib,
  ...
}:

{
  age.secrets."ca.yubikey" = {
    intermediary = true;
    rekeyFile = lib.custom.repoSecret "home/jeeves/certs/CA.yubikey.age";
    generator.script =
      {
        lib,
        pkgs,
        file,
        ...
      }:
      let
        caCert = dirOf file + "/CA.pem";
        # NOTE: as per `yubico-piv-tool --help`:
        #       `9c is for Digital Signature (PIN always checked)`
        piv-slot = "9c";
        openssl-pkcs11 = lib.getExe pkgs.custom.openssl-pkcs11;
        ykman = lib.getExe pkgs.yubikey-manager;
      in
      /* bash */ ''
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        ca_cert=${lib.escapeShellArg caCert}
        mkdir -p "$(dirname "$ca_cert")"

        if ${ykman} piv keys info ${piv-slot} >/dev/null 2>&1; then
          echo '==> Jeeves CA: exporting public key from YubiKey slot ${piv-slot}' >&2
          ${ykman} piv keys export ${piv-slot} "$tmp/CA.pub.pem"
        else
          echo '==> Jeeves CA: generating CA key on YubiKey slot ${piv-slot}' >&2
          ${ykman} piv keys generate \
            --algorithm eccp256 \
            --pin-policy always \
            --touch-policy always \
            ${piv-slot} "$tmp/CA.pub.pem"
        fi
        cat > "$tmp/CA.cnf" <<'INI'
        [v3_ca]
        subjectKeyIdentifier=hash
        authorityKeyIdentifier=keyid:always,issuer
        basicConstraints=critical,CA:true
        keyUsage=critical,keyCertSign,cRLSign
        INI

        echo '==> Jeeves CA: generating self-signed CA cert with YubiKey slot ${piv-slot}' >&2
        ${openssl-pkcs11} x509 -new \
          -key 'pkcs11:object=SIGN%20key;type=private' \
          -force_pubkey "$tmp/CA.pub.pem" \
          -subj "/CN=Jeeves Local CA" \
          -days 365000 \
          -sha256 \
          -set_serial "0x$(${lib.getExe pkgs.openssl} rand -hex 20)" \
          -out "$tmp/CA.pem" \
          -extensions v3_ca \
          -extfile "$tmp/CA.cnf"
        echo '==> Jeeves CA: importing CA cert into YubiKey slot ${piv-slot}' >&2
        ${ykman} piv certificates import \
          --verify \
          --no-update-chuid \
          ${piv-slot} "$tmp/CA.pem"
        echo '==> Jeeves CA: exporting CA.pem from YubiKey slot ${piv-slot}' >&2
        ${ykman} piv certificates export ${piv-slot} "$ca_cert"

        echo "yubikey-piv-slot=${piv-slot}"
        echo "pkcs11-uri=pkcs11:object=SIGN%20key;type=private"
      '';
  };
}
