#!/bin/bash
# This script deploys resources for the exercise, used for testing
# Make sure you are logged in to the account you want to use.
# Be sure to update the resource group name.

resourceGroup="rg-exercises"

dotnet new blazor # Create a new Blazor app
dotnet build # Build the Blazor app
dotnet publish -c Release -o ./publish # Publish the Blazor app, need for zip file deployment
cd publish
zip -r ../app.zip . # Create a zip file of the published app
cd ..
az webapp deploy  --name jjkcliblazor --resource-group $resourceGroup --src-path ./app.zip