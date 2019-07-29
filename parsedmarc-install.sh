#! /bin/bash

#####################################################################
#                                                                   #
# Author:       Martin Boller                                       #
#                                                                   #
# Email:        martin                                              #
# Last Update:  2019-07-29                                          #
# Version:      1.30                                                #
#                                                                   #
# Changes:      Initial Version (1.00)                              #
#               Added logging dir (1.10)                            #
#               Asking user for input on ini file (1.20)            #
#               Installing version 4.6.2 (1.30)                     #
#                                                                   #
# Description:  Installs parsedmarc as a service (paas :)           #
# Info:         https://domainaware.github.io/parsedmarc/           #
#                                                                   #
#####################################################################

install_parsedmarc() {
    echo "Install parsedmarc";
    sudo apt-get install -y python3-pip;
    # Currently 6.5.0 and newer doesn't work with some mailproviders
    pip3 install -U parsedmarc==6.4.2;
    /usr/bin/logger 'install_parsedmarc()' -t 'parsedmarc';
}

configure_parsedmarc() {
echo "Configure parsedmarc";
    export DEBIAN_FRONTEND=noninteractive;
    id parsedmarc || (groupadd parsedmarc && useradd -g parsedmarc parsedmarc);
    mkdir /etc/parsedmarc/;
    # Replace root-ca name/location if not already trusted
    /bin/cp /etc/elasticsearch/certs/root-ca.crt /etc/parsedmarc/;
    mkdir /var/log/parsedmarc;
    chown parsedmarc:parsedmarc -R /etc/parsedmarc;
    chown parsedmarc:parsedmarc -R /var/log/parsedmarc/;
    echo "parsedmarc log-file" > /var/log/parsedmarc/parsedmarc.log;
    # Create configuration for parsedmarc
    # obtain information from user
    read -p "Enter nameserver to use for parsedmarc: "  name_server;
    echo -e;
    read -p "Enter IMAP server to use for parsedmarc: "  imap_server;
    echo -e;
    read -p "Enter IMAP username to use for parsedmarc: "  email_address;
    echo -e;
    read -s -p "Enter IMAP users password to use for parsedmarc: "  email_password;
    echo -e;
    # Assuming Elasticsearch user is named parsedmarc
    read -s -p "Enter parsedmarc users password to use for accessing elasticsearch: "  parsedmarc_password;
    echo -e;
        
    # Create config file
    sudo sh -c "cat << EOF  >  /etc/parsedmarc/parsedmarc.ini
# Parsedmarc configuration file
# for elasticsearch
[general]
save_aggregate = True
save_forensic = True
nameservers = $name_server
log_file = /var/log/parsedmarc/parsedmarc.log
#debug: True

[imap]
host = $imap_server
user = $email_address
password = $email_password
watch = False
reports_folder = Inbox.DMARC
archive_folder = Inbox.Archive

[elasticsearch]
hosts = https://parsedmarc:$parsedmarc_password@localhost:9200
ssl = True
cert_path = /etc/parsedmarc/root-ca.crt
monthly_indexes: True
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
Documentation=https://https://docs.parsedmarc.io/en/latest/deployment.html#house-keeping
Wants=network-online.target

[Timer]
OnUnitActiveSec=10m
Unit=parsedmarc.service

[Install]
WantedBy=multi-user.target
EOF";
    sync;
    /bin/cp /etc/elasticsearch/certs/ca/root-ca.crt /etc/parsedmarc/;
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