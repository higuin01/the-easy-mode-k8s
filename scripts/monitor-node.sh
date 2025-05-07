#!/bin/bash



ipServer=$(grep server machines.txt | cut -d " " -f 1)
ipWorker_0=$(grep worker-0 machines.txt | cut -d " " -f 1)
ipWorker_1=$(grep worker-1 machines.txt | cut -d " " -f 1)
ipWorker_2=$(grep worker-2 machines.txt | cut -d " " -f 1)
CMD="sudo scripts/sys-moni.sh"

ssh -o StrictHostKeyChecking=no -n root@"${ipServer}" "$CMD"
ssh -o StrictHostKeyChecking=no -n root@"${ipWorker_0}" "$CMD"
ssh -o StrictHostKeyChecking=no -n root@"${ipWorker_1}" "$CMD"
ssh -o StrictHostKeyChecking=no -n root@"${ipWorker_2}" "$CMD"