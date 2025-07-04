
# JBoss EAP Domain Mode & Apache Load Balancer Setup (RHEL-Aware)

**Author:** Nitin Mestry

This menu-driven script automates the setup of a JBoss EAP cluster in **domain mode** and configures an Apache HTTPD load balancer.  
✅ It detects the RHEL version and chooses the correct package manager (`yum` or `dnf`) accordingly.

---

## 📦 Features

- Interactive menu-driven setup
- Compatible with RHEL 7, 8, and 9
- Automatically uses `yum` or `dnf`
- Supports:
  - JBoss Domain Controller setup
  - JBoss Host Controller (slave) setup
  - WAR deployment to domain
  - Apache HTTPD load balancer configuration

---

## 🧱 Components

| Component | Description                         | Example Hostname     |
|-----------|-------------------------------------|----------------------|
| APP1      | JBoss Domain Controller             | CLD-xxxx-APP1       |
| APP2–4    | JBoss Host Controllers (Slaves)     | CLD-xxxx-APP2–4     |
| WEB1–2    | Apache Web Load Balancer Servers    | CLD-xxxx-WEB1–2     |

---

## 🛠️ Prerequisites

- OS: RHEL 7 / 8 / 9 (auto-detected)
- JBoss EAP 7 installed at `/opt/jboss-eap-7`
- Apache HTTPD (installed by the script)
- Run the script with `sudo` or as `root`
- Ensure network connectivity between APP and WEB nodes

---

## 🚀 How to Use

### 1. Copy the script to each node

```bash
scp cluster_setup_menu.sh <node_ip>:/opt/
```

### 2. Run the script on each node

```bash
cd /opt
chmod +x cluster_setup_menu.sh
sudo ./cluster_setup_menu.sh
```

### 3. Use the interactive menu

| Option | Description                                           |
|--------|-------------------------------------------------------|
| 1      | Setup JBoss Domain Controller (APP1)                  |
| 2      | Setup JBoss Host Controller (Slaves: APP2–APP4)       |
| 3      | Deploy WAR to Domain (run from APP1)                  |
| 4      | Setup Apache HTTPD Load Balancer (on WEB1 or WEB2)    |
| 5      | Exit                                                  |

---

## 🔄 Example Workflow

1. On **APP1**, run script → choose Option 1  
2. On **APP2–4**, run script → choose Option 2 → enter DC IP  
3. On **APP1**, run script → choose Option 3 → deploy `.war`  
4. On **WEB1 & WEB2**, run script → choose Option 4 → enter APP IP:PORT  

---

## 🌐 Access URLs

- App URL: `http://<web-ip>/`
- Balancer Manager: `http://<web-ip>/balancer-manager`

---

## 📎 Notes

- Apache modules used: `mod_proxy`, `mod_proxy_http`, `mod_proxy_balancer`, `mod_slotmem_shm`
- Script supports dynamic server naming and IP input
- SELinux note (for RHEL 9):

```bash
sudo setsebool -P httpd_can_network_connect 1
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

---

## 📞 Support

For enhancements or troubleshooting, contact:

**Nitin Mestry**
