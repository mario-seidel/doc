# doc

Docker Deployment Script

**Usage:**

For example we want to build a TYPO3 environment for developing, testing and
publishing the image to a production server. First we have to initialize the
project by simple typing

```export DOC_USERNAME=myusername```
```doc initproject mytypo3```

This will build all needed images and you will be on a system where the
development can be started immediately after the TYPO3 installation is finished.

When building is finisht you will got 2 images:
- myusername/mytypo3:1.0
- myusername/typo:7.6

```doc up local``` - Brings up the containers configured in docker-compose.local.yml and mounts
the sources directory as volume to the web container for local development.

```doc deploy username/projectname``` - tags and push the image passed as second parameter
(image name must exist in docker-compose.yml)
