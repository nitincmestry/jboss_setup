#!/bin/bash
# ==============================================================
# Script: cluster_setup_menu.sh
# Author: Nitin Mestry
# Purpose: Menu-driven setup for JBoss EAP domain cluster and Apache load balancer
# ==============================================================

JBOSS_HOME="/opt/jboss-eap-7"
JBOSS_CLI="$JBOSS_HOME/bin/jboss-cli.sh"
CONFIG_DIR="$JBOSS_HOME/domain/configuration"
BALANCER_CONF="/etc/httpd/conf.d/jboss_balancer.conf"

function setup_domain_controller() {
  echo "====== JBoss Domain Controller Setup ======"
  read -p "Enter this node's name (e.g., APP1): " NODE_NAME

  sed -i "s/<name>.*<\/name>/<name>$NODE_NAME<\/name>/" "$CONFIG_DIR/host-master.xml"

  echo "[INFO] Starting JBoss as Domain Controller..."
  "$JBOSS_HOME/bin/domain.sh" --host-config=host-master.xml
}

function setup_host_controller() {
  echo "====== JBoss Host Controller (Slave) Setup ======"
  read -p "Enter this node's name (e.g., APP2): " NODE_NAME
  read -p "Enter Domain Controller IP: " DC_IP

  sed -i "s/<name>.*<\/name>/<name>$NODE_NAME<\/name>/" "$CONFIG_DIR/host-slave.xml"
  sed -i "s/<remote host=\".*\" port=\"9999\"/<remote host=\"$DC_IP\" port=\"9999\"/" "$CONFIG_DIR/host-slave.xml"

  echo "[INFO] Starting JBoss as Host Controller (slave)..."
  "$JBOSS_HOME/bin/domain.sh" --host-config=host-slave.xml
}

function deploy_war_to_domain() {
  echo "====== WAR Deployment ======"
  read -p "Enter full path to WAR file (e.g., /tmp/myapp.war): " WAR_PATH

  if [ ! -f "$WAR_PATH" ]; then
    echo "[ERROR] WAR file not found!"
    return
  fi

  echo "[INFO] Deploying to server group 'main-server-group'..."
  "$JBOSS_CLI" --connect controller=localhost:9990 <<EOF
deploy "$WAR_PATH" --server-groups=main-server-group --force
EOF
}

function setup_apache_webserver() {
  echo "====== Apache Web Server Setup ======"

  read -p "How many JBoss application nodes to add to the balancer? " COUNT
  APP_SERVERS=()
  for ((i=1; i<=COUNT; i++)); do
    read -p "Enter APP Node $i IP:PORT (e.g., 172.16.29.109:8080): " NODE
    APP_SERVERS+=("$NODE")
  done

  echo "[INFO] Installing Apache HTTPD and modules..."
  yum install -y httpd mod_proxy mod_proxy_http mod_proxy_balancer mod_slotmem_shm

  echo "[INFO] Writing Apache config to $BALANCER_CONF"
  cat <<EOF > "$BALANCER_CONF"
ProxyPreserveHost On

<Proxy "balancer://jboss_cluster">
EOF

  for SERVER in "${APP_SERVERS[@]}"; do
    echo "  BalancerMember http://$SERVER" >> "$BALANCER_CONF"
  done

  cat <<EOF >> "$BALANCER_CONF"
  ProxySet lbmethod=byrequests
</Proxy>

ProxyPass / balancer://jboss_cluster/
ProxyPassReverse / balancer://jboss_cluster/

<Location "/balancer-manager">
    SetHandler balancer-manager
    Require all granted
</Location>
EOF

  echo "[INFO] Enabling required modules in httpd.conf..."
  echo "LoadModule slotmem_shm_module modules/mod_slotmem_shm.so" >> /etc/httpd/conf/httpd.conf
  echo "LoadModule proxy_balancer_module modules/mod_proxy_balancer.so" >> /etc/httpd/conf/httpd.conf
  echo "LoadModule lbmethod_byrequests_module modules/mod_lbmethod_byrequests.so" >> /etc/httpd/conf/httpd.conf

  systemctl enable httpd
  systemctl restart httpd

  echo "[SUCCESS] Apache load balancer ready at: http://<web-server-ip>/"
  echo "Access balancer manager at: http://<web-server-ip>/balancer-manager"
}

function show_menu() {
  echo ""
  echo "========================================="
  echo "      JBoss Domain & Web Setup Menu"
  echo "        Author: Nitin Mestry"
  echo "========================================="
  echo "1) Setup JBoss Domain Controller"
  echo "2) Setup JBoss Host Controller (Slave)"
  echo "3) Deploy WAR from Domain Controller"
  echo "4) Setup Apache Web Server (Load Balancer)"
  echo "5) Exit"
  echo "========================================="
}

while true; do
  show_menu
  read -p "Choose an option [1-5]: " OPTION
  case $OPTION in
    1) setup_domain_controller ;;
    2) setup_host_controller ;;
    3) deploy_war_to_domain ;;
    4) setup_apache_webserver ;;
    5) echo "Exiting..."; exit 0 ;;
    *) echo "[ERROR] Invalid choice, please select 1–5." ;;
  esac
done
