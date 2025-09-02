# chronon
"I put my ai backend in my RV"

## Prerequisites
* Install Docker
* Install ollama on the host directly (its wildly more efficient)

## Running the Cluster
To start the cluster use `docker compose up -d`, To stop the cluster use `docker compose down`

## Files & Paths
* `data/` This is where all of the services store their actual files
* `documents/` This is where `n8n`, and `unstructured` can see & manipulate files
* `docker/` These are custom images for specific needs that are used in compose
* `config/` These are config files read by specific services

## Route Table

| Service       | Internal                                | External               |
|---------------|-----------------------------------------|------------------------|
| n8n           | http://n8n_svc:5678                     | http://localhost:5678  |
| unstructured  | http://unstructured                     | http://localhost:8001  |
| ollama        | http://ollama                           | http://localhost:11434 |
| postgres      | postgres:5432                           | localhost:5432         |
| adminer (sql) | http://adminer:8081                     | http://localhost:8081  |
| redis         | redis:6379                              | localhost:6379         |
| redisinsight  | http://redisinsight:8082                | http://localhost:8082  |
| mongodb       | mongo:27017                             | localhost:27017        |
| qdrant        | http://qdrant or http://qdrant_svc:6333 | http://localhost:6333  |

## Additional n8n nodes

You can find them at https://www.npmjs.com/search?q=keywords%3An8n-community-node-package&page=2&perPage=20

* [n8n-nodes-qdrant](https://www.npmjs.com/package/n8n-nodes-qdrant) Greater control over qdrant through n8n via REST
* [n8n-nodes-webpage-content-extractor](https://www.npmjs.com/package/n8n-nodes-webpage-content-extractor) This is an n8n community node. It extracts the contents from a given URL. Similar to the 'Reader' mode in your browser, it ignores headers, footers, banners, etc.
* [n8n-nodes-globals](https://www.npmjs.com/package/n8n-nodes-globals) Lets you use global constants without paying a billion a year to n8n. Global constants across your workflows
* [n8n-nodes-text-manipulation](https://www.npmjs.com/package/n8n-nodes-text-manipulation) Text manipulation allows various manipulations of strings. 
* [n8n-nodes-elevenlabs](https://www.npmjs.com/package/@elevenlabs/n8n-nodes-elevenlabs) This is the official ElevenLabs n8n community node.
* [n8n-nodes-edit-image-plus](https://www.npmjs.com/package/n8n-nodes-edit-image-plus) Image editing utilities
* [n8n-nodes-supercode](https://www.npmjs.com/package/@kenkaiii/n8n-nodes-supercode) No more 15+ code nodes to solve a basic problem