# Becalm server

This server holds all data used by the system:

- patients
- devices measuring patients' health
- sensor data posted by the devices

## Getting started 🚀

### Database

Install a Postgres 12 server
https://www.postgresql.org/download/

Create a new database called `becalm` add a user `becalm` and grant privileges to it
```
becalm@becalmHost:~/$ sudo -i -u postgres
postgres@becalmHost:~$ psql
psql (12.4 (Debian 12.4-1.pgdg90+1))
Type "help" for help.

postgres=# CREATE DATABASE becalm;
CREATE DATABASE
postgres=# CREATE USER becalm WITH PASSWORD 'becalmpwd' ;
CREATE ROLE
postgres=# GRANT ALL PRIVILEGES ON DATABASE becalm to becalm ;

```

Run the setup-dev.sql script located under the folder pg-database (it will create the data model and preload some data for development purposes)

### Server

Install dependencies and start the dev server:

```
npm install
npm run start
```

The app will be available from http://localhost:4000.

### Production

TBD

Identified points:

- create database script with model only items (no dev/test data)
- alternatively use a YAML-type system to track changes in the PG database model
