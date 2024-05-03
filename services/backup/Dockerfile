FROM debian:bookworm-slim

# install deps
RUN apt update
RUN apt install -y xxd curl unzip cron apt-transport-https ca-certificates gnupg
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && apt-get update -y && apt-get install google-cloud-sdk -y
RUN apt clean && \
    rm -rf /var/lib/apt/lists/*

# set up crontab
RUN touch /var/log/cron.log
RUN touch /etc/cron.d/backup-cron
RUN chmod 0644 /etc/cron.d/backup-cron
COPY create_crontab.sh /config/create_crontab.sh
RUN chmod +x /config/create_crontab.sh

# set up backup job
COPY backup.sh /config/backup.sh
RUN chmod +x /config/backup.sh

# set up init script
COPY init.sh /config/init.sh
RUN chmod +x /config/init.sh


# run init script
CMD /config/init.sh
