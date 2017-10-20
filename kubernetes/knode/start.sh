#!/bin/bash -ex

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

export KMASTER="${kmaster}"
export ZONE="${zone}"

cd ~root/docker-kubernetes-node
./fan-setup.sh

until docker info; do echo "Waiting for docker..."; sleep 10; done
until curl -k https://$KMASTER:6443/healthz; do echo "Waiting for kmaster..."; sleep 10; done

AZ=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone`
INSTANCE_TYPE=`curl http://169.254.169.254/latest/meta-data/instance-type`
AMI_ID=`curl http://169.254.169.254/latest/meta-data/ami-id`
DOCKER=`docker version --format '{{.Server.Version}}'`
SHA=$(git rev-parse --short HEAD)
export LABELS="zone=$ZONE,sha=$SHA,az=$AZ,type=$INSTANCE_TYPE,ami=$AMI_ID,docker=$DOCKER"
echo "LABELS=$LABELS"

export VAULT_ADDR=http://$KMASTER:8200
AUTH_RESULT=$(curl -X POST $VAULT_ADDR/v1/auth/aws/login -d '{"role": "knode", "pkcs7":"'"$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/pkcs7 | tr -d \\n)"'"}')
export VAULT_TOKEN=$(echo $AUTH_RESULT | jq -r .auth.client_token)

cd ~root/docker-kubernetes-node
./run $KMASTER
docker ps