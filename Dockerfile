FROM ubuntu:16.04
MAINTAINER Marc Laliberte
ENV DEBIAN_FRONTEND noninteractive
USER root
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Prep for MySQL
RUN echo "mysql-server mysql-server/root_password password MySQLPassword" | debconf-set-selections
RUN echo "mysql-server mysql-server/root_password_again password MySQLPassword" | debconf-set-selections

# Main packages
RUN apt-get update && \
  apt install -y --no-install-recommends \
    vim \
    curl \
    python \
    python-dev \
    python-virtualenv \
    g++ \
    exim4-daemon-light \
    mysql-server \
    mysql-client \
    libmysqlclient-dev \
    make \
    libffi-dev \
    libfuzzy-dev \
    automake \
    autoconf \
    git

# Install PIP
WORKDIR /tmp
RUN curl -sSL https://bootstrap.pypa.io/get-pip.py >> get-pip.py && \
  python get-pip.py && \
  pip install --upgrade setuptools \
      pip \
      virtualenv

# Download SHIVA
RUN git clone https://github.com/marclaliberte/shiva.git && \
  mkdir /opt/shiva

# Setup SHIVA helpers
RUN cp /tmp/shiva/helpers/dbcreate.py /opt/shiva/ && \
    cp /tmp/shiva/helpers/maindb.sql /opt/shiva/ && \
    cp /tmp/shiva/helpers/shiva.conf /opt/shiva/ && \
    cp /tmp/shiva/helpers/tempdb.sql /opt/shiva/ && \
    cp /tmp/shiva/helpers/setup_exim4.sh /opt/shiva/

# Setup SHVIA config
RUN sed -i 's/localdb : False/localdb : True/g' /opt/shiva/shiva.conf && \
    sed -i 's/password : password/password : MySQLPassword/g' /opt/shiva/shiva.conf

# Setup SHIVA receiver
WORKDIR /opt/shiva
RUN virtualenv shivaReceiver && \
  cd shivaReceiver && \
  source bin/activate && \
  easy_install -U distribute && \
  pip install -q apscheduler==2.1.2 \
    docutils \
    python-daemon \
    lamson==1.3.4 && \
  lamson gen -project receiver && \
  cp /tmp/shiva/receiver/core/* /opt/shiva/shivaReceiver/lib/python2.7/site-packages/lamson/ && \
  cp /tmp/shiva/receiver/config/* /opt/shiva/shivaReceiver/receiver/config/ && \
  cp /tmp/shiva/receiver/handlers/* /opt/shiva/shivaReceiver/receiver/app/handlers/ && \
  cp /tmp/shiva/helpers/clearlogs.sh /opt/shiva/shivaReceiver/receiver/logs/ && \
  cp /tmp/shiva/helpers/restart_receiver.sh /opt/shiva/shivaReceiver/receiver/ && \
  deactivate

# Setup SHIVA analyzer
WORKDIR /opt/shiva
RUN virtualenv shivaAnalyzer && \
  cd shivaAnalyzer && \
  source bin/activate && \
  easy_install -U distribute && \
  pip install -q cython==0.20.2 \
    apscheduler==2.1.2 \
    MySQL-python==1.2.5 \
    ssdeep==3.1 \
    docutils \
    python-daemon \
    lamson==1.3.4 && \
  lamson gen -project analyzer && \
  mkdir -p /opt/shiva/shivaAnalyzer/lib/python2.7/site-packages/lamson/hpfeeds/ && \
  cp /tmp/shiva/analyzer/core/* /opt/shiva/shivaAnalyzer/lib/python2.7/site-packages/lamson/ && \
  cp /tmp/shiva/hpfeeds/*.py /opt/shiva/shivaAnalyzer/lib/python2.7/site-packages/lamson/hpfeeds/ && \
  cp /tmp/shiva/analyzer/config/* /opt/shiva/shivaAnalyzer/analyzer/config/ && \
  cp /tmp/shiva/helpers/clearlogs.sh /opt/shiva/shivaAnalyzer/analyzer/logs/ && \
  deactivate

# Setup SHIVA directories
RUN mkdir /opt/shiva/queue && \
  mkdir /opt/shiva/queue/new && \
  mkdir /opt/shiva/queue/cur && \
  mkdir /opt/shiva/queue/tmp && \
  mkdir /opt/shiva/distorted && \
  mkdir /opt/shiva/attachments && \
  mkdir /opt/shiva/attachments/inlines && \
  mkdir /opt/shiva/attachments/hpfeedattach && \
  mkdir /opt/shiva/rawspams && \
  mkdir /opt/shiva/rawspams/hpfeedspam

# Finalize SHIVA config
RUN sed -i "s/queuepath : somepath/queuepath : \/opt\/shiva\/queue\//g" /opt/shiva/shiva.conf && \
    sed -i "s/undeliverable_path : somepath/undeliverable_path : \/opt\/shiva\/distorted\//g" /opt/shiva/shiva.conf && \
    sed -i "s/rawspampath : somepath/rawspampath : \/opt\/shiva\/rawspams\//g" /opt/shiva/shiva.conf && \
    sed -i "s/hpfeedspam : somepath/hpfeedspam : \/opt\/shiva\/rawspams\/hpfeeds\//g" /opt/shiva/shiva.conf && \
    sed -i "s/attachpath : somepath/attachpath : \/opt\/shiva\/attachments\//g" /opt/shiva/shiva.conf && \
    sed -i "s/inlinepath : somepath/inlinepath : \/opt\/shiva\/attachments\/inlines\//g" /opt/shiva/shiva.conf && \
    sed -i "s/hpfeedattach : somepath/hpfeedattach : \/opt\/shiva\/attachments\/hpfeedattach\//g" /opt/shiva/shiva.conf && \
    sed -i "s/listenhost : 127.0.0.1/listenhost : 0.0.0.0/g" /opt/shiva/shiva.conf && \
    sed -i "s/listenport : 2525/listenport : 25/g" /opt/shiva/shiva.conf

# Setup database
WORKDIR /opt/shiva
RUN service mysql start && python dbcreate.py

# Setup exim
RUN sed -i -e '32a\daemon_smtp_ports=2500' /etc/exim4/exim4.conf.template && \
    sed -i s/dc_eximconfig_configtype=\'local\'/dc_eximconfig_configtype=\'internet\'/ /etc/exim4/update-exim4.conf.conf && \
    service exim4 restart

# Start MySQL with docker
ENTRYPOINT service mysql restart && bash
