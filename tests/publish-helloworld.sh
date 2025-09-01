#!/bin/bash

# Check if port is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <port>"
    exit 1
fi

PORT=$1

echo "Server running on port $PORT"
echo "You can test it by running: curl http://localhost:$PORT or by opening http://localhost:$PORT in your browser"
echo "Press Ctrl+C to stop the server"

echo "
Example of usage in another terminal or browser:" 
echo "  curl http://localhost:$PORT"
echo "  or open http://localhost:$PORT in your browser
"

# Sending "hello world" on the specified port
# Using a while loop to keep the server running
while true; do
  echo -e "HTTP/1.1 200 OK
Content-Length: 12

hello world" | nc -l -p $PORT
done