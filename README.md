# doc

Docker Deployment Script

**Usage:**

First, you have to adjust the path and image names specified in docker-compose.yml file.

```doc up local``` - Brings up the containers configured in docker-compose.local.yml and mounts the sources directory as volume to the web container for local development.

```doc deploy username/projectname``` - Builds, tags and push the image passed as second parameter (image name must exist in docker-compose.yml)
