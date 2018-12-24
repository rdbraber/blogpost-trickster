#!/bin/bash

#####################################
# Author: Rob den Braber
# Version: v1.0.0
# Date: 2018-12-21
# Description: configure node during a vagrant up command
# Usage: add as a shell provisioning script in the Vagrantfile
#####################################


# Variables

PROMETHEUS_VERSION=2.6.0
NODE_EXPORTER_VERSION=0.17.0
TRICKSTER_VERSION=0.1.5


install_Prometheus () {
  # Add prometheus user
  sudo useradd --no-create-home --shell /bin/false prometheus
  # Create some directories for prometheus
  sudo install --directory --owner=prometheus --group=prometheus /etc/prometheus /var/lib/prometheus
  # Download prometheus and the sha256 checksum file
  wget -nv -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
  wget -nv -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/sha256sums.txt
  # compare the checksum of the downloaded file with the one in the checksum file
  if grep --quiet $(sha256sum prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz) sha256sums.txt
  then
    echo "sha256 checksum OK"
  else
    echo "sha256 checksum NOT OK"
    exit 1
  fi
  # Untar the downloade file
  tar -xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
  # Copy the files to the right directory and change the ownership
  sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
  sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
  sudo chown prometheus:prometheus /usr/local/bin/prometheus
  sudo chown prometheus:prometheus /usr/local/bin/promtool
  # Copy the consoles and console_libraries and change the ownership
  sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus
  sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus
  sudo chown -R prometheus:prometheus /etc/prometheus/consoles
  sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
  # Copy the prometheus configuration file and change the ownership
  sudo cp prometheus-2.6.0.linux-amd64/prometheus.yml /etc/prometheus
  sudo chown prometheus:prometheus /etc/prometheus /etc/prometheus/prometheus.yml
  # Create the systemd unit file
  sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file /etc/prometheus/prometheus.yml \\
    --storage.tsdb.path /var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
  # Start and enable Prometheus
  sudo systemctl daemon-reload
  sudo systemctl start prometheus
  sudo systemctl enable prometheus
  # Cleanup
  rm -f prometheus-2.6.0.linux-amd64.tar.gz sha256sums.txt
  rm -rf prometheus-2.6.0.linux-amd64
}

install_node_exporter () {
  # Add the node_exporter user
  sudo useradd --no-create-home --shell /bin/false node_exporter
  # Download node_exporter and the sha256 checksum file
  wget -nv -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
  wget -nv -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/sha256sums.txt
  # compare the checksum of the downloaded file with the one in the checksum file
  if grep --quiet $(sha256sum node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz) sha256sums.txt
  then
    echo "sha256 checksum OK"
  else
    echo "sha256 checksum NOT OK"
    exit 1
  fi
  # Untar the downloade file
  tar -zxvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
  # Copy the file to the right directory and change the ownership
  sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin
  sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
  # Cleanup
  rm -f node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz sha256sums.txt
  rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64
  # Create the systemd unit file
  sudo tee /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
  # Start and enable node_exporter
  sudo systemctl daemon-reload
  sudo systemctl start node_exporter
  sudo systemctl enable node_exporter
}

add_scrape_config_node_exporter () {
  # Add scraping for node_exporter to prometheus config file
  sudo tee -a /etc/prometheus/prometheus.yml <<EOF
  - job_name: 'node_exporter'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100']
EOF
  # Restart Prometheus
  sudo systemctl restart prometheus
}

install_Trickster () {
  # Add user
  sudo useradd --no-create-home --shell /bin/false trickster
  # Download file
  wget https://github.com/Comcast/trickster/releases/download/v0.1.5/trickster-0.1.5.linux-amd64.gz
  # Unzip gzipped file
  gunzip trickster-0.1.5.linux-amd64.gz
  # Copy file, change ownership and mode
  sudo cp trickster-0.1.5.linux-amd64 /usr/local/bin/trickster
  sudo chown trickster:trickster /usr/local/bin/trickster
  sudo chmod +x /usr/local/bin/trickster
  # Cleanup
  rm -rf trickster-0.1.5.linux-amd64
  # Add systemd unit file
  sudo tee /etc/systemd/system/trickster.service <<EOF
[Unit]
Description=Dashboard Accelerator for Prometheus
Documentation=https://github.com/Comcast/trickster
After=network.target

[Service]
EnvironmentFile=-/etc/default/trickster
User=trickster
ExecStart=/usr/local/bin/trickster \\
          $TRICKSTER_OPTS
ExecReload=/bin/kill -HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  # Start and enable Trickster
  sudo systemctl daemon-reload
  sudo systemctl start trickster
  sudo systemctl enable trickster
}

configure_Trickster () {
  # Download configuration file
  wget -O trickster.conf https://raw.githubusercontent.com/Comcast/trickster/master/conf/example.conf
  # Change the listen_port and the origin_url
  sed -i 's/# listen_port = 9090/listen_port=19090/' trickster.conf
  sed -i "s%origin_url = 'http://prometheus:9090'%origin_url = 'http://localhost:9090'%" trickster.conf
  # Copy the file and change the ownership
  sudo install --directory --owner=trickster --group=trickster /etc/trickster
  sudo cp trickster.conf /etc/trickster/trickster.conf
  sudo chown trickster:trickster /etc/trickster/trickster.conf
  # Restart Trickster
  sudo systemctl restart trickster
  # Cleanup
  rm -f trickster.conf
}

