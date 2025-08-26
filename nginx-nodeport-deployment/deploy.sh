#!/bin/bash

# Namespace name
NAMESPACE="loonar"

# Function to check if a command was successful
check_command() {
  if [ $? -ne 0 ]; then
    echo "Error: $1"
    exit 1
  fi
}

echo "Starting the deployment of Nginx NodePort..."

# Step 1: Create the namespace
echo "Creating the namespace '$NAMESPACE'..."
kubectl apply -f k8s/namespace.yaml
check_command "Failed to create the namespace."

# Step 2: Apply the deployment
echo "Applying the deployment in the namespace '$NAMESPACE'..."
kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
check_command "Failed to apply the deployment."

# Step 3: Apply the service
echo "Applying the NodePort service in the namespace '$NAMESPACE'..."
kubectl apply -f k8s/service.yaml -n $NAMESPACE
check_command "Failed to apply the service."

# Step 4: Retrieve the NodePort
echo "Retrieving the NodePort to access the Nginx server..."
NODE_PORT=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[0].spec.ports[0].nodePort}')
check_command "Failed to retrieve the NodePort."

# Display access information
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Nginx server is available at: http://$NODE_IP:$NODE_PORT"

echo "Deployment completed successfully!"