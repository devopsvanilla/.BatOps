# Nginx NodePort Deployment

This project sets up a minimal HTTP server using Nginx, exposed as a NodePort service in a Kubernetes cluster. Below are the instructions on how to build the Docker image, deploy it to Kubernetes, and access the Nginx server.

## Project Structure

```
nginx-nodeport-deployment
├── k8s
│   ├── deployment.yaml   # Kubernetes deployment configuration
│   ├── namespace.yaml     # Kubernetes namespace configuration
│   ├── service.yaml      # Kubernetes service configuration
├── src
│   ├── index.html        # Default HTML page served by Nginx
├── Dockerfile             # Dockerfile to build the Nginx image
└── README.md              # Project documentation
```

## Building the Docker Image

To build the Docker image for the Nginx server, run the following command in the project root directory:

```bash
docker build -t nginx-nodeport .
```

## Deploying to Kubernetes

1. **Create the Namespace:**
   To create the "loonar" namespace in your Kubernetes cluster, run:

   ```bash
   kubectl apply -f k8s/namespace.yaml
   ```

2. **Apply the Deployment:**
   To create the Nginx deployment in the "loonar" namespace, run:

   ```bash
   kubectl apply -f k8s/deployment.yaml -n loonar
   ```

3. **Apply the Service:**
   To expose the Nginx deployment as a NodePort service in the "loonar" namespace, run:

   ```bash
   kubectl apply -f k8s/service.yaml -n loonar
   ```

## Accessing the Nginx Server

Once the deployment and service are up and running, you can access the Nginx server using the NodePort assigned by Kubernetes. You can find the NodePort by running:

```bash
kubectl get services -n loonar
```

Use the Node IP and the NodePort to access the server in your web browser:

```
http://<Node-IP>:<NodePort>
```

## Notes

- Ensure that your Kubernetes cluster is running and configured correctly.
- You may need to adjust firewall settings to allow traffic on the NodePort.