add_scrape_config_Trickster () {
  # Add scraping for node_exporter to prometheus config file
  sudo tee -a /etc/prometheus/prometheus.yml <<EOF
  - job_name: 'trickster'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:8082']
EOF
  # Restart Prometheus
  sudo systemctl restart prometheus
}


install_Grafana () {
  # Add repository for Grafana
  sudo tee -a /etc/apt/sources.list <<EOF
deb https://packagecloud.io/grafana/stable/debian/ stretch main
EOF
  # Add the GPG key
  sudo curl https://packagecloud.io/gpg.key | sudo apt-key add -
  # Install Grafana
  sudo apt-get update -y
  sudo apt-get install grafana -y
  # Start and enable Grafana
  sudo systemctl daemon-reload
  sudo systemctl enable grafana-server
  sudo systemctl start grafana-server
}

add_Trickster_datasource () {
  # Add configuration file for Trickster data source
  sudo tee /etc/grafana/provisioning/datasources/trickster.yaml <<EOF
apiVersion: 1
datasources:
- name: Trickster
  type: prometheus
  access: proxy
  orgId: 1
  url: http://localhost:19090
  version: 1
  editable: true
EOF
  # change the ownership of the configuration file
  chown grafana:grafana /etc/grafana/provisioning/datasources/trickster.yaml
  # Restart Grafana
  sudo systemctl start grafana-server
}

add_dashboards () {
  # Add configuration file for dashboards
  sudo tee /etc/grafana/provisioning/dashboards/dashboards.yaml <<EOF
apiVersion: 1

providers:
- name: 'default'
  orgId: 1
  folder: ''
  type: file
  disableDeletion: false
  updateIntervalSeconds: 10 #how often Grafana will scan for changed dashboards
  options:
    path: /var/lib/grafana/dashboards
EOF
  # Change the ownership of the configuration file
  chown grafana:grafana /etc/grafana/provisioning/dashboards/dashboards.yaml
  # Create directory for dashboards
  sudo install --directory --owner=grafana --group=grafana /var/lib/grafana/dashboards

  # Node exporter dashboard

  # Download json for node exporter dashboard
  wget -O node_exporter_dashboard.json https://grafana.com/api/dashboards/1860/revisions/12/download
  # Change the data source to the Trickster data source
  sed -i 's/${DS_LOCALHOST}/Trickster/g' node_exporter_dashboard.json
  # Copy the file to the right directory and change the ownership
  sudo cp node_exporter_dashboard.json /var/lib/grafana/dashboards/
  # Change the ownership of the configuration file
  sudo chown grafana:grafana /var/lib/grafana/dashboards/node_exporter_dashboard.json
  # Cleanup
  rm -f node_exporter_dashboard.json

  # Trickster dashboard

  # Install Pie Chart Plugin needed for Trickster dashboard
  sudo grafana-cli plugins install grafana-piechart-panel
  # Download json for Trickster dashboard
  wget -O Trickster_dashboard.json https://grafana.com/api/dashboards/5756/revisions/4/download
  # Somehow there's a missing curly bracket at the end of the file
  echo "}" >> Trickster_dashboard.json
  # Change the data source to the Trickster data source
  sed -i 's/${DS_PROMETHEUS}/Trickster/g' Trickster_dashboard.json
  # Change the trickster_label_name
  sed -i 's/"app"/"job"/' Trickster_dashboard.json
  # Change the prometheus_label_value
  sed -i 's/"prometheus-collector"/"prometheus"/' Trickster_dashboard.json
  # Change some VARs, cause this is not the normal way to add dashboards
  sed -i 's/${VAR_TRICKSTER_LABEL_NAME}/job/g' Trickster_dashboard.json
  sed -i 's/${VAR_TRICKSTER_LABEL_VALUE}/trickster/g' Trickster_dashboard.json
  sed -i 's/${VAR_PROMETHEUS_LABEL_NAME}/job/g' Trickster_dashboard.json
  sed -i 's/${VAR_PROMETHEUS_LABEL_VALUE}/prometheus/g' Trickster_dashboard.json
  # Copy the file to the right directory and change the ownership
  sudo cp Trickster_dashboard.json /var/lib/grafana/dashboards/
  # Change the ownership of the configuration file
  sudo chown grafana:grafana /var/lib/grafana/dashboards/Trickster_dashboard.json
  # Cleanup
  rm -f Trickster_dashboard.json

  # Restart Grafana
  sudo systemctl start grafana-server
}

display_message () {
IP_ADDRESS_2ND_IF=`ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}'|tail -1`
  cat << EOF

  Finished installing:
  - Prometheus
  - node_exporter
  - Trickster
  - Grafana

  Prometheus: http://${IP_ADDRESS_2ND_IF}:9090
  Grafana: http://${IP_ADDRESS_2ND_IF}:3000
  Grafana User: admin
  Grafana Pass: admin
EOF
}

# main
install_Prometheus
install_node_exporter
add_scrape_config_node_exporter
install_Trickster
configure_Trickster
add_scrape_config_Trickster
install_Grafana
add_Trickster_datasource
add_dashboards
display_message
exit 0
