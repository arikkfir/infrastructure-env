#!/usr/bin/env bash

if [[ "${BRANCH_NAME}" == "master" ]]; then
    VARS_FILE="master.tfvars"
else
    VARS_FILE="non-master.tfvars"
fi

echo "Decrypting the Deployer service account JSON key (deployer-sa-key.json.enc)..."
gcloud kms decrypt --keyring=global \
                   --location=global \
                   --key=deploy \
                   --ciphertext-file=./deployer-sa-key.json.enc \
                   --plaintext-file=./deployer-sa-key.json

echo "Decrypting the Terraform common variables file (common.auto.tfvars.enc)..."
gcloud kms decrypt --keyring=global \
                   --location=global \
                   --key=deploy \
                   --ciphertext-file=./common.auto.tfvars.enc \
                   --plaintext-file=./common.auto.tfvars

echo "Decrypting the branch-specific Terraform variables file (${VARS_FILE}.enc)..."
gcloud kms decrypt --keyring=global \
                   --location=global \
                   --key=deploy \
                   --ciphertext-file=./${VARS_FILE}.enc \
                   --plaintext-file=./secret.auto.tfvars
