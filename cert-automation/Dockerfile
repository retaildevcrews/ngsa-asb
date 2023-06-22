# azure cli base image
FROM mcr.microsoft.com/azure-cli

# install certbot
RUN apk add --no-cache certbot

# create certbot user
RUN addgroup -S certbot && adduser -S certbot -G certbot

# change to certbot home directory
WORKDIR /home/certbot

# copy scripts and change ownership
COPY --chown=certbot:certbot ./cert-automation/certbot .

# change to certbot user
USER certbot
