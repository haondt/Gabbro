#!/bin/sh

# Function to perform the curl request with timeout
perform_curl() {
   curl -s "$GCP_HEALTHCHECK_URL" -m "$HEALTHCHECK_TIMEOUT"
}

# Main loop
while true; do
  # Perform the curl request
  perform_curl

  # Sleep for the specified interval
  sleep "$HEALTHCHECK_INTERVAL"
done

