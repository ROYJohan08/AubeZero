sudo docker rm -f homeassistant
sudo docker pull homeassistant/home-assistant:latest

sudo docker run -d \
  --name homeassistant \
  --restart=unless-stopped \
  --network=host \
  -e TZ="Europe/Paris" \
  -v "$PathDkHomeAssistant:/config" \
  -v /run/dbus:/run/dbus:ro \
  --device /dev/dri:/dev/dri \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --cap-add NET_RAW \
  --cap-add NET_ADMIN \
  --cap-add NET_BIND_SERVICE \
  homeassistant/home-assistant:latest
