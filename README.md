# Terraform Demo: Open WebUI on AWS Spot Instance

This demo provisions a single Ubuntu EC2 Spot Instance on AWS and deploys Open WebUI (Docker) on port `3000`.

## What this project creates

- Custom VPC: `10.1.0.0/16`
- Public subnet + internet gateway + route table
- Security groups:
- `22/tcp` open to `0.0.0.0/0` (SSH)
- `3000/tcp` open to `0.0.0.0/0` (Open WebUI)
- EC2 key pair from local public key:
- `C:/Users/USER/Documents/rose/key/id_rsa.pub`
- Random admin password (`random_password`)
- Ubuntu 26.04 AMI (latest matching filter)
- Spot instance (`t3.medium`, 40 GB `gp3`)
- Health check using `terracurl`:
- `http://<public_ip>:3000/api/health`

## Files

- `main.tf`: providers and AWS provider setup
- `vm.tf`: network, security groups, key pair, spot instance, health check
- `variable.tf`: admin username variable (`open_webui_user`)
- `output.tf`: instance `public_ip` and generated `password`
- `provision_basic.sh`: user-data bootstrap script (Docker + Open WebUI + admin injection)

## Prerequisites

- Terraform installed
- AWS credentials configured in environment variables (or default AWS credential chain)
- Existing SSH public key at:
- `C:/Users/USER/Documents/rose/key/id_rsa.pub`

## How to run

1. Initialize providers:
   ```bash
   terraform init
   ```
2. Review plan:
   ```bash
   terraform plan
   ```
3. Apply:
   ```bash
   terraform apply
   ```
4. Get outputs:
   ```bash
   terraform output public_ip
   terraform output -raw password
   ```
5. Open in browser:
   - `http://<public_ip>:3000`
   - Login user: value of `open_webui_user` (default: `rose@demo.gs`)
   - Login password: Terraform output `password`

## Optional variable override

Change admin username during apply:

```bash
terraform apply -var="open_webui_user=your-email@example.com"
```

## Destroy resources

```bash
terraform destroy
```

## Notes / Caveats

- Security groups are wide open (`0.0.0.0/0`) for demo purposes.
- `password` output is marked sensitive, but can still be retrieved with `terraform output -raw password`.
- AMI filter is pinned to Ubuntu 26.04 naming pattern in `vm.tf`.
- Spot capacity and pricing are not guaranteed; instance fulfillment can fail depending on AWS capacity.
