#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjf /tmp/workspace.tar.bz2 --exclude .git .

log "Launching ssh agent."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY" | base64 -d)

remote_command="set -e; 

log() { 
    echo '>> [remote]' \$@ ; 
}; 

workdir=\"\$HOME/${DOCKER_COMPOSE_PREFIX}_workspace\"

if [ -d \$workdir ] 
then
    if [ -f \$workdir/$DOCKER_COMPOSE_FILENAME ] 
    then
      log 'Docker Compose Down...'; 
      docker-compose -f \$workdir/$DOCKER_COMPOSE_FILENAME down
    fi
    log 'Removing workspace...'; 
    rm -rf \$workdir; 
fi

log 'Creating workspace directory...';
mkdir \$workdir; 

log 'Unpacking workspace...'; 
tar -C \$workdir -xj; 

ls -al

log 'Launching docker-compose...'; 
cd \$workdir; 
docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --remove-orphans --build"

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
