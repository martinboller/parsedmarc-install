#! /bin/bash

#####################################################################
#                                                                   #
# Author:       Martin Boller                                       #
#                                                                   #
# Email:        martin                                              #
# Last Update:  2019-06-07                                          #
# Version:      1.10                                                #
#                                                                   #
# Changes:      Initial Version (1.00)                              #
#               Added logging dir (1.10)                            #
#                                                                   #
# Description:  Installs parsedmarc as a service (paas :)           #
# Info:         https://domainaware.github.io/parsedmarc/           #
#                                                                   #
#####################################################################

install_parsedmarc() {
    echo "Install parsedmarc";
    sudo apt-get install -y python3-pip;
    pip3 install -U parsedmarc;
    /usr/bin/logger 'install_parsedmarc()' -t 'parsedmarc';
}

configure_parsedmarc() {
echo "Configure parsedmarc";
    export DEBIAN_FRONTEND=noninteractive;
    id parsedmarc || (groupadd parsedmarc && useradd -g parsedmarc parsedmarc);
    mkdir /etc/parsedmarc/;
    /bin/cp /elasticsearch/certs/root-ca /etc/parsedmarc/;
    mkdir /var/log/parsedmarc;
    chown parsedmarc:parsedmarc -R /var/log/parsedmarc/;
    echo "parsedmarc log-file" > /var/log/parsedmarc/parsedmarc.log;
    # Create configuration file for parsedmarc
    sudo sh -c "cat << EOF  >  /etc/parsedmarc/parsedmarc.ini
# Parsedmarc configuration file

[general]
save_aggregate = True
save_forensic = True
nameservers = ns1.example.org
log_file = /var/log/parsedmarc/parsedmarc.log

[imap]
host = mail01.example.com
user = dmarc@example.com
password = Password here
watch = False
reports_folder = Inbox.DMARC
archive_folder = Inbox.Archive
#skip_certificate_verification = True

[elasticsearch]
hosts = https://elasticuser:elasticpassword@localhost:9200
ssl = True
# skip_certificate_verification = True
cert_path = /etc/parsedmarc/root-ca.pem
EOF";

    # Create  Service
    sudo sh -c "cat << EOF  >  /lib/systemd/system/parsedmarc.service
[Unit]
Description=parsedmarc mailbox watcher
Documentation=https://domainaware.github.io/parsedmarc/
Wants=network-online.target
After=network.target network-online.target elasticsearch.service

[Service]
User=parsedmarc
Group=parsedmarc
ExecStart=-/usr/local/bin/parsedmarc -c /etc/parsedmarc/parsedmarc.ini
WorkingDirectory=/etc/parsedmarc

[Install]
WantedBy=multi-user.target
EOF";

   sudo sh -c "cat << EOF  >  /lib/systemd/system/parsedmarc.timer
[Unit]
Description=Triggers parsedmarc every 10 minutes
Documentation=https://http://docs.parsedmarc.io/en/latest/deployment.html#house-keeping
Wants=network-online.target

[Timer]
OnUnitActiveSec=10m
Unit=parsedmarc.service

[Install]
WantedBy=multi-user.target
EOF";
    sync;
    chown -R parsedmarc:parsedmarc /etc/parsedmarc;
    chown -R parsedmarc:parsedmarc /var/log/parsedmarc;
    systemctl daemon-reload;
    systemctl enable parsedmarc.timer;
    systemctl enable parsedmarc.service;
    systemctl start parsedmarc.timer;
    systemctl start parsedmarc.service;
    /usr/bin/logger 'configure_parsedmarc()' -t 'parsedmarc';
}

##################################################################################################################
## Main                                                                                                          #
##################################################################################################################

main() {
    install_parsedmarc;
    configure_parsedmarc;
    echo "Check the parsedmarc log: tail -f -n30 /var/log/parsedmarc/parsedmarc.log"
}

main;