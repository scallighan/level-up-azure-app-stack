docker build -t yahoomcp .
    
docker stop yahoomcp
docker rm yahoomcp

docker run -d --env MCP_API_KEY=123 -p 8000:8000 --name yahoomcp yahoomcp
docker logs -f yahoomcp