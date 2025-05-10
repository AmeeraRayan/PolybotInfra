#!/bin/bash

# Check if KEY_PATH environment variable is set (for Bastion)
if [ -z "$KEY_PATH" ]; then
  echo "KEY_PATH env var is expected"
  exit 5
fi

# Check if at least one argument (bastion IP) is provided
if [ -z "$1" ]; then
  echo "Please provide bastion IP address"
  exit 5
fi

BASTION_IP=$1
TARGET_IP=$2
COMMAND=${@:3}

# If target IP is provided – choose the correct key
if [ -n "$TARGET_IP" ]; then
  if [ "$TARGET_IP" == "10.0.0.239" ]; then
    TARGET_KEY="/home/ec2-user/polybot-key.pem"
  elif [ "$TARGET_IP" == "10.0.1.37" ]; then
    TARGET_KEY="/home/ec2-user/Yolo-key.pem"
  else
    echo "Unknown target IP. Make sure you are using the correct IPs."
    exit 5
  fi
fi

# If no target IP is provided – connect to bastion only
if [ -z "$TARGET_IP" ]; then
  ssh -tt -i "$KEY_PATH" ec2-user@$BASTION_IP

# If target IP is provided and no command – connect to target via bastion
elif [ -z "$COMMAND" ]; then
  ssh -tt -i "$KEY_PATH" ec2-user@$BASTION_IP "ssh -tt -i $TARGET_KEY ec2-user@$TARGET_IP"

# If command is provided – run it on target via bastion
else
  ssh -tt -i "$KEY_PATH" ec2-user@$BASTION_IP "ssh -tt -i $TARGET_KEY ec2-user@$TARGET_IP \"$COMMAND\""
fi