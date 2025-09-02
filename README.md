# Setup
1. Install docker on the host
2. Install ollama directly on the host
3. open terminal cd into the folder where this docker-compose.yaml file is
4. run `docker compose up -d` and wait 10s (~700mb)
  * run `ollama pull gpt-oss:20b` (~14gb)
  * run `ollama pull nomic-embed-text:latest` (~300mb)
5. Open Browser goto `http://localhost:6333/dashboard#/collections` (qdrant) and click create collection
  * Name it `main` specifically, Use case is `Global Search` Configuration set to `Simple Single Embedding` Choose dimensions is `768` with `Cosine` then Continue then Finish
6. Open Browser goto `http://localhost:5678/` (n8n) and setup owner account (highly recommend free registration but not essential)
  * Go to `http://localhost:5678/home/credentials` and click the dropdown next to `Create Workflow` button, and select `Create Credential`
  * Create an `Ollama` with the Base Url set to `http://host.docker.internal:11434` (leave api key blank)
  * Create a `QDrant API` with the Rest URI set to `http://host.docker.internal:6333` (api key blank)
  * Create a `QDrantAPI` with the Qdrant Url set to `http://host.docker.internal:6333` (api key blank) (dont ask me why you need both but you do)
7. Go back to n8n at `http://localhost:5678/home/workflows` click `Create Workflow`
  * On the top right click the ... button and select `Import from File` and choose the provided RAG.json file i supplied
8. Save the workflow and profit!

# To Load in Data
1. Open workflow and click execute workflow
2. A form will popup and ask you to upload a file, choose any text document
3. Hit submit and close the form window when it uploads and wait for the workflow to finish executing
4. Verify the data was vectorized by going to `http://localhost:6333/dashboard#/collections/main#info` (note `points_count`)

# To Talk to agent about data
1. Open workflow and click open chat window
2. Just talk to it, watch the workflow use the query tool, you can also see this in logs

# Memory Requirements
* n8n (under 1gb)
* qdrant under 1g if your using my configuration, but if the collection is on a ramdisk, it will increase as you add data, 1gb per 10k points is safe
* postgres (nothing bro)
* ollama:
  * gpt-oss:20b ~16gb vram (otherwise cpu inference, will be slow)
  * gpt-oss:120b ~80gb vram (otherwise slow as fuck)

# Model requirements
* Feel free to swap out the embedding model, though `nomic-embed-text` is the best open source model you can run cheaply so id stick with that
* Changing the model, i wouldnt recommend running anything lower than 20b, tool calling is actually kind of hard for models, the fact that gpt20b can do it reliably is kind of a miracle, but if the model doesnt support tool calling you will need a different query flow (i.e. direct prompt injection)

Cheers!
