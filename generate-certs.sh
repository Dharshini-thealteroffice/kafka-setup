set -euo pipefail

SECRETS_DIR="$(cd "$(dirname "$0")" && pwd)/secrets"
mkdir -p "$SECRETS_DIR"

DAYS=3650
CONTROLLER_CN="kafka-controller"
BROKER_CN="kafka-broker"

# 1. Certificate Authority 
echo "→ Generating CA key & self-signed cert..."
openssl genrsa -out "$SECRETS_DIR/ca.key" 4096

openssl req -new -x509 \
  -key "$SECRETS_DIR/ca.key" \
  -out "$SECRETS_DIR/ca.crt" \
  -days "$DAYS" \
  -subj "//C=US\ST=State\L=City\O=Kafka\CN=KafkaCA"

# Helper: generate key, sign cert, produce combined .pem 
sign_cert() {
  local NAME="$1"
  local CN="$2"

  echo "→ Generating key & CSR for $NAME..."
  openssl genrsa -out "$SECRETS_DIR/$NAME.key" 2048

  local SAN_CONF
  SAN_CONF=$(mktemp)
  cat > "$SAN_CONF" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CN
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF

  openssl req -new \
    -key "$SECRETS_DIR/$NAME.key" \
    -out "$SECRETS_DIR/$NAME.csr" \
    -subj "//C=US\ST=State\L=City\O=Kafka\CN=$CN" \
    -config "$SAN_CONF"

  echo "→ Signing $NAME cert with CA..."
  openssl x509 -req \
    -in "$SECRETS_DIR/$NAME.csr" \
    -CA "$SECRETS_DIR/ca.crt" \
    -CAkey "$SECRETS_DIR/ca.key" \
    -CAcreateserial \
    -out "$SECRETS_DIR/$NAME.crt" \
    -days "$DAYS" \
    -extensions v3_req \
    -extfile "$SAN_CONF"

  # Produce the combined PEM file 
  cat "$SECRETS_DIR/$NAME.key" "$SECRETS_DIR/$NAME.crt" > "$SECRETS_DIR/$NAME.pem"
  chmod 600 "$SECRETS_DIR/$NAME.pem"

  rm -f "$SAN_CONF" "$SECRETS_DIR/$NAME.csr"
  echo "✔  $NAME.pem (combined keystore) OK"
}

# 2. Controller 
sign_cert "controller" "$CONTROLLER_CN"

# 3. Broker 
sign_cert "broker" "$BROKER_CN"

# 5. Verify chain 
echo "→ Verifying certificate chains..."
for ENTITY in controller broker; do
  if openssl verify -CAfile "$SECRETS_DIR/ca.crt" "$SECRETS_DIR/$ENTITY.crt" > /dev/null 2>&1; then
    echo "✔  $ENTITY.crt chain valid"
  else
    echo "✗  $ENTITY.crt chain FAILED"
    exit 1
  fi
done