# ubuntu base image
FROM ubuntu:20.04

# Update packages
RUN apt-get update

# install SSH server, Java jdk, python
RUN apt-get update && apt-get install -y openjdk-17-jre openssh-server python3

## create ssh directory and enable the root to read, write, exectue 
RUN mkdir /root/.ssh && chmod 700 /root/.ssh

## SSH daemon requires this directory to function.
RUN mkdir /var/run/sshd

## configure whitelisted user and client alive
RUN { \
      echo 'PermitRootLogin yes'; \
      echo 'PubkeyAuthentication yes'; \
      echo 'PasswordAuthentication no'; \
      echo 'ClientAliveInterval 120'; \
      echo 'ClientAliveCountMax 3'; \
      echo 'AuthenticationMethods publickey';\
      echo 'Banner /etc/ssh/login_banner'; \
      echo 'AllowUsers root'; \
    } > /etc/ssh/sshd_config

## configure login banner
RUN echo "You success!! Welcome to SSH Server." >> /etc/ssh/login_banner

## ssh port and pet-clinic port
EXPOSE 22 8080

## foreground
CMD ["/usr/sbin/sshd", "-D"]

