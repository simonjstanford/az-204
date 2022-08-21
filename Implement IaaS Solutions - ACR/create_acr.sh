# Build the webapp
dotnet build ./webapp

# Test the app before we containerise it
# dotnet run --project ./webapp
# curl http://localhost:5000

dotnet publish -c Release ./webapp

# build and run the docker image
docker build -t webappimage:v1 .
docker run --name webapp --publish 8080:80 --detach webappimage:v1

# test
sleep 5
curl http://localhost:8080

# tidy up
docker stop webapp
docker rm webapp