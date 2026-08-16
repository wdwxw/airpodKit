#!/bin/bash
# Ensures a stable, locally-trusted code signing identity exists so that
# Accessibility / Input Monitoring grants survive across rebuilds during
# development. Ad-hoc signing ("-") produces a different identity on every
# build, which makes macOS TCC forget the grant and re-prompt each time;
# signing consistently with this local certificate keeps the same identity,
# so you only need to grant permissions once.
#
# Idempotent: does nothing if the certificate already exists.

set -euo pipefail

CERT_NAME="AirPodKit Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "Signing identity '$CERT_NAME' already exists — nothing to do."
  exit 0
fi

echo "Creating local code signing identity '$CERT_NAME'..."

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

openssl req -x509 -newkey rsa:2048 \
  -keyout "$WORKDIR/key.pem" -out "$WORKDIR/cert.pem" \
  -days 3650 -nodes -subj "/CN=$CERT_NAME" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature"

openssl pkcs12 -export -legacy \
  -out "$WORKDIR/cert.p12" \
  -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" \
  -passout pass:airpodkit

# -T grants codesign access to the private key without a "always allow" prompt.
security import "$WORKDIR/cert.p12" -k "$KEYCHAIN" -P airpodkit -T /usr/bin/codesign -T /usr/bin/security

# Trust the cert for code signing on this machine only (not distributed).
# (User-domain trust setting — no sudo/admin store needed.)
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORKDIR/cert.pem"

echo "Done. If macOS prompts once to allow 'codesign' to use this key, click Always Allow."
