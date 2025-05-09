#!/bin/bash

# IPs
BASTION_PUBLIC_IP=13.48.128.156
YOLO_PRIVATE_IP=10.0.1.37
POLYBOT_PRIVATE_IP=10.0.0.239

# Keys
BASTION_KEY=bastion-key.pem
YOLO_KEY=Yolo-key.pem
POLYBOT_KEY=polybot-key.pem

# Target to connect
TARGET=$1  # Options: yolo / polybot

if [[ "$TARGET" == "yolo" ]]; then
    ssh -i $BASTION_KEY -A ec2-user@$BASTION_PUBLIC_IP \
        -t ssh -i $YOLO_KEY ec2-user@$YOLO_PRIVATE_IP
elif [[ "$TARGET" == "polybot" ]]; then
    ssh -i $BASTION_KEY -A ec2-user@$BASTION_PUBLIC_IP \
        -t ssh -i $POLYBOT_KEY ec2-user@$POLYBOT_PRIVATE_IP
else
    echo "Usage: ./bastion_connect.sh [yolo|polybot]"
fi