#########-------ToolingList--------#########
1. OS Tooling list
    • OS Host: M2 chips macOS 14.1 
    • Virtualizer: Docker 25.0.3
    • MacOS packet manager: Homebrew 4.2.16
    • Provisioning tool: Terraform v1.7.5
    • Shell: Bash

2. Server 1 (jenkins + ansible) Tooling list
    • Jenkins docker image: jenkins/jenkins:lts-jdk17
    • openssh-client: OpenSSH_9.2p1
    • maven: Apache Maven 3.8.7
    • Ansible: ansible [core 2.14.3]

3. Server 2 production server Tooling list
    • docker image: ubuntu:20.04
    • openjdk-17-jre
    • openssh-server: OpenSSH_8.2p1
    • python3: Python 3.8.10

4. SonarQube server Tooling list
    • Sonarqube official docker image: sonarqube:latest

#########-------END--------#########

#########-------Instruction--------#########
1. Download Docker and Terraform
2. How to run (please ensure your docker engine is running)
    •$cd kaiwenh_assignment5
    •$bash lab_pipeline.sh
3. Examine pet-clinic server
    • Read the final output from the terminal, pet-clinic is running on http://localhost:8080
4. Clean Up
    • $terraform destroy
5. Clean up "lab_jenkins" and "production_image" images also
    • $docker rmi lab_jenkins
    • $docker rmi production_image
6. Steps, Provisioning file(main.tf), and Ansible playbook(deploy_app.yaml) is provided below

#########-------END--------#########

