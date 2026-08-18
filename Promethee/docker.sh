sudo docker rm -f jellyfin
sudo docker pull jellyfin/jellyfin:latest
sudo docker run -d \
  --name jellyfin \
  --restart=unless-stopped \
  -e TZ="Europe/Paris" \
  -e PUID="$USER_ID" \
  -e PGID="$GROUP_ID" \
  -p "$PortJellyFin:8096" \
  -p 8920:8920 \
  -v "$PathDkJellyfinConfig":/config \
  -v "$PathDkJellyfinCache":/cache \
  -v "$PathDkJellyfinMedia":/media:rw \
  --device /dev/dri/renderD128:/dev/dri/renderD128 \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  jellyfin/jellyfin:latest
