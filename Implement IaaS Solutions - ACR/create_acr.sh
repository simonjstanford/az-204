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
RESOURCE_GROUP='RND-RG-DCI-TRAINING'
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Standard
az acr login --name $ACR_NAME
ACR_LOGINSERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
echo $ACR_LOGINSERVER

# Tag the container image using the login server name
docker tag webappimage:v1 $ACR_LOGINSERVER/webappimage:v1
docker image ls $ACR_LOGINSERVER/webappimage:v1
docker image ls

# Push the image to the azure container registry
docker push $ACR_LOGINSERVER/webappimage:v1

# Show the repos in the ACR
az acr repository list --name $ACR_NAME --output table
az acr repository show-tags --name $ACR_NAME --repository webappimage --output table


####
# Alternatively we could build the container in Azure instead of locally using Tasks
###
az acr build --image "webappimage:v1-acr-task" --registry $ACR_NAME .
az acr repository show-tags --name $ACR_NAME --repository webappimage --output table


# create a container instance that uses an example container from microsoft
az container create \
   --resource-group $RESOURCE_GROUP \
   --name simon-psdemo-hello-world-cli \
   --dns-name-label simon-psdemo-hello-world-cli \
   --image mcr.microsoft.com/azuredocs/aci-helloworld \
   --ports 80

az container show --resource-group $RESOURCE_GROUP --name simon-psdemo-hello-world-cli
URL=$(az container show --resource-group $RESOURCE_GROUP --name simon-psdemo-hello-world-cli --query ipAddress.fqdn | tr -d '"')
echo $URL

#now create a container instance out of the container we built at the start
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query id --output tsv)
ACR_LOGINSERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)

echo "ACR ID: $ACR_REGISTRY_ID"
echo "ACR Login Server: $ACR_LOGINSERVER"

# Create a service principal and get the password and ID, this will allow Azure Container Instances to pull image from our ACR
SP_NAME=acr-service-principal
SP_PASSWD=$(az ad sp create-for-rbac \
    --name http://$ACR_NAME-pull \
    --scopes $ACR_REGISTRY_ID \
    --role acrpull \
    --query password \
    --output tsv)

SP_APPID=$(az ad sp list \
    --display-name http://$ACR_NAME-pull \
    --query '[].appId' \
    --output tsv)

echo "Service principal ID: $SP_APPID"
echo "Service principal password: $SP_PASSWD"


# Create the container in ACI, this will pull our image named
az container create \
    --resource-group $RESOURCE_GROUP \
    --name simon-psdemo-webapp-cli \
    --dns-name-label simon-psdemo-webapp-cli \
    --ports 80 \
    --image $ACR_LOGINSERVER/webappimage:v1 \
    --registry-login-server $ACR_LOGINSERVER \
    --registry-username $SP_APPID \
    --registry-password $SP_PASSWD 

az container show --resource-group $RESOURCE_GROUP --name simon-psdemo-webapp-cli
URL=$(az container show --resource-group $RESOURCE_GROUP --name simon-psdemo-webapp-cli --query ipAddress.fqdn | tr -d '"')
echo $URL
curl $URL

az container logs --resource-group $RESOURCE_GROUP --name simon-psdemo-webapp-cli

az container delete  \
    --resource-group $RESOURCE_GROUP \
    --name simon-psdemo-webapp-cli \
    --yes