#!/bin/bash
apt-get update
apt-get install -y openjdk-8-jdk unzip 
cd /opt
wget https://github.com/keycloak/keycloak/releases/download/15.0.2/keycloak-15.0.2.zip
unzip keycloak-15.0.2.zip
cd keycloak-15.0.2
./bin/add-user-keycloak.sh -r master -u admin -p admin
./bin/standalone.sh -b=0.0.0.0
