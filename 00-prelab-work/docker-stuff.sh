docker stop lab
docker rm lab


docker build -t lab .

docker run --env-file .env -p 8000:80 -p 8888:8888 --name lab lab