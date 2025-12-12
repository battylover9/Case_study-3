#!/bin/bash
# ============================================================================
# EKS Node Bootstrap Script
# ============================================================================
# This script runs when each EKS worker node starts up
# It connects the node to your EKS cluster
# ============================================================================

set -ex

# Bootstrap the node to join the EKS cluster
/etc/eks/bootstrap.sh ${cluster_name} \
  --b64-cluster-ca ${cluster_ca} \
  --apiserver-endpoint ${cluster_endpoint} \
  --container-runtime containerd \
  --kubelet-extra-args '--node-labels=nodegroup=main,environment=production'

# Install CloudWatch agent (optional but recommended)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "metrics": {
    "namespace": "EKS/ContainerInsights",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_USAGE_IDLE", "unit": "Percent"},
          {"name": "cpu_usage_iowait", "rename": "CPU_USAGE_IOWAIT", "unit": "Percent"}
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DISK_USED_PERCENT", "unit": "Percent"}
        ],
        "resources": ["/"]
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEMORY_USED_PERCENT", "unit": "Percent"}
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/eks/${cluster_name}/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json \
  -s

echo "EKS node bootstrap complete"
