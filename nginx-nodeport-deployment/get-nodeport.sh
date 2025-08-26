#!/usr/bin/bash

# Namespace name
NAMESPACE="loonar"

# Function to check if a command was successful
check_command() {
  if [ $? -ne 0 ]; then
    echo "Error: $1"
    exit 1
  fi
}

# Step 4: Retrieve the NodePort
echo "Retrieving the NodePort to access the Nginx server..."
NODE_PORT=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[0].spec.ports[0].nodePort}')
check_command "Failed to retrieve the NodePort."

# Display access information
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Nginx server is available at: http://$NODE_IP:$NODE_PORT"
