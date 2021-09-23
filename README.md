# Oasis simple monitor

## Install telegraf
```bash
sudo cat <<EOF | sudo tee /etc/apt/sources.list.d/influxdata.list
deb https://repos.influxdata.com/ubuntu bionic stable
EOF

sudo apt install -y curl gnupg2

sudo curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
sudo apt update
sudo apt -y install telegraf jq bc

sudo systemctl stop telegraf
```
## Configure telegraf
```bash
sudo mv /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig
# Attention! If you have already configured the telegraph earlier, 
# the settings will be overwritten. The old file can be restored from the backup above.
sudo cat > /etc/telegraf/telegraf.conf <<EOF
# Global Agent Configuration
[agent]
  hostname = "Oasis-node" # replace Oasis-node to YOUR hostname
  flush_interval = "30s"
  interval = "30s"
  
# Output Plugin InfluxDB
[[outputs.influxdb]]
  database = "oasismetricsdb"
  urls = [ "http://validators.top:8086" ]
  username = "oasismetrics"
  password = "oasis"

# Oasis monitor
[[inputs.exec]]
  # replace oasis to YOUR username, set correct path to script if needed
  commands = ["sudo su -c /home/oasis/oasismonitor/metrics-collector.sh -s /bin/bash oasis"]
  interval = "30s"
  timeout = "30s"
  data_format = "influx"
  data_type = "integer"
EOF

# make the telegraf user sudo and adm to be able to execute scripts
sudo adduser telegraf sudo
sudo adduser telegraf adm
sudo -- bash -c 'echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
```
## Clone this repo and start telegraf
```bash
cd ~
git clone https://github.com/hukutu4/oasismonitor
chmod +x oasismonitor/metrics-collector.sh

# Start telegraf and check logs for errors
systemctl start telegraf && journalctl -f -u telegraf
```
