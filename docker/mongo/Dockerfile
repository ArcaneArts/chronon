FROM mongo:8-noble
COPY mongod.conf /etc/mongod.conf
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/
CMD ["mongod", "--config", "/etc/mongod.conf"]