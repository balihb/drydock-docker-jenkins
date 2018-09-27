FROM ubuntu:bionic

# install_pkg
ADD install_pkg.sh /usr/local/bin
RUN chmod a+x /usr/local/bin/install_pkg.sh

# apt-utils
RUN install_pkg.sh apt-utils

# ssh
RUN install_pkg.sh \
    openssh-server &&\
    sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd &&\
    mkdir -p /var/run/sshd

# drydock
RUN groupadd -g 10000 phabricator-drydock &&\
    useradd -c "Phabricator user" -d /var/drydock -u 10000 -g 10000 -m phabricator-drydock &&\
    mkdir -p /var/drydock/.ssh &&\
    chown -R phabricator-drydock:phabricator-drydock /var/drydock &&\
    chmod -R 700 /var/drydock

# sudo
RUN install_pkg.sh \
    sudo &&\
    sed -i 's/%admin ALL=(ALL) ALL/%adm ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers &&\
    gpasswd -a phabricator-drydock adm

# ph
RUN install_pkg.sh \
    git \
    php-cli \
    php-curl \
    ca-certificates &&\
    mkdir -p /opt/phabricator &&\
    cd /opt/phabricator &&\
    git clone -b stable https://github.com/phacility/libphutil.git &&\
    rm -rf libphutil/.git &&\
    git clone -b stable https://github.com/phacility/arcanist.git &&\
    rm -rf arcanist/.git &&\
    ln -s /opt/phabricator/arcanist/bin/arc /usr/local/bin/arc

# tools
RUN install_pkg.sh \
    curl \
    jq

# Standard SSH port
EXPOSE 22

ADD run /usr/local/bin/run
ADD error_handling.sh /usr/local/bin/error_handling.sh
ADD trigger_build.sh /usr/local/bin/trigger_build.sh

# Default command
CMD ["/usr/local/bin/run"]
