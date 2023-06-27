# REDMINE-O365
Thank you for all your help [@Andrew Beam](https://github.com/beam)

1) First urn `docker compose up`
2) then Copy newly generated certificate from container `docker cp {CONTAINER ID}:/etc/ssl/private/ .\`
3) Azure AD (App Registration)
    1) Go to https://portal.azure.com/
    2) click `App registrations`
    3) click `new registration`
    4) ...
    5) click `Certificates & Secrets`
    6) click `Certificates`
    7) click `Upload client certificate` select file and click **add**
    * Sometimes it can tak up to few minutes for certificate to be activated
4) Fil in required information to `conf.json.example`
5) rename `conf.json.example` > `conf.json`
6) Restart Container `docker compose down && docker compose up -d`
