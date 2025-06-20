using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.AzureAppConfiguration;
using Azure.Identity;

//string endpoint = "YOUR_APP_CONFIGURATION_ENDPOINT"; // Replace with your Azure App Configuration endpoint
string endpoint = "https://mslearnexercise.azconfig.io"; // Replace with your Azure App Configuration endpoint

// Configure authentication options for connecting to Azure Key Vault
DefaultAzureCredentialOptions credentialOptions = new()
{
    ExcludeEnvironmentCredential = true,
    ExcludeManagedIdentityCredential = true
};


var builder = new ConfigurationBuilder();
builder.AddAzureAppConfiguration(options =>
{
    
    options.Connect(new Uri(endpoint), new DefaultAzureCredential(credentialOptions));
});

var config = builder.Build();
Console.WriteLine(config["color"] ?? "Hello world!");