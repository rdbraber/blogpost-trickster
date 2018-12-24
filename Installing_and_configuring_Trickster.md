+++
showonlyimage = true
draft = false
image = "https://i.imgur.com/uodNnPR.png"
date = "2018-12-21T16:02:22+05:30"
title = "Installing and configuring Trickster"
categories = ["Monitoring"]
tags = ["Prometheus","Grafana","Trickster"]
weight = 400
+++

For a project I'm working on we are using [Prometheus](https://prometheus.io) and [Grafana](https://grafana.com) to monitor the [Kubernetes](https://kubernetes.io/) clusters.


<!--more-->

Today I found out about [Trickster](https://github.com/Comcast/trickster), a reverse proxy cache for Prometheus which can improve the dashboard rendering time in Grafana. This blogpost describes the installation and configuration of Trickster.

## Requirements

I've created a Vagrantfile with an installation file, which installs and configures the following components:
- Prometheus, with a node-exporter to get some operating system metrics
- Trickster
- Grafana with some dashboards

For the Vagrantfile to work, you need the following tools installed on your PC or laptop:
- [Virtualbox](https://www.virtualbox.org)
- [Vagrant](https://www.vagrantup.com)
- [Git](https://git-scm.com)

As I most of the time work with Red Hat based linux systems, this post uses [Ubuntu linux 18.04](http://releases.ubuntu.com/18.04/).

## Installing Prometheus

Prometheus is not available in the standard package repositories for Ubuntu 18.04, so we have to add the binary file ourselves.

Create the user which is going to run Prometheus:

```
sudo useradd --no-create-home --shell /bin/false prometheus
```

Create two directories for prometheus with the correct ownership (always nice to learn new commands):

```
sudo install --directory --owner=prometheus --group=prometheus /etc/prometheus /var/lib/prometheus
```

Download the latest version of Prometheus. While writing this blogpost it was 2.6.0. All versions can be found at [Github](https://github.com/prometheus/prometheus/releases):

```
wget https://github.com/prometheus/prometheus/releases/download/v2.6.0/prometheus-2.6.0.linux-amd64.tar.gz
```

Also download the sha256sums.txt file to compare the sha256 checksum with the one that is the textfile:

```
wget https://github.com/prometheus/prometheus/releases/download/v2.6.0/sha256sums.txt
```

To compare the checksum of the file with the one that is in the textfile use the `grep` command. If the checksum is found it will show the output:

```
grep $(sha256sum prometheus-2.6.0.linux-amd64.tar.gz) sha256sums.txt
```

If the following output is shown, the checksum is allright:

```
sha256sums.txt:8f1f9ca9dbc06e1dc99200e30526ca8343dfe80c2bd950847d22182953261c6c  prometheus-2.6.0.linux-amd64.tar.gz
```

Untar the prometheus tarfile:

```
tar -xvf prometheus-2.6.0.linux-amd64.tar.gz
```

This will create a directory, which contains two binary files:
- prometheus
- promtool

Copy these files to the directory `/usr/local/bin` and change the ownership:

```
sudo cp prometheus-2.6.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.6.0.linux-amd64/promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
```

Copy the `consoles` and `consoles_libraries` directories to `/etc/prometheus` and change the ownership:

```
sudo cp -r prometheus-2.6.0.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-2.6.0.linux-amd64/console_libraries /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
```

As an example also a configuration file is added, so we copy that file to the `/etc/prometheus` directory:

```
sudo cp prometheus-2.6.0.linux-amd64/prometheus.yml /etc/prometheus
sudo chown prometheus:prometheus /etc/prometheus /etc/prometheus/prometheus.yml
```

Last step is to create a systemd unit file, to make sure Prometheus can be started both manually and at boottime. Create the file `/etc/systemd/system/prometheus.service`. Use the command `sudo vi /etc/systemd/system/prometheus.service` to add the following content:

```
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
```

Reload `systemd` and start Prometheus:

```
sudo systemctl daemon-reload
sudo systemctl start prometheus
```
Now Prometheus should be running. This can be checked with the `sudo systemctl status prometheus` command. If it shows the status `active (running)`, Prometheus is started correctly.

Enable the prometheus service to start at boottime:

```
sudo systemctl enable prometheus
```

Last step is to remove the downloaded files and extracted directories:
```
rm -f prometheus-2.6.0.linux-amd64.tar.gz sha256sums.txt
rm -rf prometheus-2.6.0.linux-amd64
```

To check if Prometheus is really running, use your web-browser and go to the url http:<vagrant-box>:9090. In case you used the Vagrantfile, this is http://192.168.20.10:9090. If everything went well you should see the Prometheus webpage. Currently it will only show some metrics about Prometheus itself so let's add the node-exporter, which will add some server metrics to Prometheus.

## Installing the node_exporter

Installing the node-exporter requires almost the same steps as we did with the installation of Prometheus, so I won't describe every step, but instead show the commands for the installation:

```
sudo useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v0.17.0/node_exporter-0.17.0.linux-amd64.tar.gz
wget https://github.com/prometheus/node_exporter/releases/download/v0.17.0/sha256sums.txt
grep $(sha256sum node_exporter-0.17.0.linux-amd64.tar.gz) sha256sums.txt
tar -zxvf node_exporter-0.17.0.linux-amd64.tar.gz
sudo cp node_exporter-0.17.0.linux-amd64/node_exporter /usr/local/bin
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-0.17.0.linux-amd64.tar.gz node_exporter-0.17.0.linux-amd64
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
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```

## Configuring Prometheus to scrape the metrics from the node_exporter

To be able to collect (Prometheus calls it scraping) the metrics from the node_exporter, we have to add the some extra configuration to the Prometheus configuration file `/etc/prometheus/prometheus.yml`. Don't forget to use the `sudo` command when editing this file. Add the following lines:

```
  - job_name: 'node_exporter'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100']
```

After this part has been added, restart Prometheus:

```
sudo systemctl restart prometheus
```

Now when you visit the Prometheus webpage and select Status and Targets, you should see two endpoints now (node_exporter & prometheus).


## Installing and configuring Trickster

We are going to install Trickster the same way as we did install Prometheus and the node_exporter, so again just the commands:

```
sudo useradd --no-create-home --shell /bin/false trickster
wget https://github.com/Comcast/trickster/releases/download/v0.1.5/trickster-0.1.5.linux-amd64.gz
gunzip trickster-0.1.5.linux-amd64.gz
sudo cp trickster-0.1.5.linux-amd64 /usr/local/bin/trickster
sudo chown trickster:trickster /usr/local/bin/trickster
sudo chmod +x /usr/local/bin/trickster
rm -rf trickster-0.1.5.linux-amd64
sudo tee /etc/systemd/system/trickster.service <<EOF
[Unit]
Description=Dashboard Accelerator for Prometheus
Documentation=https://github.com/Comcast/trickster
After=network.target

[Service]
EnvironmentFile=-/etc/default/trickster
User=trickster
ExecStart=/usr/local/bin/trickster \
          $TRICKSTER_OPTS
ExecReload=/bin/kill -HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl start trickster
sudo systemctl enable trickster
```

The Trickster service will start, but immediately fail, as it will try to use the same network port Prometheus is using. So what we need is a configuration file for Trickster. This file should be located at `/etc/trickster/trickster.conf`. An example can be found at [Github page of Trickster](https://raw.githubusercontent.com/Comcast/trickster/master/conf/example.conf).

Download this file:

```
wget -O trickster.conf https://raw.githubusercontent.com/Comcast/trickster/master/conf/example.conf
```

First lets change the port Trickster is listening on to 19090. Edit the file `trickster.conf` and change the line:

```
# listen_port = 9090
```

to:

```
listen_port = 19090
```

We also need to specify the Prometheus source server, which can be done by changing the parameter `origin_url`. Change the line:

```
origin_url = 'http://prometheus:9090'
```

to:

```
origin_url = 'http://localhost:9090'
```

Copy the file to the directory `/etc/trickster`:

```
sudo install --directory --owner=trickster --group=trickster /etc/trickster
sudo cp trickster.conf /etc/trickster/trickster.conf
sudo chown trickster:trickster /etc/trickster/trickster.conf
```

Now restart the Trickster service and check the status:

```
sudo systemctl restart trickster
sudo systemctl status trickster
```

## Installing and configuring Grafana

Although there is a possibility to show graphs in Prometheus, it's kind of basic. That's where Grafana comes into play. Grafana is an open-source, general purpose dashboard and graph composer. We are going to install Grafana using the normal way to install packages on Ubuntu. First add the repository to the `sources.list` file:

```
sudo tee -a /etc/apt/sources.list <<EOF
deb https://packagecloud.io/grafana/stable/debian/ stretch main
EOF
```

Add the GPG key:

```
sudo curl https://packagecloud.io/gpg.key | sudo apt-key add -
```

Install Grafana:

```
sudo apt-get update -y
sudo apt-get install grafana -y
```

Make sure Grafana is started and enabled at boottime:

```
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

## Choosing a data source for Grafana

Now that everything is installed, log on to the Grafana webpage by going to http://<vagrant-box>:3000, which in my case is http://192.168.20.10:3000. Both the username and password for Grafana are admin. Once logged in you can choose your data source by clicking on the Add data source icon.

We are going to add Trickster as our data source, but since it's actually a reverse proxy cache for Prometheus, select the Prometheus tile as your data source type. The only field that needs to be filled in is the URL field. Here we add the value `http://localhost:19090`, which is Trickster.
If you want, you can change the Name of the data source to for example Trickster.

Click on the Save & Test button and the data source is added.

## Adding dashboards to Grafana

Now that we are scraping node metrics, it would be nice to have a dashboard that can show the metrics. On the Grafana website a lot of user created dashboards can be found.
Search at [https://grafana.com/dashboards](https://grafana.com/dashboards). Search in the search box for the [Node Exporter Full](https://grafana.com/dashboards/1860) dashboard. The number of this dashboard is 1860.

On the left side of your Grafana page, click on the 4 squares and on the home button.
Click on the word Home and on Import dashboard.
Fill in the id (1860) and click on Load.

In the next screen select the data source and click on Import. Now you should be able to see some graphs about the server.

## Performance testing Grafana with and without Trickster

As we don't have much data in Prometheus yet, it's a bit difficult to measure the performance of Grafana. The good thing is that Trickster also has some metrics, so we could scrape those as well with Prometheus and see if the cache is being used.

Add the following lines to the file `/etc/prometheus/prometheus.yml`. Don't forget to use the `sudo` command when editing this file:

```
  - job_name: 'trickster'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:8082']
```
Restart Prometheus:

```
sudo systemctl restart prometheus
```

There is also a [Trickster](https://grafana.com/dashboards/5756) dashboard available (5756) which can be imported in Grafana. This dashboard requires the [grafana-piechart-panel](https://grafana.com/plugins/grafana-piechart-panel). Plugins can be installed with the `grafana-cli`:

```
sudo grafana-cli plugins install grafana-piechart-panel
```

After a plugin is installed, a restart of Grafana is required:

```
sudo systemctl restart grafana-server
```

Now in Grafana add the Trickster dashboard (5756). The following fields need to be filled in:

option|value
------|-----
Prometheus|Select the name of your data source
trickster_label_name|job
trickster_label_value|trickster
prometheus_label_name|job
prometheus_label_value|prometheus

After these values are filled in, click on the import button.

In my case I had a cache hit rate of around 90%, which seems fair, but the main question remains, if it still speeds up the loading of the dashboards.
