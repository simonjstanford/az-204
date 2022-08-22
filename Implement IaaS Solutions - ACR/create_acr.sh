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

# create the azure container registry
az login
ACR_NAME='simonpsdemoacr'
az acr create --resource-group RND-RG-DCI-TRAINING --name $ACR_NAME --sku Standard
az acr login --name $ACR_NAME
ACR_LOGINSERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
echo $ACR_LOGINSERVER

