# Kafka KRaft Cluster with SSL & SCRAM Authentication

This repository provides a **KRaft-mode Kafka cluster** with **SSL encryption** and **SCRAM authentication**, deployed via Docker Compose. The cluster includes:

- 1 **Controller**
- 1 **Broker**
- **Client certificates** for secure connections

---

## 1️⃣ Generate Certificates

Before starting the cluster, generate certificates for all components:

```bash
./generate-certs.sh
```

**What this does:**

- Creates a Certificate Authority (CA) (`secrets/ca.crt` and `secrets/ca.key`)
- Generates controller and broker certificates with private keys
- Combines key and certificate into PEM files (`controller.pem` & `broker.pem`)
- Adds Subject Alternative Names (SANs) for hostnames and localhost
- Verifies certificate chains to ensure trust between components

**Why:** Kafka KRaft requires mutual TLS (mTLS) for secure communication between controller, broker.

---

## 2️⃣ Create a `.env` File

Create a `.env` file in the repository root:

```env
CLUSTER_ID=YOUR_CLUSTER_ID
ADMIN_USERNAME=admin
ADMIN_PASSWORD=strongpassword
```

- `CLUSTER_ID` — Unique identifier for the Kafka KRaft cluster
- `ADMIN_USERNAME` / `ADMIN_PASSWORD` — Kafka superuser credentials

**Why:** Keeps sensitive information secure and allows Docker Compose to inject it into the containers.

---

## 3️⃣ Start the Cluster

Run the cluster:

```bash
docker-compose up -d
```

- **Controller** manages metadata
- **Broker** handles messages, topics, and client connections
- **Volumes** provide persistent storagegit 

**Why:** Ensures the cluster runs with SSL + SASL authentication and correct configuration.

---

## 4️⃣ Kafka Server JAAS Configuration

The `kafka_server_jaas.conf` defines SASL authentication:

```
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required;
};
```

**Why:** Enables SCRAM-SHA-256 authentication for clients connecting to the broker.

---

## 5️⃣ Verify the Setup

Check container logs:

```bash
docker logs -f kafka-controller
docker logs -f kafka-broker
```

---

## 6️⃣ Important Notes

- Do not share private keys (`*.key` files)
- Certificates expire after 10 years (adjustable in `generate-certs.sh`)
- Cluster ID must remain consistent across restarts
- Superuser credentials and ACLs are managed via the `.env` file