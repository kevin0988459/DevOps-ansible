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