let
  name = "sub";
in
{
  age.secrets."${name}.tls.key" = {
    mode = "0400";
    rekeyFile = lib.custom.repoSecret "home/jeeves/certs/${name}.key.age";
    generator = {
      dependencies = {
        ca = config.age.secrets."ca.yubikey";
      };
      script =
        {
          lib,
          pkgs,
          file,
          deps,
          ...
        }:
        let
          caCert = builtins.dirOf deps.ca.file + "/CA.pem";
          cert = builtins.dirOf file + "/${name}.pem";
          openssl-pkcs11 = lib.getExe pkgs.custom.openssl-pkcs11;
        in
        /* bash */ ''
          tmp=$(mktemp -d)
          trap 'rm -rf "$tmp"' EXIT
          ca_cert=${lib.escapeShellArg caCert}
          cert=${lib.escapeShellArg cert}
          mkdir -p "$(dirname "$cert")"

          cat > "$tmp/leaf.cnf" <<'INI'
          [v3_req]
          subjectKeyIdentifier=hash
          authorityKeyIdentifier=keyid,issuer
          basicConstraints=critical,CA:false
          keyUsage=critical,digitalSignature,keyEncipherment
          extendedKeyUsage=serverAuth
          subjectAltName=DNS:localhost,IP:127.0.0.1
          INI

          echo '==> ${name} TLS: generating local leaf key + CSR' >&2
          ${lib.getExe pkgs.openssl} req -newkey rsa:2048 -nodes \
            -keyout "$tmp/${name}.key" \
            -out "$tmp/${name}.csr" \
            -subj "/CN=localhost"

          echo '==> ${name} TLS: signing leaf cert with YubiKey CA' >&2
          ${openssl-pkcs11} x509 -req \
            -in "$tmp/${name}.csr" \
            -CA "$ca_cert" \
            -CAkey 'pkcs11:object=SIGN%20key;type=private' \
            -CAcreateserial \
            -out "$cert" \
            -days 365000 \
            -sha256 \
            -extensions v3_req \
            -extfile "$tmp/leaf.cnf"

          cat "$tmp/${name}.key"
        '';
    };
  };

  age.secrets."${name}.tls.pem" = {
    mode = "0400";
    rekeyFile = lib.custom.repoSecret "home/jeeves/certs/${name}.pem.age";
    generator = {
      dependencies = {
        key = config.age.secrets."${name}.tls.key";
      };
      script =
        {
          lib,
          pkgs,
          file,
          deps,
          ...
        }:
        let
          cert = builtins.dirOf deps.key.file + "/${name}.pem";
        in
        /* bash */ ''
          cat ${lib.escapeShellArg cert}
        '';
    };
  };
}