#########-------Steps--------#########     
1. Download Homebrew (ignore this if you already have brew)
    • $ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    • $ (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.bash_profile
    • $ eval "$(/opt/homebrew/bin/brew shellenv)"
2. Download Terraform using Homebrew
    • $brew tap hashicorp/tap
    • $brew install hashicorp/tap/terraform
3. Create a new directory HW5 and navigate to it
    • $mkdir HW5
    • $cd HW5
4. Create a terraform file called main.tf
    • $touch main.tf
5. Consigure main.tf, terraform will help you provision Three containers. One is jenkins+Ansible server, one is production server, and one is SonarQube.
    • Use VScode open main.tf
    • Copy my main.tf to you main.tf
6. Create a custom jenkins image
    • $mkdir jenkins
    • $cd jenkins
    • $touch Dockerfile
7. Configure jenkins Dockerfile, it will pre-install Ansible, openssh-client, maven, blueocean, sonar-scanner, and Jenkins Configuration as a Code(JCaSC) plugin
    • The code is provided in the "jenkins/Dockerfile"
    • $cd ..
8. Create a custom production server image
    • $mkdir production
    • $cd production
    • $touch Dockerfile
9. Configure production server Dockerfile, it will pre-install openjdk-17-jre, openssh-server, and python
    • The code is provided in the "production/Dockerfile"
    • $cd ..
10. Create ansible inventory and playbook
    • $mkdir ansible
    • $cd ansible
    • $touch ansible.cfg
    • $touch deploy_app.yml
    • $touch hosts
11. Copy my code in ansible.cfg, deploy_app.yml, and hosts to your file respectively
    • These file will place into jenkins image and used by ansible
    • $ cd ..
12. To fully automate the Jenkins setup, you need to install JCaSC into Jenkins server. JCaSC will read the yaml file and setup Jenkins configuration.
    • $touch jcasc.yaml
13. Configure jcasc.yaml, it will setup the SonarQube crediential, and put the crediential into sonar-scanner.
    • Copy my jcasc.yaml to your jcasc.yaml
14. We will use Pipeline DSL to configure the different stages in the pipeline. The stages include, git clone, build, scan, and Deploy.
    To fully automate the pipeline setup, we'll create config.xml, which include the Pipeline DSL. 
    In HW5, I add the Deploy stage. It will ask ansible to ship the jar file to production container and run it. 
    We will then upload config.xml to the Jenkins Server by Jenkins CLI (in the shell script).
    • $touch config.xml
    • Copy my config.xml to your config.xml
15. Now you have created all the required file. The last step is writing a shell script to fully automate the assignment.
    In HW5, Ansible required SSH connect so I add the ssh set up in the script. 
    The script can Run the IaC, configure Jenkins and SonarQube, setup SSH,setup pipline, and execute the pipeline.
    • $touch lab_pipeline.sh
    • Copy my lab_pipeline.sh to your lab_pipeline.sh
    • Step by step explanation is provided in the lab_pipeline.sh file
16. Run the shell script. It will automatically complete the assignment. Pet-clinic is running in the jenkins container
    • $bash lab_pipeline.sh


#########-------END--------#########

#########-------Provisioning script--------#########
terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

#configure shared network
resource "docker_network" "my_network" {
  name = "my_network"
}

#Pulls the jenksins image
resource "docker_image" "lab_jenkins" {
    name = "lab_jenkins:latest"
    # prevent pulling from remote
    keep_locally = true 
}

#Create a jenksins container
resource "docker_container" "jenkins_container" {
    image = docker_image.lab_jenkins.image_id
    name = "jenkins"
    networks_advanced {
      name = docker_network.my_network.name
    }
    ports{
        internal = 8081
        external = 8081
    }
}

#Pulls the sonarqube image
resource "docker_image" "sonarqube_image" {
    name = "sonarqube:latest"
}

#Create a sonarqube container
resource "docker_container" "sonarqube_container" {
    image = docker_image.sonarqube_image.image_id
    name = "sonarqube"
    networks_advanced {
      name = docker_network.my_network.name
    }
    ports {
      internal = 9000
      external = 9000
    }
}

## pulls the local production image
resource "docker_image" "production_image" {
    name = "production_image:latest"
    # prevent pulling from remote
    keep_locally = true 
}

# Create a container for the production server
resource "docker_container" "production_container" {
  image = docker_image.production_image.image_id
  name = "production_server"
  networks_advanced {
    name = docker_network.my_network.name
  }
  ports{
    internal = 8080
    external = 8080
  }
}
#########-------END--------#########

#########-------Ansible playbook--------#########
---
- name: Deploy Spring Petclinic Application
  hosts: production
  become: yes
  vars:
    jar_path: "{{ jar_path }}" 

  tasks:
    - name: Copy jar file to the production server
      copy:
        src: "{{ jar_path }}"
        dest: "/opt/spring-petclinic.jar"
        mode: '0755'

    - name: Run the application
      ansible.builtin.shell: nohup java -jar /opt/spring-petclinic.jar > output.log 2>&1 &
#########-------END--------#########

#########-------Automated/pipeline scripts--------#########
##Jenkins pipeline DSL is mentioned inside config.xml##

pipeline {
    agent any
    stages {
        stage('git clone') {
            steps {
                git branch: 'main', url: 'https://github.com/kevin0988459/spring-petclinic.git'
            }  
            post {
                failure { echo "[*] git clone failure" }
                success { echo '[*] git clone successful' }
            }
        }
        stage('Build') {
            steps {
                sh './mvnw package'
                // Set the JAR_PATH environment variable assuming the jar is named spring-petclinic.jar
                script {
                    env.JAR_PATH = sh(script: "ls ${WORKSPACE}/target/*.jar", returnStdout: true).trim()
                }
            }
        }
        stage('scan') {
            steps {
                withSonarQubeEnv(installationName: 'sonar'){
                    sh './mvnw org.sonarsource.scanner.maven:sonar-maven-plugin:3.7.0.1746:sonar'
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    // Ensure JAR_PATH is echoed correctly
                    echo "Deploying jar at: ${env.JAR_PATH}"
                    // Use the resolved JAR_PATH directly in the command line
                    sh "ansible-playbook -i /var/jenkins_home/ansible/hosts /var/jenkins_home/ansible/deploy_app.yml -e 'jar_path=${env.JAR_PATH}' "
                }
            }
        } 
    }
}
#########-------END--------#########

###Reference###
1. Terraform Docker provider documentation
https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
2. Terraform Docker tutorial
https://developer.hashicorp.com/terraform/tutorials/docker-get-started/install-cli
3. Pre-install sonarqube and blueocean plug-in into the image
https://www.jenkins.io/doc/book/installing/docker/
https://plugins.jenkins.io/sonar/releases/
https://plugins.jenkins.io/blueocean/releases/
4. Unable to download plugins
https://stackoverflow.com/questions/16213982/unable-to-find-plugins-in-list-of-available-plugins-in-jenkins
5. Passing Jenkins launcher parameters for modifing default port:
https://www.jenkins.io/doc/book/installing/initial-settings/
https://github.com/jenkinsci/docker?tab=readme-ov-file
6. Prevent jenkins kills the application
https://stackoverflow.com/questions/75464666/how-to-run-jar-through-jenkins-as-a-separate-process
7. Jenkins as a code
https://medium.com/globant/jenkins-jcasc-for-beginners-819dff6f8bc
https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/demos
8. Jeknins reload Configuration as a code
https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/configExport.md
9. Ansible tutorial(Chinese version)
https://github.com/880831ian/Ansible