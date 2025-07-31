FROM mcr.microsoft.com/mssql-tools


RUN ln -s /opt/mssql-tools/bin/sqlcmd /usr/local/bin/sqlcmd


COPY scripts /scripts
RUN chmod +x /scripts/*.sh

# Keep the container running to allow for exec commands or for it to act as a persistent client tool
CMD ["tail", "-f", "/dev/null"]
