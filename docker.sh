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

