#!/bin/bash
# Creates a self-signed code-signing certificate in the login keychain so that
# macOS keeps ScreenChest's Screen Recording permission across rebuilds.
# Run once: ./scripts/create-signing-identity.sh
set -euo pipefail

NAME="${1:-ScreenChest Dev}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
  echo "Identity \"$NAME\" already exists."
  exit 0
fi

cat > "$WORK/config" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CONF

OPENSSL=/usr/bin/openssl
$OPENSSL req -x509 -newkey rsa:2048 -nodes -days 3650 -sha256 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/config" >/dev/null 2>&1
$OPENSSL pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -out "$WORK/identity.p12" -passout pass:screenchest -name "$NAME" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 >/dev/null 2>&1

security import "$WORK/identity.p12" -k "$KEYCHAIN" -P screenchest -T /usr/bin/codesign -T /usr/bin/security >/dev/null
echo "Imported \"$NAME\" into the login keychain."
echo "macOS will now ask for your login password to trust it for code signing."
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
  echo "Done. 'make run' will sign with \"$NAME\" from now on."
  echo "The first codesign may show a keychain prompt: choose \"Always Allow\"."
else
  echo "The identity was imported but is not yet valid for code signing." >&2
  exit 1
fi
