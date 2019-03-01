\set postgresUserPassword `echo $(az keyvault secret show --id https://schoolexperiencevault.vault.azure.net/secrets/postgresUserPassword -o tsv --query value)`
\set schoolExperienceDB `echo ${DATABASE_NAME}`
CREATE DATABASE :schoolExperienceDB;
CREATE USER railsappuser WITH PASSWORD :'postgresUserPassword';
GRANT ALL PRIVILEGES ON DATABASE :schoolExperienceDB TO railsappuser;
