#!/bin/bash
SSH_PORT=22222
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${SSH_PORT}" vagrant@127.0.0.1 "$@"
