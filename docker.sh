#!/bin/bash
sudo yum -y update
sudo yum -y install git
sudo yum install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod 666 /var/run/docker.sock
echo 'Clone git repo to EC2'
git clone https://github.com/taral-desai/airflow.git && cd airflow
mkdir -p ./dags ./logs ./plugins ./config
echo -e "AIRFLOW_UID=$(id -u)" > .env
docker compose up airflow-init
docker compose up
ssh -o "IdentitiesOnly yes" -i private_key.pem ec2-user@ec2-54-209-106-114.compute-1.amazonaws.com -N -f -L 8080:ec2-user@ec2-54-209-106-114.compute-1.amazonaws.com:8080 && open http://localhost:8080
terraform -chdir=./terraform_aws output -raw private_key > private_key.pem && chmod 600 private_key.pem &&  && rm 
ssh -i "airflow_ec2_key20230807014109888200000003.pem" ec2-user@ec2-44-204-56-84.compute-1.amazonaws.comprivate_key.pem