#Artemis - Broker

A dockerized image for the Artemis honeynet email server package.

### Usage

Download latest container

 ```
 docker pull marclaliberte/artemis-server
 ```

Mount docker container and expose SMTP
 ```
 docker run --name artemis-server -p 25:25 -it marclaliberte/artemis-server
 ```

Inside mounted container, configure hpfeeds credentials
 ```
 vim /opt/shiva/shiva.conf
 ```

Start the receiver and analyzer
 ```
 cd /opt/shiva/shivaReceiver
 source bin/activate
 cd receiver
 lamson start
 deactivate

 cd /opt/shiva/shivaAnalyzer
 source bin/activate
 cd analyzer
 lamson start
 deactivate
 ```
