# GCP Environment Setup Guide

## Step 1: Prerequisites
Before creating the network endpoint group, ensure the following GCP resources are already configured:
- A VPC network named `f5-vpc-bigip-outside`.
- A subnet within this network named `f5-bigip-outside`.
- Instances `f5-bigip1` and `f5-bigip2` should have alias IP addresses configured: `10.1.2.16` and `10.1.2.17`, respectively, both using port `443`.

Now, create a network endpoint group `f5-neg1` in the `us-east4-c` zone with the default port 443.
```bash
gcloud compute network-endpoint-groups create f5-neg1 \
--zone=us-east4-c \
--network=f5-vpc-bigip-outside \
--subnet=f5-bigip-outside \
--default-port=443
```

## Step 2: Update the Network Endpoint Group
Add two instances with specified IPs to the `f5-neg1` group.
```bash
gcloud compute network-endpoint-groups update f5-neg1 \
--zone=us-east4-c \
--add-endpoint 'instance=f5-bigip1,ip=10.1.2.16,port=443' \
--add-endpoint 'instance=f5-bigip2,ip=10.1.2.17,port=443'
```

## Step 3: Create a Health Check
Set up an HTTP health check `f5-healthcheck1` that uses the serving port.
```bash
gcloud compute health-checks create http f5-healthcheck1 \
--use-serving-port
```

## Step 4: Create a Backend Service
Configure a global backend service `f5-backendservice1` with TCP protocol and attach the earlier health check.
```bash
gcloud compute backend-services create f5-backendservice1 \
--global \
--health-checks=f5-healthcheck1 \
--protocol=TCP
```

## Step 5: Add Backend to the Backend Service
Link the network endpoint group `f5-neg1` to the backend service.
```bash
gcloud compute backend-services add-backend f5-backendservice1 \
    --global \
    --network-endpoint-group=f5-neg1 \
    --network-endpoint-group-zone=us-east4-a \
	--balancing-mode=CONNECTION \
    --max-connections=5
```

## Step 6: Create a Target TCP Proxy
Create a global target TCP proxy `f5-tcpproxy1` to handle routing to `f5-backendservice1`.
```bash
gcloud compute target-tcp-proxies create f5-tcpproxy1 \
--backend-service=f5-backendservice1 \
--proxy-header=PROXY_V1 \
--global
```

## Step 7: Create a Forwarding Rule
Establish a global forwarding rule `f5-tcp-forwardingrule1` for TCP traffic on port 443.
```bash
gcloud compute forwarding-rules create f5-tcp-forwardingrule1 \
--ip-protocol TCP \
--ports=443 \
--global \
--target-tcp-proxy=f5-tcpproxy1
```

## Step 8: Create a Firewall Rule
Allow ingress traffic on specific ports for health checks with the rule `allow-lb-health-checks`.
```bash
gcloud compute firewall-rules create allow-lb-health-checks \
    --direction=INGRESS \
    --priority=1000 \
    --network=f5-vpc-bigip-outside \
    --action=ALLOW \
    --rules=tcp:80,tcp:443,tcp:8080,icmp \
    --source-ranges=35.191.0.0/16,130.211.0.0/22 \
    --target-tags=allow-health-checks
```

## Step 9: Add Tags to Instances
Tag instances `f5-bigip1` and `f5-bigip2` to include them in health checks.
```bash
gcloud compute instances add-tags f5-bigip1 --tags=allow-health-checks --zone=us-east4-c
gcloud compute instances add-tags f5-bigip2 --tags=allow-health-checks --zone=us-east4-c
```

## [WORK-IN-PROGRESS / UNTESTED] Step 10: Proxy Protocol v1 => X-Forwarded-For HTTP Header iRule
```tcl
when CLIENT_ACCEPTED {
    # Extract the client's original IP from the Proxy Protocol header
    set original_ip [IP::client_addr]
    # Insert the X-Forwarded-For header with the original IP
    HTTP::header insert X-Forwarded-For $original_ip
    log local0. "Preserved Client IP: $original_ip via Proxy Protocol to XFF"
}
```
# Network Diagram for GCP and F5 BIG-IP Configuration

This diagram illustrates how client traffic is managed through the GCP Global Load Balancer and processed by F5 BIG-IP instances before reaching the backend services.

```mermaid
graph LR
    A[Client] -->|TCP/443| B(GCP Global Load Balancer)
    B -->|Proxy Protocol V1| C{F5 BIG-IP Instances}
    C -->|Insert X-Forwarded-For| D[Backend Pool Member Services]

    subgraph "GCP Environment"
    B
    C
    D
    end

    subgraph "F5 BIG-IP Instances"
    F5_1[F5 BIG-IP 1 - 10.1.2.16]
    F5_2[F5 BIG-IP 2 - 10.1.2.17]
    end

    classDef gcp fill:#f9f,stroke:#333,stroke-width:2px;
    classDef f5 fill:#ccf,stroke:#333,stroke-width:2px;
    class B,C,D gcp;
    class F5_1,F5_2 f5;

