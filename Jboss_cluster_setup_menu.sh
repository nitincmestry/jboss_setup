#!/bin/bash
# ==============================================================
# Script: cluster_setup_menu.sh
# Author: Nitin Mestry
# Purpose: JBoss EAP domain cluster & Apache balancer setup
# ==============================================================

JBOSS_HOME="/opt/jboss-eap-7"
JBOSS_CLI="$JBOSS_HOME/bin/jboss-cli.sh"
CONFIG_DIR="$JBOSS_HOME/domain/configuration"
BALANCER_CONF="/etc/httpd/conf.d/jboss_balancer.conf"

# --- Detect OS version and package manager ---
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  OS_ID="$ID"
  OS_VERSION_ID="${VERSION_ID%%.*}"
else
  echo "[ERROR] Cannot determine OS version."
  exit 1
fi

# Determine package manager based on RHEL version
if [[ "$OS_ID" == "rhel" || "$OS_ID" == "centos" ]]; then
  if [[ "$OS_VERSION_ID" -ge 8 ]]; then
    PKG_MGR="dnf"
  else
    PKG_MGR="yum"
  fi
else
  echo "[ERROR] Unsupported OS: $OS_ID"
  exit 1
fi

# --- Functions ---

setup_domain_controller() {
  echo "====== Setup JBoss Domain Controller ======"
  read -p "Enter node name (e.g., APP1): " NODE_NAME
  sed -i "s/<name>.*</<name>$NODE_NAME</" "$CONFIG_DIR/host-master.xml"
  echo "[INFO] Starting Domain Controller..."
  "$JBOSS_HOME/bin/domain.sh" --host-config=host-master.xml
}

setup_host_controller() {
  echo "====== Setup JBoss Host Controller (Slave) ======"
  read -p "Enter node name (e.g., APP2): " NODE_NAME
  read -p "Enter Domain Controller IP: " DC_IP
  sed -i "s/<name>.*</<name>$NODE_NAME</" "$CONFIG_DIR/host-slave.xml"
  sed -i "s/<remote host=.* port=.*/<remote host=\"$DC_IP\" port=\"9999\"/" "$CONFIG_DIR/host-slave.xml"
  echo "[INFO] Starting Host Controller (slave)..."
  "$JBOSS_HOME/bin/domain.sh" --host-config=host-slave.xml
}

deploy_war_to_domain() {
  echo "====== Deploy WAR ======"
  read -p "Enter full path to WAR file: " WAR_PATH
  if [[ ! -f "$WAR_PATH" ]]; then
    echo "[ERROR] File not found: $WAR_PATH"
    return
  fi
  echo "[INFO] Deploying WAR to server group 'main-server-group'..."
  "$JBOSS_CLI" --connect controller=localhost:9990 <<EOF
deploy "$WAR_PATH" --server-groups=main-server-group --force
EOF
}

setup_apache_webserver() {
  echo "====== Setup Apache Web Server with mod_cluster ======"

  echo "[INFO] Installing Apache HTTPD and mod_cluster using $PKG_MGR..."
  $PKG_MGR install -y httpd mod_cluster

  echo "[INFO] Writing mod_cluster config to $BALANCER_CONF"
  cat <<EOF > "$BALANCER_CONF"
LoadModule proxy_cluster_module modules/mod_proxy_cluster.so
LoadModule advertise_module modules/mod_advertise.so

Listen 80
ManagerBalancerName mycluster

<VirtualHost *:80>
    ServerName localhost

    EnableMCPMReceive
    MaxMCMPConnections 10
    ServerAdvertise on

    <Directory />
        Require all granted
    </Directory>

    <Location "/mod_cluster_manager">
        SetHandler mod_cluster-manager
        Require all granted
    </Location>
</VirtualHost>
EOF

  echo "[INFO] Enabling and restarting Apache..."
  systemctl enable httpd
  systemctl restart httpd

  echo "[INFO] Ensure JBoss is configured with mod_cluster subsystem and matching advertise socket."
  echo "[SUCCESS] Apache with mod_cluster is ready at: http://<this-vm-ip>/"
  echo "mod_cluster Manager: http://<this-vm-ip>/mod_cluster_manager"
}


# --- Menu ---

show_menu() {
  echo ""
  echo "========================================="
  echo "  JBoss Domain & Apache Setup Menu"
  echo "        Author: Nitin Mestry"
  echo "  OS: $PRETTY_NAME | Using: $PKG_MGR"
  echo "========================================="
  echo "1) Setup JBoss Domain Controller"
  echo "2) Setup JBoss Host Controller (Slave)"
  echo "3) Deploy WAR to Domain"
  echo "4) Setup Apache Load Balancer"
  echo "5) Exit"
  echo "========================================="
}

while true; do
  show_menu
  read -p "Choose an option [1-5]: " CHOICE
  case "$CHOICE" in
    1) setup_domain_controller ;;
    2) setup_host_controller ;;
    3) deploy_war_to_domain ;;
    4) setup_apache_webserver ;;
    5) echo "Goodbye!"; exit 0 ;;
    *) echo "[ERROR] Invalid option. Try again." ;;
  esac
done
