\set postgresUserPassword `echo ${postgresUserPassword}`
\set schoolExperienceDB `echo ${DATABASE_NAME}`
CREATE DATABASE :schoolExperienceDB;
CREATE USER railsappuser WITH PASSWORD :'postgresUserPassword';
GRANT ALL PRIVILEGES ON DATABASE :schoolExperienceDB TO railsappuser;
\c :schoolExperienceDB
CREATE EXTENSION IF NOT EXISTS postgis;
