# LEP Docker

## Overview

_Not meant for production._

This is a repository meant to support your development environment configuration activities by supplying a LEP (Linux, Nginx, PHP) docker image. It is not meant for production but can be easily tweaked if necessary. It is based on the [Laravel Settler](https://github.com/laravel/settler) provisioning script.

It uses the latest version of Ubuntu. Different branches were set up to configure different versions of PHP. All images are available in Docker Hub.

## Technical requirements

- [Docker 18.03^](https://docs.docker.com/install/linux/docker-ce/ubuntu/)
- [Docker Compose 1.22^](https://docs.docker.com/compose/install/#install-compose)

## Build

To build this image it is only necessary to run the docker build command against the dockerfile available. Additionally,  you can also user docker-compose to build the image for you. In this case, we will go step by step:

```bash
imageName=lep
label=php7.2

docker build -t ${imageName}:${label} .
```

In the above command, feel free to replace `imageName` and `label` to whichever image label you want to use.

## Configure your App

To succesfully use your newly built image with your project, we are going to run a container from it and then configure your app to be served by Nginx.
There are two ways to accomplish this, by using the dockerfile with plain docker commands or to use the `docker-compose.build.yml`.

### By using the Dockerfile

- First, run the container (remember to use the `imageName` and `label` you previously used):

```bash
projectDir=/path/to/my/project/

docker container run --rm --name myLEPContainerTest --volume ${projectDir}:/app --port 8000:80 ${imageName}:${label} supervisord

# Note: Supervisor is the service configured in the image to maintain nginx and php-fpm as entrypoints.
```

- Next, we are going to use the `serve.sh` script. It helps us configure an nginx configuration file for your app:

```bash
myAppDomain=myapp.local
publicDir=public

docker container exec myLEPContainerTest ./serve.sh ${myAppDomain} /app/${publicDir}

# Note: The publicDir variable should point to the directory where the index.php file lives.
```

- Finally, go to `http://localhost:8000` to access your app. That's it! You should see your app landing page. If you need a database, please use the docker compose method that automatically sets up a DB service for you.

### By using Docker Compose

- First, edit the `.env` file to match your environment needs. The `DB_*` variables can be customized as you prefer, they are used to configure your DB service from scratch. The DB service is configured to be run using postgres, but feel free to change it to your preffered DB engine.

- Next, rename the `docker-compose.build.yml` to `docker-compose.yml` and start up the services:

```bash
mv docker-compose.build.yml docker-compose.yml
docker-compose up -d
```

- We will now create the nginx configuration file for your app:

```bash
# We need to get inside the web container first
docker-compose exec app_web bash

# Then, use the serve.sh script
cd /; ./serve.sh ${myAppDomain} /app/${publicDir}
```

- Go to `http://localhost:8000` to view your app landing page. You can use the DB/Adminer service to set up your migrations, seed data, etc. And that's it!

## Additional Notes

- Thanks to @shincoder for creating [homestead-docker](https://github.com/shincoder/homestead-docker) and that being the basis of what's defined here.
