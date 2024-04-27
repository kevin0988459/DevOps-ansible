#!/bin/bash

## 1. build jenkins+Ansible image and production server iamge
docker build -t lab_jenkins:latest -f jenkins/Dockerfile .
docker build -t production_image:latest -f production/Dockerfile .

## 2. Terraform provision IaC
terraform init 
terraform apply -auto-approve

######-------SonarQube------######

## 3. wait for SonarQube server to be up
SONARQUBE_URL="http://localhost:9000"
SONARQUBE_ADMIN_USER="admin"
SONARQUBE_ADMIN_PASS="admin"
TOKEN_NAME="sonar-token"
echo -e "\033[0;36mWaiting for SonarQube server to start...\033[0m"

## Wait sonarqube server ready
while true; do
  RESPONSE=$(curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" "$SONARQUBE_URL/api/system/health")
  HEALTH_STATUS=$(echo $RESPONSE | grep -o '"health":"[^"]*' | awk -F'"' '{ print $4 }')
  if [ "$HEALTH_STATUS" == "GREEN" ]; then
    echo -e "\033[0;32mSonarQube server is up and running\033[0m"
    break
  else
    echo "Waiting for SonarQube server to be ready (average 1 min)..."
    sleep 5
  fi
done

## 4. Generate sonarqube user token
GENERATE_TOKEN_RESPONSE=$(curl -s -u "$SONARQUBE_ADMIN_USER:$SONARQUBE_ADMIN_PASS" \
  -X POST "$SONARQUBE_URL/api/user_tokens/generate" \
  -d "name=$TOKEN_NAME")

SONARQUBE_TOKEN=$(echo $GENERATE_TOKEN_RESPONSE | grep -o '"token":"[^"]*' | awk -F'"' '{ print $4 }')

if [ ! -z "$SONARQUBE_TOKEN" ]; then
  echo "SonarQube Token: $SONARQUBE_TOKEN"
else
  echo "Token exists, failed to generate SonarQube token."
fi

######-------Systems------######

## 5. reaplce SONAR_TOKEN by overwriting jcasc.yaml
cp jcasc.yaml jcasc.yaml.backup
sed -i '' "s/SONAR_TOKEN/$SONARQUBE_TOKEN/g" jcasc.yaml

## 6. Replace jenkins as a code config file into jenkins path
docker cp jcasc.yaml jenkins:/var/jenkins_home/casc_configs/jcasc.yaml


## 7. client keygen
echo '-----generate key-----'
docker exec jenkins sh -c "
mkdir -p /var/jenkins_home/.ssh &&
chmod 700 /var/jenkins_home/.ssh &&
ssh-keygen -t rsa -b 4096 -N '' -f /var/jenkins_home/.ssh/id_rsa &&
chown -R jenkins:jenkins /var/jenkins_home/.ssh &&
chmod 600 /var/jenkins_home/.ssh/id_rsa"

## 8. Get the pub_key and pipe it to the server so the sever can store the pub_key
echo '----copy public key to server----'
docker exec jenkins cat /var/jenkins_home/.ssh/id_rsa.pub | docker exec -i production_server bash -c 'cat >> /root/.ssh/authorized_keys'

## 9. Auth the .ssh
docker exec production_server chmod 700 /root/.ssh

## 10. Auth the /authorized_keys
docker exec production_server chmod 600 /root/.ssh/authorized_keys

## 11. client ssh into server, touch the created.txt and check it was created
echo '----client remote access to server----'
docker exec -it jenkins ssh -o StrictHostKeyChecking=no root@production_server 'touch created.txt && ls -la'

######-------Jenkins------######
JENKINS_URL="http://localhost:8081"
JENKINS_USER="admin"
JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
JOB_NAME="lab5"
CONFIG_XML_PATH="./config.xml"

## 12. Download Jenkins CLI
echo "Downloading Jenkins CLI..."
curl -O "${JENKINS_URL}/jnlpJars/jenkins-cli.jar"
chmod +r jenkins-cli.jar

## 13. reload Configuration as a Code
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_PASSWORD} reload-jcasc-configuration

## 14. Create the Job
echo "Creating job '${JOB_NAME}'..."
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_PASSWORD} create-job ${JOB_NAME} < ${CONFIG_XML_PATH}

## 15. Trigger the Job
echo "Triggering job '${JOB_NAME}'..."
java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_USER}:${JENKINS_PASSWORD} build ${JOB_NAME} -s -v



echo "##################################################"
echo -e "\n"
echo -e "\033[0;32mPipeline created\033[0m"
echo "Visit http://localhost:8080 to view the petclinc homepage"
echo "Visit http://localhost:8081/blue/organizations/jenkins/lab4/detail/lab4/1/pipeline to visit blueocean, login to jenkins first"
echo "Visit http://localhost:8081 to login to the Jenkins server, the default password is: $JENKINS_PASSWORD"
echo "Visit http://localhost:9000 to login to the Sonaqube server, the default username and password are both admin"
echo -e "\n"
echo "##################################################"


## revoke jcasc.yaml to original template
mv jcasc.yaml.backup jcasc.yaml
