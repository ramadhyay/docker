# Data Analytics Stack

This is a data analyitics stack which can be used to simulate your data pipeline all the way to reporting in  BIP tool.



The stack includes

| Name            | Type       | Container Name         | Description                                            |
| --------------- | ---------- | ---------------------- | ------------------------------------------------------ |
| **Apache NiFi** | Middleware | **apache_nifi**        | Data integration platform ETL                          |
| **PostgresSQL** | Database   | **postgres_db**        | Open source relational database                        |
| **ClickHouse**  | Database   | **clickhouse_db**      | *Columnar* database. Uses *community edition*          |
| **Metabase**    | BI         | **metabase_analytics** | BI tool to perform analytics. Uses *community edition* |
| **pgAdmin 4**   | Client     | **pgadmin_ui**         | Client to manage *PostgresSQL*                         |



## Accessing the Tools

##### Apache NiFi

| URL       | `https://localhost:8443` |
| --------- | ------------------------ |
| User Name | admin                    |
| Password  | welcome2nifni            |



**URL**: `https://localhost:8443`

**User Name**: admin

**Password**: welcome2nifi



##### PostgreSQL

**Host (external access)**: localhost

**Host (intra container access)**: postgres_db

**Port**: 5432










