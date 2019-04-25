\set postgresUserPassword `echo ${postgresUserPassword}`
\set schoolExperienceDB `echo ${DATABASE_NAME}`
\set dbuser `echo ${dbuser}`
CREATE DATABASE :schoolExperienceDB;
CREATE USER :dbuser WITH PASSWORD :'postgresUserPassword';
GRANT ALL PRIVILEGES ON DATABASE :schoolExperienceDB TO :dbuser;
\c :schoolExperienceDB
CREATE EXTENSION IF NOT EXISTS postgis;
