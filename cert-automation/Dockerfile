# azure cli base image
FROM mcr.microsoft.com/azure-cli

# install certbot
RUN apk add --no-cache certbot

# create certbot user
RUN addgroup -S certbot && adduser -S certbot -G certbot

# change to certbot home directory
WORKDIR /home/certbot

# create a directory for certbot generate files
RUN mkdir -p ./certbot-files && chown -R certbot:certbot ./certbot-files

# copy scripts and change ownership
COPY --chown=certbot:certbot ./cert-automation/certbot ./cert-automation/certbot

# change to certbot user
USER certbot

# set default entrypoint and command
ENTRYPOINT [ "certbot" ]

CMD [ "--version" ]
