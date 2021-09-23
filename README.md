# Oasis simple monitor
This solution is designed to monitor metrics of Cipher ParaTime nodes and Mainnet Validator nodes in the Oasis Network. It uses one file [metrics-collector.sh](https://github.com/hukutu4/oasismonitor/blob/main/metrics-collector.sh) to collect metrics from the node via Telegraf and send it every 30 seconds to [validators.top](https://validators.top), where installed Grafana and InfluxDB, and where you can see the metrics of your node by the public key named Entity ID.

- This installation assumes the use of community dashboard [validators.top](https://validators.top), so you don't need to set up your own monitoring server.
- If you only need JSON dashboard model - it is available here [oasis-community-dashboard.json](https://github.com/hukutu4/oasismonitor/blob/main/oasis-community-dashboard.json).

Validator node
![image](https://user-images.githubusercontent.com/15308726/134585275-53878448-1b2b-43d5-aeba-92db3de7862f.png)
Cipher ParaTime node
![image](https://user-images.githubusercontent.com/15308726/134585318-fa7f8400-5d49-462d-80fb-bf0de948f888.png)

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

## edit settings header at oasismonitor/metrics-collector.sh, default values below:
nano oasismonitor/metrics-collector.sh
# configDir="/node/etc"  # the directory for the config files, eg.: /node/etc
# sockAddr="unix:/node/data/internal.sock"
# binDir="/node/bin"

# Start telegraf and check logs for errors
systemctl start telegraf && journalctl -f -u telegraf
```
