# Global Variables for the Entire Project
# Think of this as the "settings menu" for your infrastructure

# 📝 LOKI - Log Aggregation and Analysis
# REQ-NCA-P2-05, REQ-NCA-P2-09
# Think of Loki as:
# - A librarian that organizes all log books
# - Searchable logs from all your services
# - Like grep but for the entire infrastructure

# 🛡️ SECURITY GROUPS - Firewall rules for different parts of the system
# Think of these as different types of locks on different doors

# 🌐 PRIVATE DNS - So computers can find each other by name
# REQ-NCA-P2-04: Internal cloud DNS resolution

# Think of this like a phone book for your computers
# Instead of remembering "10.0.11.5", you can use "database.internal"

# 🔐 VPN CONNECTION - The Tunnel Between Home and Cloud
# This connects your on-premises toy box to the cloud toy box
=============================================================================================

# 🐳 ECS FARGATE CLUSTER - Where Containers Run
# REQ-NCA-P2-01: Design for failure (multiple AZs)
# REQ-NCA-P2-07: Serverless components (Fargate = no server management)

# Think of ECS as a toy organizer that automatically:
# - Puts toys (containers) on shelves (servers)
# - Replaces broken toys
# - Adds more shelves when busy

# Generate python app that generates random logs to test loki pipeline

# 📊 MONITORING INFRASTRUCTURE - EC2 Instance
# REQ-NCA-P2-05, REQ-NCA-P2-08, REQ-NCA-P2-09
# This server hosts Prometheus, Grafana, and Loki

# Think of this as the "security camera control room"
# Where all the monitors show what's happening everywhere

# 📊 GRAFANA - Visualization and Dashboards
# REQ-NCA-P2-05, REQ-NCA-P2-08, REQ-NCA-P2-09

# Think of Grafana as:
# - A TV screen showing all your camera feeds (metrics)
# - Beautiful dashboards to see everything at a glance
# - Alerts when something goes wrong

# 📊 PROMETHEUS - Metrics Collection and Monitoring
# REQ-NCA-P2-05, REQ-NCA-P2-08, REQ-NCA-P2-09

# Think of Prometheus as a smart camera system that:
# - Watches all your servers (scrapes metrics)
# - Records everything (stores time-series data)
# - Alerts you when something is wrong

# 🗄️ RDS DATABASE - PostgreSQL with Private Access
# REQ-NCA-P2-03: Database NOT exposed to public internet
# REQ-NCA-P2-01: Multi-AZ for high availability

# Think of this as a secure vault that only trusted apps can access
