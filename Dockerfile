FROM mcr.microsoft.com/powershell

COPY conf.json /app/conf.json
COPY cert.ps1 /app/cert.ps1
RUN pwsh /app/cert.ps1